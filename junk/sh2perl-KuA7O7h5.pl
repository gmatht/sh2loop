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

my $new_interface_mtu-;
my @new_interface_mtu-;
my %new_interface_mtu-;

my $MAGIC_576 = 576;

$__set_e = 1;

sub set_mtu {
    my $mtu = "$_[0]";
    my $interface = "$_[1]";
if (($mtu < $MAGIC_576)) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "MTU $mtu is smaller than 576 which is the minimum for dhcpcd. Ignoring MTU.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
return;
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "/sys/class/net/" . ${interface} . "/mtu"
      or die "Cannot open file: $OS_ERROR\n";
        print ${mtu};
if ( !( (${mtu}) =~ m{\n\z}msx ) ) { print "\n"; }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
    my $__echo_line = "MTU of " . ${interface} . " set to " . ${mtu};
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
if ((!($CHILD_ERROR = 0) && "${new_interface_mtu-}" ne q{})) {
    set_mtu(($ENV{new_interface_mtu} // q{}), ($ENV{interface?} // q{}));
}

exit $main_exit_code;
