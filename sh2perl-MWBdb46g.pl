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

my $SUBDIRECTORY_OK;
my @SUBDIRECTORY_OK;
my %SUBDIRECTORY_OK;
$SUBDIRECTORY_OK = 'Yes';
my $OPTIONS_KEEPDASHDASH;
my @OPTIONS_KEEPDASHDASH;
my %OPTIONS_KEEPDASHDASH;
$OPTIONS_KEEPDASHDASH = q{};
my $OPTIONS_STUCKLONG;
my @OPTIONS_STUCKLONG;
my %OPTIONS_STUCKLONG;
$OPTIONS_STUCKLONG = q{};
my $OPTIONS_SPEC;
my @OPTIONS_SPEC;
my %OPTIONS_SPEC;
$OPTIONS_SPEC = "git request-pull [options] start url [end]\n--\np    show patch text as well\n";
$main_exit_code = system('.', 'git-sh-setup') >> 8;
my $GIT_PAGER;
my @GIT_PAGER;
my %GIT_PAGER;
$GIT_PAGER = q{};
$ENV{GIT_PAGER} = $GIT_PAGER;
my $patch;
my @patch;
my %patch;
$patch = q{};
while ( if ("${scalar(@ARGV)}" =~ /^0$/msx) {
    last;} ) {
if ("$_[0]" =~ /^-p$/msx) {
                $patch = '-p';
    } elsif ("$_[0]" =~ /^--$/msx) {
        # Builtin command 'shift' not implemented
        last;    } elsif ("$_[0]" =~ /^-.*$/msx) {
                $main_exit_code = system('bash', 'usage') >> 8;
    } elsif (1) {
        last;    }
# Builtin command 'shift' not implemented
}
my $base;
my @base;
my %base;
$base = $1;
my $url;
my @url;
my %url;
$url = $2;
my $status;
my @status;
my %status;
$status = q{0};
if (do {
$main_exit_code = system('test', '-n', "$base") >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('test', '-n', "$url") >> 8;
}
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('bash', 'usage') >> 8;
}
my $baserev;
my @baserev;
my %baserev;
$baserev = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'git', 'rev-parse', '--verify', '--quiet', "$base", '^0');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
if (StringInterpolation(StringInterpolation { parts: [Variable("baserev")] }, None) eq q{}) {
    $main_exit_code = system('die', "fatal: Not a valid revision: $base") >> 8;
}
my $local;
my @local;
my %local;
$local = scalar reverse( (scalar reverse $_[2]) =~ s/^.*?://r );
$local = (defined ${local} && ${local} ne q{} ? ${local} : 'HEAD');
my $remote;
my @remote;
my %remote;
$remote = $_[2] =~ s/^.*?://r;
my $pretty_remote;
my @pretty_remote;
my %pretty_remote;
$pretty_remote = ${remote} =~ s/^refs///r;
$pretty_remote = ${pretty_remote} =~ s/^heads///r;
my $head;
my @head;
my %head;
$head = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'git', 'symbolic-ref', '-q', "$local");
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
};
$head = (defined ${head} && ${head} ne q{} ? ${head} : do { my $_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;

    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'git', 'show-ref', '--heads', '--tags');
    close $in_3 or croak 'Close failed: $OS_ERROR';
    $output_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }
    my @lines_4 = split /\n/msx, $output_2;
    my @result_4;
    foreach my $line (@lines_4) {
    chomp $line;
    my @fields = split /\ /msx, $line;
    if (@fields > 1) {
        push @result_4, $fields[1];
    }
    }
    $output_2 = join "\n", @result_4;
    if ($output_2 ne q{} && !($output_2  =~ m{\n\z}msx)) { $output_2 .= "\n"; }

    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
    $output_2 =~ s/\n+\z//msx;
    $output_2;
}; $_pipeline_result; }; $_result; });
$head = (defined ${head} && ${head} ne q{} ? ${head} : do { my $_result = do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'git', 'rev-parse', '--quiet', '--verify', "$local");
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
}; $_result; });
if (do {
$main_exit_code = system('test', '-z', "$head") >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('die', "fatal: Not a valid revision: $local") >> 8;
}
my $headrev;
my @headrev;
my %headrev;
$headrev = do {
    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'git', 'rev-parse', '--verify', '--quiet', "$head", '^0');
    close $in_6 or croak 'Close failed: $OS_ERROR';
    my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    $result_6
};
if (do {
$main_exit_code = system('test', '-z', "$headrev") >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('die', "fatal: Ambiguous revision: $local") >> 8;
}
my $local_sha1;
my @local_sha1;
my %local_sha1;
$local_sha1 = do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'git', 'rev-parse', '--verify', '--quiet', "$head");
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
};
my $branch_name;
my @branch_name;
my %branch_name;
$branch_name = ${head} =~ s/^refs/heads///r;
if ((!($main_exit_code = system('test', "z$branch_name", q{=}, "z$ENV{headref}") >> 8) || !(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
!($main_exit_code = system('git', 'config', "branch.$branch_name.description") >> 8;)
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
}))) {
    $branch_name = q{};
}
my $merge_base;
my @merge_base;
my %merge_base;
$merge_base = do {
    my ($in_8, $out_8);
    my $pid_8 = open3($in_8, $out_8, '>&STDERR', 'git', 'merge-base', $baserev, $headrev);
    close $in_8 or croak 'Close failed: $OS_ERROR';
    my $result_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
    close $out_8 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_8, 0;
    $result_8
};
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('die', "fatal: No commits in common between $base and $head") >> 8;
}
my $find_matching_ref;
my @find_matching_ref;
my %find_matching_ref;
$find_matching_ref = "\n\tmy ($head,$headrev) = (@ARGV);\n\tmy $pattern = qr{/\\Q$head\\E$};\n\tmy ($remote_sha1, $found);\n\n\twhile (<STDIN>) {\n\t\tchomp;\n\t\tmy ($sha1, $ref, $deref) = /^(\\S+)\\s+([^^]+)(\\S*)$/;\n\n\t\tif ($sha1 eq $head) {\n\t\t\t$found = $remote_sha1 = $sha1;\n\t\t\tbreak;\n\t\t}\n\n\t\tif ($ref eq $head || $ref =~ $pattern) {\n\t\t\tif ($deref eq \"\") {\n\t\t\t\t# Remember the matching object on the remote side\n\t\t\t\t$remote_sha1 = $sha1;\n\t\t\t}\n\t\t\tif ($sha1 eq $headrev) {\n\t\t\t\t$found = $ref;\n\t\t\t\tbreak;\n\t\t\t}\n\t\t}\n\t}\n\tif ($found) {\n\t\t$remote_sha1 = $headrev if ! defined $remote_sha1;\n\t\tprint \"$remote_sha1 $found\\n\";\n\t}\n";
# set fnord not implemented
my $remote_sha1;
my @remote_sha1;
my %remote_sha1;
$remote_sha1 = $2;
my $ref;
my @ref;
my %ref;
$ref = $3;
if (StringInterpolation(StringInterpolation { parts: [Variable("ref")] }, None) eq q{}) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "warn: No match for commit $headrev found at $url";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "warn: Are you sure you pushed '" . (defined (defined ${remote} && ${remote} ne q{} ? ${remote} : 'HEAD') && (defined ${remote} && ${remote} ne q{} ? ${remote} : 'HEAD') ne q{} ? (defined ${remote} && ${remote} ne q{} ? ${remote} : 'HEAD') : 'HEAD') . "' there?";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    $status = q{1};
}
else {
    if ((!StringInterpolation(StringInterpolation { parts: [Variable("local_sha1")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("remote_sha1")] }, None))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "warn: $head found at $url but points to a different object";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "warn: Are you sure you pushed '" . (defined (defined ${remote} && ${remote} ne q{} ? ${remote} : 'HEAD') && (defined ${remote} && ${remote} ne q{} ? ${remote} : 'HEAD') ne q{} ? (defined ${remote} && ${remote} ne q{} ? ${remote} : 'HEAD') : 'HEAD') . "' there?";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        $status = q{1};
    }
}
if (StringInterpolation(StringInterpolation { parts: [Variable("ref")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("refs/tags/"), Variable("pretty_remote")] }, None)) {
    $pretty_remote = 'tags/';
    $CHILD_ERROR = 0;
}
$url = do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'git', 'ls-remote', '--get-url', "$url");
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
};
if (do {
if (do {
if (do {
if (do {
if (do {
if (do {
$main_exit_code = system('git', 'show', '-s', "--format=The following changes since commit %H:\n\n  %s (%ci)\n\nare available in the Git repository at:\n", $merge_base) >> 8;
    $CHILD_ERROR == 0
}) {
        do {
    my $__echo_line = "  $url $pretty_remote";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('git', 'show', '-s', "--format=\nfor you to fetch changes up to %H:\n\n  %s (%ci)\n\n----------------------------------------------------------------", $headrev) >> 8;
}
    $CHILD_ERROR == 0
}) {
    if (CommandSubstitution(Simple(SimpleCommand { name: Literal("git", None), args: [Literal("cat-file", None), Literal("-t", None), StringInterpolation(StringInterpolation { parts: [Variable("head")] }, None)], redirects: [], env_vars: {}, stdout_used: true, stderr_used: true }), None) eq tag) {
        # Original bash: git cat-file tag "$head" |
{
            my $output_10 = q{};
            my $output_printed_10;
            my $pipeline_success_10 = 1;
                        my ($in_11, $out_11);
            my $pid_11 = open3($in_11, $out_11, '>&STDERR', 'git', 'cat-file', 'tag');
            close $in_11 or croak 'Close failed: $OS_ERROR';
            $output_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
            close $out_11 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_11, 0;

                        my @sed_lines_10 = split /\n/msx, $output_10;
            my @sed_result_10;
            foreach my $line (@sed_lines_10) {
            chomp $line;
            push @sed_result_10, $line;
            }
            $output_10 = join "\n", @sed_result_10;
            if ($output_10 ne q{} && !defined $output_printed_10) {
                print $output_10;
                if (!($output_10 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_10 ) { $main_exit_code = 1; }
            }
        print "\n";
        $CHILD_ERROR = 0;
        print "----------------------------------------------------------------\n";
    }
}
    $CHILD_ERROR == 0
}) {
    if (StringInterpolation(StringInterpolation { parts: [Variable("branch_name")] }, None) ne q{}) {
        do {
    my $__echo_line = "(from the branch description for $branch_name local branch)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print "\n";
        $CHILD_ERROR = 0;
        $main_exit_code = system('git', 'config', "branch.$branch_name.description") >> 8;
        print "----------------------------------------------------------------\n";
    }
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('git', 'shortlog', '^$baserev', $headrev) >> 8;
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('git', 'diff', '-M', '--stat', '--summary', $patch, $merge_base, '..', $headrev) >> 8;
}
if ($CHILD_ERROR != 0) {
        $status = q{1};
}


exit $main_exit_code;
