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

my $action;
my @action;
my %action;
my $crondir;
my @crondir;
my %crondir;
my $tab_links;
my @tab_links;
my %tab_links;
my $tab_owner;
my @tab_owner;
my %tab_owner;
my $tab_name;
my @tab_name;
my %tab_name;

my $MAGIC_1730 = 1_730;
my $MAGIC_600  = 600;

$__set_e = 1;
$crondir = "/var/spool/cron";
$action = "$_[0]";
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
    $main_exit_code = system('systemd-sysusers', (defined ($ENV{DPKG_ROOT} // q{}) && ($ENV{DPKG_ROOT} // q{}) ne q{} ? ($ENV{DPKG_ROOT} // q{}) : '--root="$DPKG_ROOT"'), 'cron-daemon-common.conf') >> 8;
}
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
if ((-x "$(command -v systemd-tmpfiles)")) {
                $main_exit_code = system('systemd-tmpfiles', (defined ($ENV{DPKG_ROOT} // q{}) && ($ENV{DPKG_ROOT} // q{}) ne q{} ? ($ENV{DPKG_ROOT} // q{}) : '--root="$DPKG_ROOT"'), '--create', 'cron-daemon-common.conf') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
}
if ("$action" ne configure) {
exit 0;
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('getent', 'group', 'crontab') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('addgroup', "--" . "sys" . "tem", 'crontab') >> 8;
}
if ((-d $crondir/crontabs)) {
do {
    my ($owner, $group) = split /:/, 'root:crontab', 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ($crondir, '/crontabs') or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
chmod(oct('1730'), ($crondir, '/crontabs')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    chdir($crondir);
    $CHILD_ERROR = 0;
# set +e not implemented
    for my $tab_name (q{*}) {
        if ("$tab_name" eq "*") {
            next;            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        $tab_links = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'stat', '-c', '%h', "$tab_name");
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
};
        $tab_owner = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'stat', '-c', '%U', "$tab_name");
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
};
if ((!-f "$tab_name")) {
            do {
    my $__echo_line = "Warning: $tab_name is not a regular file!";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
next;
}
        else {
            if (($tab_links != 1)) {
                do {
    my $__echo_line = "Warning: $tab_name has more than one hard link!";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
next;
}
            else {
                if ("$tab_owner" ne "$tab_name") {
                    do {
    my $__echo_line = "Warning: $tab_name name differs from owner $tab_owner!";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
next;
                }
            }
        }
do {
    my ($owner, $group) = split /:/, "$tab_owner:crontab", 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ("$tab_name") or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
chmod(oct('600'), ("$tab_name")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
$__set_e = 1;
}

exit $main_exit_code;
