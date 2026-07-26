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

my $CMD;
my @CMD;
my %CMD;
$CMD = ( ( basename($_[0]) ) =~ s|^.*/||sr );
delete $ENV{LD_LIBRARY_PATH};
delete $ENV{PYTHONPATH};
delete $ENV{PYTHONDONTWRITEBYTECODE};
$ENV{PATH} = '';
if ("$(id -u)" eq "0") {
# Builtin command 'exec' not implemented
}
# Builtin command 'exec' not implemented

exit $main_exit_code;
