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

my $MAGIC_3 = 3;

if (((!($main_exit_code = system('test', '-z', "$ENV{GIT_EXEC_PATH}") >> 8) || !(!($main_exit_code = system('test', '-f', "$ENV{GIT_EXEC_PATH}/git-sh-setup") >> 8;))) || !(    if (do {
$main_exit_code = system('test', (($ENV{PATH} // q{}) =~ s/^"\$\{GIT_EXEC_PATH\}:"//r =~ s/^"\$\{GIT_EXEC_PATH\}:"//r), q{=}, "$ENV{PATH}") >> 8;
        $CHILD_ERROR == 0
    }) {
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            $main_exit_code = system('test', q{!}, "$ENV{GIT_EXEC_PATH}", '-ef', (($ENV{PATH} // q{}) =~ s/:.*$//sr =~ s/:.*$//sr)) >> 8;
        };
    }))) {
    my $basename;
    my @basename;
    my %basename;
    $basename = q{};
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $main_exit_code = system('bash', 'It looks like either your git installation or your') >> 8;
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $main_exit_code = system('bash', 'git-subtree installation is broken.') >> 8;
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $main_exit_code = system('bash', 'Tips:') >> 8;
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $CHILD_ERROR = 0;
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $main_exit_code = system('bash', '   your git install directory, then set the GIT_EXEC_PATH') >> 8;
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $main_exit_code = system('bash', '   environment variable to the correct directory.') >> 8;
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $CHILD_ERROR = 0;
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $CHILD_ERROR = 0;
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $CHILD_ERROR = 0;
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        $CHILD_ERROR = 0;
    };
exit 126;
}
my $OPTS_SPEC;
my @OPTS_SPEC;
my %OPTS_SPEC;
$OPTS_SPEC = "\
git subtree add   --prefix=<prefix> <commit>
git subtree add   --prefix=<prefix> <repository> <ref>
git subtree merge --prefix=<prefix> <commit>
git subtree split --prefix=<prefix> [<commit>]
git subtree pull  --prefix=<prefix> <repository> <ref>
git subtree push  --prefix=<prefix> <repository> <refspec>
--
h,help!       show the help
q,quiet!      quiet
d,debug!      show debug messages
P,prefix=     the name of the subdir to split out
 options for 'split' (also: 'push')
annotate=     add a prefix to commit message of new commits
b,branch!=    create a new branch from the split subtree
ignore-joins  ignore prior --rejoin commits
onto=         try connecting new tree to an existing one
rejoin        merge the new branch back into HEAD
 options for 'add' and 'merge' (also: 'pull', 'split --rejoin', and 'push --rejoin')
squash        merge subtree changes as a single commit
m,message!=   use the given message as the commit message for the merge commit
";
my $indent;
my @indent;
my %indent;
$indent = q{0};

sub say {
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_quiet")] }, None) eq q{}) {
foreach my $item (@ARGV) {
    printf("%s\n", $item);
}
    }
    return;
}

sub debug {
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_debug")] }, None) ne q{}) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s%s\n", q{}, "@ARGV");
        };
    }
    return;
}

sub progress {
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_quiet")] }, None) eq q{}) {
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_debug")] }, None) eq q{}) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
foreach my $item (@ARGV) {
    printf("%s\r", $item);
}
            };
}
        else {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
foreach my $item (@ARGV) {
    printf("progress: %s\n", $item);
}
            };
        }
    }
    return;
}

sub assert {
if (!(!($CHILD_ERROR = 0;))) {
        $main_exit_code = system('die', "fatal: assertion failed: @ARGV") >> 8;
    }
    return;
}

sub die_incompatible_opt {
    assert('test', "${scalar(@ARGV)}", q{=}, q{2});
    my $opt;
    my @opt;
    my %opt;
    $opt = "$_[0]";
    my $arg_command;
    my @arg_command;
    my %arg_command;
    $arg_command = "$_[1]";
    $main_exit_code = system('die', "fatal: the '$opt' flag does not make sense with 'git subtree $arg_command'.") >> 8;
    return;
}

sub main {
if ((Variable("#", false, None) == 0)) {
# set -- not implemented
# set -h not implemented
    }
    my $set_args;
    my @set_args;
    my %set_args;
    $set_args = (do { my $_chomp_temp = do {
    local $ENV{OPTS_SPEC} = $OPTS_SPEC;
    my $command = 'echo "$OPTS_SPEC" | git rev-parse --parseopt -- "$@" || echo exit Variable("?", false, None)';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
do { my $eval_input = $set_args; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    $main_exit_code = system('.', 'git-sh-setup') >> 8;
    $main_exit_code = system('bash', 'require_work_tree') >> 8;
    my $arg_split_rejoin;
    my @arg_split_rejoin;
    my %arg_split_rejoin;
    $arg_split_rejoin = q{};
    my $allow_split;
    my @allow_split;
    my %allow_split;
    $allow_split = q{};
    my $allow_addmerge;
    my @allow_addmerge;
    my %allow_addmerge;
    $allow_addmerge = q{};
    my $# = 0;
while ( (Variable("#", false, None) > 0) ) {
        my $opt;
        my @opt;
        my %opt;
        $opt = "$_[0]";
# Builtin command 'shift' not implemented
if ("$opt" =~ /^--annotate$/msx or "$opt" =~ /^-b$/msx or "$opt" =~ /^-P$/msx or "$opt" =~ /^-m$/msx or "$opt" =~ /^--onto$/msx) {
            # Builtin command 'shift' not implemented
        } elsif ("$opt" =~ /^--rejoin$/msx) {
                        $arg_split_rejoin = q{1};
        } elsif ("$opt" =~ /^--no-rejoin$/msx) {
                        $arg_split_rejoin = q{};
        } elsif ("$opt" =~ /^--$/msx) {
            last;        }
    }
    my $arg_command;
    my @arg_command;
    my %arg_command;
    $arg_command = $1;
if ("$arg_command" =~ /^add$/msx or "$arg_command" =~ /^merge$/msx or "$arg_command" =~ /^pull$/msx) {
                $allow_addmerge = q{1};
    } elsif ("$arg_command" =~ /^split$/msx or "$arg_command" =~ /^push$/msx) {
                $allow_split = q{1};
                $allow_addmerge = $arg_split_rejoin;
    } elsif (1) {
                $main_exit_code = system('die', "fatal: unknown command '$arg_command'") >> 8;
    }
do { my $eval_input = $set_args; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    my $arg_quiet;
    my @arg_quiet;
    my %arg_quiet;
    $arg_quiet = q{};
    my $arg_debug;
    my @arg_debug;
    my %arg_debug;
    $arg_debug = q{};
    my $arg_prefix;
    my @arg_prefix;
    my %arg_prefix;
    $arg_prefix = q{};
    my $arg_split_branch;
    my @arg_split_branch;
    my %arg_split_branch;
    $arg_split_branch = q{};
    my $arg_split_onto;
    my @arg_split_onto;
    my %arg_split_onto;
    $arg_split_onto = q{};
    my $arg_split_ignore_joins;
    my @arg_split_ignore_joins;
    my %arg_split_ignore_joins;
    $arg_split_ignore_joins = q{};
    my $arg_split_annotate;
    my @arg_split_annotate;
    my %arg_split_annotate;
    $arg_split_annotate = q{};
    my $arg_addmerge_squash;
    my @arg_addmerge_squash;
    my %arg_addmerge_squash;
    $arg_addmerge_squash = q{};
    my $arg_addmerge_message;
    my @arg_addmerge_message;
    my %arg_addmerge_message;
    $arg_addmerge_message = q{};
while ( (Variable("#", false, None) > 0) ) {
        $opt = "$_[0]";
# Builtin command 'shift' not implemented
if ("$opt" =~ /^-q$/msx) {
                        $arg_quiet = q{1};
        } elsif ("$opt" =~ /^-d$/msx) {
                        $arg_debug = q{1};
        } elsif ("$opt" =~ /^--annotate$/msx) {
                                    $main_exit_code = system('test', '-n', "$allow_split") >> 8;
            if ($CHILD_ERROR != 0) {
                                die_incompatible_opt("$opt", "$arg_command");
            }
                        $arg_split_annotate = "$_[0]";
            # Builtin command 'shift' not implemented
        } elsif ("$opt" =~ /^--no-annotate$/msx) {
                                    $main_exit_code = system('test', '-n', "$allow_split") >> 8;
            if ($CHILD_ERROR != 0) {
                                die_incompatible_opt("$opt", "$arg_command");
            }
                        $arg_split_annotate = q{};
        } elsif ("$opt" =~ /^-b$/msx) {
                                    $main_exit_code = system('test', '-n', "$allow_split") >> 8;
            if ($CHILD_ERROR != 0) {
                                die_incompatible_opt("$opt", "$arg_command");
            }
                        $arg_split_branch = "$_[0]";
            # Builtin command 'shift' not implemented
        } elsif ("$opt" =~ /^-P$/msx) {
                        $arg_prefix = (scalar reverse( (scalar reverse $_[0]) =~ s/^///r ) =~ s//$//r);
            # Builtin command 'shift' not implemented
        } elsif ("$opt" =~ /^-m$/msx) {
                                    $main_exit_code = system('test', '-n', "$allow_addmerge") >> 8;
            if ($CHILD_ERROR != 0) {
                                die_incompatible_opt("$opt", "$arg_command");
            }
                        $arg_addmerge_message = "$_[0]";
            # Builtin command 'shift' not implemented
        } elsif ("$opt" =~ /^--no-prefix$/msx) {
                        $arg_prefix = q{};
        } elsif ("$opt" =~ /^--onto$/msx) {
                                    $main_exit_code = system('test', '-n', "$allow_split") >> 8;
            if ($CHILD_ERROR != 0) {
                                die_incompatible_opt("$opt", "$arg_command");
            }
                        $arg_split_onto = "$_[0]";
            # Builtin command 'shift' not implemented
        } elsif ("$opt" =~ /^--no-onto$/msx) {
                                    $main_exit_code = system('test', '-n', "$allow_split") >> 8;
            if ($CHILD_ERROR != 0) {
                                die_incompatible_opt("$opt", "$arg_command");
            }
                        $arg_split_onto = q{};
        } elsif ("$opt" =~ /^--rejoin$/msx) {
                                    $main_exit_code = system('test', '-n', "$allow_split") >> 8;
            if ($CHILD_ERROR != 0) {
                                die_incompatible_opt("$opt", "$arg_command");
            }
        } elsif ("$opt" =~ /^--no-rejoin$/msx) {
                                    $main_exit_code = system('test', '-n', "$allow_split") >> 8;
            if ($CHILD_ERROR != 0) {
                                die_incompatible_opt("$opt", "$arg_command");
            }
        } elsif ("$opt" =~ /^--ignore-joins$/msx) {
                                    $main_exit_code = system('test', '-n', "$allow_split") >> 8;
            if ($CHILD_ERROR != 0) {
                                die_incompatible_opt("$opt", "$arg_command");
            }
                        $arg_split_ignore_joins = q{1};
        } elsif ("$opt" =~ /^--no-ignore-joins$/msx) {
                                    $main_exit_code = system('test', '-n', "$allow_split") >> 8;
            if ($CHILD_ERROR != 0) {
                                die_incompatible_opt("$opt", "$arg_command");
            }
                        $arg_split_ignore_joins = q{};
        } elsif ("$opt" =~ /^--squash$/msx) {
                                    $main_exit_code = system('test', '-n', "$allow_addmerge") >> 8;
            if ($CHILD_ERROR != 0) {
                                die_incompatible_opt("$opt", "$arg_command");
            }
                        $arg_addmerge_squash = q{1};
        } elsif ("$opt" =~ /^--no-squash$/msx) {
                                    $main_exit_code = system('test', '-n', "$allow_addmerge") >> 8;
            if ($CHILD_ERROR != 0) {
                                die_incompatible_opt("$opt", "$arg_command");
            }
                        $arg_addmerge_squash = q{};
        } elsif ("$opt" =~ /^--$/msx) {
            last;        } elsif (1) {
                        $main_exit_code = system('die', "fatal: unexpected option: $opt") >> 8;
        }
    }
# Builtin command 'shift' not implemented
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_prefix")] }, None) eq q{}) {
        $main_exit_code = system('die', "fatal: you must provide the --prefix option.") >> 8;
    }
if ("$arg_command" =~ /^add$/msx) {
                if (do {
$main_exit_code = system('test', '-e', "$arg_prefix") >> 8;
            $CHILD_ERROR == 0
        }) {
                        $main_exit_code = system('die', "fatal: prefix '$arg_prefix' already exists.") >> 8;
        }
    } elsif (1) {
                        $main_exit_code = system('test', '-e', "$arg_prefix") >> 8;
        if ($CHILD_ERROR != 0) {
                        $main_exit_code = system('die', "fatal: '$arg_prefix' does not exist; use 'git subtree add'") >> 8;
        }
    }
    my $dir;
    my @dir;
    my %dir;
    $dir = (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname("$arg_prefix/."); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; });
    debug("command: {$arg_command}");
    debug("quiet: {$arg_quiet}");
    debug("dir: {$dir}");
    debug("opts: {@ARGV}");
    debug();
    $CHILD_ERROR = 0;
    return;
}

sub cache_setup {
    assert('test', scalar(@ARGV), q{=}, q{0});
    my $cachedir;
    my @cachedir;
    my %cachedir;
    $cachedir = "$ENV{GIT_DIR}/subtree-cache/$ENV{$}";
    if ( -e "$cachedir" ) {
        if ( -d "$cachedir" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$cachedir", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "$cachedir", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$cachedir" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$cachedir",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', "fatal: can't delete old cachedir: $cachedir") >> 8;
    }
        use File::Path qw(make_path);
    my $err;
    if ( !-d "$cachedir" ) {
        make_path( "$cachedir", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . "$cachedir" . ": $err->[0]\n";
        }
    }
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', "fatal: can't create new cachedir: $cachedir") >> 8;
    }
        use File::Path qw(make_path);
    if ( !-d "$cachedir/notree" ) {
        make_path( "$cachedir/notree", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . "$cachedir/notree" . ": $err->[0]\n";
        }
    }
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', "fatal: can't create new cachedir: $cachedir/notree") >> 8;
    }
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        debug("Using cachedir: $cachedir");
    };
    return;
}

sub cache_get {
    my $oldrev;
    for my $oldrev (@ARGV) {
if ((-r 'StringInterpolation(StringInterpolation { parts: [Variable("cachedir"), Literal("/"), Variable("oldrev")] }, None)')) {
open STDIN, '<', "$ENV{cachedir}/$oldrev" or croak "Cannot open file: $OS_ERROR\n";
$newrev = <>;
chomp $newrev;
$CHILD_ERROR = defined($newrev) ? 0 : 1;
            print $newrev;
if ( !( ($newrev) =~ m{\n\z}msx ) ) { print "\n"; }
        }
    }
    return;
}

sub cache_miss {
    my $oldrev;
    for my $oldrev (@ARGV) {
if (!(!($main_exit_code = system('test', '-r', "$ENV{cachedir}/$oldrev") >> 8;))) {
            print $oldrev;
if ( !( ($oldrev) =~ m{\n\z}msx ) ) { print "\n"; }
        }
    }
    return;
}

sub check_parents {
        my $missed;
    my @missed;
    my %missed;
    $missed = do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'cache_miss', "@ARGV");
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
};
    if ($CHILD_ERROR != 0) {
            }
    my $indent = eval { int($indent + 1) } // "";
    my $miss;
    for my $miss ($missed) {
if (!(!($main_exit_code = system('test', '-r', "$ENV{cachedir}/notree/$miss") >> 8;))) {
            debug("incorrect order: $miss");
            $main_exit_code = system('process_split_commit', "$miss", "") >> 8;
        }
    }
    return;
}

sub set_notree {
    assert('test', scalar(@ARGV), q{=}, q{1});
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$ENV{cachedir}/notree/$_[0]"
      or die "Cannot open file: $OS_ERROR\n";
        print "1\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub cache_set {
    assert('test', scalar(@ARGV), q{=}, q{2});
    my $oldrev;
    my @oldrev;
    my %oldrev;
    $oldrev = "$_[0]";
    my $newrev;
    my @newrev;
    my %newrev;
    $newrev = "$_[1]";
if (((!(    $main_exit_code = system('test', "$oldrev", q{!}, q{=}, "latest_old") >> 8) && !(    $main_exit_code = system('test', "$oldrev", q{!}, q{=}, "latest_new") >> 8)) && !(    $main_exit_code = system('test', '-e', "$ENV{cachedir}/$oldrev") >> 8))) {
        $main_exit_code = system('die', "fatal: cache for $oldrev already exists!") >> 8;
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$ENV{cachedir}/$oldrev"
      or die "Cannot open file: $OS_ERROR\n";
        print $newrev;
if ( !( ($newrev) =~ m{\n\z}msx ) ) { print "\n"; }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub rev_exists {
    assert('test', scalar(@ARGV), q{=}, q{1});
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('git', 'rev-parse', "$_[0]") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
return q{0};
}
    else {
return q{1};
    }
    return;
}

sub try_remove_previous {
    my ($file) = @_;
    assert('test', scalar(@ARGV), q{=}, q{1});
if (!(    rev_exists("$_[0]^"))) {
        do {
    my $__echo_line = "^$_[0]^";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    return;
}

sub process_subtree_split_trailer {
    assert('test', scalar(@ARGV), q{=}, q{2}, '-o', scalar(@ARGV), q{=}, q{3});
    my $b;
    my @b;
    my %b;
    $b = "$_[0]";
    my $sq;
    my @sq;
    my %sq;
    $sq = "$_[1]";
    my $repository;
    my @repository;
    my %repository;
    $repository = "";
if (StringInterpolation(StringInterpolation { parts: [Variable("#")] }, None) eq 3) {
        $repository = "$_[2]";
    }
    my $fail_msg;
    my @fail_msg;
    my %fail_msg;
    $fail_msg = "fatal: could not rev-parse split hash $b from commit $sq";
if (!(!(my $sub;
    my @sub;
    my %sub;
    $sub = (do { my $_chomp_temp = do {
    my ($in_8, $out_8);
    my $pid_8 = open3($in_8, $out_8, '>&STDERR', 'git', 'rev-parse', '--verify', '--quiet', "$b^{commit}");
    close $in_8 or croak 'Close failed: $OS_ERROR';
    my $result_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
    close $out_8 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_8, 0;
    $result_8
}; chomp $_chomp_temp; $_chomp_temp; });))) {
if (StringInterpolation(StringInterpolation { parts: [ParameterExpansion(ParameterExpansion { variable: "repository", operator: None, is_mutable: true })] }, None) ne q{}) {
            $main_exit_code = system('git', 'fetch', "$repository", "$b") >> 8;
                        $sub = (do { my $_chomp_temp = do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'git', 'rev-parse', '--verify', '--quiet', "$b^{commit}");
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
}; chomp $_chomp_temp; $_chomp_temp; });
            if ($CHILD_ERROR != 0) {
                                $main_exit_code = system('die', "$fail_msg") >> 8;
            }
}
        else {
            my $hint1;
            my @hint1;
            my %hint1;
            $hint1 = sprintf('hint: hash might be a tag, try fetching it from the subtree repository:');
;
            my $hint2;
            my @hint2;
            my %hint2;
            $hint2 = sprintf('hint:    git fetch <subtree-repository> ');
;
            $fail_msg = sprintf("\n\n");
;
            $main_exit_code = system('die', "$fail_msg") >> 8;
        }
    }
    return;
}

sub find_latest_squash {
    assert('test', scalar(@ARGV), q{=}, q{1}, '-o', scalar(@ARGV), q{=}, q{2});
    my $dir;
    my @dir;
    my %dir;
    $dir = "$_[0]";
    my $repository;
    my @repository;
    my %repository;
    $repository = "";
if (StringInterpolation(StringInterpolation { parts: [Variable("#")] }, None) eq 2) {
        $repository = "$_[1]";
    }
    debug("Looking for latest squash (dir=$dir, repository=$repository)...");
    my $indent = eval { int($indent + 1) } // "";
    my $sq;
    my @sq;
    my %sq;
    $sq = q{};
    my $main;
    my @main;
    my %main;
    $main = q{};
    my $sub;
    my @sub;
    my %sub;
    $sub = q{};
    {
        my $output_10 = q{};
        my $output_printed_10;
        my $pipeline_success_10 = 1;
                my ($in_11, $out_11);
        my $pid_11 = open3($in_11, $out_11, '>&STDERR', 'git', 'log', "--grep=^git-subtree-dir: $dir/*\\$", '--no-show-signature', '--pretty=format:', 'START %H%n%s%n%n%b%nEND%n', 'HEAD');
        close $in_11 or croak 'Close failed: $OS_ERROR';
        $output_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
        close $out_11 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_11, 0;

                my @lines = split /\n/msx, $output_10;
        my $result_10_1 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        debug("$ENV{a} $ENV{b} $ENV{junk}");
        debug("{{$sq/$main/$sub}}");
        if ("$ENV{a}" =~ /^START$/msx) {
        $sq = "$ENV{b}";
        } elsif ("$ENV{a}" =~ /^git-subtree-mainline:$/msx) {
        $main = "$ENV{b}";
        } elsif ("$ENV{a}" =~ /^git-subtree-split:$/msx) {
        process_subtree_split_trailer("$ENV{b}", "$sq", "$repository");
        } elsif ("$ENV{a}" =~ /^END$/msx) {
        if (StringInterpolation(StringInterpolation { parts: [Variable("sub")] }, None) ne q{}) {
        if (StringInterpolation(StringInterpolation { parts: [Variable("main")] }, None) ne q{}) {
        $sq = do {
        my ($in_12, $out_12);
        my $pid_12 = open3($in_12, $out_12, '>&STDERR', 'git', 'rev-parse', '--verify', "$sq^2");
        close $in_12 or croak 'Close failed: $OS_ERROR';
        my $result_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
        close $out_12 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_12, 0;
        $result_12
        };
        if ($CHILD_ERROR != 0) {
        $main_exit_code = system('bash', 'die') >> 8;
        }
        }
        debug("Squash found: $sq $sub");
        do {
        my $__echo_line = $sq . q{ } . $sub;
        if (!($__echo_line =~ /\n$/msx)) {
        $__echo_line .= "\n";
        }
        $output .= $__echo_line;
        };
        $CHILD_ERROR = 0;
        last;
        }
        $sq = q{};
        $main = q{};
        $sub = q{};
        }
        }
        $output_10 = $result_10_1;
        if ($output_10 ne q{} && !defined $output_printed_10) {
            print $output_10;
            if (!($output_10 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_10 ) { $main_exit_code = 1; }
        }
    if ($CHILD_ERROR != 0) {
            }
    return;
}

sub find_existing_splits {
    assert('test', scalar(@ARGV), q{=}, q{2}, '-o', scalar(@ARGV), q{=}, q{3});
    debug("Looking for prior splits...");
    my $indent = eval { int($indent + 1) } // "";
    my $dir;
    my @dir;
    my %dir;
    $dir = "$_[0]";
    my $rev;
    my @rev;
    my %rev;
    $rev = "$_[1]";
    my $repository;
    my @repository;
    my %repository;
    $repository = "";
if (StringInterpolation(StringInterpolation { parts: [Variable("#")] }, None) eq 3) {
        $repository = "$_[2]";
    }
    my $main;
    my @main;
    my %main;
    $main = q{};
    my $sub;
    my @sub;
    my %sub;
    $sub = q{};
    my $grep_format = "^git-subtree-dir: $dir/*$";
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_split_ignore_joins")] }, None) ne q{}) {
        $grep_format = "^Add '$dir/' from commit '";
    }
    {
        my $output_13 = q{};
        my $output_printed_13;
        my $pipeline_success_13 = 1;
                my ($in_14, $out_14);
        my $pid_14 = open3($in_14, $out_14, '>&STDERR', 'git', 'log', '--grep=$grep_format', '--no-show-signature', '--pretty=format:', 'START %H%n%s%n%n%b%nEND%n');
        close $in_14 or croak 'Close failed: $OS_ERROR';
        $output_13 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_14> };
        close $out_14 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_14, 0;

                my @lines = split /\n/msx, $output_13;
        my $result_13_1 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        if ("$ENV{a}" =~ /^START$/msx) {
        my $sq;
        my @sq;
        my %sq;
        $sq = "$ENV{b}";
        } elsif ("$ENV{a}" =~ /^git-subtree-mainline:$/msx) {
        $main = "$ENV{b}";
        } elsif ("$ENV{a}" =~ /^git-subtree-split:$/msx) {
        process_subtree_split_trailer("$ENV{b}", "$sq", "$repository");
        } elsif ("$ENV{a}" =~ /^END$/msx) {
        debug("Main is: '$main'");
        if ((StringInterpolation(StringInterpolation { parts: [Variable("main")] }, None) eq q{} && StringInterpolation(StringInterpolation { parts: [Variable("sub")] }, None) ne q{})) {
        debug("  Squash: $sq from $sub");
        cache_set("$sq", "$sub");
        }
        if ((StringInterpolation(StringInterpolation { parts: [Variable("main")] }, None) ne q{} && StringInterpolation(StringInterpolation { parts: [Variable("sub")] }, None) ne q{})) {
        debug("  Prior: $main -> $sub");
        cache_set($main, $sub);
        cache_set($sub, $sub);
        try_remove_previous("$main");
        try_remove_previous("$sub");
        }
        $main = q{};
        $sub = q{};
        }
        }
        $output_13 = $result_13_1;
        if ($output_13 ne q{} && !defined $output_printed_13) {
            print $output_13;
            if (!($output_13 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_13 ) { $main_exit_code = 1; }
        }
    if ($CHILD_ERROR != 0) {
            }
    return;
}

sub copy_commit {
    my ($file) = @_;
    assert('test', scalar(@ARGV), q{=}, q{3});
    debug('copy_commit', "{$_[0]}", "{$_[1]}", "{$_[2]}");
    {
        my $output_15 = q{};
        my $output_printed_15;
        my $pipeline_success_15 = 1;
                my ($in_16, $out_16);
        my $pid_16 = open3($in_16, $out_16, '>&STDERR', 'git', 'log', '-1', '--no-show-signature', '--pretty=format:', '%an%n%ae%n%aD%n%cn%n%ce%n%cD%n%B');
        close $in_16 or croak 'Close failed: $OS_ERROR';
        $output_15 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_16> };
        close $out_16 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_16, 0;

                $output_15 = q{};
        my @_pcmd_18 = ('sh', '-c', 'read GIT_AUTHOR_NAME');
        my ($in_17, $out_17);
        my $pid_17 = open3($in_17, $out_17, '>&STDERR', @_pcmd_18);
        close $in_17 or croak 'Close failed: $OS_ERROR';
        $output_15 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> };
        close $out_17 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_17, 0;
        my @_pcmd_20 = ('sh', '-c', 'read GIT_AUTHOR_EMAIL');
        my ($in_19, $out_19);
        my $pid_19 = open3($in_19, $out_19, '>&STDERR', @_pcmd_20);
        close $in_19 or croak 'Close failed: $OS_ERROR';
        $output_15 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19> };
        close $out_19 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_19, 0;
        my @_pcmd_22 = ('sh', '-c', 'read GIT_AUTHOR_DATE');
        my ($in_21, $out_21);
        my $pid_21 = open3($in_21, $out_21, '>&STDERR', @_pcmd_22);
        close $in_21 or croak 'Close failed: $OS_ERROR';
        $output_15 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_21> };
        close $out_21 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_21, 0;
        my @_pcmd_24 = ('sh', '-c', 'read GIT_COMMITTER_NAME');
        my ($in_23, $out_23);
        my $pid_23 = open3($in_23, $out_23, '>&STDERR', @_pcmd_24);
        close $in_23 or croak 'Close failed: $OS_ERROR';
        $output_15 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
        close $out_23 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_23, 0;
        my @_pcmd_26 = ('sh', '-c', 'read GIT_COMMITTER_EMAIL');
        my ($in_25, $out_25);
        my $pid_25 = open3($in_25, $out_25, '>&STDERR', @_pcmd_26);
        close $in_25 or croak 'Close failed: $OS_ERROR';
        $output_15 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_25> };
        close $out_25 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_25, 0;
        my @_pcmd_28 = ('sh', '-c', 'read GIT_COMMITTER_DATE');
        my ($in_27, $out_27);
        my $pid_27 = open3($in_27, $out_27, '>&STDERR', @_pcmd_28);
        close $in_27 or croak 'Close failed: $OS_ERROR';
        $output_15 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_27> };
        close $out_27 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_27, 0;
        my @_pcmd_30 = ('sh', '-c', ': "Complex command cannot be converted to shell command"');
        my ($in_29, $out_29);
        my $pid_29 = open3($in_29, $out_29, '>&STDERR', @_pcmd_30);
        close $in_29 or croak 'Close failed: $OS_ERROR';
        $output_15 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_29> };
        close $out_29 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_29, 0;
        my @_pcmd_32 = ('sh', '-c', '(printf %s "$arg_split_annotate"; cat) | git commit-tree "$2" Variable("3", false, None)');
        my ($in_31, $out_31);
        my $pid_31 = open3($in_31, $out_31, '>&STDERR', @_pcmd_32);
        close $in_31 or croak 'Close failed: $OS_ERROR';
        $output_15 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
        close $out_31 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_31, 0;
        if ($output_15 ne q{} && !defined $output_printed_15) {
            print $output_15;
            if (!($output_15 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
        }
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', "fatal: can't copy commit $_[0]") >> 8;
    }
    return;
}

sub add_msg {
    assert('test', scalar(@ARGV), q{=}, q{3});
    my $dir;
    my @dir;
    my %dir;
    $dir = "$_[0]";
    my $latest_old;
    my @latest_old;
    my %latest_old;
    $latest_old = "$_[1]";
    my $latest_new;
    my @latest_new;
    my %latest_new;
    $latest_new = "$_[2]";
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_addmerge_message")] }, None) ne q{}) {
        my $commit_message;
        my @commit_message;
        my %commit_message;
        $commit_message = "$ENV{arg_addmerge_message}";
}
    else {
        $commit_message = "Add '$dir/' from commit '$latest_new'";
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_split_rejoin")] }, None) ne q{}) {
        print $commit_message;
if ( !( ($commit_message) =~ m{\n\z}msx ) ) { print "\n"; }
return;
    }
print "\t\t$commit_message

\t\tgit-subtree-dir: $dir
\t\tgit-subtree-mainline: $latest_old
\t\tgit-subtree-split: $latest_new
";
    return;
}

sub add_squashed_msg {
    my ($file) = @_;
    assert('test', scalar(@ARGV), q{=}, q{2});
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_addmerge_message")] }, None) ne q{}) {
        print $arg_addmerge_message;
if ( !( ($arg_addmerge_message) =~ m{\n\z}msx ) ) { print "\n"; }
}
    else {
        do {
    my $__echo_line = "Merge commit '$_[0]' as '$_[1]'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    return;
}

sub rejoin_msg {
    assert('test', scalar(@ARGV), q{=}, q{3});
    my $dir;
    my @dir;
    my %dir;
    $dir = "$_[0]";
    my $latest_old;
    my @latest_old;
    my %latest_old;
    $latest_old = "$_[1]";
    my $latest_new;
    my @latest_new;
    my %latest_new;
    $latest_new = "$_[2]";
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_addmerge_message")] }, None) ne q{}) {
        my $commit_message;
        my @commit_message;
        my %commit_message;
        $commit_message = "$ENV{arg_addmerge_message}";
}
    else {
        $commit_message = "Split '$dir/' into commit '$latest_new'";
    }
print "\t\t$commit_message

\t\tgit-subtree-dir: $dir
\t\tgit-subtree-mainline: $latest_old
\t\tgit-subtree-split: $latest_new
";
    return;
}

sub squash_msg {
    assert('test', scalar(@ARGV), q{=}, q{3});
    my $dir;
    my @dir;
    my %dir;
    $dir = "$_[0]";
    my $oldsub;
    my @oldsub;
    my %oldsub;
    $oldsub = "$_[1]";
    my $newsub;
    my @newsub;
    my %newsub;
    $newsub = "$_[2]";
    my $newsub_short;
    my @newsub_short;
    my %newsub_short;
    $newsub_short = do {
    my ($in_33, $out_33);
    my $pid_33 = open3($in_33, $out_33, '>&STDERR', 'git', 'rev-parse', '--short', "$newsub");
    close $in_33 or croak 'Close failed: $OS_ERROR';
    my $result_33 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_33> };
    close $out_33 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_33, 0;
    $result_33
};
if (StringInterpolation(StringInterpolation { parts: [Variable("oldsub")] }, None) ne q{}) {
        my $oldsub_short;
        my @oldsub_short;
        my %oldsub_short;
        $oldsub_short = do {
    my ($in_34, $out_34);
    my $pid_34 = open3($in_34, $out_34, '>&STDERR', 'git', 'rev-parse', '--short', "$oldsub");
    close $in_34 or croak 'Close failed: $OS_ERROR';
    my $result_34 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_34> };
    close $out_34 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_34, 0;
    $result_34
};
        do {
    my $__echo_line = "Squashed '$dir/' changes from $oldsub_short..$newsub_short";
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
        $main_exit_code = system('git', 'log', '--no-show-signature', '--pretty=tformat:', '%h %s', "$oldsub..$newsub") >> 8;
        $main_exit_code = system('git', 'log', '--no-show-signature', '--pretty=tformat:', 'REVERT: %h %s', "$newsub..$oldsub") >> 8;
}
    else {
        do {
    my $__echo_line = "Squashed '$dir/' content from commit $newsub_short";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    print "\n";
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "git-subtree-dir: $dir";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "git-subtree-split: $newsub";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}

sub toptree_for_commit {
    assert('test', scalar(@ARGV), q{=}, q{1});
    my $commit;
    my @commit;
    my %commit;
    $commit = "$_[0]";
        $main_exit_code = system('git', 'rev-parse', '--verify', "$commit^{tree}") >> 8;
    if ($CHILD_ERROR != 0) {
            }
    return;
}

sub subtree_for_commit {
    assert('test', scalar(@ARGV), q{=}, q{2});
    my $commit;
    my @commit;
    my %commit;
    $commit = "$_[0]";
    my $dir;
    my @dir;
    my %dir;
    $dir = "$_[1]";
    {
        my $output_35 = q{};
        my $output_printed_35;
        my $pipeline_success_35 = 1;
                my ($in_36, $out_36);
        my $pid_36 = open3($in_36, $out_36, '>&STDERR', 'git', 'ls-tree', '--');
        close $in_36 or croak 'Close failed: $OS_ERROR';
        $output_35 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_36> };
        close $out_36 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_36, 0;

                my @lines = split /\n/msx, $output_35;
        my $result_35_1 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        assert('test', "$ENV{name}", q{=}, "$dir");
        assert('test', "$ENV{type}", q{=}, "tree", '-o', "$ENV{type}", q{=}, "commit");
        if (do {
        $main_exit_code = system('test', "$ENV{type}", q{=}, "commit") >> 8;
        $CHILD_ERROR == 0
        }) {
        next;        }
        print $tree;
        if ( !( ($tree) =~ m{\n\z}msx ) ) { print "\n"; }
        last;}
        $output_35 = $result_35_1;
        if ($output_35 ne q{} && !defined $output_printed_35) {
            print $output_35;
            if (!($output_35 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_35 ) { $main_exit_code = 1; }
        }
    if ($CHILD_ERROR != 0) {
            }
    return;
}

sub tree_changed {
    assert('test', scalar(@ARGV), '-gt', q{0});
    my $tree;
    my @tree;
    my %tree;
    $tree = $1;
# Builtin command 'shift' not implemented
if ((Variable("#", false, None) != 1)) {
return q{0};
}
    else {
                my $ptree;
        my @ptree;
        my %ptree;
        $ptree = do {
    my ($in_37, $out_37);
    my $pid_37 = open3($in_37, $out_37, '>&STDERR', 'toptree_for_commit', $1);
    close $in_37 or croak 'Close failed: $OS_ERROR';
    my $result_37 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_37> };
    close $out_37 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_37, 0;
    $result_37
};
        if ($CHILD_ERROR != 0) {
                    }
if ((!StringInterpolation(StringInterpolation { parts: [Variable("ptree")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("tree")] }, None))) {
return q{0};
}
        else {
return q{1};
        }
    }
    return;
}

sub new_squash_commit {
    assert('test', scalar(@ARGV), q{=}, q{3});
    my $old;
    my @old;
    my %old;
    $old = "$_[0]";
    my $oldsub;
    my @oldsub;
    my %oldsub;
    $oldsub = "$_[1]";
    my $newsub;
    my @newsub;
    my %newsub;
    $newsub = "$_[2]";
        my $tree;
    my @tree;
    my %tree;
    $tree = do {
    my ($in_38, $out_38);
    my $pid_38 = open3($in_38, $out_38, '>&STDERR', 'toptree_for_commit', $newsub);
    close $in_38 or croak 'Close failed: $OS_ERROR';
    my $result_38 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_38> };
    close $out_38 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_38, 0;
    $result_38
};
    if ($CHILD_ERROR != 0) {
            }
if (StringInterpolation(StringInterpolation { parts: [Variable("old")] }, None) ne q{}) {
        {
            my $output_39 = q{};
            my $output_printed_39;
            my $pipeline_success_39 = 1;
                        my ($in_40, $out_40);
            my $pid_40 = open3($in_40, $out_40, '>&STDERR', 'squash_msg', );
            close $in_40 or croak 'Close failed: $OS_ERROR';
            $output_39 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_40> };
            close $out_40 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_40, 0;

                        my $cmd_42 = 'git';
            my ($in_41, $out_41);
            my $pid_41 = open3($in_41, $out_41, '>&STDERR', $cmd_42, 'commit-tree', '-p');
            print {$in_41} $output_39;
            close $in_41 or croak 'Close failed: $OS_ERROR';
            $output_39 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_41> };
            close $out_41 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_41, 0;
            if ($output_39 ne q{} && !defined $output_printed_39) {
                print $output_39;
                if (!($output_39 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_39 ) { $main_exit_code = 1; }
            }
        if ($CHILD_ERROR != 0) {
                    }
}
    else {
        {
            my $output_43 = q{};
            my $output_printed_43;
            my $pipeline_success_43 = 1;
                        my ($in_44, $out_44);
            my $pid_44 = open3($in_44, $out_44, '>&STDERR', 'squash_msg', );
            close $in_44 or croak 'Close failed: $OS_ERROR';
            $output_43 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_44> };
            close $out_44 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_44, 0;

                        my $cmd_46 = 'git';
            my ($in_45, $out_45);
            my $pid_45 = open3($in_45, $out_45, '>&STDERR', $cmd_46, 'commit-tree');
            print {$in_45} $output_43;
            close $in_45 or croak 'Close failed: $OS_ERROR';
            $output_43 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_45> };
            close $out_45 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_45, 0;
            if ($output_43 ne q{} && !defined $output_printed_43) {
                print $output_43;
                if (!($output_43 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_43 ) { $main_exit_code = 1; }
            }
        if ($CHILD_ERROR != 0) {
                    }
    }
    return;
}

sub copy_or_skip {
    assert('test', scalar(@ARGV), q{=}, q{3});
    my $rev;
    my @rev;
    my %rev;
    $rev = "$_[0]";
    my $tree;
    my @tree;
    my %tree;
    $tree = "$_[1]";
    my $newparents;
    my @newparents;
    my %newparents;
    $newparents = "$_[2]";
    assert('test', '-n', "$tree");
    my $identical;
    my @identical;
    my %identical;
    $identical = q{};
    my $nonidentical;
    my @nonidentical;
    my %nonidentical;
    $nonidentical = q{};
    my $p;
    my @p;
    my %p;
    $p = q{};
    my $gotparents;
    my @gotparents;
    my %gotparents;
    $gotparents = q{};
    my $copycommit;
    my @copycommit;
    my %copycommit;
    $copycommit = q{};
    my $parent;
    for my $parent ($newparents) {
                my $ptree;
        my @ptree;
        my %ptree;
        $ptree = do {
    my ($in_47, $out_47);
    my $pid_47 = open3($in_47, $out_47, '>&STDERR', 'toptree_for_commit', $parent);
    close $in_47 or croak 'Close failed: $OS_ERROR';
    my $result_47 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_47> };
    close $out_47 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_47, 0;
    $result_47
};
        if ($CHILD_ERROR != 0) {
                    }
        if (do {
$main_exit_code = system('test', '-z', "$ptree") >> 8;
            $CHILD_ERROR == 0
        }) {
            next;        }
if (StringInterpolation(StringInterpolation { parts: [Variable("ptree")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("tree")] }, None)) {
if (StringInterpolation(StringInterpolation { parts: [Variable("identical")] }, None) ne q{}) {
                my $mergebase;
                my @mergebase;
                my %mergebase;
                $mergebase = do {
    my ($in_48, $out_48);
    my $pid_48 = open3($in_48, $out_48, '>&STDERR', 'git', 'merge-base', $identical, $parent);
    close $in_48 or croak 'Close failed: $OS_ERROR';
    my $result_48 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_48> };
    close $out_48 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_48, 0;
    $result_48
};
if (StringInterpolation(StringInterpolation { parts: [Variable("identical")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("mergebase")] }, None)) {
                    $identical = "$parent";
}
                else {
                    if ((!StringInterpolation(StringInterpolation { parts: [Variable("parent")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("mergebase")] }, None))) {
                        $copycommit = q{1};
                    }
                }
}
            else {
                $identical = "$parent";
            }
}
        else {
            $nonidentical = "$parent";
        }
        my $is_new;
        my @is_new;
        my %is_new;
        $is_new = q{1};
        my $gp;
        for my $gp ($gotparents) {
if (StringInterpolation(StringInterpolation { parts: [Variable("gp")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("parent")] }, None)) {
                $is_new = q{};
last;
            }
        }
if (StringInterpolation(StringInterpolation { parts: [Variable("is_new")] }, None) ne q{}) {
            $gotparents = "$gotparents $parent";
            $p = "$p -p $parent";
        }
    }
if ((!(    $main_exit_code = system('test', '-n', "$identical") >> 8) && !(    $main_exit_code = system('test', '-n', "$nonidentical") >> 8))) {
        my $extras;
        my @extras;
        my %extras;
        $extras = do {
    my ($in_49, $out_49);
    my $pid_49 = open3($in_49, $out_49, '>&STDERR', 'git', 'rev-list', '--count', $identical, '..', $nonidentical);
    close $in_49 or croak 'Close failed: $OS_ERROR';
    my $result_49 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_49> };
    close $out_49 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_49, 0;
    $result_49
};
if ((StringInterpolation(StringInterpolation { parts: [Variable("extras")] }, None) != 0)) {
            $copycommit = q{1};
        }
    }
if ((!(    $main_exit_code = system('test', '-n', "$identical") >> 8) && !(    $main_exit_code = system('test', '-z', "$copycommit") >> 8))) {
        print $identical;
if ( !( ($identical) =~ m{\n\z}msx ) ) { print "\n"; }
}
    else {
                copy_commit("$rev", "$tree", "$p");
        if ($CHILD_ERROR != 0) {
                    }
    }
    return;
}

sub ensure_clean {
    assert('test', scalar(@ARGV), q{=}, q{0});
if (!(!(do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        $main_exit_code = system('git', 'diff-index', 'HEAD', '--exit-code', '--quiet') >> 8;
    };))) {
        $main_exit_code = system('die', "fatal: working tree has modifications.  Cannot add.") >> 8;
    }
if (!(!(do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        $main_exit_code = system('git', 'diff-index', '--cached', 'HEAD', '--exit-code', '--quiet') >> 8;
    };))) {
        $main_exit_code = system('die', "fatal: index has modifications.  Cannot add.") >> 8;
    }
    return;
}

sub ensure_valid_ref_format {
    assert('test', scalar(@ARGV), q{=}, q{1});
        $main_exit_code = system('git', 'check-ref-format', "refs/heads/$_[0]") >> 8;
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', "fatal: '$_[0]' does not look like a ref") >> 8;
    }
    return;
}

sub process_split_commit {
    assert('test', scalar(@ARGV), q{=}, q{2});
    my $rev = "$_[0]";
    my $parents = "$_[1]";
if ((Variable("indent", false, None) == 0)) {
        my $revcount;
        my @revcount;
        my %revcount;
        $revcount = eval { int($revcount + 1) } // "";
}
    else {
        $parents = do {
    my ($in_50, $out_50);
    my $pid_50 = open3($in_50, $out_50, '>&STDERR', 'git', 'rev-parse', "$rev^@");
    close $in_50 or croak 'Close failed: $OS_ERROR';
    my $result_50 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_50> };
    close $out_50 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_50, 0;
    $result_50
};
        my $extracount;
        my @extracount;
        my %extracount;
        $extracount = eval { int($extracount + 1) } // "";
    }
    progress("$revcount/$ENV{revmax} ($ENV{createcount}) [$extracount]");
    debug("Processing commit: $rev");
    my $indent = eval { int($indent + 1) } // "";
        my $exists;
    my @exists;
    my %exists;
    $exists = do {
    my ($in_51, $out_51);
    my $pid_51 = open3($in_51, $out_51, '>&STDERR', 'cache_get', "$rev");
    close $in_51 or croak 'Close failed: $OS_ERROR';
    my $result_51 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_51> };
    close $out_51 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_51, 0;
    $result_51
};
    if ($CHILD_ERROR != 0) {
            }
if (StringInterpolation(StringInterpolation { parts: [Variable("exists")] }, None) ne q{}) {
        debug("prior: $exists");
return;
    }
    my $createcount;
    my @createcount;
    my %createcount;
    $createcount = eval { int($createcount + 1) } // "";
    debug("parents: $parents");
    check_parents($parents);
        my $newparents;
    my @newparents;
    my %newparents;
    $newparents = do {
    my ($in_52, $out_52);
    my $pid_52 = open3($in_52, $out_52, '>&STDERR', 'cache_get', $parents);
    close $in_52 or croak 'Close failed: $OS_ERROR';
    my $result_52 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_52> };
    close $out_52 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_52, 0;
    $result_52
};
    if ($CHILD_ERROR != 0) {
            }
    debug("newparents: $newparents");
        my $tree;
    my @tree;
    my %tree;
    $tree = do {
    my ($in_53, $out_53);
    my $pid_53 = open3($in_53, $out_53, '>&STDERR', 'subtree_for_commit', "$rev", "$ENV{dir}");
    close $in_53 or croak 'Close failed: $OS_ERROR';
    my $result_53 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_53> };
    close $out_53 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_53, 0;
    $result_53
};
    if ($CHILD_ERROR != 0) {
            }
    debug("tree is: $tree");
if (StringInterpolation(StringInterpolation { parts: [Variable("tree")] }, None) eq q{}) {
        set_notree("$rev");
if (StringInterpolation(StringInterpolation { parts: [Variable("newparents")] }, None) ne q{}) {
            cache_set("$rev", "$rev");
        }
return;
    }
        my $newrev;
    my @newrev;
    my %newrev;
    $newrev = do {
    my ($in_54, $out_54);
    my $pid_54 = open3($in_54, $out_54, '>&STDERR', 'copy_or_skip', "$rev", "$tree", "$newparents");
    close $in_54 or croak 'Close failed: $OS_ERROR';
    my $result_54 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_54> };
    close $out_54 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_54, 0;
    $result_54
};
    if ($CHILD_ERROR != 0) {
            }
    debug("newrev is: $newrev");
    cache_set("$rev", "$newrev");
    cache_set('latest_new', "$newrev");
    cache_set('latest_old', "$rev");
    return;
}

sub cmd_add {
    my ($file) = @_;
    ensure_clean();
if ((Variable("#", false, None) == 1)) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('git', 'rev-parse', '-q', '--verify', "$_[0]^{commit}") >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ($CHILD_ERROR != 0) {
                        $main_exit_code = system('die', "fatal: '$_[0]' does not refer to a commit") >> 8;
        }
        $main_exit_code = system('cmd_add_commit', "@ARGV") >> 8;
}
    else {
        if ((Variable("#", false, None) == 2)) {
            ensure_valid_ref_format("$_[1]");
            $main_exit_code = system('cmd_add_repository', "@ARGV") >> 8;
}
        else {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                say();
            };
            $CHILD_ERROR = 0;
            $main_exit_code = system('die', "Provide either a commit or a repository and commit.") >> 8;
        }
    }
    return;
}

sub cmd_add_repository {
    assert('test', scalar(@ARGV), q{=}, q{2});
    do {
    my $__echo_line = "git fetch" . q{ } . @ARGV;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    my $repository;
    my @repository;
    my %repository;
    $repository = $1;
    my $refspec;
    my @refspec;
    my %refspec;
    $refspec = $2;
        $main_exit_code = system('git', 'fetch', "@ARGV") >> 8;
    if ($CHILD_ERROR != 0) {
            }
    $main_exit_code = system('cmd_add_commit', 'FETCH_HEAD') >> 8;
    return;
}

sub cmd_add_commit {
    assert('test', scalar(@ARGV), q{=}, q{1});
        my $rev;
    my @rev;
    my %rev;
    $rev = do {
    my ($in_55, $out_55);
    my $pid_55 = open3($in_55, $out_55, '>&STDERR', 'git', 'rev-parse', '--verify', "$_[0]^{commit}");
    close $in_55 or croak 'Close failed: $OS_ERROR';
    my $result_55 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_55> };
    close $out_55 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_55, 0;
    $result_55
};
    if ($CHILD_ERROR != 0) {
            }
    debug("Adding $ENV{dir} as '$rev'...");
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_split_rejoin")] }, None) eq q{}) {
                $main_exit_code = system('git', 'read-tree', '--prefix=$dir', $rev) >> 8;
        if ($CHILD_ERROR != 0) {
                    }
    }
        $main_exit_code = system('git', 'checkout', '--', "$ENV{dir}") >> 8;
    if ($CHILD_ERROR != 0) {
            }
        my $tree;
    my @tree;
    my %tree;
    $tree = do {
    my ($in_56, $out_56);
    my $pid_56 = open3($in_56, $out_56, '>&STDERR', 'git', 'write-tree');
    close $in_56 or croak 'Close failed: $OS_ERROR';
    my $result_56 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_56> };
    close $out_56 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_56, 0;
    $result_56
};
    if ($CHILD_ERROR != 0) {
            }
        my $headrev;
    my @headrev;
    my %headrev;
    $headrev = do {
    my ($in_57, $out_57);
    my $pid_57 = open3($in_57, $out_57, '>&STDERR', 'git', 'rev-parse', '--verify', 'HEAD');
    close $in_57 or croak 'Close failed: $OS_ERROR';
    my $result_57 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_57> };
    close $out_57 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_57, 0;
    $result_57
};
    if ($CHILD_ERROR != 0) {
            }
if ((!(    $main_exit_code = system('test', '-n', "$headrev") >> 8) && !(    $main_exit_code = system('test', "$headrev", q{!}, q{=}, "$rev") >> 8))) {
        my $headp;
        my @headp;
        my %headp;
        $headp = "-p $headrev";
}
    else {
        $headp = q{};
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_addmerge_squash")] }, None) ne q{}) {
                $rev = do {
    my ($in_58, $out_58);
    my $pid_58 = open3($in_58, $out_58, '>&STDERR', 'new_squash_commit', "", "", "$rev");
    close $in_58 or croak 'Close failed: $OS_ERROR';
    my $result_58 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_58> };
    close $out_58 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_58, 0;
    $result_58
};
        if ($CHILD_ERROR != 0) {
                    }
                my $commit;
        my @commit;
        my %commit;
        $commit = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_59 = q{};
            my $output_printed_59;
            my $pipeline_success_59 = 1;

            my ($in_60, $out_60);
            my $pid_60 = open3($in_60, $out_60, '>&STDERR', 'add_squashed_msg', );
            close $in_60 or croak 'Close failed: $OS_ERROR';
            $output_59 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_60> };
            close $out_60 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_60, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_59 = 0; }

            my $cmd_62 = 'git';
            my ($in_61, $out_61);
            my $pid_61 = open3($in_61, $out_61, '>&STDERR', $cmd_62, 'commit-tree', '-p');
            print {$in_61} $output_59;
            close $in_61 or croak 'Close failed: $OS_ERROR';
            $output_59 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_61> };
            close $out_61 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_61, 0;
            if ( !$pipeline_success_59 ) { $main_exit_code = 1; }
            $output_59 =~ s/\n+\z//msx;
            $output_59;
}; $_pipeline_result; };
        if ($CHILD_ERROR != 0) {
                    }
}
    else {
                my $revp;
        my @revp;
        my %revp;
        $revp = do {
    my ($in_63, $out_63);
    my $pid_63 = open3($in_63, $out_63, '>&STDERR', 'peel_committish', "$rev");
    close $in_63 or croak 'Close failed: $OS_ERROR';
    my $result_63 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_63> };
    close $out_63 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_63, 0;
    $result_63
};
        if ($CHILD_ERROR != 0) {
                    }
                $commit = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_64 = q{};
            my $output_printed_64;
            my $pipeline_success_64 = 1;

            my ($in_65, $out_65);
            my $pid_65 = open3($in_65, $out_65, '>&STDERR', 'add_msg', );
            close $in_65 or croak 'Close failed: $OS_ERROR';
            $output_64 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_65> };
            close $out_65 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_65, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_64 = 0; }

            my $cmd_67 = 'git';
            my ($in_66, $out_66);
            my $pid_66 = open3($in_66, $out_66, '>&STDERR', $cmd_67, 'commit-tree', '-p');
            print {$in_66} $output_64;
            close $in_66 or croak 'Close failed: $OS_ERROR';
            $output_64 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_66> };
            close $out_66 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_66, 0;
            if ( !$pipeline_success_64 ) { $main_exit_code = 1; }
            $output_64 =~ s/\n+\z//msx;
            $output_64;
}; $_pipeline_result; };
        if ($CHILD_ERROR != 0) {
                    }
    }
        $main_exit_code = system('git', 'reset', "$commit") >> 8;
    if ($CHILD_ERROR != 0) {
            }
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        say();
    };
    $CHILD_ERROR = 0;
    return;
}

sub cmd_split {
if ((Variable("#", false, None) == 0)) {
        my $rev;
        my @rev;
        my %rev;
        $rev = do {
    my ($in_68, $out_68);
    my $pid_68 = open3($in_68, $out_68, '>&STDERR', 'git', 'rev-parse', 'HEAD');
    close $in_68 or croak 'Close failed: $OS_ERROR';
    my $result_68 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_68> };
    close $out_68 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_68, 0;
    $result_68
};
}
    else {
        if (((Variable("#", false, None) == 1) || (Variable("#", false, None) == 2))) {
                        $rev = do {
    my ($in_69, $out_69);
    my $pid_69 = open3($in_69, $out_69, '>&STDERR', 'git', 'rev-parse', '-q', '--verify', "$_[0]^{commit}");
    close $in_69 or croak 'Close failed: $OS_ERROR';
    my $result_69 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_69> };
    close $out_69 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_69, 0;
    $result_69
};
            if ($CHILD_ERROR != 0) {
                                $main_exit_code = system('die', "fatal: '$_[0]' does not refer to a commit") >> 8;
            }
}
        else {
            $main_exit_code = system('die', "fatal: you must provide exactly one revision, and optionnally a repository.  Got: '@ARGV'") >> 8;
        }
    }
    my $repository;
    my @repository;
    my %repository;
    $repository = "";
if (StringInterpolation(StringInterpolation { parts: [Variable("#")] }, None) eq 2) {
        $repository = "$_[1]";
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_split_rejoin")] }, None) ne q{}) {
        ensure_clean();
    }
    debug("Splitting $ENV{dir}...");
        cache_setup();
    if ($CHILD_ERROR != 0) {
            }
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_split_onto")] }, None) ne q{}) {
        debug("Reading history for --onto=$ENV{arg_split_onto}...");
        {
            my $output_70 = q{};
            my $output_printed_70;
            my $pipeline_success_70 = 1;
                        my ($in_71, $out_71);
            my $pid_71 = open3($in_71, $out_71, '>&STDERR', 'git', 'rev-list');
            close $in_71 or croak 'Close failed: $OS_ERROR';
            $output_70 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_71> };
            close $out_71 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_71, 0;

                        my @lines = split /\n/msx, $output_70;
            my $result_70_1 = q{};
            for my $line (@lines) {
            chomp $line;
            my $L = $line;
            debug("cache: $rev");
            cache_set("$rev", "$rev");
            }
            $output_70 = $result_70_1;
            if ($output_70 ne q{} && !defined $output_printed_70) {
                print $output_70;
                if (!($output_70 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_70 ) { $main_exit_code = 1; }
            }
        if ($CHILD_ERROR != 0) {
                    }
    }
        my $unrevs;
    my @unrevs;
    my %unrevs;
    $unrevs = (do { my $_chomp_temp = do {
    my ($in_72, $out_72);
    my $pid_72 = open3($in_72, $out_72, '>&STDERR', 'find_existing_splits', "$ENV{dir}", "$rev", "$repository");
    close $in_72 or croak 'Close failed: $OS_ERROR';
    my $result_72 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_72> };
    close $out_72 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_72, 0;
    $result_72
}; chomp $_chomp_temp; $_chomp_temp; });
    if ($CHILD_ERROR != 0) {
            }
    my $grl;
    my @grl;
    my %grl;
    $grl = 'git rev-list --topo-order --reverse --parents $rev $unrevs';
    my $revmax;
    my @revmax;
    my %revmax;
    $revmax = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_73 = q{};
        my $output_printed_73;
        my $pipeline_success_73 = 1;
        my @_pcmd_75 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
        my ($in_74);
        my $pid_74 = open3($in_74, $out_74, '>&STDERR', @_pcmd_75);
        close $in_74 or croak 'Close failed: $OS_ERROR';
        my $temp_result;
        $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_74> };
        $output_73 = $temp_result;
        close $out_74 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_74, 0;
        my $output_73_1 = do {
        my $_wc_data = $output_73;
        my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
        my $_wc_result = q{};
        $_wc_result .= sprintf q{%d}, $_wc_lines;
        $_wc_result .= "\n";
        $_wc_result;
        };
        $output_73 = $output_73_1;
        if ( !$pipeline_success_73 ) { $main_exit_code = 1; }
        $output_73 =~ s/\n+\z//msx;
        $output_73;
}; $_pipeline_result; };
    my $revcount;
    my @revcount;
    my %revcount;
    $revcount = q{0};
    my $createcount;
    my @createcount;
    my %createcount;
    $createcount = q{0};
    my $extracount;
    my @extracount;
    my %extracount;
    $extracount = q{0};
    {
        my $output_76 = q{};
        my $output_printed_76;
        my $pipeline_success_76 = 1;
                my @_pcmd_78 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
        my ($in_77);
        my $pid_77 = open3($in_77, $out_77, '>&STDERR', @_pcmd_78);
        close $in_77 or croak 'Close failed: $OS_ERROR';
        my $temp_result;
        $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_77> };
        $output_76 = $temp_result;
        close $out_77 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_77, 0;

                my @lines = split /\n/msx, $output_76;
        my $result_76_1 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        process_split_commit("$rev", "$ENV{parents}");
        }
        $output_76 = $result_76_1;
        if ($output_76 ne q{} && !defined $output_printed_76) {
            print $output_76;
            if (!($output_76 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_76 ) { $main_exit_code = 1; }
        }
    if ($CHILD_ERROR != 0) {
            }
        my $latest_new;
    my @latest_new;
    my %latest_new;
    $latest_new = do {
    my ($in_79, $out_79);
    my $pid_79 = open3($in_79, $out_79, '>&STDERR', 'cache_get', 'latest_new');
    close $in_79 or croak 'Close failed: $OS_ERROR';
    my $result_79 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_79> };
    close $out_79 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_79, 0;
    $result_79
};
    if ($CHILD_ERROR != 0) {
            }
if (StringInterpolation(StringInterpolation { parts: [Variable("latest_new")] }, None) eq q{}) {
        $main_exit_code = system('die', "fatal: no new revisions were found") >> 8;
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_split_rejoin")] }, None) ne q{}) {
        debug("Merging split branch into HEAD...");
                my $latest_old;
        my @latest_old;
        my %latest_old;
        $latest_old = do {
    my ($in_80, $out_80);
    my $pid_80 = open3($in_80, $out_80, '>&STDERR', 'cache_get', 'latest_old');
    close $in_80 or croak 'Close failed: $OS_ERROR';
    my $result_80 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_80> };
    close $out_80 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_80, 0;
    $result_80
};
        if ($CHILD_ERROR != 0) {
                    }
                my $arg_addmerge_message;
        my @arg_addmerge_message;
        my %arg_addmerge_message;
        $arg_addmerge_message = (do { my $_chomp_temp = do {
    my ($in_81, $out_81);
    my $pid_81 = open3($in_81, $out_81, '>&STDERR', 'rejoin_msg', "$ENV{dir}", "$latest_old", "$latest_new");
    close $in_81 or croak 'Close failed: $OS_ERROR';
    my $result_81 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_81> };
    close $out_81 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_81, 0;
    $result_81
}; chomp $_chomp_temp; $_chomp_temp; });
        if ($CHILD_ERROR != 0) {
                    }
if (StringInterpolation(StringInterpolation { parts: [CommandSubstitution(Simple(SimpleCommand { name: Literal("find_latest_squash", None), args: [StringInterpolation(StringInterpolation { parts: [Variable("dir")] }, None)], redirects: [], env_vars: {}, stdout_used: true, stderr_used: true }))] }, None) eq q{}) {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                cmd_add("$latest_new");
            };
            if ($CHILD_ERROR != 0) {
                            }
}
        else {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                $main_exit_code = system('cmd_merge', "$latest_new") >> 8;
            };
            if ($CHILD_ERROR != 0) {
                            }
        }
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_split_branch")] }, None) ne q{}) {
if (!(        rev_exists("refs/heads/$ENV{arg_split_branch}"))) {
if (!(!($main_exit_code = system('git', 'merge-base', '--is-ancestor', "$ENV{arg_split_branch}", "$latest_new") >> 8;))) {
                $main_exit_code = system('die', "fatal: branch '$ENV{arg_split_branch}' is not an ancestor of commit '$latest_new'.") >> 8;
            }
            my $action;
            my @action;
            my %action;
            $action = 'Updated';
}
        else {
            $action = 'Created';
        }
                $main_exit_code = system('git', 'update-ref', '-m', 'subtree split', "refs/heads/$ENV{arg_split_branch}", "$latest_new") >> 8;
        if ($CHILD_ERROR != 0) {
                    }
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            say();
        };
        $CHILD_ERROR = 0;
    }
    print $latest_new;
if ( !( ($latest_new) =~ m{\n\z}msx ) ) { print "\n"; }
exit 0;
    return;
}

sub cmd_merge {
        $main_exit_code = system('test', scalar(@ARGV), '-eq', q{1}, '-o', scalar(@ARGV), '-eq', q{2}) >> 8;
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', "fatal: you must provide exactly one revision, and optionally a repository. Got: '@ARGV'") >> 8;
    }
        my $rev;
    my @rev;
    my %rev;
    $rev = do {
    my ($in_82, $out_82);
    my $pid_82 = open3($in_82, $out_82, '>&STDERR', 'git', 'rev-parse', '-q', '--verify', "$_[0]^{commit}");
    close $in_82 or croak 'Close failed: $OS_ERROR';
    my $result_82 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_82> };
    close $out_82 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_82, 0;
    $result_82
};
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', "fatal: '$_[0]' does not refer to a commit") >> 8;
    }
    my $repository;
    my @repository;
    my %repository;
    $repository = "";
if (StringInterpolation(StringInterpolation { parts: [Variable("#")] }, None) eq 2) {
        $repository = "$_[1]";
    }
    ensure_clean();
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_addmerge_squash")] }, None) ne q{}) {
                my $first_split;
        my @first_split;
        my %first_split;
        $first_split = (do { my $_chomp_temp = do {
    my ($in_83, $out_83);
    my $pid_83 = open3($in_83, $out_83, '>&STDERR', 'find_latest_squash', "$ENV{dir}", "$repository");
    close $in_83 or croak 'Close failed: $OS_ERROR';
    my $result_83 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_83> };
    close $out_83 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_83, 0;
    $result_83
}; chomp $_chomp_temp; $_chomp_temp; });
        if ($CHILD_ERROR != 0) {
                    }
if (StringInterpolation(StringInterpolation { parts: [Variable("first_split")] }, None) eq q{}) {
            $main_exit_code = system('die', "fatal: can't squash-merge: '$ENV{dir}' was never added.") >> 8;
        }
        my $old;
        my @old;
        my %old;
        $old = $1;
        my $sub;
        my @sub;
        my %sub;
        $sub = $2;
if (StringInterpolation(StringInterpolation { parts: [Variable("sub")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("rev")] }, None)) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                say();
            };
            $CHILD_ERROR = 0;
exit 0;
        }
                my $new;
        my @new;
        my %new;
        $new = do {
    my ($in_84, $out_84);
    my $pid_84 = open3($in_84, $out_84, '>&STDERR', 'new_squash_commit', "$old", "$sub", "$rev");
    close $in_84 or croak 'Close failed: $OS_ERROR';
    my $result_84 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_84> };
    close $out_84 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_84, 0;
    $result_84
};
        if ($CHILD_ERROR != 0) {
                    }
        debug("New squash commit: $new");
        $rev = "$new";
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("arg_addmerge_message")] }, None) ne q{}) {
        $main_exit_code = system('git', 'merge', '--no-ff', '-Xsubtree', q{=}, "$ENV{arg_prefix}", '--message=$arg_addmerge_message', "$rev") >> 8;
}
    else {
        $main_exit_code = system('git', 'merge', '--no-ff', '-Xsubtree', q{=}, "$ENV{arg_prefix}", $rev) >> 8;
    }
    return;
}

sub cmd_pull {
if ((Variable("#", false, None) != 2)) {
        $main_exit_code = system('die', "fatal: you must provide <repository> <ref>") >> 8;
    }
    my $repository;
    my @repository;
    my %repository;
    $repository = "$_[0]";
    my $ref;
    my @ref;
    my %ref;
    $ref = "$_[1]";
    ensure_clean();
    ensure_valid_ref_format("$ref");
        $main_exit_code = system('git', 'fetch', "$repository", "$ref") >> 8;
    if ($CHILD_ERROR != 0) {
            }
    cmd_merge('FETCH_HEAD', "$repository");
    return;
}

sub cmd_push {
if ((Variable("#", false, None) != 2)) {
        $main_exit_code = system('die', "fatal: you must provide <repository> <refspec>") >> 8;
    }
if ((-e 'StringInterpolation(StringInterpolation { parts: [Variable("dir")] }, None)')) {
        my $repository;
        my @repository;
        my %repository;
        $repository = $1;
        my $refspec;
        my @refspec;
        my %refspec;
        $refspec = $_[1] =~ s/^\+//r;
        my $remoteref;
        my @remoteref;
        my %remoteref;
        $remoteref = ${refspec} =~ s/^.*?://r;
if (StringInterpolation(StringInterpolation { parts: [Variable("remoteref")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("refspec")] }, None)) {
            my $localrevname_presplit;
            my @localrevname_presplit;
            my %localrevname_presplit;
            $localrevname_presplit = 'HEAD';
}
        else {
            $localrevname_presplit = ${refspec} =~ s/:.*$//sr;
        }
        ensure_valid_ref_format("$remoteref");
                my $localrev_presplit;
        my @localrev_presplit;
        my %localrev_presplit;
        $localrev_presplit = do {
    my ($in_85, $out_85);
    my $pid_85 = open3($in_85, $out_85, '>&STDERR', 'git', 'rev-parse', '-q', '--verify', "$localrevname_presplit^{commit}");
    close $in_85 or croak 'Close failed: $OS_ERROR';
    my $result_85 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_85> };
    close $out_85 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_85, 0;
    $result_85
};
        if ($CHILD_ERROR != 0) {
                        $main_exit_code = system('die', "fatal: '$localrevname_presplit' does not refer to a commit") >> 8;
        }
        do {
    my $__echo_line = "git push using: " . q{ } . $repository . q{ } . $refspec;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
                my $localrev;
        my @localrev;
        my %localrev;
        $localrev = do {
    my ($in_86, $out_86);
    my $pid_86 = open3($in_86, $out_86, '>&STDERR', 'cmd_split', "$localrev_presplit", "$repository");
    close $in_86 or croak 'Close failed: $OS_ERROR';
    my $result_86 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_86> };
    close $out_86 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_86, 0;
    $result_86
};
        if ($CHILD_ERROR != 0) {
                        $main_exit_code = system('bash', 'die') >> 8;
        }
        $main_exit_code = system('git', 'push', "$repository", "$localrev", q{:}, "refs/heads/$remoteref") >> 8;
}
    else {
        $main_exit_code = system('die', "fatal: '$ENV{dir}' must already exist. Try 'git subtree add'.") >> 8;
    }
    return;
}
main("@ARGV");

exit $main_exit_code;
