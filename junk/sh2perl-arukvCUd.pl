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

$__set_e = 1;
# set uo not implemented
# set pipefail not implemented
print "Testing ls * .sh:\n";
my @ls_files_0 = ();
my $ls_all_found_1 = 1;
my @ls_inputs_2 = ();
my @ls_glob_ls_inputs_2_0 = glob('*');
if ( !@ls_glob_ls_inputs_2_0 ) {
    push @ls_inputs_2, '*';
    $ls_all_found_1 = 0;
} else {
    push @ls_inputs_2, @ls_glob_ls_inputs_2_0;
}
push @ls_inputs_2, '.sh';
my @ls_files_3 = ();
my @ls_dirs_4 = ();
my $ls_show_headers_5 = scalar(@ls_inputs_2) > 1;
for my $ls_item_6 (@ls_inputs_2) {
    if ( -f $ls_item_6 ) {
        push @ls_files_3, $ls_item_6;
    }
    elsif ( -d $ls_item_6 ) {
        push @ls_dirs_4, $ls_item_6;
    }
    else {
        $ls_all_found_1 = 0;
    }
}
@ls_files_3 = sort { $a cmp $b } @ls_files_3;
@ls_dirs_4 = sort { $a cmp $b } @ls_dirs_4;
if (@ls_files_3) {
    push @ls_files_0, join("\n", @ls_files_3);
}
for my $ls_dir_7 (@ls_dirs_4) {
    my @ls_dir_entries_8 = ();
    if ( opendir my $dh, $ls_dir_7 ) {
        while ( my $file = readdir $dh ) {
            next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
            push @ls_dir_entries_8, $file;
        }
        closedir $dh;
        @ls_dir_entries_8 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_8;
        if ( $ls_show_headers_5 ) {
            if ( @ls_dir_entries_8 ) {
                push @ls_files_0, $ls_dir_7 . ":\n" . join("\n", @ls_dir_entries_8);
            } else {
                push @ls_files_0, $ls_dir_7 . ':';
            }
        }
        elsif ( @ls_dir_entries_8 ) {
            push @ls_files_0, join("\n", @ls_dir_entries_8);
        }
    }
    else {
        $ls_all_found_1 = 0;
    }
}
if (@ls_files_0) {
    print join "\n\n", @ls_files_0;
    print "\n";
}
if ( $ls_all_found_1 ) {
    local $CHILD_ERROR = 0;
    $ls_success = 1;
}
else {
    local $CHILD_ERROR = 2;
    $ls_success = 0;
    $main_exit_code = $CHILD_ERROR;
}

exit $main_exit_code;
