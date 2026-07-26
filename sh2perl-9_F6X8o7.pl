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

my $REMOTE_CONTAINERS_PATH;
my @REMOTE_CONTAINERS_PATH;
my %REMOTE_CONTAINERS_PATH;
my $script_file;
my @script_file;
my %script_file;
my $IN_WSL;
my @IN_WSL;
my %IN_WSL;
my $WSL_BUILD;
my @WSL_BUILD;
my %WSL_BUILD;
my $basedir;
my @basedir;
my %basedir;
my $WSL_DISTRO_NAME;
my @WSL_DISTRO_NAME;
my %WSL_DISTRO_NAME;

$script_file = $PROGRAM_NAME;
while (  -h "$script_file" ) {
    $script_file = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'readlink', $script_file);
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
}
$basedir = do { use File::Basename qw(dirname); my $dirname_output = dirname((do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_1 = q{};
    my $output_printed_1;
    my $pipeline_success_1 = 1;
    $output_1 .= $script_file . "\n";
    if ( !($output_1 =~ m{\n\z}msx) ) { $output_1 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
    my @sed_lines_1 = split /\n/msx, $output_1;
    my @sed_result_1;
    foreach my $line (@sed_lines_1) {
    chomp $line;
    push @sed_result_1, $line;
    }
    $output_1 = join "\n", @sed_result_1;

    if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
    $output_1 =~ s/\n+\z//msx;
    $output_1;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $dirname_output; };
$IN_WSL = 'false';
if ("$WSL_DISTRO_NAME" ne q{}) {
    $IN_WSL = 'true';
}
else {
    $WSL_BUILD = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_2 = q{};
        my $output_printed_2;
        my $pipeline_success_2 = 1;
        do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; $output_2 = join(" ", @__parts) . "\n"; $CHILD_ERROR = 0; };
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
if ("$WSL_BUILD" ne q{}) {
        $IN_WSL = 'true';
    }
}
my $VSCODE_PATH;
my @VSCODE_PATH;
my %VSCODE_PATH;
$VSCODE_PATH = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$basedir/vscode-path" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$basedir/vscode-path" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
my $DEVCONTAINER_CLI_PATH;
my @DEVCONTAINER_CLI_PATH;
my %DEVCONTAINER_CLI_PATH;
$DEVCONTAINER_CLI_PATH = $script_file;
$REMOTE_CONTAINERS_PATH = q{};
if ((-f "$basedir/remote-containers-path")) {
    $REMOTE_CONTAINERS_PATH = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$basedir/remote-containers-path" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$basedir/remote-containers-path" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
if ($IN_WSL eq true) {
        $REMOTE_CONTAINERS_PATH = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'wslpath', '-u', $REMOTE_CONTAINERS_PATH);
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
};
    }
if ((!-f "$REMOTE_CONTAINERS_PATH/dev-containers-user-cli/cli.js")) {
        $REMOTE_CONTAINERS_PATH = q{};
    }
}
if ("$REMOTE_CONTAINERS_PATH" eq q{}) {
    print "Failed to determine Dev Containers path\n";
exit 1;
}
if ($IN_WSL eq true) {
$ENV{WSLENV} = '';
    my $CLI;
    my @CLI;
    my %CLI;
    $CLI = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'wslpath', '-m', "$REMOTE_CONTAINERS_PATH/dev-containers-user-cli/cli.js");
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
};
    my $ELECTRON;
    my @ELECTRON;
    my %ELECTRON;
    $ELECTRON = do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'wslpath', '-u', "$VSCODE_PATH");
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
};
    $IN_WSL = $IN_WSL;
    $DEVCONTAINER_CLI_PATH = "$DEVCONTAINER_CLI_PATH";
    my $ELECTRON_RUN_AS_NODE;
    my @ELECTRON_RUN_AS_NODE;
    my %ELECTRON_RUN_AS_NODE;
    $ELECTRON_RUN_AS_NODE = q{1};
    # Original bash: "$ELECTRON" "$CLI" "$@" | cat
{
        my $output_6 = q{};
        my $output_printed_6;
        my $pipeline_success_6 = 1;
                my ($in_7, $out_7);
        my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'unknown_command', );
        close $in_7 or croak 'Close failed: $OS_ERROR';
        $output_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
        close $out_7 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_7, 0;

                if ($output_6 ne q{} && !defined $output_printed_6) {
            print $output_6;
            if (!($output_6 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
        }
}
else {
    $ELECTRON = "$VSCODE_PATH";
    $CLI = $REMOTE_CONTAINERS_PATH;
    $main_exit_code = system('bash', '/dev-containers-user-cli/cli.js') >> 8;
    $DEVCONTAINER_CLI_PATH = "$DEVCONTAINER_CLI_PATH";
    $ELECTRON_RUN_AS_NODE = q{1};
    $CHILD_ERROR = 0;
}

exit $main_exit_code;
