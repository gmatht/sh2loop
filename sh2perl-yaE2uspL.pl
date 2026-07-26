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

$main_exit_code = system('.', '/etc/orangepi-release') >> 8;
do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
    print "update-initramfs: Converting to u-boot format\n";
};
my $tempname;
my @tempname;
my %tempname;
$tempname = "/boot/uInitrd-$_[0]";
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('mkimage', '-A', $INITRD_ARCH, '-O', 'linux', '-T', 'ramdisk', '-C', 'gzip', '-n', 'uInitrd', '-d', $2, $tempname) >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
symlink q{f}, '/boot/uInitrd' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if ($CHILD_ERROR != 0) {
        my $err;
    my $force = 0;
    if ( -e "$tempname" ) {
        my $dest = '/boot/uInitrd';
        if ( -e $dest && -d $dest ) {
            my $source_name = "$tempname";
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
        if ( File::Copy::move( "$tempname", $dest ) ) {
        } else {
            croak
  "mv: cannot move "$tempname" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "$tempname": No such file or directory\n";
    }
}
exit 0;

exit $main_exit_code;
