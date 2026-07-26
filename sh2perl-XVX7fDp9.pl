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

my $CONFIG;
my @CONFIG;
my %CONFIG;

my $MAGIC_750 = 750;

$__set_e = 1;
$CONFIG = '/etc/samba/smb.conf';
if ("$1" eq configure) {
if (!(!(do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('dpkg-statoverride', '--list', '/var/log/samba') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };))) {
chmod(oct('0750'), ('/var/log/samba')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
do {
    my ($owner, $group) = split /:/, 'root:adm', 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ('/var/log/samba') or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
    }
    $main_exit_code = system('ucf', '--three-way', '--debconf-ok', '/usr/share/samba/smb.conf', "$CONFIG") >> 8;
if ((!-e "$CONFIG")) {
        print "Install/upgrade will fail. To recover, please try:\n";
        do {
    my $__echo_line = " sudo cp /usr/share/samba/smb.conf $CONFIG";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print " sudo dpkg --configure -a\n";
}
    else {
        $main_exit_code = system('ucfr', 'samba-common', "$CONFIG") >> 8;
chmod(oct('a+r'), ("$CONFIG")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/dhcp/dhclient-enter-hooks.d/samba', "2:4.19.2\\+dfsg-2\\~", '--', "@ARGV") >> 8;

exit $main_exit_code;
