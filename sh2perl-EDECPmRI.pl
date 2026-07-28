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

my $EUID;
my @EUID;
my %EUID;

my $SERVICE_FILE;
my @SERVICE_FILE;
my %SERVICE_FILE;
$SERVICE_FILE = "autossh.service";
my $SERVICE_NAME;
my @SERVICE_NAME;
my %SERVICE_NAME;
$SERVICE_NAME = "autossh";
print "Installing autossh " . "sys" . "tem" . "d daemon...\n";
if (($EUID != 0)) {
    print "This script must be run as root (use sudo)\n";
exit 1;
}
if (!(!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('command', '-v', 'autossh') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};))) {
    print "Error: autossh is not installed. Please install it first.\n";
    print "On Ubuntu/Debian: sudo apt-get install autossh\n";
    print "On CentOS/RHEL: sudo yum install autossh\n";
    print "On Arch: sudo pacman -S autossh\n";
exit 1;
}
print "Copying service file to /etc/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/\n";
use File::Copy qw(copy);
if ( -e "$SERVICE_FILE" ) {
    if ( -d "/etc/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/" ) {
        require File::Copy; File::Copy::copy("$SERVICE_FILE", "/etc/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/" . '/' . ("$SERVICE_FILE" =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy("$SERVICE_FILE", "/etc/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/");
    }
} else {
    croak "cp: cannot stat '$SERVICE_FILE': No such file or directory\n";
}
print "Reloading " . "sys" . "tem" . "d daemon...\n";
$main_exit_code = system('systemctl', 'daemon-reload') >> 8;
print "Enabling service to start on boot...\n";
$main_exit_code = system('systemctl', 'enable', "$SERVICE_NAME") >> 8;
print "Starting autossh service...\n";
$main_exit_code = system('systemctl', 'start', "$SERVICE_NAME") >> 8;
print "Checking service status...\n";
$main_exit_code = system('systemctl', 'status', "$SERVICE_NAME", '--no-pager') >> 8;
print "\n";
print "Installation complete!\n";
print "\n";
print "Useful commands:\n";
do {
    my $__echo_line = "  Check status:  sudo " . "sys" . "tem" . "ctl status $SERVICE_NAME";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    my $__echo_line = "  Start service: sudo " . "sys" . "tem" . "ctl start $SERVICE_NAME";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    my $__echo_line = "  Stop service:  sudo " . "sys" . "tem" . "ctl stop $SERVICE_NAME";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    my $__echo_line = "  View logs:     sudo journalctl -u $SERVICE_NAME -f";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    my $__echo_line = "  Disable boot:  sudo " . "sys" . "tem" . "ctl disable $SERVICE_NAME";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;

exit $main_exit_code;
