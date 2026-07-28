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
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/mc/edit.spell.rc', '3:4.8.5-1', '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/mc/mc.charsets', '3:4.8-1', '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/mc/mc.ext', '3:4.8.29-2', '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/mc/mc.lib', '3:4.8-1', '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/mc/mc.menu.sr', '3:4.8.17-0', '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/mc/Syntax', '3:4.8-1', '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'mv_conffile', '/etc/mc/cedit.menu', '/etc/mc/mcedit.menu', '3:4.8-1', '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'mv_conffile', '/etc/mc/mc.keymap.emacs', '/etc/mc/mc.emacs.keymap', '3:4.8.8-0', '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'mv_conffile', '/etc/mc/mc.keymap.default', '/etc/mc/mc.default.keymap', '3:4.8.8-0', '--', "@ARGV") >> 8;

exit $main_exit_code;
