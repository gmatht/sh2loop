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

my $PREREQ;
my @PREREQ;
my %PREREQ;
$PREREQ = "kernelextras";

sub prereqs {
    print $PREREQ;
if ( !( ($PREREQ) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}
if ($arg1 =~ /^prereqs$/msx) {
        prereqs();
    exit 0;
}
$main_exit_code = system('.', '/usr/share/initramfs-tools/hook-functions') >> 8;
$main_exit_code = system('copy_exec', '/bin/setfont', '/bin') >> 8;
$main_exit_code = system('copy_exec', '/bin/kbd_mode', '/bin') >> 8;
$main_exit_code = system('copy_exec', '/bin/loadkeys', '/bin') >> 8;
exit 0;

exit $main_exit_code;
