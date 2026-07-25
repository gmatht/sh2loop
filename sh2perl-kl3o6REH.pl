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
my $flavour;
my @flavour;
my %flavour;
$flavour = "default";
my $basedir;
my @basedir;
my %basedir;
$basedir = "/etc/selinux/" . ${flavour};
if ("$_[0]" =~ /^purge$/msx) {
    if ( -e "${basedir}" ) {
        if ( -d "${basedir}" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("${basedir}", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", ${basedir}, ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "${basedir}" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ${basedir},
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if ( -e "/var/lib/selinux/" ) {
        if ( -d "/var/lib/selinux/" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("/var/lib/selinux/", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "/var/lib/selinux/", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "/var/lib/selinux/" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/lib/selinux/",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "$flavour" ) {
        if ( -d "$flavour" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$flavour", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", $flavour, ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$flavour" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $flavour,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
        if ((-d '/var/lib/selinux/final/')) {
        rmdir ('/var/lib/selinux/final/') or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
} elsif ("$_[0]" =~ /^remove$/msx or "$_[0]" =~ /^upgrade$/msx or "$_[0]" =~ /^failed-upgrade$/msx or "$_[0]" =~ /^abort-install$/msx or "$_[0]" =~ /^abort-upgrade$/msx or "$_[0]" =~ /^disappear$/msx) {
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
    exit 1;
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/selinux/default/users/local.users', "2:2.20140421-10\\", q{~}, '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', "/etc/selinux/default/users/" . "sys" . "tem" . ".users", "2:2.20140421-10\\", q{~}, '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/selinux/default/modules/semanage.read.LOCK', "2:2.20140421-10\\", q{~}, '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/selinux/default/modules/semanage.trans.LOCK', "2:2.20140421-10\\", q{~}, '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/selinux/default/modules/active/file_contexts.local', "2:2.20140421-10\\", q{~}, '--', "@ARGV") >> 8;
exit 0;

exit $main_exit_code;
