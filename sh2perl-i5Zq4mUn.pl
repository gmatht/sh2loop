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

my $OutstandingPackages;
my @OutstandingPackages;
my %OutstandingPackages;
my $OlderThanOneDay;
my @OlderThanOneDay;
my %OlderThanOneDay;

if ("$-" ne "${-#*i}") {
    $OutstandingPackages = (do { my $_chomp_temp = do { my $command = "egrep -v 'linux-base|linux-image' /var/run/reboot-required.pkgs 2> /dev/null"; chomp(my $result = qx{$command}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; });
if ((-f "/var/run/.reboot_required")) {
printf("\n[e[0;91m Kernel was updated, please rebootx1B[0m ]\n\n");
}
    else {
        if ("X${OutstandingPackages}" ne "X") {
            my $Packages;
            my @Packages;
            my %Packages;
            $Packages = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_1 = q{};
                my $output_printed_1;
                my $pipeline_success_1 = 1;

                my ($in_2, $out_2);
                my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'egrep', '-v', '/var/run/reboot-required.pkgs');
                close $in_2 or croak 'Close failed: $OS_ERROR';
                $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
                close $out_2 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_2, 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
                my @sort_lines_1_1 = split /\n/msx, $output_1;
                my @sort_sorted_1_1 = sort @sort_lines_1_1;
                $output_1 = join "\n", @sort_sorted_1_1;
                                if ($output_1 ne q{} && !($output_1 =~ m{\n\z}msx)) {
                                    $output_1 .= "\n";
                                }
                my @uniq_lines_1_2 = split /\n/msx, $output_1;
                @uniq_lines_1_2 = grep { $_ ne q{} } @uniq_lines_1_2; # Filter out empty lines
                my %uniq_seen_1_2;
                my @uniq_result_1_2;
                foreach my $line (@uniq_lines_1_2) {
                if (!$uniq_seen_1_2{$line}++) { push @uniq_result_1_2, $line; }
                }
                $output_1 = join "\n", @uniq_result_1_2;
                                if ($output_1 ne q{} && !($output_1 =~ m{\n\z}msx)) {
                                    $output_1 .= "\n";
                                }
                my $set1_3 = "\\n";
                my $set2_3 = q{,};
                my $input_3 = $output_1;
                # Expand character ranges for tr command
                my $expanded_set1_3 = $set1_3;
                my $expanded_set2_3 = $set2_3;
                # Handle a-z range in set1
                if ($expanded_set1_3 =~ /a-z/msx) {
                    $expanded_set1_3 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
                }
                # Handle A-Z range in set1
                if ($expanded_set1_3 =~ /A-Z/msx) {
                    $expanded_set1_3 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
                }
                # Handle [:upper:] POSIX class in set1
                if ($expanded_set1_3 =~ /\[:upper:\]/msx) {
                    $expanded_set1_3 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
                }
                # Handle [:lower:] POSIX class in set1
                if ($expanded_set1_3 =~ /\[:lower:\]/msx) {
                    $expanded_set1_3 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
                }
                # Handle a-z range in set2
                if ($expanded_set2_3 =~ /a-z/msx) {
                    $expanded_set2_3 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
                }
                # Handle A-Z range in set2
                if ($expanded_set2_3 =~ /A-Z/msx) {
                    $expanded_set2_3 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
                }
                # Handle [:upper:] POSIX class in set2
                if ($expanded_set2_3 =~ /\[:upper:\]/msx) {
                    $expanded_set2_3 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
                }
                # Handle [:lower:] POSIX class in set2
                if ($expanded_set2_3 =~ /\[:lower:\]/msx) {
                    $expanded_set2_3 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
                }
                my $tr_result_1_3 = q{};
                for my $char ( split //msx, $input_3 ) {
                    my $pos_3 = index $expanded_set1_3, $char;
                    if ( $pos_3 >= 0 && $pos_3 < length $expanded_set2_3 ) {
                        $tr_result_1_3 .= substr $expanded_set2_3, $pos_3, 1;
                    } else {
                        $tr_result_1_3 .= $char;
                    }
                }
                                if (!($tr_result_1_3 =~ m{\n\z}msx || $tr_result_1_3 eq q{})) {
                                    $tr_result_1_3 .= "\n";
                                }
                                $output_1 = $tr_result_1_3;
                my @sed_lines_1 = split /\n/msx, $output_1;
                my @sed_result_1;
                foreach my $line (@sed_lines_1) {
                chomp $line;
                push @sed_result_1, $line;
                }
                $output_1 = join "\n", @sed_result_1;

                if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
                $output_1 =~ s/\n+\z//msx;
                $output_1;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
            $OlderThanOneDay = do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { if (1) { push @find_results, $File::Find::name; } }, '/var/run/reboot-required');
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
};
if ("X${OlderThanOneDay}" eq "X") {
printf("\n[e[0;92m some packages require a reboot ()x1B[0m ]\n\n");
}
            else {
printf("\n[e[0;91m some packages require a reboot since more than 1 day ()x1B[0m ]\n\n");
            }
        }
    }
}

exit $main_exit_code;
