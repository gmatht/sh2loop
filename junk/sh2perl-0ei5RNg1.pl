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

my $DPKG_ROOT;
my @DPKG_ROOT;
my %DPKG_ROOT;

$__set_e = 1;
if ("$_[0]" =~ /^remove$/msx or "$_[0]" =~ /^upgrade$/msx or "$_[0]" =~ /^failed-upgrade$/msx or "$_[0]" =~ /^abort-install$/msx or "$_[0]" =~ /^abort-upgrade$/msx or "$_[0]" =~ /^disappear$/msx) {
} elsif ("$_[0]" =~ /^purge$/msx) {
    if ( -e "r" ) {
        if ( -d "r" ) {
            carp "rm: carping: ", "r",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "r" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "r",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/var/lib/aptitude" ) {
        if ( -d "/var/lib/aptitude" ) {
            carp "rm: carping: ", "/var/lib/aptitude",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/var/lib/aptitude" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/lib/aptitude",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if ( -e "/var/log/aptitude" ) {
        if ( -d "/var/log/aptitude" ) {
            carp "rm: carping: ", "/var/log/aptitude",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/var/log/aptitude" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/log/aptitude",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/var/log/aptitude." ) {
        if ( -d "/var/log/aptitude." ) {
            carp "rm: carping: ", "/var/log/aptitude.",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/var/log/aptitude." ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/log/aptitude.",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "[0-9]" ) {
        if ( -d "[0-9]" ) {
            carp "rm: carping: ", "[0-9]",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "[0-9]" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "[0-9]",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e ".gz" ) {
        if ( -d ".gz" ) {
            carp "rm: carping: ", ".gz",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink ".gz" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ".gz",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "postrm called with unknown argument \\" . chr(96) . "$_[0]'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    exit 0;
}
if (((-x "`command -v update-menus`") && (-x "$DPKG_ROOT`command -v update-menus`"))) {
    $main_exit_code = system('bash', 'update-menus') >> 8;
}

exit $main_exit_code;
