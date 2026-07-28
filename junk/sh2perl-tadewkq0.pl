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

my $d;
my @d;
my %d;
my $APP_PROFILE;
my @APP_PROFILE;
my %APP_PROFILE;
my $DPKG_ROOT;
my @DPKG_ROOT;
my %DPKG_ROOT;

my $MAGIC_640 = 640;
my $MAGIC_750 = 750;

$__set_e = 1;
if ("$_[0]" =~ /^configure$/msx) {
        $main_exit_code = system('adduser', "--" . "sys" . "tem", '--group', '--quiet', '--comment', "Chrony daemon", '--home', '/var/lib/chrony', '--no-create-home', '_chrony') >> 8;
    if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'ucf') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        $main_exit_code = system('ucf', '--three-way', '/usr/share/chrony/chrony.conf', '/etc/chrony/chrony.conf') >> 8;
        $main_exit_code = system('ucf', '--three-way', '/usr/share/chrony/chrony.keys', '/etc/chrony/chrony.keys') >> 8;
if ((-x "$(command -v ucfr)")) {
            $main_exit_code = system('ucfr', 'chrony', '/etc/chrony/chrony.conf') >> 8;
            $main_exit_code = system('ucfr', 'chrony', '/etc/chrony/chrony.keys') >> 8;
        }
    }
    if (!(!(# Original bash: chronyd -p | grep -q "^user";
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
                my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'chronyd', '-p');
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;

                my $grep_result_0_1;
        my @grep_lines_0_1 = split /\n/msx, $output_0;
        my @grep_filtered_0_1 = grep { /^user/msx } @grep_lines_0_1;
        $grep_result_0_1 = join "\n", @grep_filtered_0_1;
        if (!($grep_result_0_1 =~ m{\n\z}msx || $grep_result_0_1 eq q{})) {
        $grep_result_0_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_0_1 > 0 ? 0 : 1;
        $grep_result_0_1 = q{};
        $output_0 = q{};
        if ((scalar @grep_filtered_0_1) == 0) {
            $pipeline_success_0 = 0;
        }
        if ($output_0 ne q{} && !defined $output_printed_0) {
            print $output_0;
            if (!($output_0 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        }))) {
        for my $d ('/var/lib/chrony', '/var/log/chrony', '/etc/chrony/chrony.keys') {
if (!(!(do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('dpkg-statoverride', '--list', "$d") >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };))) {
if ("$d" eq "/etc/chrony/chrony.keys") {
                    $main_exit_code = system('dpkg-statoverride', '--update', '--add', 'root', '_chrony', '0640', "$d") >> 8;
}
                else {
                    $main_exit_code = system('dpkg-statoverride', '--update', '--add', '_chrony', '_chrony', '0750', "$d") >> 8;
                }
            }
        }
        $d = '/etc/chrony/chrony.keys';
    }
} elsif ("$_[0]" =~ /^abort-upgrade$/msx or "$_[0]" =~ /^abort-remove$/msx or "$_[0]" =~ /^abort-deconfigure$/msx) {
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
    exit 1;
}
if ("$1" eq "configure") {
    $APP_PROFILE = "/etc/apparmor.d/usr.sbin.chronyd";
if ((-f "$APP_PROFILE")) {
        my $LOCAL_APP_PROFILE;
        my @LOCAL_APP_PROFILE;
        my %LOCAL_APP_PROFILE;
        $LOCAL_APP_PROFILE = "/etc/apparmor.d/local/usr.sbin.chronyd";
                $main_exit_code = system('test', '-e', "$LOCAL_APP_PROFILE") >> 8;
        if ($CHILD_ERROR != 0) {
                            use File::Path qw(make_path);
                my $err;
                if ( !-d do { use File::Basename qw(dirname); my $dirname_output = dirname("$LOCAL_APP_PROFILE"); $CHILD_ERROR = 0; $dirname_output; } ) {
                    make_path( do { use File::Basename qw(dirname); my $dirname_output = dirname("$LOCAL_APP_PROFILE"); $CHILD_ERROR = 0; $dirname_output; }, { error => \$err } );
                    if ( @{$err} ) {
                        croak "mkdir: cannot create directory " . do { use File::Basename qw(dirname); my $dirname_output = dirname("$LOCAL_APP_PROFILE"); $CHILD_ERROR = 0; $dirname_output; } . ": $err->[0]\n";
                    }
                }
                $main_exit_code = system('install', '--mode', '644', '/dev/null', "$LOCAL_APP_PROFILE") >> 8;
        }
if (!(        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            $main_exit_code = system('aa-enabled', '--quiet') >> 8;
        })) {
                        $main_exit_code = system('apparmor_parser', '-r', '-T', '-W', "$APP_PROFILE") >> 8;
            if ($CHILD_ERROR != 0) {
                1;
            }
        }
    }
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/NetworkManager/dispatcher.d/20', '-c', 'hrony', "3.5-7\\~", 'chrony', '--', "@ARGV") >> 8;
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
if (("${DPKG_ROOT:-}" eq q{} && (-x "/etc/init.d/chrony"))) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('update-rc.d', 'chrony', 'defaults') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
if ("$2" ne q{}) {
            my $_dh_action;
            my @_dh_action;
            my %_dh_action;
            $_dh_action = 'restart';
}
        else {
            $_dh_action = 'start';
        }
                $main_exit_code = system('invoke-rc.d', "--skip-" . "sys" . "tem" . "d-native", 'chrony', $_dh_action) >> 8;
        if ($CHILD_ERROR != 0) {
            exit 1;
        }
    }
}
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('deb-systemd-helper', 'unmask', 'chrony.service') >> 8;
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
if (!(    $main_exit_code = system('deb-systemd-helper', '--quiet', 'was-enabled', 'chrony.service') >> 8)) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'enable', 'chrony.service') >> 8;
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
    else {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'update-state', 'chrony.service') >> 8;
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
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
if ((-d '/run/systemd/system')) {
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
if ("$2" ne q{}) {
            $_dh_action = 'restart';
}
        else {
            $_dh_action = 'start';
        }
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-invoke', $_dh_action, 'chrony.service') >> 8;
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
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
if (!(    $main_exit_code = system('deb-systemd-helper', 'debian-installed', 'chrony-wait.service') >> 8)) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'unmask', 'chrony-wait.service') >> 8;
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
if (!(        $main_exit_code = system('deb-systemd-helper', '--quiet', 'was-enabled', 'chrony-wait.service') >> 8)) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('deb-systemd-helper', 'enable', 'chrony-wait.service') >> 8;
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
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('deb-systemd-helper', 'update-state', 'chrony-wait.service') >> 8;
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
exit 0;

exit $main_exit_code;
