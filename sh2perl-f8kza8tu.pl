#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $input;
my @input;
my %input;
$input = do { my @_qx_cmd = ("mktemp 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ($CHILD_ERROR != 0) {
        $input = '/tmp/input';
}
my $output;
my @output;
my %output;
$output = do { my @_qx_cmd = ("mktemp 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ($CHILD_ERROR != 0) {
        $output = '/tmp/test';
}
# Builtin command 'trap' with dynamic handler not supported

exit $main_exit_code;
