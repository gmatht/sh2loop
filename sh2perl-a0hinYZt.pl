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
if ((("$1" eq "install" && "$2" ne q{}) && (-e "/etc/init.d/unattended-upgrades"))) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
chmod(oct('+x'), ("/etc/init.d/unattended-upgrades")) or warn "chmod failed: $OS_ERROR\n";
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
my $CONFIG;
my @CONFIG;
my %CONFIG;
$CONFIG = "/etc/apt/apt.conf.d/50unattended-upgrades";
if ("$_[0]" =~ /^install$/msx or "$_[0]" =~ /^upgrade$/msx) {
    if ((("$2" ne q{} && !(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', "1.8~") >> 8)) && !({
        my $output_2 = q{};
        my $output_printed_2;
        my $pipeline_success_2 = 1;
                my ($in_3, $out_3);
        my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'dpkg-query', '-W', '-f', q{=}, "${Conffiles}\\n", 'unattended-upgrades');
        close $in_3 or croak 'Close failed: $OS_ERROR';
        $output_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
        close $out_3 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_3, 0;

                my $grep_result_2_1;
        my @grep_lines_2_1 = split /\n/msx, $output_2;
        my @grep_filtered_2_1 = grep { /$CONFIG\ .*\ obsolete/msx } @grep_lines_2_1;
        $grep_result_2_1 = join "\n", @grep_filtered_2_1;
        if (!($grep_result_2_1 =~ m{\n\z}msx || $grep_result_2_1 eq q{})) {
        $grep_result_2_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_2_1 > 0 ? 0 : 1;
        $grep_result_2_1 = q{};
        $output_2 = q{};
        if ((scalar @grep_filtered_2_1) == 0) {
            $pipeline_success_2 = 0;
        }
        if ($output_2 ne q{} && !defined $output_printed_2) {
            print $output_2;
            if (!($output_2 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
        }))) {
        use File::Copy qw(copy);
        if ( -e "$CONFIG" ) {
            if ( -d "$CONFIG.ucftmp" ) {
                require File::Copy; File::Copy::copy("$CONFIG", "$CONFIG.ucftmp" . '/' . ("$CONFIG" =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy("$CONFIG", "$CONFIG.ucftmp");
            }
        } else {
            croak "cp: cannot stat '$CONFIG': No such file or directory\n";
        }
        $main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', "$CONFIG", '--', "@ARGV") >> 8;
    }
}

exit $main_exit_code;
