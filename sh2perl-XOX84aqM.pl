#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

my $main_exit_code = 0;
my $output         = q{};
our $CHILD_ERROR;

$main_exit_code = system('handle_all_ucf_files', $PKGDIR, $LOCDIR) >> 8;
open my $fh, '>', '$LOCF' or die "$LOCF: $!\n";
say {*fh} "this is a locally changed file";
close $fh;
$main_exit_code = system('bash', 'take_ref') >> 8;
$main_exit_code = system('handle_all_ucf_files', $PKGDIR, $LOCDIR) >> 8;
if (do {
$main_exit_code = system('is_local', $LOCF) >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('check_ucfq_number', q{1}) >> 8;
}
return $?;

exit $main_exit_code;
