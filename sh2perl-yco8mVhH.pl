#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy move);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

$main_exit_code = system('handle_all_ucf_files', $PKGDIR, $LOCDIR) >> 8;
use File::Copy qw(copy);
if ( -e 'package-changed' ) {
    if ( -d $PKGF ) {
        require File::Copy; File::Copy::copy('package-changed', $PKGF . '/' . ('package-changed' =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy('package-changed', $PKGF);
    }
} else {
    croak "cp: cannot stat 'package-changed': No such file or directory\n";
}
if ( -e "$LOCF" ) {
    if ( -d "$LOCF" ) {
        carp "rm: carping: ", $LOCF,
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "$LOCF" ) {
                    }
        else {
            carp "rm: carping: could not remove ", $LOCF,
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
$main_exit_code = system('bash', 'take_ref') >> 8;
$ENV{UCF_FORCE_CONFFNEW} = 1;
$main_exit_code = system('handle_all_ucf_files', $PKGDIR, $LOCDIR) >> 8;
if (do {
$main_exit_code = system('is_package', $LOCF) >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('check_ucfq_number', q{1}) >> 8;
}
return $?;

exit $main_exit_code;
