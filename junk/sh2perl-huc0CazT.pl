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

$__set_e = 1;
if ("$_[0]" =~ /^configure$/msx) {
    if (!(!(# Original bash: getent group shadow | grep -q '^shadow:[^:]*:42'
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
                my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'getent', 'group', 'shadow');
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;

                my $grep_result_0_1;
        my @grep_lines_0_1 = split /\n/msx, $output_0;
        my @grep_filtered_0_1 = grep { /^shadow:[^:]*:42/msx } @grep_lines_0_1;
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
                $main_exit_code = system('groupadd', '-g', '42', 'shadow') >> 8;
        if ($CHILD_ERROR != 0) {
                        do {
                local %ENV = %ENV;
print "Group ID 42 has been allocated for the shadow group.  You have either
used 42 yourself or created a shadow group with a different ID.
Please correct this problem and reconfigure with ``dpkg --configure passwd''.

Note that both user and group IDs in the range 0-99 are globally
allocated by the Debian project and must be the same on every Debian
system.
";
exit 1;
                q{};
            };
        }
    }
}
if ("$2" eq q{}) {
        $main_exit_code = system('shadowconfig', 'on') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
if ((-x "$(command -v systemd-tmpfiles)")) {
                $main_exit_code = system('systemd-tmpfiles', (defined ($ENV{DPKG_ROOT} // q{}) && ($ENV{DPKG_ROOT} // q{}) ne q{} ? ($ENV{DPKG_ROOT} // q{}) : '--root="$DPKG_ROOT"'), '--create', 'passwd.conf') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/cron.daily/passwd', "1:4.7-2\\~", '--', "@ARGV") >> 8;
exit 0;

exit $main_exit_code;
