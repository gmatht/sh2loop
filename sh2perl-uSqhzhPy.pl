#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $MC_XDG_OPEN;
my @MC_XDG_OPEN;
my %MC_XDG_OPEN;

my $action;
my @action;
my %action;
$action = $1;
my $filetype;
my @filetype;
my %filetype;
$filetype = $2;
if (!("${MC_XDG_OPEN}" ne q{})) {
        $MC_XDG_OPEN = "xdg-open";
}

sub do_view_action {
    $filetype = $1;
if (${filetype} =~ /^trpm$/msx) {
                $main_exit_code = system('rpm', '-qivl', '--scripts', do { use File::Basename qw(basename); my $basename_output = basename(($ENV{MC_EXT_BASENAME} // q{})); $CHILD_ERROR = 0; $basename_output; }) >> 8;
    } elsif (${filetype} =~ /^src.rpm$/msx or ${filetype} =~ /^rpm$/msx) {
        if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('rpm', '--nosignature', '--version') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            my $RPM;
            my @RPM;
            my %RPM;
            $RPM = "rpm --nosignature";
}
        else {
            $RPM = "rpm";
        }
                $CHILD_ERROR = 0;
    } elsif (${filetype} =~ /^deb$/msx) {
                if (do {
if (do {
$main_exit_code = system('dpkg-deb', '-I', ($ENV{MC_EXT_FILENAME} // q{})) >> 8;
    $CHILD_ERROR == 0
}) {
        print "\n";
    $CHILD_ERROR = 0;
}
            $CHILD_ERROR == 0
        }) {
                        $main_exit_code = system('dpkg-deb', '-c', ($ENV{MC_EXT_FILENAME} // q{})) >> 8;
        }
    } elsif (${filetype} =~ /^debd$/msx) {
                $main_exit_code = system('dpkg', '-s', do { do {
            my $output_0 = q{};
            my $output_printed_0;
            my $pipeline_success_0 = 1;
            $output_0 .= ($ENV{MC_EXT_BASENAME} // q{}) . "\n";
            if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
            my @sed_lines_0 = split /\n/msx, $output_0;
            my @sed_result_0;
            foreach my $line (@sed_lines_0) {
            chomp $line;
            $line =~ s/\([0-9a-z.-]*\).*/\1/gmsx;
            push @sed_result_0, $line;
            }
            $output_0 = join "\n", @sed_result_0;

            if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
            $output_0 =~ s/\n+\z//msx;
            $output_0;
} }) >> 8;
    } elsif (${filetype} =~ /^deba$/msx) {
                $main_exit_code = system('apt-cache', 'show', do { do {
            my $output_1 = q{};
            my $output_printed_1;
            my $pipeline_success_1 = 1;
            $output_1 .= ($ENV{MC_EXT_BASENAME} // q{}) . "\n";
            if ( !($output_1 =~ m{\n\z}msx) ) { $output_1 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
            my @sed_lines_1 = split /\n/msx, $output_1;
            my @sed_result_1;
            foreach my $line (@sed_lines_1) {
            chomp $line;
            $line =~ s/\([0-9a-z.-]*\).*/\1/gmsx;
            push @sed_result_1, $line;
            }
            $output_1 = join "\n", @sed_result_1;

            if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
            $output_1 =~ s/\n+\z//msx;
            $output_1;
} }) >> 8;
    } elsif (1) {
    }
    return;
}

sub do_open_action {
    $filetype = $1;
if (1) {
    }
    return;
}
if (${action} =~ /^view$/msx) {
        do_view_action(${filetype});
} elsif (${action} =~ /^open$/msx) {
            do {
        local %ENV = %ENV;
        my $action = $action;
        my $filetype = $filetype;
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
        q{};
    };
    if ($CHILD_ERROR != 0) {
                do_open_action(${filetype});
    }
} elsif (1) {
}

exit $main_exit_code;
