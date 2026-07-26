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

if ((defined ($ENV{returncode} // q{}) && ($ENV{returncode} // q{}) ne q{} ? ($ENV{returncode} // q{}) : '0') =~ /^$DIALOG_OK$/msx) {
        print "OK\n";
} elsif ((defined ($ENV{returncode} // q{}) && ($ENV{returncode} // q{}) ne q{} ? ($ENV{returncode} // q{}) : '0') =~ /^$DIALOG_CANCEL$/msx) {
        print "Cancel pressed.\n";
} elsif ((defined ($ENV{returncode} // q{}) && ($ENV{returncode} // q{}) ne q{} ? ($ENV{returncode} // q{}) : '0') =~ /^$DIALOG_HELP$/msx) {
        print "Help pressed.\n";
} elsif ((defined ($ENV{returncode} // q{}) && ($ENV{returncode} // q{}) ne q{} ? ($ENV{returncode} // q{}) : '0') =~ /^$DIALOG_EXTRA$/msx) {
        print "Extra button pressed.\n";
} elsif ((defined ($ENV{returncode} // q{}) && ($ENV{returncode} // q{}) ne q{} ? ($ENV{returncode} // q{}) : '0') =~ /^$DIALOG_ITEM_HELP$/msx) {
        print "Item-help button pressed.\n";
} elsif ((defined ($ENV{returncode} // q{}) && ($ENV{returncode} // q{}) ne q{} ? ($ENV{returncode} // q{}) : '0') =~ /^$DIALOG_TIMEOUT$/msx) {
        print "Timeout expired.\n";
} elsif ((defined ($ENV{returncode} // q{}) && ($ENV{returncode} // q{}) ne q{} ? ($ENV{returncode} // q{}) : '0') =~ /^$DIALOG_ERROR$/msx) {
        print "ERROR!\n";
} elsif ((defined ($ENV{returncode} // q{}) && ($ENV{returncode} // q{}) ne q{} ? ($ENV{returncode} // q{}) : '0') =~ /^$DIALOG_ESC$/msx) {
        print "ESC pressed.\n";
} elsif (1) {
        do {
    my $__echo_line = "Return code was $ENV{returncode}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
}

exit $main_exit_code;
