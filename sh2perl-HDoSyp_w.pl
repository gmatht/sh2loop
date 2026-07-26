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

my $DPKG_ROOT;
my @DPKG_ROOT;
my %DPKG_ROOT;

$__set_e = 1;
if ("$_[0]" =~ /^purge$/msx) {
    if ((-d '/var/lib/smartmontools')) {
if ( -e "/var/lib/smartmontools" ) {
            if ( -d "/var/lib/smartmontools" ) {
                my $err;
                require File::Path;
                File::Path::remove_tree("/var/lib/smartmontools", {error => \$err});
                if (@{$err}) {
                    carp "rm: carping: could not remove ", "/var/lib/smartmontools", ": $err->[0]\n";
                }
                else {
                                    }
            }
            else {
                if ( unlink "/var/lib/smartmontools" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/var/lib/smartmontools",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
}
if (("$1" eq "remove" && (-x "/etc/init.d/smartmontools"))) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
$CHILD_ERROR = 0;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
}
if (("${DPKG_ROOT:-}" eq q{} && "$1" eq "purge")) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('update-rc.d', 'smartmontools', 'remove') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/smartd_warning.sh', "6.3\\+svn4002-2\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/init.d/smartd', "6.1\\+svn3812-1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/smartmontools/run.d/10powersave-notify', "7.0\\~", '--', "@ARGV") >> 8;
if (("$1" eq remove && (-d '/run/systemd/system'))) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', "--" . "sys" . "tem", 'daemon-reload') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
}
if ("$1" eq "purge") {
if ((-x "/usr/bin/deb-systemd-helper")) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'purge', 'smartd.service', 'smartmontools.service') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
}
exit 0;

exit $main_exit_code;
