#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

my $main_exit_code = 0;
my $output         = q{};
our $CHILD_ERROR;

my $image_path;
my $DEB_MAINT_PARAMS;
my $version;

$__set_e = 1;
if (!("$DEB_MAINT_PARAMS" eq q{})) {
    exit 0;
}
$version = "$_[0]";
$image_path = "$_[1]";
if (!("$version" ne q{})) {
    exit 0;
}
if (!("$image_path" ne q{})) {
    exit 0;
}
$main_exit_code = system('linux-update-symlinks', 'install', $version, $image_path) >> 8;
exit 0;

exit $main_exit_code;
