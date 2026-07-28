#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

$__set_e = 1;
if (("$1" eq "remove" || "$1" eq "upgrade")) {
    $main_exit_code = system('update-xmlcatalog', '--verbose', '--add', '--root', '--type', 'public', '--id', "-//FOO//DTD FOO//EN") >> 8;
    $main_exit_code = system('update-xmlcatalog', '--verbose', '--add', '--root', '--type', "sys" . "tem", '--id', "http://www.foo.org/foo/foo.dtd") >> 8;
    $main_exit_code = system('update-xmlcatalog', '--verbose', '--add', '--package', 'foo', '--type', 'public', '--id', "-//FOO//DTD FOO//EN") >> 8;
    $main_exit_code = system('update-xmlcatalog', '--verbose', '--add', '--package', 'foo', '--type', "sys" . "tem", '--id', "http://www.foo.org/foo/foo.dtd") >> 8;
}
exit 0;
