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
    if ( -d $PKGRF ) {
        require File::Copy; File::Copy::copy('package-changed', $PKGRF . '/' . ('package-changed' =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy('package-changed', $PKGRF);
    }
} else {
    croak "cp: cannot stat 'package-changed': No such file or directory\n";
}
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
do {
    my $__echo_line = "rename_ucf_file $ENV{LOCF} $ENV{LOCRF}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
$main_exit_code = system('rename_ucf_file', $LOCF, $LOCRF) >> 8;
do {
    my $__echo_line = "handle_all_ucf_files $ENV{PKGDIR} $ENV{LOCDIR}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
$ENV{UCF_FORCE_CONFFOLD} = 1;
$main_exit_code = system('handle_all_ucf_files', $PKGDIR, $LOCDIR) >> 8;
print "final check\n";
if (do {
if (do {
$main_exit_code = system('is_deleted', $LOCRF) >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('is_deleted', $LOCF) >> 8;
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('check_ucfq_number', q{1}) >> 8;
}
return $?;

exit $main_exit_code;
