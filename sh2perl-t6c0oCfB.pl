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
$main_exit_code = system('update-alternatives', '--remove', 'ksh', '/usr/bin/zsh') >> 8;
$main_exit_code = system('update-alternatives', '--remove', 'ksh', '/bin/zsh4') >> 8;
$main_exit_code = system('update-alternatives', '--remove', 'zsh', '/bin/zsh5') >> 8;
$main_exit_code = system('update-alternatives', '--remove', 'rzsh', '/bin/zsh5') >> 8;
if ("$_[0]" =~ /^configure$/msx) {
    if (((!-e /usr/bin/zsh) && (!-L /usr/bin/zsh))) {
symlink '/bin/zsh', '/usr/bin/zsh' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
} elsif ("$_[0]" =~ /^abort-upgrade$/msx or "$_[0]" =~ /^abort-remove$/msx or "$_[0]" =~ /^abort-deconfigure$/msx) {
    exit 0;
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "postinst called with unknown argument \\" . chr(96) . "$_[0]'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    exit 0;
}
$main_exit_code = system('dpkg-maintscript-helper', 'symlink_to_dir', '/usr/share/doc/zsh', 'zsh-common', '5.0.7-3', '--', "@ARGV") >> 8;
exit 0;

exit $main_exit_code;
