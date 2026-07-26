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

my $RET;
my @RET;
my %RET;
my $ENABLED;
my @ENABLED;
my %ENABLED;

$__set_e = 1;
my $S_VERSION;
my @S_VERSION;
my %S_VERSION;
$S_VERSION = "10.3.1-1~";
my $PACKAGE;
my @PACKAGE;
my %PACKAGE;
$PACKAGE = "sysstat";
my $DEFAULT;
my @DEFAULT;
my %DEFAULT;
$DEFAULT = "/etc/default/$PACKAGE";
$ENABLED = "false";

sub manage_default_file {
    $ENABLED = "$_[0]";
if (("$ENABLED" ne "true" && "$ENABLED" ne "false")) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Internal error in the sysstat's postinst: $ENABLED=$ENABLED";
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
    my $def_file;
    my @def_file;
    my %def_file;
    $def_file = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'mktemp', '-t', 'sstatXXXXXXXXX.def');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
open my $fh_cat, '>', "\"$def_file\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "#
# Default settings for /etc/init.d/sysstat, /etc/cron.d/sysstat
# and /etc/cron.daily/sysstat files
#

# Should sadc collect system activity informations? Valid values
# are \"true\" and \"false\". Please do not put other values, they
# will be overwritten by debconf!
ENABLED=\"$ENABLED\"

";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    $main_exit_code = system('ucf', '--three-way', '--debconf-ok', "$def_file", "$DEFAULT") >> 8;
    $main_exit_code = system('ucfr', "$PACKAGE", "$DEFAULT") >> 8;
    if ((-e "$DEFAULT")) {
        chmod(oct('644'), ("$DEFAULT")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if ( -e "$def_file" ) {
        if ( -d "$def_file" ) {
            carp "rm: carping: ", "$def_file",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$def_file" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$def_file",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}

sub manage_systemd_services {
    $ENABLED = "$_[0]";
    my $all_services;
    my @all_services;
    my %all_services;
    $all_services = 'sysstat-collect.timer sysstat-summary.timer sysstat.service';
    my $num_all_services;
    my @num_all_services;
    my %num_all_services;
    $num_all_services = q{3};
    my $sysctl;
    my @sysctl;
    my %sysctl;
    $sysctl = "/bin/" . "sys" . "tem" . "ctl";
    my $num_disabled;
    my @num_disabled;
    my %num_disabled;
    $num_disabled = q{0};
        if ((-x "$sysctl")) {
        (-d '/run/systemd/system')        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
        return q{0};    }
    my $service;
    for my $service ($all_services) {
                $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) {
                        $num_disabled = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'expr', $num_disabled, q{+}, q{1});
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
        }
    }
if (($num_disabled ne 0 && $num_disabled ne $num_all_services)) {
return q{0};
    }
        if ($num_disabled eq 0) {
                my $is_enabled;
        my @is_enabled;
        my %is_enabled;
        $is_enabled = "true";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
                $is_enabled = "false";
    }
    if (!("$ENABLED" ne "$is_enabled")) {
        return q{0};    }
        if ("$ENABLED" eq "true") {
                my $enable_arg;
        my @enable_arg;
        my %enable_arg;
        $enable_arg = "enable";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
                $enable_arg = "disable";
    }
    for my $service ($all_services) {
if ($service =~ /^.*.timer$/msx) {
                        my $options;
            my @options;
            my %options;
            $options = "--now";
        } elsif (1) {
                        $options = "";
        }
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
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
    return;
}
$main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;
$ENABLED = "";
if ("$1" eq "configure") {
if (!(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt-nl', "$S_VERSION") >> 8)) {
        $RET = "";
                $main_exit_code = system('db_get', 'sysstat/remove_files') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
if ("$RET" eq "true") {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "Removing old statistics from /var/log/sysstat.\n";
            };
            require File::Find;
            File::Find::find(sub {     next unless $_ =~ /^sa[0-9][0-9]\.bz2$/msx;     my $depth = ($File::Find::dir =~ tr/\///) + 1; next if $depth > 2;     print "$File::Find::name\n"; }, '/var/log/sysstat');
        }
    }
        $main_exit_code = system('db_reset', 'sysstat/remove_files') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
        $main_exit_code = system('db_get', 'sysstat/enable') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
    $ENABLED = "$RET";
    manage_default_file("$ENABLED");
        $main_exit_code = system('bash', 'db_stop') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
if (!(!(# Original bash: update-alternatives --display sar 2>/dev/null | grep -q '^/usr/bin/sar\.sysstat';
{
        my $output_8 = q{};
        my $output_printed_8;
        my $pipeline_success_8 = 1;
                $output = q{};
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_9 = q{};

my $cmd_12 = 'update-alternatives';
my ($in_11, $out_11);
my $pid_11 = open3($in_11, $out_11, '>&STDERR', $cmd_12, '--display', 'sar');
print {$in_11} $output_8;
close $in_11 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
close $out_11 or croak 'Close failed: $OS_ERROR';
waitpid $pid_11, 0;
$tmp_redirect_9;
        };
        $output_8 = $output;

                my $grep_result_8_1;
        my @grep_lines_8_1 = split /\n/msx, $output_8;
        my @grep_filtered_8_1 = grep { /^\/usr\/bin\/sar[.]sysstat/msx } @grep_lines_8_1;
        $grep_result_8_1 = join "\n", @grep_filtered_8_1;
        if (!($grep_result_8_1 =~ m{\n\z}msx || $grep_result_8_1 eq q{})) {
        $grep_result_8_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_8_1 > 0 ? 0 : 1;
        $grep_result_8_1 = q{};
        $output_8 = q{};
        if ((scalar @grep_filtered_8_1) == 0) {
            $pipeline_success_8 = 0;
        }
        if ($output_8 ne q{} && !defined $output_printed_8) {
            print $output_8;
            if (!($output_8 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
        }))) {
        $main_exit_code = system('update-alternatives', '--install', '/usr/bin/sar', 'sar', '/usr/bin/sar.sysstat', q{0}, '--slave', '/usr/share/man/man1/sar.1.gz', 'sar.1.gz', '/usr/share/man/man1/sar.sysstat.1.gz') >> 8;
    }
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/profile.d/sysstat.sh', "11.7.3\\~", 'sysstat', '--', "@ARGV") >> 8;
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
if ((-x "/etc/init.d/sysstat")) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('update-rc.d', 'sysstat', 'defaults') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
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
        $main_exit_code = system('deb-systemd-helper', 'unmask', 'sysstat-collect.timer') >> 8;
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
if (!(    $main_exit_code = system('deb-systemd-helper', '--quiet', 'was-enabled', 'sysstat-collect.timer') >> 8)) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'enable', 'sysstat-collect.timer') >> 8;
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
            $main_exit_code = system('deb-systemd-helper', 'update-state', 'sysstat-collect.timer') >> 8;
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
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('deb-systemd-helper', 'unmask', 'sysstat-summary.timer') >> 8;
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
if (!(    $main_exit_code = system('deb-systemd-helper', '--quiet', 'was-enabled', 'sysstat-summary.timer') >> 8)) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'enable', 'sysstat-summary.timer') >> 8;
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
            $main_exit_code = system('deb-systemd-helper', 'update-state', 'sysstat-summary.timer') >> 8;
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
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('deb-systemd-helper', 'unmask', 'sysstat.service') >> 8;
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
if (!(    $main_exit_code = system('deb-systemd-helper', '--quiet', 'was-enabled', 'sysstat.service') >> 8)) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'enable', 'sysstat.service') >> 8;
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
            $main_exit_code = system('deb-systemd-helper', 'update-state', 'sysstat.service') >> 8;
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
if (("$1" eq "configure" && "$ENABLED" ne q{})) {
    manage_systemd_services("$ENABLED");
if (("$ENABLED" eq "true" && (-x '/usr/lib/sysstat/sa1'))) {
        if (my $pid = fork()) {
            # Parent process continues
        } elsif (defined $pid) {
            # Child process executes the background command
            exec 'bash', '-c', q{(: 'Complex command not supported in bash string generation'; /usr/lib/sysstat/sa1 1 1)};
            croak "exec failed: $OS_ERROR\n";
        } else {
            die "Cannot fork: $ERRNO\n";
        }
    }
}
exit 0;

exit $main_exit_code;
