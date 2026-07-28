#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use File::Basename;
use IPC::Open3;

my $main_exit_code = 0;
my $output         = q{};
our $CHILD_ERROR;

my $DISTRO;
my $LINE;

my $lock_file = '/var/run/orangepi-motd-updates.lock';
if (!(# set -C not implemented
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('bash', '2') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };)) {
# Builtin command 'trap' with dynamic handler not supported
}
else {
exit 0;
}
if ((qx'dpkg -l | grep ^..r' ne q{})) {
    exit 0;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if ("$((apt-get upgrade -s -qq) 2>&1)" =~ /^.*"Unmet\ dependencies".*$/msx) {
    exit 0;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
my $myfile = "/var/cache/apt/archives/updates.number";
if (do {
$DISTRO = do {
    do { do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;

    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'lsb_release', '-c');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
    my @lines_2 = split /\n/, $output_0;
    my @result_2;
    foreach my $line (@lines_2) {
    chomp $line;
    my @fields = split /:/msx, $line;
    if (@fields > 1) {
        push @result_2, $fields[1];
    }
    }
    $output_0 = join "\n", @result_2;
    if ($output_0 ne q{} && !($output_0  =~ m{\n\z})) { $output_0 .= "\n"; }

    my $set1_3 = '[:space:]';
    my $input_3 = $output_0;
    my $tr_result_0_2 = q{};
    for my $char ( split //msx, $input_3 ) {
        if ( (index $set1_3, $char) == -1 ) {
            $tr_result_0_2 .= $char;
        }
    }
        if (!($tr_result_0_2 =~ m{\n\z} || $tr_result_0_2 eq q{})) {
            $tr_result_0_2 .= "\n";
        }
        $output_0 = $tr_result_0_2;
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    $output_0 =~ s/\n+\z//msx;
    $output_0;
}; };
};
    $CHILD_ERROR == 0
}) {
        $DISTRO = lc(${DISTRO});
}
my $upgrades = q{0};
my $security_upgrades = q{0};
my $temp_file_ps_fh_1 = q{/tmp} . '/process_sub_fh_1.tmp';
my $output_ps_fh_1;
{
my ($in, $out);
my $pid = open3($in, $out, '>&STDERR', 'bash', '-c', 'apt-get upgrade -s -qq | sed -n /^Inst/p');
close $in or croak 'Close failed: $OS_ERROR';
$output_ps_fh_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
close $out or croak 'Close failed: $OS_ERROR';
waitpid $pid, 0;
$CHILD_ERROR = $? >> 8;
}
use File::Path qw(make_path);
my $temp_dir_fh_1 = dirname($temp_file_ps_fh_1);
if (!-d $temp_dir_fh_1) { make_path($temp_dir_fh_1); }
open my $fh_ps_fh_1, '>', $temp_file_ps_fh_1 or croak "Cannot create temp file: $ERRNO\n";
print {$fh_ps_fh_1} $output_ps_fh_1;
close $fh_ps_fh_1 or croak "Close failed: $ERRNO\n";
open STDIN, '<', $temp_file_ps_fh_1 or croak "Cannot open process substitution: $ERRNO\n";
my $LINE;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split //msx, $L;
    $LINE = $_fields[0] // q{};
    $CHILD_ERROR = ($main_exit_code = eval { int($upgrades++) } // "") ? 0 : 1;
    if (${LINE} =~ /^.*"[$]{DISTRO}-sec".*$/msx) {
                $CHILD_ERROR = ($main_exit_code = eval { int($security_upgrades++) } // "") ? 0 : 1;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
}
open my $fh_cat, '>', '$myfile' or croak "Cannot access file: $OS_ERROR\n";
print {$fh_cat} "NUM_UPDATES=\"${upgrades}\"
NUM_SECURITY_UPDATES=\"${security_upgrades}\"
DATE=\"$(date +\"%Y-%m-%d %H:%M\")\"
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
exit 0;

exit $main_exit_code;
