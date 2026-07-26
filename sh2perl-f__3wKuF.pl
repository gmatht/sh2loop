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

my $MAGIC_30 = 30;
my $MAGIC_10 = 10;
my $MAGIC_40 = 40;

$main_exit_code = system('.', './setup-vars') >> 8;
my $backtitle;
my @backtitle;
my %backtitle;
$backtitle = "An Example for the use of --inputmenu:";
my $ids;
my @ids;
my %ids;
$ids = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;

    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'id', );
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
}; $_pipeline_result; };
my $uid;
my @uid;
my %uid;
$uid = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;
    $output_2 .= $ids . "\n";
    if ( !($output_2 =~ m{\n\z}msx) ) { $output_2 .= "\n"; }
    $CHILD_ERROR = 0;
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
}; $_pipeline_result; };
my $gid;
my @gid;
my %gid;
$gid = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_3 = q{};
    my $output_printed_3;
    my $pipeline_success_3 = 1;
    $output_3 .= $ids . "\n";
    if ( !($output_3 =~ m{\n\z}msx) ) { $output_3 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_3 = 0; }
    my @sed_lines_3 = split /\n/msx, $output_3;
    my @sed_result_3;
    foreach my $line (@sed_lines_3) {
    chomp $line;
    push @sed_result_3, $line;
    }
    $output_3 = join "\n", @sed_result_3;

    if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
    $output_3 =~ s/\n+\z//msx;
    $output_3;
}; $_pipeline_result; };
my $user;
my @user;
my %user;
$user = "$ENV{USER}";
my $home;
my @home;
my %home;
$home = "$ENV{HOME}";
my $returncode;
my @returncode;
my %returncode;
$returncode = q{0};
while (1) {
    last unless do {
        $main_exit_code = system('test', $returncode, q{!}, q{=}, q{1}) >> 8;
        $CHILD_ERROR == 0
    };
    last unless do {
        $main_exit_code = system('test', $returncode, q{!}, q{=}, '250') >> 8;
        $CHILD_ERROR == 0
    };
    do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
    };
    my $returntext;
    my @returntext;
    my %returntext;
    $returntext = do { my @_qx_cmd = ("$DIALOG --clear --ok-label Create --extra-label Edit --backtitle \"$backtitle\" \"$@\" --inputmenu \"Originally I designed --inputmenu for a \\\\\\nconfiguration purpose. Here is a possible piece of a configuration program.\" 20 50 10 Username: \"$user\" UID: \"$uid\" GID: \"$gid\" HOME: \"$home\" 2>&1 2>&3"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    $returncode = $?;
    do {
local *STDERR;
open STDERR, '>', q{-} or croak "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
    };
if ($returncode =~ /^$DIALOG_CANCEL$/msx) {
                $CHILD_ERROR = 0;
        if ($? =~ /^$DIALOG_OK$/msx) {
            last;        } elsif ($? =~ /^$DIALOG_CANCEL$/msx) {
                        $returncode = '99';
        }
    } elsif ($returncode =~ /^$DIALOG_OK$/msx) {
                $CHILD_ERROR = 0;
    } elsif ($returncode =~ /^$DIALOG_EXTRA$/msx) {
                my $tag;
        my @tag;
        my %tag;
        $tag = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_4 = q{};
            my $output_printed_4;
            my $pipeline_success_4 = 1;
            $output_4 .= $returntext . "\n";
            if ( !($output_4 =~ m{\n\z}msx) ) { $output_4 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_4 = 0; }
            my @sed_lines_4 = split /\n/msx, $output_4;
            my @sed_result_4;
            foreach my $line (@sed_lines_4) {
            chomp $line;
            push @sed_result_4, $line;
            }
            $output_4 = join "\n", @sed_result_4;

            if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
            $output_4 =~ s/\n+\z//msx;
            $output_4;
}; $_pipeline_result; };
                my $item;
        my @item;
        my %item;
        $item = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_5 = q{};
            my $output_printed_5;
            my $pipeline_success_5 = 1;
            $output_5 .= $returntext . "\n";
            if ( !($output_5 =~ m{\n\z}msx) ) { $output_5 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_5 = 0; }
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
}; $_pipeline_result; };
        if ("$tag" =~ /^Username$/msx) {
                        $user = "$item";
        } elsif ("$tag" =~ /^UID$/msx) {
                        $uid = "$item";
        } elsif ("$tag" =~ /^GID$/msx) {
                        $gid = "$item";
        } elsif ("$tag" =~ /^HOME$/msx) {
                        $home = "$item";
        }
    } elsif (1) {
                $main_exit_code = system('.', './report-button') >> 8;
        last;    }
}

exit $main_exit_code;
