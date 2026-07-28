#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

$__set_e = 1;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/securetty', "1:4.7-1\\~", '--', "\@ARGV") >> 8;
