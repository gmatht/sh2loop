#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $DPKG_ROOT;

$__set_e = 1;
my $mandir = '/usr/share/man';
my $slaves;
if ("$1" eq "configure") {
    $slaves = "--slave $mandir/man8/aptitude.8.gz aptitude.8.gz $mandir/man8/aptitude-curses.8.gz";
    my $lang;
    for my $lang ('cs', 'de', 'es', 'fi', 'fr', 'gl', 'it', 'ja', 'pl') {
        $slaves = "$slaves --slave $mandir/$lang/man8/aptitude.8.gz aptitude.$lang.8.gz $mandir/$lang/man8/aptitude-curses.8.gz";
    }
;
    $main_exit_code = system('update-alternatives', '--install', '/usr/bin/aptitude', 'aptitude', '/usr/bin/aptitude-curses', '30', $slaves) >> 8;
}
if ((("$1" eq "configure" && (-x "`command -v update-menus`")) && (-x "$DPKG_ROOT`command -v update-menus`"))) {
    $main_exit_code = system('bash', 'update-menus') >> 8;
}
