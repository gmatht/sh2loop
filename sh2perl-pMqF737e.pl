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


sub prep_mv_conffile {
    my $PKGNAME = "$_[0]";
    my $CONFFILE = "$_[1]";
    if (!((-e "$CONFFILE"))) {
        return q{0};    }
    my $md5sum = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;

        my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'md5sum', );
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
        my @sed_lines_0 = split /\n/msx, $output_0;
        my @sed_result_0;
        foreach my $line (@sed_lines_0) {
        chomp $line;
        push @sed_result_0, $line;
        }
        $output_0 = join "\n", @sed_result_0;

        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        $output_0 =~ s/\n+\z//msx;
        $output_0;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
    my $old_md5sum = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_2 = q{};
        my $output_printed_2;
        my $pipeline_success_2 = 1;

        my ($in_3, $out_3);
        my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'dpkg-query', '-W', '-f', q{=}, '${Conffiles}');
        close $in_3 or croak 'Close failed: $OS_ERROR';
        $output_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
        close $out_3 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_3, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }
        my @sed_lines_2 = split /\n/msx, $output_2;
        my @sed_result_2;
        foreach my $line (@sed_lines_2) {
        chomp $line;
        push @sed_result_2, $line;
        }
        $output_2 = join "\n", @sed_result_2;

        if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
        $output_2 =~ s/\n+\z//msx;
        $output_2;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
if ("$md5sum" eq "$old_md5sum") {
if ( -e "$CONFFILE" ) {
            if ( -d "$CONFFILE" ) {
                carp "rm: carping: ", "$CONFFILE",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$CONFFILE" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$CONFFILE",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    return;
}
if ("$_[0]" =~ /^install$/msx or "$_[0]" =~ /^upgrade$/msx) {
    if (!(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'le', "30~pre9-2") >> 8)) {
        prep_mv_conffile('wireless-tools', "/etc/network/if-up.d/wireless-tools");
        prep_mv_conffile('wireless-tools', "/etc/network/if-down.d/wireless-tools");
    }
}

exit $main_exit_code;
