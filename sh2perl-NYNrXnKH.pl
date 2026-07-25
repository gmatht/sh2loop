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

$__set_e = 1;
if ("$_[0]" =~ /^purge$/msx) {
    if ( -e "/etc/bash_completion" ) {
        if ( -d "/etc/bash_completion" ) {
            carp "rm: carping: ", "/etc/bash_completion",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/bash_completion" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/bash_completion",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if ((-d '/etc/bash_completion.d')) {
        my $f;
        for my $f (do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { if (-f $_ && $_ =~ /^.*\.dpkg-.*$/msx) { push @find_results, $File::Find::name; } }, '/etc/bash_completion.d/');
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
}) {
            $main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', scalar reverse( (scalar reverse ${f}) =~ s/^.*?-gkpd\.//r ), '1:1.3-1', '--', "@ARGV") >> 8;
        }
    }
} elsif ("$_[0]" =~ /^remove$/msx or "$_[0]" =~ /^upgrade$/msx or "$_[0]" =~ /^failed-upgrade$/msx or "$_[0]" =~ /^abort-install$/msx or "$_[0]" =~ /^abort-upgrade$/msx or "$_[0]" =~ /^disappear$/msx) {
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "postrm called with unknown argument \\" . chr(96) . "$_[0]'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    exit 1;
}
exit 0;

exit $main_exit_code;
