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

my $basedir;
my @basedir;
my %basedir;
$basedir = '/usr/local/mysql';
my $bindir;
my @bindir;
my %bindir;
$bindir = '/usr/local/mysql/bin';
if ((-x 'Variable("bindir", false, None) /mysqld_multi')) {
    my $mysqld_multi;
    my @mysqld_multi;
    my %mysqld_multi;
    $mysqld_multi = "$bindir/mysqld_multi";
}
else {
    do {
    my $__echo_line = "Can't execute $bindir/mysqld_multi from dir $basedir";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
exit $main_exit_code;
}
if ("$_[0]" =~ /^start$/msx) {
        $CHILD_ERROR = 0;
} elsif ("$_[0]" =~ /^stop$/msx) {
        $CHILD_ERROR = 0;
} elsif ("$_[0]" =~ /^report$/msx) {
        $CHILD_ERROR = 0;
} elsif ("$_[0]" =~ /^restart$/msx) {
        $CHILD_ERROR = 0;
        $CHILD_ERROR = 0;
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "Usage: $PROGRAM_NAME {start|stop|report|restart}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
}

exit $main_exit_code;
