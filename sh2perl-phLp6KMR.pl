#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

$__set_e = 1;
if ("$_[0]" =~ /^configure$/msx) {
        my $ext;
    for my $ext ('new', 'neww', 'old') {
if ( -e "/usr/share/misc/pci.ids." ) {
            if ( -d "/usr/share/misc/pci.ids." ) {
                carp "rm: carping: ", "/usr/share/misc/pci.ids.",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "/usr/share/misc/pci.ids." ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/usr/share/misc/pci.ids.",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "$ext" ) {
            if ( -d "$ext" ) {
                carp "rm: carping: ", $ext,
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$ext" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", $ext,
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
} elsif ("$_[0]" =~ /^abort-upgrade$/msx or "$_[0]" =~ /^abort-remove$/msx or "$_[0]" =~ /^abort-deconfigure$/msx) {
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "postinst called with unknown argument '$_[0]'";
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
exit 0;

exit $main_exit_code;
