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

$main_exit_code = system('.', './setup-vars') >> 8;
do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
};
my $returntext;
my @returntext;
my %returntext;
$returntext = do { my @_qx_cmd = ("$DIALOG --backtitle 'Debian Configuration' --title 'Configuring debconf' --default-item Dialog \"$@\" --menu \"Packages that use debconf for configuration share a common look and feel. You can \\nselect the type of user interface they use.\\n\\\\n\\\\n\\\\\\nThe dialog frontend is a full-screen, character based interface, while the readline \\nfrontend uses a more traditional plain text interface, and both the gnome and kde \\nfrontends are modern X interfaces, fitting the respective desktops (but may be used \\nin any X environment). The editor frontend lets you configure things using your \\nfavorite text editor. The noninteractive frontend never asks you any questions.\\n\\\\n\\\\n\\\\\\nInterface to use:\" 0 0 6 Dialog  Readline  Gnome  Kde  Editor  Noninteractive  2>&1 2>&3"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
my $returncode;
my @returncode;
my %returncode;
$returncode = $?;
do {
local *STDERR;
open STDERR, '>', q{-} or croak "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
};
$main_exit_code = system('.', './report-string') >> 8;

exit $main_exit_code;
