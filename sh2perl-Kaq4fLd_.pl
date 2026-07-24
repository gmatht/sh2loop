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


sub get_system_info {
    my %info = ();
    $info{"os"} = (do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; }; chomp $_chomp_temp; $_chomp_temp; });
    $info{"arch"} = (do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__mach; join(" ", @__parts) . "\n"; }; chomp $_chomp_temp; $_chomp_temp; });
    $info{"hostname"} = (do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); $__node . "\n"; }; chomp $_chomp_temp; $_chomp_temp; });
    $info{"user"} = "$ENV{USER}";
    # Original bash: #!/bin/bash
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
                $output_0 = q{};
        my @output_0_items = (keys %info);
        for my $key (@output_0_items) {
        $output_0 .= "info[$key]=" . $info{$key}. "\n";
        }

                my @sort_lines_0_1 = split /\n/msx, $output_0;
        my @sort_sorted_0_1 = sort @sort_lines_0_1;
        my $output_0_1 = join "\n", @sort_sorted_0_1;
        if ($output_0_1 ne q{} && !($output_0_1 =~ m{\n\z}msx)) {
        $output_0_1 .= "\n";
        }
        $output_0 = $output_0_1;
        $output_0 = $output_0_1;
        if ($output_0 ne q{} && !defined $output_printed_0) {
            print $output_0;
            if (!($output_0 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        }
    return;
}
get_system_info();

exit $main_exit_code;
