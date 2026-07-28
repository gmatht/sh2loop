#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

$main_exit_code = system('handle_all_ucf_files', $PKGDIR, $LOCDIR) >> 8;
if ( -e "$PKGF" ) {
    if ( -d "$PKGF" ) {
        carp "rm: carping: ", $PKGF,
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "$PKGF" ) {
                    }
        else {
            carp "rm: carping: could not remove ", $PKGF,
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
$main_exit_code = system('bash', 'take_ref') >> 8;
$main_exit_code = system('handle_all_ucf_files', $PKGDIR, $LOCDIR) >> 8;
if (do {
$main_exit_code = system('is_deleted', $LOCF) >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('check_ucfq_number', q{0}) >> 8;
}
return $?;

exit $main_exit_code;
