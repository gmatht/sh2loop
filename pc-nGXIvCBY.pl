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

my $LANG;
my @LANG;
my %LANG;
$LANG = q{C};
$ENV{LANG} = $LANG;
my $LC_TIME;
my @LC_TIME;
my %LC_TIME;
$LC_TIME = q{C};
$ENV{LC_TIME} = $LC_TIME;
$main_exit_code = system('umask', '077') >> 8;
my $prefix;
my @prefix;
my %prefix;
$prefix = '[git]';

sub gitfs_list {
    my $DATE;
    my @DATE;
    my %DATE;
    $DATE = do {
require POSIX; POSIX::strftime('', localtime(time())) . "\n"
};
    my $GIT_DIR;
    my @GIT_DIR;
    my %GIT_DIR;
    $GIT_DIR = "$_[1]/.git";
    my $user;
    my @user;
    my %user;
    $user = do { my $whoami_user = (getpwuid($<))[0]; $whoami_user . "\n"; };
    # Original bash: git ls-files -v -c -m -d | sort -k 2 | uniq -f 1 | while read status fname
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
                my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'git', 'ls-files', '-v', '-c', '-m', '-d');
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;

                my @sort_lines_0_1 = split /\n/msx, $output_0;
        my @sort_sorted_0_1 = sort {
        my @a_fields = split /\s+/msx, $a;
        my @b_fields = split /\s+/msx, $b;
        my $a_key = (scalar @a_fields > 1) ? $a_fields[1] : q{};
        my $b_key = (scalar @b_fields > 1) ? $b_fields[1] : q{};
        $a_key cmp $b_key || $a cmp $b
        } @sort_lines_0_1;
        my $output_0_1 = join "\n", @sort_sorted_0_1;
        if ($output_0_1 ne q{} && !($output_0_1 =~ m{\n\z}msx)) {
        $output_0_1 .= "\n";
        }
        $output_0 = $output_0_1;
        $output_0 = $output_0_1;

                my @uniq_lines_0_2 = split /\n/msx, $output_0;
        @uniq_lines_0_2 = grep { $_ ne q{} } @uniq_lines_0_2; # Filter out empty lines
        my %uniq_seen_0_2;
        my @uniq_result_0_2;
        foreach my $line (@uniq_lines_0_2) {
        if (!$uniq_seen_0_2{$line}++) { push @uniq_result_0_2, $line; }
        }
        my $output_0_2 = join "\n", @uniq_result_0_2;
        if ($output_0_2 ne q{} && !($output_0_2 =~ m{\n\z}msx)) {
        $output_0_2 .= "\n";
        }
        $output_0 = $output_0_2;

                my @lines = split /\n/msx, $output_0;
        my $result_0_3 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        if ("$status" eq "H") {
        my $status;
        my @status;
        my %status;
        $status = " ";
        $CHILD_ERROR = 0;
        } else {
        $CHILD_ERROR = 1;
        }
        if ("$status" eq "C") {
        $status = "*";
        $CHILD_ERROR = 0;
        } else {
        $CHILD_ERROR = 1;
        }
        do {
        my $__echo_line = "-r--r--r--   1 $user     0  0 $DATE " . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname($fname); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) . "/$prefix$status" . (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($fname); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
        if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        $__echo_line .= "\n";
        }
        $output .= $__echo_line;
        };
        $CHILD_ERROR = 0;
        }
        $output_0 = $result_0_3;
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

sub gitfs_copyout {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$_[3]"
      or die "Cannot open file: $OS_ERROR\n";
printf("%s\n", "$_[1]");
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    my $b;
    my @b;
    my %b;
    $b = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_3 = q{};
        my $output_printed_3;
        my $pipeline_success_3 = 1;
        $output_3 .= $prefix . "\n";
        if ( !($output_3 =~ m{\n\z}msx) ) { $output_3 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_3 = 0; }
        $output_3 = do {
                    my $_wc_data = $output_3;
                    my $_wc_bytes = length($_wc_data);
                    my $_wc_result = q{};
                    $_wc_result .= sprintf q{%d}, $_wc_bytes;
                    $_wc_result .= "\n";
                    $_wc_result;
                };
        if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
        $output_3 =~ s/\n+\z//msx;
        $output_3;
}; $_pipeline_result; };
    $b = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'expr', "$b", q{+}, q{1});
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
};
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$_[3]"
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname("$_[2]"); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) . "/" . (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_5 = q{};
        my $output_printed_5;
        my @tail_lines = ();
        my $output_6 = q{};
        while (my $line = <>) {
            chomp $line;
            # basename doesn't support line-by-line processing
            # tail -10: collecting all lines first (pipeline limitation)
            push @tail_lines, $line;
            $line = q{}; # Clear line to prevent printing
        }
        if (@tail_lines) {
            my $tail_count = scalar @tail_lines;
            my $start_idx = $tail_count > 3 ? $tail_count - 3 : 0;
            for my $i ($start_idx .. $tail_count - 1) {
                print $tail_lines[$i] . "\n";
            }
        }
        $output_6;
        if (@tail_lines > 0) {
            my @last_lines = @tail_lines[-3..-1];
            $output_5 = join "\n", @last_lines;
            if ($output_5 ne q{}) {
                $output_5 .= "\n";
            }
        } };
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$_[3]"
      or die "Cannot open file: $OS_ERROR\n";
        print "git\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}
if ("$_[0]" =~ /^list$/msx) {
        gitfs_list("@ARGV");
} elsif ("$_[0]" =~ /^copyout$/msx) {
        gitfs_copyout("@ARGV");
} elsif (1) {
    exit 1;
}
exit 0;

exit $main_exit_code;
