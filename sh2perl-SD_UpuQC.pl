#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $d;
my $DPKG_ROOT;

$__set_e = 1;
my $USR_MERGE = "bin lib lib32 lib64 libo32 lib64 sbin";
if (("$1" eq install || "$1" eq upgrade)) {
    for my $d ($USR_MERGE) {
if (((-d "$DPKG_ROOT/$d") && !(!(( -h "$DPKG_ROOT/$d"))))) {
print "

******************************************************************************
*
* The base-files package cannot be installed because this system has a
* split /usr.
*
* Please install the usrmerge package to convert this system to merged-/usr.
*
* For more information please read https://wiki.debian.org/UsrMerge.
*
******************************************************************************


";
exit 1;
        }
    }
    for my $d ($USR_MERGE) {
        $main_exit_code = system('dpkg-divert', '--quiet', '--package', 'base-files', '--add', '--no-rename', '--divert', q{/}, "$d.usr-is-merged", q{/}, $d) >> 8;
    }
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/default/motd-news', "11ubuntu11\\~", 'base-files', '--', "\@ARGV") >> 8;
