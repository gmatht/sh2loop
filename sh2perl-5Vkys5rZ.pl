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

do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
};
do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
};

sub list_packages {
    my $text;
    my @text;
    my %text;
    $text = "$_[0]";
# Builtin command 'shift' not implemented
if ("$1" ne q{}) {
printf(":\n\n");
        $main_exit_code = system('dpkg-query', '-l', "@ARGV") >> 8;
if ((-x '/usr/bin/debsums')) {
            my $FILES;
            my @FILES;
            my %FILES;
            $FILES = (do { my $_chomp_temp = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'debsums', '-c', q{e}, "@ARGV");
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
}; chomp $_chomp_temp; $_chomp_temp; });
if ("$FILES" ne q{}) {
printf("\nThe following files were modified:\n\n\n");
            }
        }
    }
printf("\n");
    return;
}
if ((-x '/usr/bin/aptitude')) {
    my $TEXT;
    my @TEXT;
    my %TEXT;
    $TEXT = "Packages which depend, recommend, suggest or enhance a zsh package and hence may provide code meant to be sourced in .zshrc";
    my $PKGS;
    my @PKGS;
    my %PKGS;
    $PKGS = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'aptitude', '-q', '-F', '%p', 'search', '( ?enhances(?name(^zsh)) | ?depends(?name(^zsh)) | ?recommends(?name(^zsh)) | ?suggests(?name(^zsh)) ) !?source-package(^zsh$) ~i');
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
};
}
else {
    $TEXT = "Packages which provide code meant to be sourced in .zshrc";
    $PKGS = do { my @_qx_cmd = ("dpkg-query -W -f \"\\${Package}\\\\n\" autojump command-not-found environment-modules fizsh oh-my-zsh ondir python-powerline python3-powerline rosbash thefuck zec zgen zsh-antigen zsh-autosuggestions zsh-syntax-highlighting 'grml-*' 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
}
list_packages("$TEXT", $PKGS);
list_packages("Packages which provide vendor completions", do { do {
    my $output_5 = q{};
    my $output_printed_5;
    my $pipeline_success_5 = 1;

    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'dpkg-query', '-S', '/usr/share/zsh/vendor-completions/');
    close $in_6 or croak 'Close failed: $OS_ERROR';
    $output_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_5 = 0; }
    my @lines = split /\n/msx, $output_5;
    my @result;
    foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /:/msx, $line;
        push @result, ($fields[0] . "\n");
    }
    $output_5 = join "", @result;

    my @sed_lines_5 = split /\n/msx, $output_5;
    my @sed_result_5;
    foreach my $line (@sed_lines_5) {
    chomp $line;
    push @sed_result_5, $line;
    }
    $output_5 = join "\n", @sed_result_5;

    if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
    $output_5 =~ s/\n+\z//msx;
    $output_5;
} });
list_packages("Packages which provide vendor functions", do { do {
    my $output_7 = q{};
    my $output_printed_7;
    my $pipeline_success_7 = 1;

    my ($in_8, $out_8);
    my $pid_8 = open3($in_8, $out_8, '>&STDERR', 'dpkg-query', '-S', '/usr/share/zsh/vendor-functions/');
    close $in_8 or croak 'Close failed: $OS_ERROR';
    $output_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
    close $out_8 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_8, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_7 = 0; }
    my @lines = split /\n/msx, $output_7;
    my @result;
    foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /:/msx, $line;
        push @result, ($fields[0] . "\n");
    }
    $output_7 = join "", @result;

    my @sed_lines_7 = split /\n/msx, $output_7;
    my @sed_result_7;
    foreach my $line (@sed_lines_7) {
    chomp $line;
    push @sed_result_7, $line;
    }
    $output_7 = join "\n", @sed_result_7;

    if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
    $output_7 =~ s/\n+\z//msx;
    $output_7;
} });

exit $main_exit_code;
