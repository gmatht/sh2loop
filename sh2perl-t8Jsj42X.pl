#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy move);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;


sub usage {
    do {
    my $__echo_line = "usage:" . q{ } . @ARGV;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
exit 127;
    return;
}

sub die {
    do {
    my $__echo_line = @ARGV;
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
exit 128;
    return;
}

sub failed {
    die("unable to create new workdir '$ENV{new_workdir}'!");
    return;
}
if ((!($main_exit_code = system('test', scalar(@ARGV), '-lt', q{2}) >> 8) || !($main_exit_code = system('test', scalar(@ARGV), '-gt', q{3}) >> 8))) {
    usage("$PROGRAM_NAME <repository> <new_workdir> [<branch>]");
}
my $orig_git;
my @orig_git;
my %orig_git;
$orig_git = $1;
my $new_workdir;
my @new_workdir;
my %new_workdir;
$new_workdir = $2;
my $branch;
my @branch;
my %branch;
$branch = $3;
my $git_dir;
my @git_dir;
my %git_dir;
$git_dir = do { my @_qx_cmd = ('cd "$orig_git" 2> /dev/null && git rev-parse --git-dir 2> /dev/null'); my $result = qx{$_qx_cmd[0]}; $CHILD_ERROR = $? >> 8; $result; };
if ($CHILD_ERROR != 0) {
        die("Not a git repository: \"$orig_git\"");
}
if ("$git_dir" =~ /^.git$/msx) {
        $git_dir = "$orig_git/.git";
} elsif ("$git_dir" =~ /^.$/msx) {
        $git_dir = $orig_git;
}
my $isbare;
my @isbare;
my %isbare;
$isbare = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'git', '--git-dir=$git_dir', 'config', '--bool', '--get', 'core.bare');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
if (ztrue eq StringInterpolation(StringInterpolation { parts: [Literal("z"), Variable("isbare")] }, None)) {
    die("\"$git_dir\" has core.bare set to true,", " remove from \"$git_dir/config\" to use $PROGRAM_NAME");
}
if ((-h StringInterpolation(StringInterpolation { parts: [Variable("git_dir"), Literal("/config")] }, None))) {
    die("\"$orig_git\" is a working directory only, please specify", "a complete repository.");
}
$git_dir = do {
    my $left_result_1 = do { chdir("$git_dir"); q{} };
;
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_1 = do { use Cwd; getcwd(); };
        $left_result_1 . $right_result_1;
    } else {
        q{};
    }
};
if ($CHILD_ERROR != 0) {
    exit 1;
}
if ((-d 'StringInterpolation(StringInterpolation { parts: [Variable("new_workdir")] }, None)')) {
if ((CommandSubstitution(Pipeline(Pipeline { commands: [Simple(SimpleCommand { name: Literal("ls", None), args: [Literal("-a1", None), StringInterpolation(StringInterpolation { parts: [Variable("new_workdir"), Literal("/.")] }, None)], redirects: [], env_vars: {}, stdout_used: true, stderr_used: true }), Simple(SimpleCommand { name: Literal("wc", None), args: [Literal("-l", None)], redirects: [], env_vars: {}, stdout_used: true, stderr_used: true })], source_text: None, stdout_used: true, stderr_used: true }), None) != 2)) {
        die("destination directory '$new_workdir' is not empty.");
    }
    my $cleandir;
    my @cleandir;
    my %cleandir;
    $cleandir = "$new_workdir/.git";
}
else {
    $cleandir = "$new_workdir";
}
use File::Path qw(make_path);
my $err;
if ( !-d "$new_workdir/.git" ) {
    make_path( "$new_workdir/.git", { error => \$err } );
    if ( @{$err} ) {
        croak "mkdir: cannot create directory " . "$new_workdir/.git" . ": $err->[0]\n";
    }
}
if ($CHILD_ERROR != 0) {
        failed();
}
$cleandir = do {
    my $left_result_3 = do { chdir("$cleandir"); q{} };
;
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_3 = do { use Cwd; getcwd(); };
        $left_result_3 . $right_result_3;
    } else {
        q{};
    }
};
if ($CHILD_ERROR != 0) {
        failed();
}

sub cleanup {
if ( -e "$cleandir" ) {
        if ( -d "$cleandir" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$cleandir", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "$cleandir", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$cleandir" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$cleandir",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}
my $siglist;
my @siglist;
my %siglist;
$siglist = "0 1 2 15";
# Builtin command 'trap' not implemented for signal
my $x;
for my $x ('config', 'refs', 'logs/refs', 'objects', 'info', 'hooks', 'packed-refs', 'remotes', 'rr-cache', 'svn') {
if ($x =~ /^.*/.*$/msx) {
                use File::Path qw(make_path);
        if ( !-d "$new_workdir/.git/" . ( ( dirname(${x}) ) =~ s|/[^/]*$||sr ) ) {
            make_path( "$new_workdir/.git/" . ( ( dirname(${x}) ) =~ s|/[^/]*$||sr ), { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . "$new_workdir/.git/" . ( ( dirname(${x}) ) =~ s|/[^/]*$||sr ) . ": $err->[0]\n";
            }
        }
    }
    symlink "$git_dir/$x", "$new_workdir/.git/$x" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) {
                failed();
    }
}
chdir("$new_workdir");
$CHILD_ERROR = 0;
if ($CHILD_ERROR != 0) {
        failed();
}
use File::Copy qw(copy);
if ( -e "$git_dir/HEAD" ) {
    if ( -d '.git/HEAD' ) {
        require File::Copy; File::Copy::copy("$git_dir/HEAD", '.git/HEAD' . '/' . ("$git_dir/HEAD" =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy("$git_dir/HEAD", '.git/HEAD');
    }
} else {
    croak "cp: cannot stat '$git_dir/HEAD': No such file or directory\n";
}
if ($CHILD_ERROR != 0) {
        failed();
}
# Builtin command 'trap' not implemented for signal
$main_exit_code = system('git', 'checkout', '-f', $branch) >> 8;

exit $main_exit_code;
