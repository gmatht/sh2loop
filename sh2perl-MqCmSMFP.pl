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
my $err;
my $force = 0;
if ( -e "$PKGF" ) {
    my $dest = $PKGRF;
    if ( -e $dest && -d $dest ) {
        my $source_name = "$PKGF";
        $source_name =~ s{^.*[\/]}{};
        $dest = "$dest/$source_name";
    }
    if ( -e $dest && !$force ) {
        croak "mv: $dest: File exists (use -f to force overwrite)\n";
    }
    my $dest_dir = $dest;
    $dest_dir =~ s/\/[^\/]*$//msx;
    if ( $dest_dir eq $dest ) {
        $dest_dir = q{};
    }
    if ( $dest_dir ne q{} && !-d $dest_dir ) {
        my $err;
        make_path( $dest_dir, { error => \$err } );
        if ( @{$err} ) {
            croak "mv: cannot create directory $dest_dir: $err->[0]\n";
        }
    }
    require File::Copy;
    if ( File::Copy::move( "$PKGF", $dest ) ) {
    } else {
        croak
  "mv: cannot move "$PKGF" to $dest: $ERRNO\n";
    }
} else {
    croak "mv: "$PKGF": No such file or directory\n";
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
print "rename_ucf_file\n";
$main_exit_code = system('rename_ucf_file', $LOCF, $LOCRF) >> 8;
print "handle_all_ucf_files\n";
$main_exit_code = system('handle_all_ucf_files', $PKGDIR, $LOCDIR) >> 8;
if (do {
if (do {
$main_exit_code = system('is_deleted', $LOCF) >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('is_deleted', $LOCRF) >> 8;
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('check_ucfq_number', q{1}) >> 8;
}
return $?;

exit $main_exit_code;
