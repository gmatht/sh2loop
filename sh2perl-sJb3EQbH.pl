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

$main_exit_code = system('test', scalar(@ARGV), q{=}, q{0}) >> 8;
if ($CHILD_ERROR != 0) {
            do {
    my $__echo_line = "Usage: $PROGRAM_NAME";
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
        print "Unloads all AppArmor profiles\n";
exit 1;
}
$main_exit_code = system('/lib/apparmor/apparmor.systemd', 'stop') >> 8;

exit $main_exit_code;
