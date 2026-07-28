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

my $MAGIC_6   = 6;
my $MAGIC_126 = 126;

my $TOOL_MODE;
my @TOOL_MODE;
my %TOOL_MODE;
$TOOL_MODE = 'diff';
$main_exit_code = system('.', 'git-mergetool--lib') >> 8;

sub should_prompt {
    my $prompt_merge;
    my @prompt_merge;
    my %prompt_merge;
    $prompt_merge = do {
    my $command = 'git config --bool mergetool.prompt || echo true';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
    my $prompt;
    my @prompt;
    my %prompt;
    $prompt = do {
    local $ENV{prompt_merge} = $prompt_merge;
    my $command = 'git config --bool difftool.prompt || echo Variable("prompt_merge", false, None)';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
if (StringInterpolation(StringInterpolation { parts: [Variable("prompt")] }, None) eq true) {
        $main_exit_code = system('test', '-z', "$ENV{GIT_DIFFTOOL_NO_PROMPT}") >> 8;
}
    else {
        $main_exit_code = system('test', '-n', "$ENV{GIT_DIFFTOOL_PROMPT}") >> 8;
    }
    return;
}

sub use_ext_cmd {
    $main_exit_code = system('test', '-n', "$ENV{GIT_DIFFTOOL_EXTCMD}") >> 8;
    return;
}

sub launch_merge_tool {
    my $MERGED;
    my @MERGED;
    my %MERGED;
    $MERGED = "$_[0]";
    my $LOCAL;
    my @LOCAL;
    my %LOCAL;
    $LOCAL = "$_[1]";
    my $REMOTE;
    my @REMOTE;
    my %REMOTE;
    $REMOTE = "$_[2]";
    my $BASE;
    my @BASE;
    my %BASE;
    $BASE = "$_[0]";
if (!(    should_prompt())) {
printf("\nViewing (%s/%s): '%s'\n", "$ENV{GIT_DIFF_PATH_COUNTER}", "$ENV{GIT_DIFF_PATH_TOTAL}", "$MERGED");
if (!(        use_ext_cmd())) {
printf('Launch \'%s\' [Y/n]? ', "$ENV{GIT_DIFFTOOL_EXTCMD}");
}
        else {
printf('Launch \'%s\' [Y/n]? ', "$ENV{merge_tool}");
        }
        $ans = <>;
chomp $ans;
$CHILD_ERROR = defined($ans) ? 0 : 1;
        if ($CHILD_ERROR != 0) {
            return;        }
if (StringInterpolation(StringInterpolation { parts: [Variable("ans")] }, None) eq n) {
return;
        }
    }
if (!(    use_ext_cmd())) {
$ENV{BASE} = $BASE;
do { my $eval_input = $GIT_DIFFTOOL_EXTCMD . "\"$LOCAL\"" . "\"$REMOTE\""; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
}
    else {
        $main_exit_code = system('initialize_merge_tool', "$ENV{merge_tool}") >> 8;
        $main_exit_code = system('run_merge_tool', "$ENV{merge_tool}") >> 8;
    }
    return;
}
if (!(!(use_ext_cmd();))) {
if (StringInterpolation(StringInterpolation { parts: [Variable("GIT_DIFF_TOOL")] }, None) ne q{}) {
        my $merge_tool;
        my @merge_tool;
        my %merge_tool;
        $merge_tool = "$ENV{GIT_DIFF_TOOL}";
}
    else {
        $merge_tool = (do { my $_chomp_temp = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'get_merge_tool');
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
}; chomp $_chomp_temp; $_chomp_temp; });
        my $subshell_exit_status;
        my @subshell_exit_status;
        my %subshell_exit_status;
        $subshell_exit_status = $?;
if ((Variable("subshell_exit_status", false, None) > 1)) {

        }
    }
}
if (StringInterpolation(StringInterpolation { parts: [Variable("GIT_DIFFTOOL_DIRDIFF")] }, None) ne q{}) {
    my $LOCAL;
    my @LOCAL;
    my %LOCAL;
    $LOCAL = "$_[0]";
    my $REMOTE;
    my @REMOTE;
    my %REMOTE;
    $REMOTE = "$_[1]";
    $main_exit_code = system('initialize_merge_tool', "$merge_tool") >> 8;
    $main_exit_code = system('run_merge_tool', "$merge_tool", 'false') >> 8;
}
else {
    my $# = 0;
while ( (Variable("#", false, None) > $MAGIC_6) ) {
        launch_merge_tool("$_[0]", "$_[1]", "$_[4]");
        my $status;
        my @status;
        my %status;
        $status = $?;
if ((Variable("status", false, None) >= 12$MAGIC_6)) {

        }
if ((!(        $main_exit_code = system('test', "$status", q{!}, q{=}, q{0}) >> 8) && !(        $main_exit_code = system('test', "$ENV{GIT_DIFFTOOL_TRUST_EXIT_CODE}", q{=}, 'true') >> 8))) {

        }
# Builtin command 'shift' not implemented
    }
}
exit 0;

exit $main_exit_code;
