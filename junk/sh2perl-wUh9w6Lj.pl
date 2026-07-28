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

my $MAGIC_77 = 77;

my $CAB;
my @CAB;
my %CAB;
$CAB = 'cabextract';

sub mccabfs_list {
    my ($file) = @_;
    # Original bash: $CAB -l "$1" | awk -v uid=`id -un` -v gid=`id -gn` '
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
                my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'unknown_command', '-l');
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;

                my @lines = split /\n/msx, $output_0;
        my @result;
        foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        if (!(BEGIN)) { next; }
        push @result, (f "%s 1 %s %s %d %02d/%02d/%02d %02d:%02d  %s
        " . pr . uid . gid . $fields[0] . a[2] . a[1] . a[3] . b[1] . b[2] . $fields[5] . "\n");
        }
        $output_0 = join "", @result;
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

sub mccabfs_copyout {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$_[2]"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $CHILD_ERROR = 0;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}
my $LC_ALL;
my @LC_ALL;
my %LC_ALL;
$LC_ALL = q{C};
$ENV{LC_ALL} = $LC_ALL;
$main_exit_code = system('umask', '077') >> 8;
my $cmd;
my @cmd;
my %cmd;
$cmd = "$_[0]";
if ("$cmd" =~ /^list$/msx) {
        mccabfs_list("$_[1]");
} elsif ("$cmd" =~ /^copyout$/msx) {
        mccabfs_copyout("$_[1]", "$_[2]", "$_[3]");
} elsif (1) {
    exit 1;
}
exit 0;

exit $main_exit_code;
