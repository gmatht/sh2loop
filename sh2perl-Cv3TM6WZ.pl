#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

$main_exit_code = system('svn', 'export', '--force', 'http://svn.red-bean.com/bob/macholib/trunk/macholib/', q{.}) >> 8;
