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

my $RANDOM;
my @RANDOM;
my %RANDOM;
my $f;
my @f;
my %f;
my $THIS_SCRIPT;
my @THIS_SCRIPT;
my %THIS_SCRIPT;

$THIS_SCRIPT = "config";
my $MOTD_DISABLE;
my @MOTD_DISABLE;
my %MOTD_DISABLE;
$MOTD_DISABLE = "";
if ((-f '/etc/default/orangepi-motd')) {
        $main_exit_code = system('.', '/etc/default/orangepi-motd') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
for my $f ($MOTD_DISABLE) {
    if ($f =~ /^[$]THIS_SCRIPT$/msx) {
        exit 0;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
}
if ((eval { int( $RANDOM % 2 ) } // "") =~ /^0$/msx) {
if ((-f '/usr/sbin/orangepi-config')) {
        print "[\\e[31m General system configuration (beta)\\e[0m: \\e[1morangepi-config\\e[0m ]\n" . "\n";
        $CHILD_ERROR = 0;
}
    else {
        print "[\\e[31m Menu-driven system configuration (beta)\\e[0m: \\e[1msudo dpkg -i orangepi-config.deb\\e[0m ]\n" . "\n";
        $CHILD_ERROR = 0;
    }
}
exit 0;

exit $main_exit_code;
