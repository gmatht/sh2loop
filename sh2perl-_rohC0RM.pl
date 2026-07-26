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
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/bash_completion.d/dkms', "3.0.3-2\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/kernel_install.d_dkms', "3.0.3-2\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkdeb/debian/rules', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkdeb/debian/prerm', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkdeb/debian/postinst', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkdeb/debian/dirs', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkdeb/debian/copyright', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkdeb/debian/control', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkdeb/debian/compat', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkdeb/debian/changelog', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkdeb/debian/README.Debian', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkdeb/Makefile', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkbmdeb/debian/rules', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkbmdeb/debian/copyright', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkbmdeb/debian/control', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkbmdeb/debian/compat', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkbmdeb/debian/changelog', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkbmdeb/debian/README.Debian', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/template-dkms-mkbmdeb/Makefile', "3.0.3-3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dkms/sign_helper.sh', "3.0.10-8\\~", '--', "@ARGV") >> 8;

exit $main_exit_code;
