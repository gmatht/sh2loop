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
my $FILE;
my @FILE;
my %FILE;
$FILE = $HOME;
my $n;
for my $n ('.cshrc', '.profile', '.bashrc') {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("HOME"), Literal("/"), Variable("n")] }, None)')) {
        $FILE = $HOME;
        $main_exit_code = system('/', $n) >> 8;
last;
    }
}
do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
};
my $returntext;
my @returntext;
my %returntext;
$returntext = do { my @_qx_cmd = ("$DIALOG --title 'Please choose a file' \"$@\" --fselect \"$FILE\" 14 48 2>&1 2>&3"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
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
