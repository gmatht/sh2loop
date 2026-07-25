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
if ("$1" eq purge) {
do { my $rm_cmd_str = 'rm -Rf /run/samba/ /var/cache/samba/ /var/lib/samba'; system $rm_cmd_str; };
do { my $rm_cmd_str = 'rm -Rf /var/log/samba/'; system $rm_cmd_str; };
do { my $rm_cmd_str = 'rm -Rf /etc/samba/'; system $rm_cmd_str; };
if ((-x "`which ucf 2>/dev/null`")) {
        $main_exit_code = system('ucf', '--purge', '/etc/samba/smb.conf') >> 8;
    }
if ((-x "`which ucfr 2>/dev/null`")) {
        $main_exit_code = system('ucfr', '--purge', 'samba-common', '/etc/samba/smb.conf') >> 8;
    }
if ((-f '/var/lib/samba/dhcp.conf')) {
if ( -e "/var/lib/samba/dhcp.conf" ) {
            if ( -d "/var/lib/samba/dhcp.conf" ) {
                croak "rm: ", "/var/lib/samba/dhcp.conf",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "/var/lib/samba/dhcp.conf" ) {
                                    }
                else {
                    croak "rm: cannot remove ", "/var/lib/samba/dhcp.conf",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 1;
            croak "rm: ", "/var/lib/samba/dhcp.conf", ": No such file or directory\n";
        }
    }
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dhcp/dhclient-enter-hooks.d/samba', "2:4.19.2\\+dfsg-2\\~", '--', "@ARGV") >> 8;

exit $main_exit_code;
