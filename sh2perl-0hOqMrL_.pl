#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $filter_tag_name;
my @filter_tag_name;
my %filter_tag_name;
my $filter_tree;
my @filter_tree;
my %filter_tree;
my $filter_parent;
my @filter_parent;
my %filter_parent;
my $type;
my @type;
my %type;
my $sha1;
my @sha1;
my %sha1;

my $MAGIC_10 = 10;

my $functions;
my @functions;
my %functions;
$functions = do { my @_qx_cmd = ("cat"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
do { my $eval_input = $functions; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };

sub finish_ident {
    do {
    my $__echo_line = "case \"$GIT_$ENV{1_NAME}\" in \"\") GIT_$ENV{1_NAME}=\"${GIT_$ENV{1_EMAIL}%%@*}\" && export GIT_$ENV{1_NAME};; esac";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "export GIT_$ENV{1_NAME}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "export GIT_$ENV{1_EMAIL}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "export GIT_$ENV{1_DATE}";
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

sub set_ident {
    $main_exit_code = system('parse_ident_from_commit', 'author', 'AUTHOR', 'committer', 'COMMITTER') >> 8;
    finish_ident('AUTHOR');
    finish_ident('COMMITTER');
    return;
}
if (StringInterpolation(StringInterpolation { parts: [Variable("FILTER_BRANCH_SQUELCH_WARNING"), Variable("GIT_TEST_DISALLOW_ABBREVIATED_OPTIONS")] }, None) eq q{}) {
print "WARNING: git-filter-branch has a glut of gotchas generating mangled history
\t rewrites.  Hit Ctrl-C before proceeding to abort, then use an
\t alternative filtering tool such as 'git filter-repo'
\t (https://github.com/newren/git-filter-repo/) instead.  See the
\t filter-branch manual page for more details; to squelch this warning,
\t set FILTER_BRANCH_SQUELCH_WARNING=1.
";
require Time::HiRes; Time::HiRes::sleep('10');
printf("Proceeding with filter-branch...\n\n");
}
my $USAGE;
my @USAGE;
my %USAGE;
$USAGE = "[--setup <command>] [--subdirectory-filter <directory>] [--env-filter <command>]
	[--tree-filter <command>] [--index-filter <command>]
	[--parent-filter <command>] [--msg-filter <command>]
	[--commit-filter <command>] [--tag-name-filter <command>]
	[--original <namespace>]
	[-d <directory>] [-f | --force] [--state-branch <branch>]
	[--] [<rev-list options>...]";
my $OPTIONS_SPEC;
my @OPTIONS_SPEC;
my %OPTIONS_SPEC;
$OPTIONS_SPEC = q{};
$main_exit_code = system('.', 'git-sh-setup') >> 8;
if ("$(is_bare_repository)" eq false) {
    $main_exit_code = system('require_clean_work_tree', 'rewrite branches') >> 8;
}
my $tempdir;
my @tempdir;
my %tempdir;
$tempdir = '.git-rewrite';
my $filter_setup;
my @filter_setup;
my %filter_setup;
$filter_setup = q{};
my $filter_env;
my @filter_env;
my %filter_env;
$filter_env = q{};
$filter_tree = q{};
my $filter_index;
my @filter_index;
my %filter_index;
$filter_index = q{};
$filter_parent = q{};
my $filter_msg;
my @filter_msg;
my %filter_msg;
$filter_msg = 'cat';
my $filter_commit;
my @filter_commit;
my %filter_commit;
$filter_commit = q{};
$filter_tag_name = q{};
my $filter_subdir;
my @filter_subdir;
my %filter_subdir;
$filter_subdir = q{};
my $state_branch;
my @state_branch;
my %state_branch;
$state_branch = q{};
my $orig_namespace;
my @orig_namespace;
my %orig_namespace;
$orig_namespace = 'refs/original/';
my $force;
my @force;
my %force;
$force = q{};
my $prune_empty;
my @prune_empty;
my %prune_empty;
$prune_empty = q{};
my $remap_to_ancestor;
my @remap_to_ancestor;
my %remap_to_ancestor;
$remap_to_ancestor = q{};
while ( $main_exit_code = system('bash', ':') >> 8 ) {
if ("$_[0]" =~ /^--$/msx) {
        # Builtin command 'shift' not implemented
        last;    } elsif ("$_[0]" =~ /^--force$/msx or "$_[0]" =~ /^-f$/msx) {
        # Builtin command 'shift' not implemented
                $force = q{t};
        next;    } elsif ("$_[0]" =~ /^--remap-to-ancestor$/msx) {
        # Builtin command 'shift' not implemented
                $remap_to_ancestor = q{t};
        next;    } elsif ("$_[0]" =~ /^--prune-empty$/msx) {
        # Builtin command 'shift' not implemented
                $prune_empty = q{t};
        next;    } elsif ("$_[0]" =~ /^-.*$/msx) {
    } elsif (1) {
        last;    }
    my $ARG;
    my @ARG;
    my %ARG;
    $ARG = "$_[0]";
if ("${scalar(@ARGV)}" =~ /^1$/msx) {
                $main_exit_code = system('bash', 'usage') >> 8;
    }
# Builtin command 'shift' not implemented
    my $OPTARG;
    my @OPTARG;
    my %OPTARG;
    $OPTARG = "$_[0]";
# Builtin command 'shift' not implemented
if ("$ARG" =~ /^-d$/msx) {
                $tempdir = "$OPTARG";
    } elsif ("$ARG" =~ /^--setup$/msx) {
                $filter_setup = "$OPTARG";
    } elsif ("$ARG" =~ /^--subdirectory-filter$/msx) {
                $filter_subdir = "$OPTARG";
                $remap_to_ancestor = q{t};
    } elsif ("$ARG" =~ /^--env-filter$/msx) {
                $filter_env = "$OPTARG";
    } elsif ("$ARG" =~ /^--tree-filter$/msx) {
                $filter_tree = "$OPTARG";
    } elsif ("$ARG" =~ /^--index-filter$/msx) {
                $filter_index = "$OPTARG";
    } elsif ("$ARG" =~ /^--parent-filter$/msx) {
                $filter_parent = "$OPTARG";
    } elsif ("$ARG" =~ /^--msg-filter$/msx) {
                $filter_msg = "$OPTARG";
    } elsif ("$ARG" =~ /^--commit-filter$/msx) {
                $filter_commit = "$functions; $OPTARG";
    } elsif ("$ARG" =~ /^--tag-name-filter$/msx) {
                $filter_tag_name = "$OPTARG";
    } elsif ("$ARG" =~ /^--original$/msx) {
                $orig_namespace = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'expr', "$OPTARG/", q{:}, "\\(.*[^/]\\)/*$");
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
                $main_exit_code = system('bash', '/') >> 8;
    } elsif ("$ARG" =~ /^--state-branch$/msx) {
                $state_branch = "$OPTARG";
    } elsif (1) {
                $main_exit_code = system('bash', 'usage') >> 8;
    }
}
if ("$prune_empty,$filter_commit" =~ /^,$/msx) {
        $filter_commit = "git commit-tree \"$@\"";
} elsif ("$prune_empty,$filter_commit" =~ /^t,$/msx) {
        $filter_commit = "$functions; git_commit_non_empty_tree \"$@\"";
} elsif ("$prune_empty,$filter_commit" =~ /^,.*$/msx) {
} elsif (1) {
        $main_exit_code = system('die', "Cannot set --prune-empty and --commit-filter at the same time") >> 8;
}
if ("$force" =~ /^t$/msx) {
    if ( -e "$tempdir" ) {
        if ( -d "$tempdir" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$tempdir", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "$tempdir", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$tempdir" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$tempdir",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
} elsif ("$force" =~ /^$/msx) {
        if (do {
$main_exit_code = system('test', '-d', "$tempdir") >> 8;
        $CHILD_ERROR == 0
    }) {
                $main_exit_code = system('die', "$tempdir already exists, please remove it") >> 8;
    }
}
my $orig_dir;
my @orig_dir;
my %orig_dir;
$orig_dir = do { use Cwd; getcwd(); };
if (do {
if (do {
if (do {
use File::Path qw(make_path);
my $err;
if ( !-d "$tempdir/t" ) {
    make_path( "$tempdir/t", { error => \$err } );
    if ( @{$err} ) {
        croak "mkdir: cannot create directory " . "$tempdir/t" . ": $err->[0]\n";
    }
}
    $CHILD_ERROR == 0
}) {
        $tempdir = (do { my $_chomp_temp = do { chdir("$tempdir"); q{} };
; chomp $_chomp_temp; $_chomp_temp; });
}
    $CHILD_ERROR == 0
}) {
        chdir("$tempdir/t");
    $CHILD_ERROR = 0;
}
    $CHILD_ERROR == 0
}) {
        my $workdir;
    my @workdir;
    my %workdir;
    $workdir = (do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; });
}
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('die', "") >> 8;
}
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'cd "$orig_dir"; rm -rf "$tempdir" 2>&1'; print $end_out if $end_out ne q{}; }
my $ORIG_GIT_DIR;
my @ORIG_GIT_DIR;
my %ORIG_GIT_DIR;
$ORIG_GIT_DIR = "$ENV{GIT_DIR}";
my $ORIG_GIT_WORK_TREE;
my @ORIG_GIT_WORK_TREE;
my %ORIG_GIT_WORK_TREE;
$ORIG_GIT_WORK_TREE = "$ENV{GIT_WORK_TREE}";
my $ORIG_GIT_INDEX_FILE;
my @ORIG_GIT_INDEX_FILE;
my %ORIG_GIT_INDEX_FILE;
$ORIG_GIT_INDEX_FILE = "$ENV{GIT_INDEX_FILE}";
my $ORIG_GIT_AUTHOR_NAME;
my @ORIG_GIT_AUTHOR_NAME;
my %ORIG_GIT_AUTHOR_NAME;
$ORIG_GIT_AUTHOR_NAME = "$ENV{GIT_AUTHOR_NAME}";
my $ORIG_GIT_AUTHOR_EMAIL;
my @ORIG_GIT_AUTHOR_EMAIL;
my %ORIG_GIT_AUTHOR_EMAIL;
$ORIG_GIT_AUTHOR_EMAIL = "$ENV{GIT_AUTHOR_EMAIL}";
my $ORIG_GIT_AUTHOR_DATE;
my @ORIG_GIT_AUTHOR_DATE;
my %ORIG_GIT_AUTHOR_DATE;
$ORIG_GIT_AUTHOR_DATE = "$ENV{GIT_AUTHOR_DATE}";
my $ORIG_GIT_COMMITTER_NAME;
my @ORIG_GIT_COMMITTER_NAME;
my %ORIG_GIT_COMMITTER_NAME;
$ORIG_GIT_COMMITTER_NAME = "$ENV{GIT_COMMITTER_NAME}";
my $ORIG_GIT_COMMITTER_EMAIL;
my @ORIG_GIT_COMMITTER_EMAIL;
my %ORIG_GIT_COMMITTER_EMAIL;
$ORIG_GIT_COMMITTER_EMAIL = "$ENV{GIT_COMMITTER_EMAIL}";
my $ORIG_GIT_COMMITTER_DATE;
my @ORIG_GIT_COMMITTER_DATE;
my %ORIG_GIT_COMMITTER_DATE;
$ORIG_GIT_COMMITTER_DATE = "$ENV{GIT_COMMITTER_DATE}";
my $GIT_WORK_TREE;
my @GIT_WORK_TREE;
my %GIT_WORK_TREE;
$GIT_WORK_TREE = q{.};
$ENV{GIT_DIR} = $GIT_DIR;
$ENV{GIT_WORK_TREE} = $GIT_WORK_TREE;
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', "$tempdir"
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('git', 'for-each-ref') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
$main_exit_code = system('bash', '/backup-refs') >> 8;
if ($CHILD_ERROR != 0) {
    exit $main_exit_code;
}
open STDIN, '<', "$tempdir" or croak "Cannot open file: $OS_ERROR\n";
my $sha1;
my $type;
my $name;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $sha1 = $_fields[0] // q{};
    $type = $_fields[1] // q{};
    $name = $_fields[2] // q{};
if ("$force,$arg1" =~ /^,$orig_namespace.*$/msx) {
                $main_exit_code = system('die', "Cannot create a new backup.
A previous backup already exists in $orig_namespace
Force overwriting the backup with -f") >> 8;
    } elsif ("$force,$arg1" =~ /^t,$orig_namespace.*$/msx) {
                $main_exit_code = system('git', 'update-ref', '-d', "$name", $sha1) >> 8;
    }
}
$main_exit_code = system('bash', '/backup-refs') >> 8;
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', "$tempdir"
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('git', 'rev-parse', '--no-flags', '--revs-only', '--symbolic-full-name', '--default', 'HEAD', "@ARGV") >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
$main_exit_code = system('bash', '/raw-refs') >> 8;
if ($CHILD_ERROR != 0) {
    exit $main_exit_code;
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', "$tempdir"
      or die "Cannot open file: $OS_ERROR\n";
    my $ref;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $ref = $_fields[0] // q{};
if ("$ref" =~ /^^..*$/msx) {
            next;        }
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('git', 'rev-parse', '--verify', "$ref", '^0') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            print $ref;
if ( !( ($ref) =~ m{\n\z}msx ) ) { print "\n"; }
}
        else {
            $main_exit_code = system('warn', "WARNING: not rewriting '$ref' (not a committish)") >> 8;
        }
    }
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
open STDIN, '<', "$tempdir" or croak "Cannot open file: $OS_ERROR\n";
$main_exit_code = system('bash', '/heads') >> 8;
$main_exit_code = system('bash', '/raw-refs') >> 8;
$main_exit_code = system('test', '-s', "$tempdir", '/heads') >> 8;
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('die', "You must specify a ref to rewrite.") >> 8;
}
my $GIT_INDEX_FILE;
my @GIT_INDEX_FILE;
my %GIT_INDEX_FILE;
$GIT_INDEX_FILE = (do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; }) . "/../index";
$ENV{GIT_INDEX_FILE} = $GIT_INDEX_FILE;
use File::Path qw(make_path);
if ( mkdir '../map' ) {
    }
else {
    croak "mkdir: cannot create directory " . '../map' . ": File exists\n";
}
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('die', "Could not create map/ directory") >> 8;
}
if (StringInterpolation(StringInterpolation { parts: [Variable("state_branch")] }, None) ne q{}) {
    my $state_commit;
    my @state_commit;
    my %state_commit;
    $state_commit = do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'git', 'rev-parse', '--no-flags', '--revs-only', "$state_branch");
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
};
if (StringInterpolation(StringInterpolation { parts: [Variable("state_commit")] }, None) ne q{}) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Populating map from $state_branch ($state_commit)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        @ARGV = ("$state_commit");
if (!defined $ENV{SHELL_VAR}) { $ENV{SHELL_VAR} = q{}; }
        open(my $MAP, "-|", "git show $ARGV[0]:filter.map") or die;
        while (<$MAP>) {
        m/(.*):(.*)/ or die;
        open my $F, ">../map/$1" or die;
        print {$F} "$2" or die;
        close($F) or die;
        }
        close($MAP) or die;
        if ($CHILD_ERROR != 0) {
                        $main_exit_code = system('die', "Unable to load state from $state_branch:filter.map") >> 8;
        }
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Branch $state_branch does not exist. Will create";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
    }
}
my $nonrevs;
my @nonrevs;
my %nonrevs;
$nonrevs = do {
    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'git', 'rev-parse', '--no-revs', "@ARGV");
    close $in_6 or croak 'Close failed: $OS_ERROR';
    my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    $result_6
};
if ($CHILD_ERROR != 0) {
    exit $main_exit_code;
}
if (StringInterpolation(StringInterpolation { parts: [Variable("nonrevs")] }, None) eq q{}) {
    my $dashdash;
    my @dashdash;
    my %dashdash;
    $dashdash = '--';
}
else {
    $dashdash = q{};
    $remap_to_ancestor = q{t};
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '../parse'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('git', 'rev-parse', '--revs-only', "@ARGV") >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if ("$filter_subdir" =~ /^$/msx) {
    do { my $eval_input = "set" . "--" . q{}; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
} elsif (1) {
    do { my $eval_input = "set" . "--" . q{}; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
}
open STDIN, '<', '../parse' or croak "Cannot open file: $OS_ERROR\n";
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '../revs'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('git', 'rev-list', '--reverse', '--topo-order', '--default', 'HEAD', '--parents', '--simplify-merges', '--stdin', "@ARGV") >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('die', "Could not get the commits") >> 8;
}
my $commits;
my @commits;
my %commits;
$commits = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_7 = q{};
    my $output_printed_7;
    my $pipeline_success_7 = 1;
    open STDIN, '<', '../revs' or croak "Cannot open file: $OS_ERROR\n";
    my $wc_output_8 = do {
    my $_wc_data = do {{ local $INPUT_RECORD_SEPARATOR = undef; <STDIN> }};
    my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
    my $_wc_result = q{};
    $_wc_result .= sprintf q{%d}, $_wc_lines;
    $_wc_result .= "\n";
    $_wc_result;
    };
    print $wc_output_8;
    my $set1_9 = " ";
    my $input_9 = $output_7;
    my $tr_result_7_1 = q{};
    for my $char ( split //msx, $input_9 ) {
    if ( (index $set1_9, $char) == -1 ) {
    $tr_result_7_1 .= $char;
    }
    }
    if (!($tr_result_7_1 =~ m{\n\z}msx || $tr_result_7_1 eq q{})) {
    $tr_result_7_1 .= "\n";
    }
    $output_7 = $tr_result_7_1;
    $output_7 = $tr_result_7_1;
    if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
    $output_7 =~ s/\n+\z//msx;
    $output_7;
}; $_pipeline_result; };
if (do {
$main_exit_code = system('test', $commits, '-eq', q{0}) >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('die_with_status', q{2}, "Found nothing to rewrite") >> 8;
}

sub report_progress {
if ((!(    $main_exit_code = system('test', '-n', "$ENV{progress}") >> 8) && !(    $main_exit_code = system('test', $git_filter_branch__commit_count, '-gt', $next_sample_at) >> 8))) {
        my $count;
        my @count;
        my %count;
        $count = $git_filter_branch__commit_count;
        my $now;
        my @now;
        my %now;
        $now = do {
require POSIX; POSIX::strftime('%s', localtime(time())) . "\n"
};
        my $elapsed;
        my @elapsed;
        my %elapsed;
        my $start_timestamp;
        $elapsed = eval { int($now - $start_timestamp) } // "";
        my $remaining;
        my @remaining;
        my %remaining;
        $remaining = eval { int( ($commits - $count) * $elapsed / $count ) } // "";
if ((Variable("elapsed", false, None) > 0)) {
            my $next_sample_at;
            my @next_sample_at;
            my %next_sample_at;
            $next_sample_at = eval { int( ($elapsed + 1) * $count / $elapsed ) } // "";
}
        else {
            $next_sample_at = eval { int($next_sample_at + 1) } // "";
        }
        my $progress;
        my @progress;
        my %progress;
        $progress = " ($elapsed seconds passed, remaining $remaining predicted)";
    }
printf("\rRewrite  (/)    ");
    return;
}
my $git_filter_branch__commit_count;
my @git_filter_branch__commit_count;
my %git_filter_branch__commit_count;
$git_filter_branch__commit_count = q{0};
my $progress;
my @progress;
my %progress;
$progress = q{};
my $start_timestamp;
my @start_timestamp;
my %start_timestamp;
$start_timestamp = q{};
if (!(# Original bash: date '+%s' 2>/dev/null | grep -q '^[0-9][0-9]*$'
{
    my $output_11 = q{};
    my $output_printed_11;
    my $pipeline_success_11 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_12 = q{};
my $date = do {
require POSIX; POSIX::strftime('%s', localtime(time())) . "\n"
};
print $date;
$tmp_redirect_12;
    };
    $output_11 = $output;

        my $grep_result_11_1;
    my @grep_lines_11_1 = split /\n/msx, $output_11;
    my @grep_filtered_11_1 = grep { /^[0-9][0-9]*$/msx } @grep_lines_11_1;
    $grep_result_11_1 = join "\n", @grep_filtered_11_1;
    if (!($grep_result_11_1 =~ m{\n\z}msx || $grep_result_11_1 eq q{})) {
    $grep_result_11_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_11_1 > 0 ? 0 : 1;
    $grep_result_11_1 = q{};
    $output_11 = q{};
    if ((scalar @grep_filtered_11_1) == 0) {
        $pipeline_success_11 = 0;
    }
    if ($output_11 ne q{} && !defined $output_printed_11) {
        print $output_11;
        if (!($output_11 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
    })) {
    my $next_sample_at;
    my @next_sample_at;
    my %next_sample_at;
    $next_sample_at = q{0};
    $progress = "dummy to ensure this is not empty";
    $start_timestamp = do {
require POSIX; POSIX::strftime('%s', localtime(time())) . "\n"
};
}
if (((!($main_exit_code = system('test', '-n', "$filter_index") >> 8) || !($main_exit_code = system('test', '-n', "$filter_tree") >> 8)) || !($main_exit_code = system('test', '-n', "$filter_subdir") >> 8))) {
    my $need_index;
    my @need_index;
    my %need_index;
    $need_index = q{t};
}
else {
    $need_index = q{};
}
open STDIN, '<', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
do { my $eval_input = $filter_setup; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('die', "filter setup failed: $filter_setup") >> 8;
}
open STDIN, '<', '../revs' or croak "Cannot open file: $OS_ERROR\n";
my $commit;
my $parents;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $commit = $_fields[0] // q{};
    $parents = $_fields[1] // q{};
    $git_filter_branch__commit_count = eval { int($git_filter_branch__commit_count+1) } // "";
    report_progress();
    if (do {
$main_exit_code = system('test', '-f', "$workdir", '/../map/', $commit) >> 8;
        $CHILD_ERROR == 0
    }) {
        next;    }
    if ("$filter_subdir" =~ /^$/msx) {
        if (StringInterpolation(StringInterpolation { parts: [Variable("need_index")] }, None) ne q{}) {
            my $GIT_ALLOW_NULL_SHA1 = q{1};
            $main_exit_code = system('git', 'read-tree', '-i', '-m', $commit) >> 8;
        }
    } elsif (1) {
                        $err = do {
    local $ENV{commit} = $commit;
    local $ENV{filter_subdir} = $filter_subdir;
    my $command = 'true; git read-tree -i -m Variable("commit", false, None) : "$filter_subdir" 2>&1';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
        if ($CHILD_ERROR != 0) {
            if (!(!($main_exit_code = system('git', 'rev-parse', '-q', '--verify', $commit, q{:}, "$filter_subdir") >> 8;))) {
if ( -e "$GIT_INDEX_FILE" ) {
                        if ( -d "$GIT_INDEX_FILE" ) {
                            carp "rm: carping: ", "$GIT_INDEX_FILE",
          " is a directory (use -r to remove recursively)\n";
                        }
                        else {
                            if ( unlink "$GIT_INDEX_FILE" ) {
                                                            }
                            else {
                                carp "rm: carping: could not remove ", "$GIT_INDEX_FILE",
              ": $OS_ERROR\n";
                            }
                        }
                    }
                    else {
                        local $CHILD_ERROR = 0;
                    }
}
                else {
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                        print "\n";
                        $CHILD_ERROR = 0;
                    };
                    $CHILD_ERROR = 0;
exit 1;
                }
        }
    }
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', "Could not initialize the index") >> 8;
    }
    my $GIT_COMMIT;
    my @GIT_COMMIT;
    my %GIT_COMMIT;
    $GIT_COMMIT = $commit;
$ENV{GIT_COMMIT} = $GIT_COMMIT;
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '../commit'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('git', 'cat-file', 'commit', "$commit") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', "Cannot read commit $commit") >> 8;
    }
    do { my $eval_input = q{}; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', "setting author/committer failed for commit $commit") >> 8;
    }
    open STDIN, '<', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
do { my $eval_input = $filter_env; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', "env filter failed: $filter_env") >> 8;
    }
if (("$filter_tree")) {
                $main_exit_code = system('git', 'checkout-index', '-f', '-u', '-a') >> 8;
        if ($CHILD_ERROR != 0) {
                        $main_exit_code = system('die', "Could not checkout the index") >> 8;
        }
        $main_exit_code = system('git', 'clean', '-d', '-q', '-f', '-x') >> 8;
        open STDIN, '<', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
do { my $eval_input = $filter_tree; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
        if ($CHILD_ERROR != 0) {
                        $main_exit_code = system('die', "tree filter failed: $filter_tree") >> 8;
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$tempdir"
      or die "Cannot open file: $OS_ERROR\n";
            do {
                local %ENV = %ENV;
                my $dashdash = $dashdash;
                my $OPTIONS_SPEC = $OPTIONS_SPEC;
                my $start_timestamp = $start_timestamp;
                my $OPTARG = $OPTARG;
                my $functions = $functions;
                my $need_index = $need_index;
                my $workdir = $workdir;
                my $sha1 = $sha1;
                my $prune_empty = $prune_empty;
                my $ORIG_GIT_COMMITTER_DATE = $ORIG_GIT_COMMITTER_DATE;
                my $filter_msg = $filter_msg;
                my $orig_dir = $orig_dir;
                my $ORIG_GIT_COMMITTER_NAME = $ORIG_GIT_COMMITTER_NAME;
                my $ref = $ref;
                my $commits = $commits;
                my $wc_output_8 = $wc_output_8;
                my $progress = $progress;
                my $parents = $parents;
                my $filter_index = $filter_index;
                my $commit = $commit;
                my $GIT_COMMIT = $GIT_COMMIT;
                my $USAGE = $USAGE;
                my $ORIG_GIT_COMMITTER_EMAIL = $ORIG_GIT_COMMITTER_EMAIL;
                my $force = $force;
                my $ARG = $ARG;
                my $filter_commit = $filter_commit;
                my $next_sample_at = $next_sample_at;
                my $err = $err;
                my $ORIG_GIT_DIR = $ORIG_GIT_DIR;
                my $orig_namespace = $orig_namespace;
                my $ORIG_GIT_WORK_TREE = $ORIG_GIT_WORK_TREE;
                my $GIT_ALLOW_NULL_SHA1 = $GIT_ALLOW_NULL_SHA1;
                my $GIT_INDEX_FILE = $GIT_INDEX_FILE;
                my $state_branch = $state_branch;
                my $ORIG_GIT_INDEX_FILE = $ORIG_GIT_INDEX_FILE;
                my $ORIG_GIT_AUTHOR_NAME = $ORIG_GIT_AUTHOR_NAME;
                my $filter_subdir = $filter_subdir;
                my $ORIG_GIT_AUTHOR_DATE = $ORIG_GIT_AUTHOR_DATE;
                my $filter_env = $filter_env;
                my $remap_to_ancestor = $remap_to_ancestor;
                my $GIT_WORK_TREE = $GIT_WORK_TREE;
                my $type = $type;
                my $name = $name;
                my $state_commit = $state_commit;
                my $tempdir = $tempdir;
                my $ORIG_GIT_AUTHOR_EMAIL = $ORIG_GIT_AUTHOR_EMAIL;
                my $filter_setup = $filter_setup;
                my $nonrevs = $nonrevs;
                my $git_filter_branch__commit_count = $git_filter_branch__commit_count;
                if (do {
$main_exit_code = system('git', 'diff-index', '-r', '--name-only', '--ignore-submodules', $commit, '--') >> 8;
                    $CHILD_ERROR == 0
                }) {
                                        $main_exit_code = system('git', 'ls-files', '--others') >> 8;
                }
                q{};
            };
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
                $main_exit_code = system('bash', '/tree-state') >> 8;
        if ($CHILD_ERROR != 0) {
            exit $main_exit_code;
        }
open STDIN, '<', "$tempdir" or croak "Cannot open file: $OS_ERROR\n";
        $main_exit_code = system('git', 'update-index', '--add', '--replace', '--remove', '--stdin') >> 8;
                $main_exit_code = system('bash', '/tree-state') >> 8;
        if ($CHILD_ERROR != 0) {
            exit $main_exit_code;
        }
    }
    open STDIN, '<', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
do { my $eval_input = $filter_index; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', "index filter failed: $filter_index") >> 8;
    }
    my $parentstr;
    my @parentstr;
    my %parentstr;
    $parentstr = q{};
    my $parent;
    for my $parent ($parents) {
        my $reparent;
        for my $reparent (do {
    my ($in_15, $out_15);
    my $pid_15 = open3($in_15, $out_15, '>&STDERR', 'map', "$parent");
    close $in_15 or croak 'Close failed: $OS_ERROR';
    my $result_15 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_15> };
    close $out_15 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_15, 0;
    $result_15
}) {
if ("$parentstr " =~ /^.*" -p $reparent ".*$/msx) {
            } elsif (1) {
                                $parentstr = "$parentstr -p $reparent";
            }
        }
    }
if (("$filter_parent")) {
                $parentstr = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_16 = q{};
            my $output_printed_16;
            my $pipeline_success_16 = 1;
            $output_16 .= $parentstr . "\n";
            if ( !($output_16 =~ m{\n\z}msx) ) { $output_16 .= "\n"; }
            $CHILD_ERROR = 0;
            my @_pcmd_18 = ('bash', '-c', "echo \"${output_16}\" | : \"Complex command cannot be converted to shell command\"");
            my ($in_17);
            my $pid_17 = open3($in_17, $out_17, '>&STDERR', @_pcmd_18);
            close $in_17 or croak 'Close failed: $OS_ERROR';
            my $temp_result;
            $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> };
            $output_16 = $temp_result;
            close $out_17 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_17, 0;
            if ( !$pipeline_success_16 ) { $main_exit_code = 1; }
            $output_16 =~ s/\n+\z//msx;
            $output_16;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
        if ($CHILD_ERROR != 0) {
                        $main_exit_code = system('die', "parent filter failed: $filter_parent") >> 8;
        }
    }
    {
        my $output_19 = q{};
        my $output_printed_19;
        my $pipeline_success_19 = 1;
                $output = q{};
        open STDIN, '<', '../commit' or croak "Cannot open file: $OS_ERROR\n";
            my $header_line;
while (1) {
                my $IFS = q{};
                last unless $CHILD_ERROR == 0;
                last unless do {
                    $header_line = <>;
                    chomp $header_line;
                    $CHILD_ERROR = defined($header_line) ? 0 : 1;
                    $CHILD_ERROR == 0
                };
                last unless do {
                    $main_exit_code = system('test', '-n', "$header_line") >> 8;
                    $CHILD_ERROR == 0
                };
                $main_exit_code = system('bash', ':') >> 8;
            }
my $cat_stdin = do { local $INPUT_RECORD_SEPARATOR = undef; <STDIN> };
print $cat_stdin;
        $output_19 = $output;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '../message'
        or die "Cannot open file: $OS_ERROR\n";
        do { my $eval_input = $filter_msg; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_19 ) { $main_exit_code = 1; }
        }
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', "msg filter failed: $filter_msg") >> 8;
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("need_index")] }, None) ne q{}) {
        my $tree;
        my @tree;
        my %tree;
        $tree = do {
    my ($in_22, $out_22);
    my $pid_22 = open3($in_22, $out_22, '>&STDERR', 'git', 'write-tree');
    close $in_22 or croak 'Close failed: $OS_ERROR';
    my $result_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_22> };
    close $out_22 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_22, 0;
    $result_22
};
}
    else {
        $tree = do {
    my ($in_23, $out_23);
    my $pid_23 = open3($in_23, $out_23, '>&STDERR', 'git', 'rev-parse', "$commit^{tree}");
    close $in_23 or croak 'Close failed: $OS_ERROR';
    my $result_23 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
    close $out_23 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_23, 0;
    $result_23
};
    }
    $workdir = $workdir;
open STDIN, '<', '../message' or croak "Cannot open file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '../map/'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('/bin/sh', '-c', "$filter_commit", "git commit-tree", "$tree", $parentstr) >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
        $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', "could not write rewritten commit") >> 8;
    }
}
if (StringInterpolation(StringInterpolation { parts: [Variable("remap_to_ancestor")] }, None) eq t) {
open STDIN, '<', "$tempdir" or croak "Cannot open file: $OS_ERROR\n";
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $ref = $_fields[0] // q{};
        $sha1 = do {
    my ($in_24, $out_24);
    my $pid_24 = open3($in_24, $out_24, '>&STDERR', 'git', 'rev-parse', "$ref", '^0');
    close $in_24 or croak 'Close failed: $OS_ERROR';
    my $result_24 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_24> };
    close $out_24 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_24, 0;
    $result_24
};
        if (do {
$main_exit_code = system('test', '-f', "$workdir", '/../map/', $sha1) >> 8;
            $CHILD_ERROR == 0
        }) {
            next;        }
        my $ancestor;
        my @ancestor;
        my %ancestor;
        $ancestor = do {
    my ($in_25, $out_25);
    my $pid_25 = open3($in_25, $out_25, '>&STDERR', 'git', 'rev-list', '--simplify-merges', '-1', "$ref", "@ARGV");
    close $in_25 or croak 'Close failed: $OS_ERROR';
    my $result_25 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_25> };
    close $out_25 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_25, 0;
    $result_25
};
        if (do {
$main_exit_code = system('test', "$ancestor") >> 8;
            $CHILD_ERROR == 0
        }) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$workdir"
      or die "Cannot open file: $OS_ERROR\n";
                print join(" ", grep { length } split /\s+/msx, do {
    my ($in_26, $out_26);
    my $pid_26 = open3($in_26, $out_26, '>&STDERR', 'map', $ancestor);
    close $in_26 or croak 'Close failed: $OS_ERROR';
    my $result_26 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_26> };
    close $out_26 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_26, 0;
    $result_26
});
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
        $main_exit_code = system('/../map/', $sha1) >> 8;
    }
    $main_exit_code = system('bash', '/heads') >> 8;
}
print "\n";
$CHILD_ERROR = 0;
open STDIN, '<', "$tempdir" or croak "Cannot open file: $OS_ERROR\n";
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $ref = $_fields[0] // q{};
    if (do {
$main_exit_code = system('test', '-f', "$orig_namespace$ref") >> 8;
        $CHILD_ERROR == 0
    }) {
        next;    }
    $sha1 = do {
    my ($in_27, $out_27);
    my $pid_27 = open3($in_27, $out_27, '>&STDERR', 'git', 'rev-parse', "$ref", '^0');
    close $in_27 or croak 'Close failed: $OS_ERROR';
    my $result_27 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_27> };
    close $out_27 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_27, 0;
    $result_27
};
    my $rewritten;
    my @rewritten;
    my %rewritten;
    $rewritten = do {
    my ($in_28, $out_28);
    my $pid_28 = open3($in_28, $out_28, '>&STDERR', 'map', $sha1);
    close $in_28 or croak 'Close failed: $OS_ERROR';
    my $result_28 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_28> };
    close $out_28 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_28, 0;
    $result_28
};
    if (do {
if (do {
$main_exit_code = system('test', $sha1, q{=}, "$rewritten") >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('warn', "WARNING: Ref '$ref' is unchanged") >> 8;
}
        $CHILD_ERROR == 0
    }) {
        next;    }
if ("$rewritten" =~ /^$/msx) {
                do {
    my $__echo_line = "Ref '$ref' was deleted";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
                        $main_exit_code = system('git', 'update-ref', '-m', "filter-branch: delete", '-d', "$ref", $sha1) >> 8;
        if ($CHILD_ERROR != 0) {
                        $main_exit_code = system('die', "Could not delete $ref") >> 8;
        }
    } elsif (1) {
                do {
    my $__echo_line = "Ref '$ref' was rewritten";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        if (!(!(do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            $main_exit_code = system('git', 'update-ref', '-m', "filter-branch: rewrite", "$ref", $rewritten, $sha1) >> 8;
        };))) {
if (CommandSubstitution(Simple(SimpleCommand { name: Literal("git", None), args: [Literal("cat-file", None), Literal("-t", None), StringInterpolation(StringInterpolation { parts: [Variable("ref")] }, None)], redirects: [], env_vars: {}, stdout_used: true, stderr_used: true }), None) eq tag) {
if (StringInterpolation(StringInterpolation { parts: [Variable("filter_tag_name")] }, None) eq q{}) {
                    $main_exit_code = system('warn', "WARNING: You said to rewrite tagged commits, but not the corresponding tag.") >> 8;
                    $main_exit_code = system('warn', "WARNING: Perhaps use '--tag-name-filter cat' to rewrite the tag.") >> 8;
                }
}
            else {
                $main_exit_code = system('die', "Could not rewrite $ref") >> 8;
            }
        }
    }
        $main_exit_code = system('git', 'update-ref', '-m', "filter-branch: backup", "$orig_namespace$ref", $sha1) >> 8;
    if ($CHILD_ERROR != 0) {
        exit $main_exit_code;
    }
}
$main_exit_code = system('bash', '/heads') >> 8;
if (("$filter_tag_name")) {
    # Original bash: git for-each-ref --format='%(objectname) %(objecttype) %(refname)' refs/tags |
{
        my $output_29 = q{};
        my $output_printed_29;
        my $pipeline_success_29 = 1;
                my ($in_30, $out_30);
        my $pid_30 = open3($in_30, $out_30, '>&STDERR', 'git', 'for-each-ref', '--format=%(objectname) %(objecttype) %(refname)', 'refs/tags');
        close $in_30 or croak 'Close failed: $OS_ERROR';
        $output_29 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
        close $out_30 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_30, 0;

                my @lines = split /\n/msx, $output_29;
        my $result_29_1 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        $ref = (${ref} =~ s/^refs/tags///r =~ s/^refs/tags///r);
        if (("$type" ne "commit" && "$type" ne "tag")) {
        next;
        }
        if ("$type" eq "tag") {
        my $sha1t;
        my @sha1t;
        my %sha1t;
        $sha1t = "$sha1";
        $sha1 = (do { my $_chomp_temp = do {
        my ($in_31, $out_31);
        my $pid_31 = open3($in_31, $out_31, '>&STDERR', 'git', 'rev-parse', '-q', "$sha1", q{^}, '\'commit\'');
        close $in_31 or croak 'Close failed: $OS_ERROR';
        my $result_31 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
        close $out_31 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_31, 0;
        $result_31
        }; chomp $_chomp_temp; $_chomp_temp; });
        if ($CHILD_ERROR != 0) {
        next;            }
        }
        if (!((-f "../map/$sha1"))) {
        next;        }
        my $new_sha1;
        my @new_sha1;
        my %new_sha1;
        $new_sha1 = (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', "../map/$sha1" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "../map/$sha1" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; });
        $GIT_COMMIT = "$sha1";
        $ENV{GIT_COMMIT} = $GIT_COMMIT;
        my $new_ref;
        my @new_ref;
        my %new_ref;
        $new_ref = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $pipeline_success_29 = 1;
        $output_29 .= $ref . "\n";
        if ( !($output_29 =~ m{\n\z}msx) ) { $output_29 .= "\n"; }
        $CHILD_ERROR = 0;
        my @_pcmd_33 = ('bash', '-c', "echo \"${output_29}\" | : \"Complex command cannot be converted to shell command\"");
        my ($in_32);
        my $pid_32 = open3($in_32, $out_32, '>&STDERR', @_pcmd_33);
        close $in_32 or croak 'Close failed: $OS_ERROR';
        my $temp_result;
        $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_32> };
        $output_29 = $temp_result;
        close $out_32 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_32, 0;
        if ( !$pipeline_success_29 ) { $main_exit_code = 1; }
        $output_29 =~ s/\n+\z//msx;
        $output_29;
        }; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
        if ($CHILD_ERROR != 0) {
        $main_exit_code = system('die', "tag name filter failed: $filter_tag_name") >> 8;
        }
        do {
        my $__echo_line = "$ref -> $new_ref ($sha1 -> $new_sha1)";
        if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        $__echo_line .= "\n";
        }
        $output .= $__echo_line;
        };
        $CHILD_ERROR = 0;
        if ("$type" eq "tag") {
        $new_sha1 = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $pipeline_success_29 = 1;
        $output_29 = q{};
        my @_pcmd_35 = ('sh', '-c', 'printf "object %s\\\\ntype commit\\\\ntag %s\\\\n" "$new_sha1" "$new_ref"');
        my ($in_34, $out_34);
        my $pid_34 = open3($in_34, $out_34, '>&STDERR', @_pcmd_35);
        close $in_34 or croak 'Close failed: $OS_ERROR';
        $output_29 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_34> };
        close $out_34 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_34, 0;
        my @_pcmd_37 = ('sh', '-c', q(git cat-file tag "$ref" | sed -n -e '1,/^$/{
        /^object /d
        /^type /d
        /^tag /d
        }' -e '/^-----BEGIN PGP SIGNATURE-----/q' -ep));
        my ($in_36, $out_36);
        my $pid_36 = open3($in_36, $out_36, '>&STDERR', @_pcmd_37);
        close $in_36 or croak 'Close failed: $OS_ERROR';
        $output_29 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_36> };
        close $out_36 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_36, 0;
        my $cmd_39 = 'git';
        my ($in_38, $out_38);
        my $pid_38 = open3($in_38, $out_38, '>&STDERR', $cmd_39, 'hash-object', '-t', 'tag', '-w', '--stdin');
        print {$in_38} $output_29;
        close $in_38 or croak 'Close failed: $OS_ERROR';
        $output_29 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_38> };
        close $out_38 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_38, 0;
        if ( !$pipeline_success_29 ) { $main_exit_code = 1; }
        $output_29 =~ s/\n+\z//msx;
        $output_29;
        }; $_pipeline_result; };
        if ($CHILD_ERROR != 0) {
        $main_exit_code = system('die', "Could not create new tag object for $ref") >> 8;
        }
        if (!(            # Original bash: git cat-file tag "$ref" | \
        {
        my $pipeline_success_29 = 1;
        my ($in_40, $out_40);
        my $pid_40 = open3($in_40, $out_40, '>&STDERR', 'git', 'cat-file', 'tag');
        close $in_40 or croak 'Close failed: $OS_ERROR';
        $output_29 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_40> };
        close $out_40 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_40, 0;
        my $grep_result_29_1;
        my @grep_lines_29_1 = split /\n/msx, $output_29;
        my @grep_filtered_29_1 = grep { /^-----BEGIN\ PGP\ SIGNATURE-----/msx } @grep_lines_29_1;
        $grep_result_29_1 = join "\n", @grep_filtered_29_1;
        if (!($grep_result_29_1 =~ m{\n\z}msx || $grep_result_29_1 eq q{})) {
        $grep_result_29_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_29_1 > 0 ? 0 : 1;
        $output_29 = $grep_result_29_1;
        if ( !$pipeline_success_29 ) { $main_exit_code = 1; }
        })) {
        $main_exit_code = system('warn', "gpg signature stripped from tag object $sha1t") >> 8;
        }
        }
        $main_exit_code = system('git', 'update-ref', "refs/tags/$new_ref", "$new_sha1") >> 8;
        if ($CHILD_ERROR != 0) {
        $main_exit_code = system('die', "Could not write tag $new_ref") >> 8;
        }
        }
        $output_29 = $result_29_1;
        if ($output_29 ne q{} && !defined $output_printed_29) {
            print $output_29;
            if (!($output_29 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_29 ) { $main_exit_code = 1; }
        }
}
delete $ENV{GIT_DIR};
undef $GIT_WORK_TREE;
delete $ENV{GIT_WORK_TREE};
undef $GIT_INDEX_FILE;
delete $ENV{GIT_INDEX_FILE};
delete $ENV{GIT_AUTHOR_NAME};
delete $ENV{GIT_AUTHOR_EMAIL};
delete $ENV{GIT_AUTHOR_DATE};
delete $ENV{GIT_COMMITTER_NAME};
delete $ENV{GIT_COMMITTER_EMAIL};
delete $ENV{GIT_COMMITTER_DATE};
$main_exit_code = system('test', '-z', "$ORIG_GIT_DIR") >> 8;
if ($CHILD_ERROR != 0) {
            if (do {
my $GIT_DIR;
my @GIT_DIR;
my %GIT_DIR;
$GIT_DIR = "$ORIG_GIT_DIR";
            $CHILD_ERROR == 0
        }) {
            $ENV{GIT_DIR} = $GIT_DIR;
        }
}
$main_exit_code = system('test', '-z', "$ORIG_GIT_WORK_TREE") >> 8;
if ($CHILD_ERROR != 0) {
            if (do {
$GIT_WORK_TREE = "$ORIG_GIT_WORK_TREE";
            $CHILD_ERROR == 0
        }) {
            $ENV{GIT_WORK_TREE} = $GIT_WORK_TREE;
        }
}
$main_exit_code = system('test', '-z', "$ORIG_GIT_INDEX_FILE") >> 8;
if ($CHILD_ERROR != 0) {
            if (do {
$GIT_INDEX_FILE = "$ORIG_GIT_INDEX_FILE";
            $CHILD_ERROR == 0
        }) {
            $ENV{GIT_INDEX_FILE} = $GIT_INDEX_FILE;
        }
}
$main_exit_code = system('test', '-z', "$ORIG_GIT_AUTHOR_NAME") >> 8;
if ($CHILD_ERROR != 0) {
            if (do {
my $GIT_AUTHOR_NAME;
my @GIT_AUTHOR_NAME;
my %GIT_AUTHOR_NAME;
$GIT_AUTHOR_NAME = "$ORIG_GIT_AUTHOR_NAME";
            $CHILD_ERROR == 0
        }) {
            $ENV{GIT_AUTHOR_NAME} = $GIT_AUTHOR_NAME;
        }
}
$main_exit_code = system('test', '-z', "$ORIG_GIT_AUTHOR_EMAIL") >> 8;
if ($CHILD_ERROR != 0) {
            if (do {
my $GIT_AUTHOR_EMAIL;
my @GIT_AUTHOR_EMAIL;
my %GIT_AUTHOR_EMAIL;
$GIT_AUTHOR_EMAIL = "$ORIG_GIT_AUTHOR_EMAIL";
            $CHILD_ERROR == 0
        }) {
            $ENV{GIT_AUTHOR_EMAIL} = $GIT_AUTHOR_EMAIL;
        }
}
$main_exit_code = system('test', '-z', "$ORIG_GIT_AUTHOR_DATE") >> 8;
if ($CHILD_ERROR != 0) {
            if (do {
my $GIT_AUTHOR_DATE;
my @GIT_AUTHOR_DATE;
my %GIT_AUTHOR_DATE;
$GIT_AUTHOR_DATE = "$ORIG_GIT_AUTHOR_DATE";
            $CHILD_ERROR == 0
        }) {
            $ENV{GIT_AUTHOR_DATE} = $GIT_AUTHOR_DATE;
        }
}
$main_exit_code = system('test', '-z', "$ORIG_GIT_COMMITTER_NAME") >> 8;
if ($CHILD_ERROR != 0) {
            if (do {
my $GIT_COMMITTER_NAME;
my @GIT_COMMITTER_NAME;
my %GIT_COMMITTER_NAME;
$GIT_COMMITTER_NAME = "$ORIG_GIT_COMMITTER_NAME";
            $CHILD_ERROR == 0
        }) {
            $ENV{GIT_COMMITTER_NAME} = $GIT_COMMITTER_NAME;
        }
}
$main_exit_code = system('test', '-z', "$ORIG_GIT_COMMITTER_EMAIL") >> 8;
if ($CHILD_ERROR != 0) {
            if (do {
my $GIT_COMMITTER_EMAIL;
my @GIT_COMMITTER_EMAIL;
my %GIT_COMMITTER_EMAIL;
$GIT_COMMITTER_EMAIL = "$ORIG_GIT_COMMITTER_EMAIL";
            $CHILD_ERROR == 0
        }) {
            $ENV{GIT_COMMITTER_EMAIL} = $GIT_COMMITTER_EMAIL;
        }
}
$main_exit_code = system('test', '-z', "$ORIG_GIT_COMMITTER_DATE") >> 8;
if ($CHILD_ERROR != 0) {
            if (do {
my $GIT_COMMITTER_DATE;
my @GIT_COMMITTER_DATE;
my %GIT_COMMITTER_DATE;
$GIT_COMMITTER_DATE = "$ORIG_GIT_COMMITTER_DATE";
            $CHILD_ERROR == 0
        }) {
            $ENV{GIT_COMMITTER_DATE} = $GIT_COMMITTER_DATE;
        }
}
if (StringInterpolation(StringInterpolation { parts: [Variable("state_branch")] }, None) ne q{}) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "Saving rewrite state to $state_branch";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    my $state_blob;
    my @state_blob;
    my %state_blob;
    $state_blob = do {
    my $command = q[perl -e "opendir D, \"../map\" or die;
			open H, \"|-\", \"git hash-object -w --stdin\" or die;
			foreach (sort readdir(D)) {
				next if m/^\\.\\.?\$/;
				open F, \"<../map/\$_\" or die;
				chomp(\$f = <F>);
				print H \"\$_:\$f\\n\" or die;
			}
			close(H) or die;" || die 'Unable to save state'];
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
    my $state_tree;
    my @state_tree;
    my %state_tree;
    $state_tree = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_41 = q{};
        my $output_printed_41;
        my $pipeline_success_41 = 1;
        my $output_41;
        {
            local *STDOUT;
            open STDOUT, '>', \$output_41 or die "Cannot redirect STDOUT";
            printf("100644 blob %s\tfilter.map\n", "$state_blob");
        }
        if ($CHILD_ERROR != 0) { $pipeline_success_41 = 0; }

        my $cmd_43 = 'git';
        my ($in_42, $out_42);
        my $pid_42 = open3($in_42, $out_42, '>&STDERR', $cmd_43, 'mktree');
        print {$in_42} $output_41;
        close $in_42 or croak 'Close failed: $OS_ERROR';
        $output_41 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_42> };
        close $out_42 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_42, 0;
        if ( !$pipeline_success_41 ) { $main_exit_code = 1; }
        $output_41 =~ s/\n+\z//msx;
        $output_41;
}; $_pipeline_result; };
if (StringInterpolation(StringInterpolation { parts: [Variable("state_commit")] }, None) ne q{}) {
        $state_commit = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_44 = q{};
            my $output_printed_44;
            my $pipeline_success_44 = 1;
            $output_44 .= 'Sync' . "\n";
            if ( !($output_44 =~ m{\n\z}msx) ) { $output_44 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_44 = 0; }

            my $cmd_46 = 'git';
            my ($in_45, $out_45);
            my $pid_45 = open3($in_45, $out_45, '>&STDERR', $cmd_46, 'commit-tree', '-p');
            print {$in_45} $output_44;
            close $in_45 or croak 'Close failed: $OS_ERROR';
            $output_44 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_45> };
            close $out_45 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_45, 0;
            if ( !$pipeline_success_44 ) { $main_exit_code = 1; }
            $output_44 =~ s/\n+\z//msx;
            $output_44;
}; $_pipeline_result; };
}
    else {
        $state_commit = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_47 = q{};
            my $output_printed_47;
            my $pipeline_success_47 = 1;
            $output_47 .= 'Sync' . "\n";
            if ( !($output_47 =~ m{\n\z}msx) ) { $output_47 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_47 = 0; }

            my $cmd_49 = 'git';
            my ($in_48, $out_48);
            my $pid_48 = open3($in_48, $out_48, '>&STDERR', $cmd_49, 'commit-tree');
            print {$in_48} $output_47;
            close $in_48 or croak 'Close failed: $OS_ERROR';
            $output_47 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_48> };
            close $out_48 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_48, 0;
            if ( !$pipeline_success_47 ) { $main_exit_code = 1; }
            $output_47 =~ s/\n+\z//msx;
            $output_47;
}; $_pipeline_result; };
    }
    $main_exit_code = system('git', 'update-ref', "$state_branch", "$state_commit") >> 8;
}
chdir("$orig_dir");
$CHILD_ERROR = 0;
if ( -e "$tempdir" ) {
    if ( -d "$tempdir" ) {
        my $err;
        require File::Path;
        File::Path::remove_tree("$tempdir", {error => \$err});
        if (@{$err}) {
            carp "rm: carping: could not remove ", "$tempdir", ": $err->[0]\n";
        }
        else {
                    }
    }
    else {
        if ( unlink "$tempdir" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "$tempdir",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'- 2>&1'; print $end_out if $end_out ne q{}; }
if ("$(is_bare_repository)" eq false) {
        $main_exit_code = system('git', 'read-tree', '-u', '-m', 'HEAD') >> 8;
    if ($CHILD_ERROR != 0) {
        exit $main_exit_code;
    }
}
exit 0;

exit $main_exit_code;
