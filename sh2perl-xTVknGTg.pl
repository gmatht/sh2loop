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

my $NAME;
my @NAME;
my %NAME;

my $PATH;
my @PATH;
my %PATH;
$PATH = "/sbin:/bin:/usr/sbin:/usr/bin";
$NAME = "plymouth-log";
my $DESC;
my @DESC;
my %DESC;
$DESC = "Boot splash manager (write log file)";
$main_exit_code = system('test', '-x', '/usr/bin/plymouth') >> 8;
if ($CHILD_ERROR != 0) {
    exit 0;
}
if ((-r "/etc/default/${NAME}")) {
    $main_exit_code = system('.', "/etc/default/" . ${NAME}) >> 8;
}
$main_exit_code = system('.', '/lib/lsb/init-functions') >> 8;
$__set_e = 1;
if ($_[0] =~ /^start$/msx) {
    if (!(    $main_exit_code = system('plymouth', '--ping') >> 8)) {
        $main_exit_code = system('/usr/bin/plymouth', 'update-root-fs', '--read-write') >> 8;
    }
} elsif ($_[0] =~ /^stop$/msx or $_[0] =~ /^restart$/msx or $_[0] =~ /^force-reload$/msx) {
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "Usage: " . $_[0] . " {start|stop|restart|force-reload}";
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
