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
if (purge eq "$1") {
    $main_exit_code = system('userdel', 'dnsmasq') >> 8;
if ( -e "/run/dnsmasq" ) {
        if ( -d "/run/dnsmasq" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("/run/dnsmasq", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "/run/dnsmasq", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "/run/dnsmasq" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/run/dnsmasq",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', "/etc/dbus-1/" . "sys" . "tem" . ".d/dnsmasq.conf", "2.89-1.1\\~", 'dnsmasq-base', '--', "@ARGV") >> 8;

exit $main_exit_code;
