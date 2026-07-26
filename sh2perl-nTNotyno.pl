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

my $HOME;
my @HOME;
my %HOME;
my $ZDOTDIR;
my @ZDOTDIR;
my %ZDOTDIR;

my $MAGIC_5000 = 5_000;

$__set_e = 1;
my $USER;
my @USER;
my %USER;
$USER = (defined ${USER} && ${USER} ne q{} ? ${USER} : do { my $_result = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'id', '-u', '-n');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; $_result; });
$HOME = (defined (defined ${HOME} && ${HOME} ne q{} ? ${HOME} : do { my $_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_1 = q{};
    my $output_printed_1;
    my $pipeline_success_1 = 1;
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'getent', 'passwd');
    close $in_2 or croak 'Close failed: $OS_ERROR';
    $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    my @lines_3 = split /\n/msx, $output_1;
    my @result_3;
    foreach my $line (@lines_3) {
    chomp $line;
    my @fields = split /:/msx, $line;
    if (@fields > 5) {
    push @result_3, $fields[5];
    }
    }
    $output_1 = join "\n", @result_3;
    if ($output_1 ne q{} && !($output_1  =~ m{\n\z}msx)) { $output_1 .= "\n"; }
    if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_1 =~ s/\n+\z//msx;
    $output_1;
}; $_pipeline_result; }; $_result; }) && (defined ${HOME} && ${HOME} ne q{} ? ${HOME} : do { my $_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_1 = q{};
    my $output_printed_1;
    my $pipeline_success_1 = 1;
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'getent', 'passwd');
    close $in_2 or croak 'Close failed: $OS_ERROR';
    $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    my @lines_3 = split /\n/msx, $output_1;
    my @result_3;
    foreach my $line (@lines_3) {
    chomp $line;
    my @fields = split /:/msx, $line;
    if (@fields > 5) {
    push @result_3, $fields[5];
    }
    }
    $output_1 = join "\n", @result_3;
    if ($output_1 ne q{} && !($output_1  =~ m{\n\z}msx)) { $output_1 .= "\n"; }
    if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_1 =~ s/\n+\z//msx;
    $output_1;
}; $_pipeline_result; }; $_result; }) ne q{} ? (defined ${HOME} && ${HOME} ne q{} ? ${HOME} : do { my $_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_1 = q{};
    my $output_printed_1;
    my $pipeline_success_1 = 1;
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'getent', 'passwd');
    close $in_2 or croak 'Close failed: $OS_ERROR';
    $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    my @lines_3 = split /\n/msx, $output_1;
    my @result_3;
    foreach my $line (@lines_3) {
    chomp $line;
    my @fields = split /:/msx, $line;
    if (@fields > 5) {
    push @result_3, $fields[5];
    }
    }
    $output_1 = join "\n", @result_3;
    if ($output_1 ne q{} && !($output_1  =~ m{\n\z}msx)) { $output_1 .= "\n"; }
    if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_1 =~ s/\n+\z//msx;
    $output_1;
}; $_pipeline_result; }; $_result; }) : do { my $_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_4 = q{};
    my $output_printed_4;
    my $pipeline_success_4 = 1;
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'getent', 'passwd');
    close $in_5 or croak 'Close failed: $OS_ERROR';
    $output_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    my @lines_6 = split /\n/msx, $output_4;
    my @result_6;
    foreach my $line (@lines_6) {
    chomp $line;
    my @fields = split /:/msx, $line;
    if (@fields > 5) {
    push @result_6, $fields[5];
    }
    }
    $output_4 = join "\n", @result_6;
    if ($output_4 ne q{} && !($output_4  =~ m{\n\z}msx)) { $output_4 .= "\n"; }
    if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_4 =~ s/\n+\z//msx;
    $output_4;
}; $_pipeline_result; }; $_result; });
$HOME = (defined (defined ${HOME} && ${HOME} ne q{} ? ${HOME} : do { my $_result = do {
    local $ENV{USER} = $USER;
    my $command = q{: 'Complex command not supported in bash string generation'};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; $_result; }) && (defined ${HOME} && ${HOME} ne q{} ? ${HOME} : do { my $_result = do {
    local $ENV{USER} = $USER;
    my $command = q{: 'Complex command not supported in bash string generation'};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; $_result; }) ne q{} ? (defined ${HOME} && ${HOME} ne q{} ? ${HOME} : do { my $_result = do {
    local $ENV{USER} = $USER;
    my $command = q{: 'Complex command not supported in bash string generation'};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; $_result; }) : do { my $_result = do {
    local $ENV{USER} = $USER;
    my $command = q{: 'Complex command not supported in bash string generation'};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; $_result; });
my $custom_zsh;
my @custom_zsh;
my %custom_zsh;
$custom_zsh = (defined ($ENV{ZSH} // q{}) && ($ENV{ZSH} // q{}) ne q{} ? ($ENV{ZSH} // q{}) : 'yes');
my $zdot;
my @zdot;
my %zdot;
$zdot = (defined (defined ${ZDOTDIR} && ${ZDOTDIR} ne q{} ? ${ZDOTDIR} : '$HOME') && (defined ${ZDOTDIR} && ${ZDOTDIR} ne q{} ? ${ZDOTDIR} : '$HOME') ne q{} ? (defined ${ZDOTDIR} && ${ZDOTDIR} ne q{} ? ${ZDOTDIR} : '$HOME') : '$HOME');
if (("$ZDOTDIR" ne q{} && "$ZDOTDIR" ne "$HOME")) {
    my $ZSH;
    my @ZSH;
    my %ZSH;
    $ZSH = (defined (defined ${ZSH} && ${ZSH} ne q{} ? ${ZSH} : '$ZDOTDIR/ohmyzsh') && (defined ${ZSH} && ${ZSH} ne q{} ? ${ZSH} : '$ZDOTDIR/ohmyzsh') ne q{} ? (defined ${ZSH} && ${ZSH} ne q{} ? ${ZSH} : '$ZDOTDIR/ohmyzsh') : '$ZDOTDIR/ohmyzsh');
}
$ZSH = (defined (defined ${ZSH} && ${ZSH} ne q{} ? ${ZSH} : '$HOME/.oh-my-zsh') && (defined ${ZSH} && ${ZSH} ne q{} ? ${ZSH} : '$HOME/.oh-my-zsh') ne q{} ? (defined ${ZSH} && ${ZSH} ne q{} ? ${ZSH} : '$HOME/.oh-my-zsh') : '$HOME/.oh-my-zsh');
my $REPO;
my @REPO;
my %REPO;
$REPO = (defined ${REPO} && ${REPO} ne q{} ? ${REPO} : 'ohmyzsh/ohmyzsh');
my $REMOTE;
my @REMOTE;
my %REMOTE;
$REMOTE = (defined ${REMOTE} && ${REMOTE} ne q{} ? ${REMOTE} : 'https://github.com/${REPO}.git');
my $BRANCH;
my @BRANCH;
my %BRANCH;
$BRANCH = (defined ${BRANCH} && ${BRANCH} ne q{} ? ${BRANCH} : 'master');
my $CHSH;
my @CHSH;
my %CHSH;
$CHSH = (defined ${CHSH} && ${CHSH} ne q{} ? ${CHSH} : 'yes');
my $RUNZSH;
my @RUNZSH;
my %RUNZSH;
$RUNZSH = (defined ${RUNZSH} && ${RUNZSH} ne q{} ? ${RUNZSH} : 'yes');
my $KEEP_ZSHRC;
my @KEEP_ZSHRC;
my %KEEP_ZSHRC;
$KEEP_ZSHRC = (defined ${KEEP_ZSHRC} && ${KEEP_ZSHRC} ne q{} ? ${KEEP_ZSHRC} : 'no');

sub command_exists {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', "@ARGV") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub user_can_sudo {
        command_exists('sudo');
    if ($CHILD_ERROR != 0) {
        return q{1};    }
if ("$ENV{PREFIX}" =~ /^.*com.termux.*$/msx) {
        return q{1};    }
!(# Original bash: LANG= sudo -n -v 2>&1 | grep -q "may not run sudo"
{
        my $output_7 = q{};
        my $output_printed_7;
        my $pipeline_success_7 = 1;
                $output = q{};
                do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_8 = q{};

my $cmd_11 = 'sudo';
my ($in_10, $out_10);
my $pid_10 = open3($in_10, $out_10, '>&STDERR', $cmd_11, '-n', '-v');
print {$in_10} $output_7;
close $in_10 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
close $out_10 or croak 'Close failed: $OS_ERROR';
waitpid $pid_10, 0;
$tmp_redirect_8;
        };
        $output_7 = $output;

                my $grep_result_7_1;
        my @grep_lines_7_1 = split /\n/msx, $output_7;
        my @grep_filtered_7_1 = grep { /may\ not\ run\ sudo/msx } @grep_lines_7_1;
        $grep_result_7_1 = join "\n", @grep_filtered_7_1;
        if (!($grep_result_7_1 =~ m{\n\z}msx || $grep_result_7_1 eq q{})) {
        $grep_result_7_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_7_1 > 0 ? 0 : 1;
        $grep_result_7_1 = q{};
        $output_7 = q{};
        if ((scalar @grep_filtered_7_1) == 0) {
            $pipeline_success_7 = 0;
        }
        if ($output_7 ne q{} && !defined $output_printed_7) {
            print $output_7;
            if (!($output_7 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        })
    return;
}
if ((-t1)) {

sub is_tty {
1;
        return;
}
}
else {

sub is_tty {
exit 1;
        return;
}
}

sub supports_hyperlinks {
if ("$FORCE_HYPERLINK" ne q{}) {
"$FORCE_HYPERLINK" ne 0
return $?;
    }
        is_tty();
    if ($CHILD_ERROR != 0) {
        return q{1};    }
if ("$DOMTERM" ne q{}) {
return q{0};
    }
if ("$VTE_VERSION" ne q{}) {
($VTE_VERSION >= $MAGIC_5000)
return $?;
    }
if ("$ENV{TERM_PROGRAM}" =~ /^Hyper$/msx or "$ENV{TERM_PROGRAM}" =~ /^iTerm.app$/msx or "$ENV{TERM_PROGRAM}" =~ /^terminology$/msx or "$ENV{TERM_PROGRAM}" =~ /^WezTerm$/msx or "$ENV{TERM_PROGRAM}" =~ /^vscode$/msx) {
        return q{0};    }
if ("$ENV{TERM}" =~ /^xterm-kitty$/msx or "$ENV{TERM}" =~ /^alacritty$/msx or "$ENV{TERM}" =~ /^alacritty-direct$/msx) {
        return q{0};    }
if ("$COLORTERM" eq "xfce4-terminal") {
return q{0};
    }
if ("$WT_SESSION" ne q{}) {
return q{0};
    }
return q{1};
    return;
}

sub supports_truecolor {
if ("$ENV{COLORTERM}" =~ /^truecolor$/msx or "$ENV{COLORTERM}" =~ /^24bit$/msx) {
        return q{0};    }
if ("$ENV{TERM}" =~ /^iterm$/msx or "$ENV{TERM}" =~ /^tmux-truecolor$/msx or "$ENV{TERM}" =~ /^linux-truecolor$/msx or "$ENV{TERM}" =~ /^xterm-truecolor$/msx or "$ENV{TERM}" =~ /^screen-truecolor$/msx) {
        return q{0};    }
return q{1};
    return;
}

sub fmt_link {
    my ($file) = @_;
if (!(    supports_hyperlinks())) {
printf("033]8;;%s033\\%s033]8;;033\\\n", "$_[1]", "$_[0]");
return;
    }
if ("$_[2]" =~ /^--text$/msx) {
        printf("%s\n", "$_[0]");
    } elsif ("$_[2]" =~ /^--url$/msx or 1) {
                $main_exit_code = system('fmt_underline', "$_[1]") >> 8;
    }
    return;
}

sub fmt_underline {
        if (do {
is_tty();
        $CHILD_ERROR == 0
    }) {
        foreach my $item (@ARGV) {
    printf("033[4m%s033[24m\n", $item);
}
    }
    if ($CHILD_ERROR != 0) {
        foreach my $item (@ARGV) {
    printf("%s\n", $item);
}
    }
    return;
}

sub fmt_code {
        if (do {
is_tty();
        $CHILD_ERROR == 0
    }) {
        foreach my $item (@ARGV) {
    printf(chr(96) . "033[2m%s033[22m" . chr(96) . "
", $item);
}
    }
    if ($CHILD_ERROR != 0) {
        foreach my $item (@ARGV) {
    printf(chr(96) . "%s" . chr(96) . "
", $item);
}
    }
    return;
}

sub fmt_error {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%sError: %s%s\n", ($ENV{FMT_BOLD} // q{}) . ($ENV{FMT_RED} // q{}), "@ARGV", "$ENV{FMT_RESET}");
    };
    return;
}

sub setup_color {
if (!(!(is_tty();))) {
        my $FMT_RAINBOW;
        my @FMT_RAINBOW;
        my %FMT_RAINBOW;
        $FMT_RAINBOW = "";
        my $FMT_RED;
        my @FMT_RED;
        my %FMT_RED;
        $FMT_RED = "";
        my $FMT_GREEN;
        my @FMT_GREEN;
        my %FMT_GREEN;
        $FMT_GREEN = "";
        my $FMT_YELLOW;
        my @FMT_YELLOW;
        my %FMT_YELLOW;
        $FMT_YELLOW = "";
        my $FMT_BLUE;
        my @FMT_BLUE;
        my %FMT_BLUE;
        $FMT_BLUE = "";
        my $FMT_BOLD;
        my @FMT_BOLD;
        my %FMT_BOLD;
        $FMT_BOLD = "";
        my $FMT_RESET;
        my @FMT_RESET;
        my %FMT_RESET;
        $FMT_RESET = "";
return;
    }
if (!(    supports_truecolor())) {
        $FMT_RAINBOW = "
      " . (do { my $_chomp_temp = sprintf('033[38;2;255;0;0m');
; chomp $_chomp_temp; $_chomp_temp; }) . "
      " . (do { my $_chomp_temp = sprintf('033[38;2;255;97;0m');
; chomp $_chomp_temp; $_chomp_temp; }) . "
      " . (do { my $_chomp_temp = sprintf('033[38;2;247;255;0m');
; chomp $_chomp_temp; $_chomp_temp; }) . "
      " . (do { my $_chomp_temp = sprintf('033[38;2;0;255;30m');
; chomp $_chomp_temp; $_chomp_temp; }) . "
      " . (do { my $_chomp_temp = sprintf('033[38;2;77;0;255m');
; chomp $_chomp_temp; $_chomp_temp; }) . "
      " . (do { my $_chomp_temp = sprintf('033[38;2;168;0;255m');
; chomp $_chomp_temp; $_chomp_temp; }) . "
      " . (do { my $_chomp_temp = sprintf('033[38;2;245;0;172m');
; chomp $_chomp_temp; $_chomp_temp; }) . "
    ";
}
    else {
        $FMT_RAINBOW = "
      " . (do { my $_chomp_temp = sprintf('033[38;5;196m');
; chomp $_chomp_temp; $_chomp_temp; }) . "
      " . (do { my $_chomp_temp = sprintf('033[38;5;202m');
; chomp $_chomp_temp; $_chomp_temp; }) . "
      " . (do { my $_chomp_temp = sprintf('033[38;5;226m');
; chomp $_chomp_temp; $_chomp_temp; }) . "
      " . (do { my $_chomp_temp = sprintf('033[38;5;082m');
; chomp $_chomp_temp; $_chomp_temp; }) . "
      " . (do { my $_chomp_temp = sprintf('033[38;5;021m');
; chomp $_chomp_temp; $_chomp_temp; }) . "
      " . (do { my $_chomp_temp = sprintf('033[38;5;093m');
; chomp $_chomp_temp; $_chomp_temp; }) . "
      " . (do { my $_chomp_temp = sprintf('033[38;5;163m');
; chomp $_chomp_temp; $_chomp_temp; }) . "
    ";
    }
    $FMT_RED = sprintf('033[31m');
;
    $FMT_GREEN = sprintf('033[32m');
;
    $FMT_YELLOW = sprintf('033[33m');
;
    $FMT_BLUE = sprintf('033[34m');
;
    $FMT_BOLD = sprintf('033[1m');
;
    $FMT_RESET = sprintf('033[0m');
;
    return;
}

sub setup_ohmyzsh {
    $main_exit_code = system('umask', 'g-w,o-w') >> 8;
    do {
    my $__echo_line = ($ENV{FMT_BLUE} // q{}) . "Cloning Oh My Zsh..." . ($ENV{FMT_RESET} // q{});
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
        command_exists('git');
    if ($CHILD_ERROR != 0) {
                    fmt_error("git is not installed");
exit 1;
    }
    my $ostype;
    my @ostype;
    my %ostype;
    $ostype = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; };
if (("${ostype%CYGWIN*}" eq q{} && !({
        my $output_21 = q{};
        my $output_printed_21;
        my $pipeline_success_21 = 1;
                my ($in_22, $out_22);
        my $pid_22 = open3($in_22, $out_22, '>&STDERR', 'git', '--version');
        close $in_22 or croak 'Close failed: $OS_ERROR';
        $output_21 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_22> };
        close $out_22 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_22, 0;

                my $grep_result_21_1;
        my @grep_lines_21_1 = split /\n/msx, $output_21;
        my @grep_filtered_21_1 = grep { /msysgit|windows/msx } @grep_lines_21_1;
        $grep_result_21_1 = join "\n", @grep_filtered_21_1;
        if (!($grep_result_21_1 =~ m{\n\z}msx || $grep_result_21_1 eq q{})) {
        $grep_result_21_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_21_1 > 0 ? 0 : 1;
        $grep_result_21_1 = q{};
        $output_21 = q{};
        if ((scalar @grep_filtered_21_1) == 0) {
            $pipeline_success_21 = 0;
        }
        if ($output_21 ne q{} && !defined $output_printed_21) {
            print $output_21;
            if (!($output_21 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_21 ) { $main_exit_code = 1; }
        }))) {
        fmt_error("Windows/MSYS Git is not supported on Cygwin");
        fmt_error("Make sure the Cygwin git package is installed and is first on the $PATH");
exit 1;
    }
        if (do {
if (do {
if (do {
if (do {
if (do {
if (do {
if (do {
if (do {
if (do {
if (do {
if (do {
$main_exit_code = system('git', 'init', '--quiet', "$ZSH") >> 8;
    $CHILD_ERROR == 0
}) {
        chdir("$ZSH");
    $CHILD_ERROR = 0;
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('git', 'config', 'core.eol', 'lf') >> 8;
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('git', 'config', 'core.autocrlf', 'false') >> 8;
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('git', 'config', 'fsck.zeroPaddedFilemode', 'ignore') >> 8;
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('git', 'config', 'fetch.fsck.zeroPaddedFilemode', 'ignore') >> 8;
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('git', 'config', 'receive.fsck.zeroPaddedFilemode', 'ignore') >> 8;
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('git', 'config', 'oh-my-zsh.remote', 'origin') >> 8;
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('git', 'config', 'oh-my-zsh.branch', "$BRANCH") >> 8;
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('git', 'remote', 'add', 'origin', "$REMOTE") >> 8;
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('git', 'fetch', '--depth=1', 'origin') >> 8;
}
        $CHILD_ERROR == 0
    }) {
                $main_exit_code = system('git', 'checkout', '-b', "$BRANCH", "origin/$BRANCH") >> 8;
    }
    if ($CHILD_ERROR != 0) {
                    if (!((!-d "$ZSH"))) {
                                    chdir(q{-});
                    $CHILD_ERROR = 0;
                    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
if ( -e "$ZSH" ) {
                            if ( -d "$ZSH" ) {
                                my $err;
                                require File::Path;
                                File::Path::remove_tree("$ZSH", {error => \$err});
                                if (@{$err}) {
                                    carp "rm: carping: could not remove ", "$ZSH", ": $err->[0]\n";
                                }
                                else {
                                                                    }
                            }
                            else {
                                if ( unlink "$ZSH" ) {
                                                                    }
                                else {
                                    carp "rm: carping: could not remove ", "$ZSH",
              ": $OS_ERROR\n";
                                }
                            }
                        }
                        else {
                            local $CHILD_ERROR = 0;
                        }
                    };
            }
            fmt_error("git clone of oh-my-zsh repo failed");
exit 1;
    }
    chdir(q{-});
    $CHILD_ERROR = 0;
    print "\n";
    $CHILD_ERROR = 0;
    return;
}

sub setup_zshrc {
    do {
    my $__echo_line = ($ENV{FMT_BLUE} // q{}) . "Looking for an existing zsh config..." . ($ENV{FMT_RESET} // q{});
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    my $OLD_ZSHRC;
    my @OLD_ZSHRC;
    my %OLD_ZSHRC;
    $OLD_ZSHRC = "$zdot/.zshrc.pre-oh-my-zsh";
if (((-f "$zdot/.zshrc") || ( -h "$zdot/.zshrc"))) {
if ("$KEEP_ZSHRC" eq yes) {
            do {
    my $__echo_line = ($ENV{FMT_YELLOW} // q{}) . "Found " . ${zdot} . "/.zshrc." . ($ENV{FMT_RESET} // q{}) . " " . ($ENV{FMT_GREEN} // q{}) . "Keeping..." . ($ENV{FMT_RESET} // q{});
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
if ((-e "$OLD_ZSHRC")) {
            my $OLD_OLD_ZSHRC;
            my @OLD_OLD_ZSHRC;
            my %OLD_OLD_ZSHRC;
            $OLD_OLD_ZSHRC = ${OLD_ZSHRC} . "-" . (do { my $_chomp_temp = do {
require POSIX; POSIX::strftime('%Y-%m-%d_%H-%M-%S', localtime(time())) . "\n"
}; chomp $_chomp_temp; $_chomp_temp; });
if ((-e "$OLD_OLD_ZSHRC")) {
                fmt_error("$OLD_OLD_ZSHRC exists. Can't back up " . ${OLD_ZSHRC});
                fmt_error("re-run the installer again in a couple of seconds");
exit 1;
            }
            my $err;
            my $force = 0;
            if ( -e "$OLD_ZSHRC" ) {
                my $dest = ${OLD_OLD_ZSHRC};
                if ( -e $dest && -d $dest ) {
                    my $source_name = "$OLD_ZSHRC";
                    $source_name =~ s{^.*[\/]}{};
                    $dest = "$dest/$source_name";
                }
                if ( -e $dest && !$force ) {
                    croak "mv: $dest: File exists (use -f to force overwrite)\n";
                }
                my $dest_dir = $dest;
                $dest_dir =~ s/\/[^\/]*$//msx;
                if ( $dest_dir eq $dest ) {
                    $dest_dir = q{};
                }
                if ( $dest_dir ne q{} && !-d $dest_dir ) {
                    my $err;
                    make_path( $dest_dir, { error => \$err } );
                    if ( @{$err} ) {
                        croak "mv: cannot create directory $dest_dir: $err->[0]\n";
                    }
                }
                require File::Copy;
                if ( File::Copy::move( "$OLD_ZSHRC", $dest ) ) {
                } else {
                    croak
  "mv: cannot move "$OLD_ZSHRC" to $dest: $ERRNO\n";
                }
            } else {
                croak "mv: "$OLD_ZSHRC": No such file or directory\n";
            }
            print ($ENV{FMT_YELLOW} // q{}) . "Found old .zshrc.pre-oh-my-zsh." . q{ } . ($ENV{FMT_GREEN} // q{}) . "Backing up to " . ${OLD_OLD_ZSHRC} . ($ENV{FMT_RESET} // q{}) . "\n";
            $CHILD_ERROR = 0;
        }
        do {
    my $__echo_line = ($ENV{FMT_YELLOW} // q{}) . "Found " . ${zdot} . "/.zshrc." . ($ENV{FMT_RESET} // q{}) . " " . ($ENV{FMT_GREEN} // q{}) . "Backing up to " . ${OLD_ZSHRC} . ($ENV{FMT_RESET} // q{});
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        if ( -e "$zdot/.zshrc" ) {
            my $dest = "$OLD_ZSHRC";
            if ( -e $dest && -d $dest ) {
                my $source_name = "$zdot/.zshrc";
                $source_name =~ s{^.*[\/]}{};
                $dest = "$dest/$source_name";
            }
            if ( -e $dest && !$force ) {
                croak "mv: $dest: File exists (use -f to force overwrite)\n";
            }
            my $dest_dir = $dest;
            $dest_dir =~ s/\/[^\/]*$//msx;
            if ( $dest_dir eq $dest ) {
                $dest_dir = q{};
            }
            if ( $dest_dir ne q{} && !-d $dest_dir ) {
                my $err;
                make_path( $dest_dir, { error => \$err } );
                if ( @{$err} ) {
                    croak "mv: cannot create directory $dest_dir: $err->[0]\n";
                }
            }
            require File::Copy;
            if ( File::Copy::move( "$zdot/.zshrc", $dest ) ) {
            } else {
                croak
  "mv: cannot move "$zdot/.zshrc" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "$zdot/.zshrc": No such file or directory\n";
        }
    }
    do {
    my $__echo_line = ($ENV{FMT_GREEN} // q{}) . "Using the Oh My Zsh template file and adding it to $zdot/.zshrc." . ($ENV{FMT_RESET} // q{});
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    my $omz;
    my @omz;
    my %omz;
    $omz = "$ZSH";
if (("$ZDOTDIR" ne q{} && "$ZDOTDIR" ne "$HOME")) {
        $omz = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_25 = q{};
            my $output_printed_25;
            my $pipeline_success_25 = 1;
            $output_25 .= $omz . "\n";
            if ( !($output_25 =~ m{\n\z}msx) ) { $output_25 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_25 = 0; }
            my @sed_lines_25 = split /\n/msx, $output_25;
            my @sed_result_25;
            foreach my $line (@sed_lines_25) {
            chomp $line;
            push @sed_result_25, $line;
            }
            $output_25 = join "\n", @sed_result_25;

            if ( !$pipeline_success_25 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_25 =~ s/\n+\z//msx;
            $output_25;
}; $_pipeline_result; };
    }
    $omz = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_26 = q{};
        my $output_printed_26;
        my $pipeline_success_26 = 1;
        $output_26 .= $omz . "\n";
        if ( !($output_26 =~ m{\n\z}msx) ) { $output_26 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_26 = 0; }
        my @sed_lines_26 = split /\n/msx, $output_26;
        my @sed_result_26;
        foreach my $line (@sed_lines_26) {
        chomp $line;
        push @sed_result_26, $line;
        }
        $output_26 = join "\n", @sed_result_26;

        if ( !$pipeline_success_26 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_26 =~ s/\n+\z//msx;
        $output_26;
}; $_pipeline_result; };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$zdot/.zshrc-omztemp"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
my @sed_lines_27 = split /\n/msx, $;
my @sed_result_27;
foreach my $line (@sed_lines_27) {
chomp $line;
push @sed_result_27, $line;
}
$ = join "\n", @sed_result_27;

        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ( -e "$zdot/.zshrc-omztemp" ) {
        my $dest = "$zdot/.zshrc";
        if ( -e $dest && -d $dest ) {
            my $source_name = "$zdot/.zshrc-omztemp";
            $source_name =~ s{^.*[\/]}{};
            $dest = "$dest/$source_name";
        }
        if ( -e $dest && !$force ) {
            croak "mv: $dest: File exists (use -f to force overwrite)\n";
        }
        my $dest_dir = $dest;
        $dest_dir =~ s/\/[^\/]*$//msx;
        if ( $dest_dir eq $dest ) {
            $dest_dir = q{};
        }
        if ( $dest_dir ne q{} && !-d $dest_dir ) {
            my $err;
            make_path( $dest_dir, { error => \$err } );
            if ( @{$err} ) {
                croak "mv: cannot create directory $dest_dir: $err->[0]\n";
            }
        }
        require File::Copy;
        if ( File::Copy::move( "$zdot/.zshrc-omztemp", $dest ) ) {
        } else {
            croak
  "mv: cannot move "$zdot/.zshrc-omztemp" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "$zdot/.zshrc-omztemp": No such file or directory\n";
    }
    print "\n";
    $CHILD_ERROR = 0;
    return;
}

sub setup_shell {
if ("$CHSH" eq no) {
return;
    }
if ("$(basename -- "$SHELL")" eq "zsh") {
return;
    }
if (!(!(command_exists('chsh');))) {
print "I can't change your shell automatically because this system does not have chsh.
${FMT_BLUE}Please manually change your default shell to zsh${FMT_RESET}
";
return;
    }
    do {
    my $__echo_line = ($ENV{FMT_BLUE} // q{}) . "Time to change your default shell to zsh:" . ($ENV{FMT_RESET} // q{});
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
print do {
    my @__args = ("\\\n", "$ENV{FMT_YELLOW}", "$ENV{FMT_RESET}");
    my $result = '';
    while (@__args) {
        my @__batch = splice(@__args, 0, 2);
        push @__batch, ('') x (2 - scalar @__batch) if @__batch < 2;
        $result .= sprintf '%sDo you want to change your default shell to zsh? [Y/n]%s ', @__batch;
    }
    $result;
};
$opt = <>;
chomp $opt;
$CHILD_ERROR = defined($opt) ? 0 : 1;
if ($opt =~ /^y.*$/msx or $opt =~ /^Y.*$/msx or $opt =~ /^$/msx) {
    } elsif ($opt =~ /^n.*$/msx or $opt =~ /^N.*$/msx) {
                print "Shell change skipped.\n";
        return;    } elsif (1) {
                print "Invalid choice. Shell change skipped.\n";
        return;    }
if ("$ENV{PREFIX}" =~ /^.*com.termux.*$/msx) {
                my $termux;
        my @termux;
        my %termux;
        $termux = 'true';
                my $zsh;
        my @zsh;
        my %zsh;
        $zsh = 'zsh';
    } elsif (1) {
                $termux = 'false';
    }
if ("$termux" ne true) {
if ((-f '/etc/shells')) {
            my $shells_file;
            my @shells_file;
            my %shells_file;
            $shells_file = '/etc/shells';
}
        else {
            if ((-f '/usr/share/defaults/etc/shells')) {
                $shells_file = '/usr/share/defaults/etc/shells';
}
            else {
                fmt_error("could not find /etc/shells file. Change your default shell manually.");
return;
            }
        }
if (!(!($zsh = do {
    my ($in_31, $out_31);
    my $pid_31 = open3($in_31, $out_31, '>&STDERR', 'command', '-v', 'zsh');
    close $in_31 or croak 'Close failed: $OS_ERROR';
    my $result_31 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
    close $out_31 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_31, 0;
    $result_31
};
        if ($CHILD_ERROR != 0) {
            !(my $grep_result_32;
my @grep_lines_32 = ();
my @grep_filtered_32 = grep { /$zsh/msx } @grep_lines_32;
$grep_result_32 = join "\n", @grep_filtered_32;
            if (!($grep_result_32 =~ m{\n\z}msx || $grep_result_32 eq q{})) {
                $grep_result_32 .= "\n";
            }
$CHILD_ERROR = scalar @grep_filtered_32 > 0 ? 0 : 1;
$grep_result_32 = q{};)
        }))) {
if (!(!($zsh = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_33 = q{};
            my $output_printed_33;
            my @tail_lines = ();
            my $output_34 = q{};
            while (my $line = <>) {
                chomp $line;
                                if (!($line =~ /^\/.*\/zsh$/msx)) {
                    next;
                }
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
            $output_34;
            if (@tail_lines > 0) {
                my @last_lines = @tail_lines[-3..-1];
                $output_33 = join "\n", @last_lines;
                if ($output_33 ne q{}) {
                    $output_33 .= "\n";
                }
            } };
}; $_pipeline_result; };
            if ($CHILD_ERROR != 0) {
                (!-f "$zsh")            }))) {
                fmt_error("no zsh binary found or not present in '$shells_file'");
                fmt_error("change your default shell manually.");
return;
            }
        }
    }
if ("$SHELL" ne q{}) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$zdot/.shell.pre-oh-my-zsh"
      or die "Cannot open file: $OS_ERROR\n";
            print $SHELL;
if ( !( ($SHELL) =~ m{\n\z}msx ) ) { print "\n"; }
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
}
    else {
        # Original bash: grep "^$USER:" /etc/passwd | awk -F: '{print $7}' > "$zdot/.shell.pre-oh-my-zsh"
{
            my $output_35 = q{};
            my $output_printed_35;
            my $pipeline_success_35 = 1;
                        my $grep_result_35_0;
            my @grep_lines_35_0 = ();
            my @grep_filenames_35_0 = ();
            if (-e "/etc/passwd") {
            open my $fh, '<', "/etc/passwd" or croak "Cannot open file: $ERRNO";
            while (my $line = <$fh>) {
            chomp $line;
            push @grep_lines_35_0, $line;
            push @grep_filenames_35_0, "/etc/passwd";
            }
            close $fh
            or croak "Close failed: $OS_ERROR";
            }
            else { print {*STDERR} "grep: /etc/passwd: No such file or directory\n"; }
            my @grep_filtered_35_0 = grep { /^$USER:/msx } @grep_lines_35_0;
            $grep_result_35_0 = join "\n", @grep_filtered_35_0;
            if (!($grep_result_35_0 =~ m{\n\z}msx || $grep_result_35_0 eq q{})) {
            $grep_result_35_0 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_35_0 > 0 ? 0 : 1;
            $output_35 = $grep_result_35_0;
            $output_35 = $grep_result_35_0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$zdot/.shell.pre-oh-my-zsh"
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_36 = q{};
            my @lines = split /\n/msx, $output_35;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /:/msx, $line;
            push @result, ($fields[6] . "\n");
            }
            $output_35 = join "", @result;
            $tmp_redirect_36;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_35; }
            $output_printed_35 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_35 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
    }
    do {
    my $__echo_line = "Changing your shell to $zsh...";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if (!(    user_can_sudo())) {
        $main_exit_code = system('sudo', '-k', 'chsh', '-s', "$zsh", "$USER") >> 8;
}
    else {
        $main_exit_code = system('chsh', '-s', "$zsh", "$USER") >> 8;
    }
if (($? != 0)) {
        fmt_error("chsh command unsuccessful. Change your default shell manually.");
}
    else {
$ENV{SHELL} = '';
        do {
    my $__echo_line = ($ENV{FMT_GREEN} // q{}) . "Shell successfully changed to '$zsh'." . ($ENV{FMT_RESET} // q{});
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
    return;
}

sub print_success {
printf("%s         %s__      %s           %s        %s       %s     %s__   %s\n", $FMT_RAINBOW, $FMT_RESET);
printf("%s  ____  %s/ /_    %s ____ ___  %s__  __  %s ____  %s_____%s/ /_  %s\n", $FMT_RAINBOW, $FMT_RESET);
printf("%s / __ \\%s/ __ \\  %s / __ " . chr(96) . "__ \\%s/ / / / %s /_  / %s/ ___/%s __ \\ %s
", $FMT_RAINBOW, $FMT_RESET);
printf("%s/ /_/ /%s / / / %s / / / / / /%s /_/ / %s   / /_%s(__  )%s / / / %s\n", $FMT_RAINBOW, $FMT_RESET);
printf("%s\\____/%s_/ /_/ %s /_/ /_/ /_/%s\\__, / %s   /___/%s____/%s_/ /_/  %s\n", $FMT_RAINBOW, $FMT_RESET);
printf("%s    %s        %s           %s /____/ %s       %s     %s          %s....is now installed!%s\n", $FMT_RAINBOW, $FMT_GREEN, $FMT_RESET);
printf("\n");
printf("\n");
print do {
    my @__args = ("Before you scream " . ($ENV{FMT_BOLD} // q{}) . ($ENV{FMT_YELLOW} // q{}) . "Oh My Zsh!" . ($ENV{FMT_RESET} // q{}) . " look over the", "\\\n", (do { my $_chomp_temp = do {
    my ($in_48, $out_48);
    my $pid_48 = open3($in_48, $out_48, '>&STDERR', 'fmt_code', (do { my $_chomp_temp = do {
    my ($in_47, $out_47);
    my $pid_47 = open3($in_47, $out_47, '>&STDERR', 'fmt_link', ".zshrc", "file://$zdot/.zshrc", '--text');
    close $in_47 or croak 'Close failed: $OS_ERROR';
    my $result_47 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_47> };
    close $out_47 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_47, 0;
    $result_47
}; chomp $_chomp_temp; $_chomp_temp; }));
    close $in_48 or croak 'Close failed: $OS_ERROR';
    my $result_48 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_48> };
    close $out_48 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_48, 0;
    $result_48
}; chomp $_chomp_temp; $_chomp_temp; }), "\\\n", "file to select plugins, themes, and options.");
    my $result = '';
    while (@__args) {
        my @__batch = splice(@__args, 0, 3);
        push @__batch, ('') x (3 - scalar @__batch) if @__batch < 3;
        $result .= sprintf "%s %s %s\n", @__batch;
    }
    $result;
};
printf("\n");
printf("%s\n", "• Follow us on X: " . (do { my $_chomp_temp = do {
    my ($in_51, $out_51);
    my $pid_51 = open3($in_51, $out_51, '>&STDERR', 'fmt_link', '@ohmyzsh', 'https://x.com/ohmyzsh');
    close $in_51 or croak 'Close failed: $OS_ERROR';
    my $result_51 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_51> };
    close $out_51 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_51, 0;
    $result_51
}; chomp $_chomp_temp; $_chomp_temp; }));
printf("%s\n", "• Join our Discord community: " . (do { my $_chomp_temp = do {
    my ($in_53, $out_53);
    my $pid_53 = open3($in_53, $out_53, '>&STDERR', 'fmt_link', "Discord server", 'https://discord.gg/ohmyzsh');
    close $in_53 or croak 'Close failed: $OS_ERROR';
    my $result_53 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_53> };
    close $out_53 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_53, 0;
    $result_53
}; chomp $_chomp_temp; $_chomp_temp; }));
printf("%s\n", "• Get stickers, t-shirts, coffee mugs and more: " . (do { my $_chomp_temp = do {
    my ($in_55, $out_55);
    my $pid_55 = open3($in_55, $out_55, '>&STDERR', 'fmt_link', "Planet Argon Shop", 'https://shop.planetargon.com/collections/oh-my-zsh');
    close $in_55 or croak 'Close failed: $OS_ERROR';
    my $result_55 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_55> };
    close $out_55 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_55, 0;
    $result_55
}; chomp $_chomp_temp; $_chomp_temp; }));
printf("%s\n", $FMT_RESET);
    return;
}

sub main {
if ((!-t0)) {
        $RUNZSH = 'no';
        $CHSH = 'no';
    }
while ( scalar(@ARGV) > 0 ) {
if ($arg1 =~ /^--unattended$/msx) {
                        $RUNZSH = 'no';
                        $CHSH = 'no';
        } elsif ($arg1 =~ /^--skip-chsh$/msx) {
                        $CHSH = 'no';
        } elsif ($arg1 =~ /^--keep-zshrc$/msx) {
                        $KEEP_ZSHRC = 'yes';
        }
# Builtin command 'shift' not implemented
    }
    setup_color();
if (!(!(command_exists('zsh');))) {
        do {
    my $__echo_line = ($ENV{FMT_YELLOW} // q{}) . "Zsh is not installed." . ($ENV{FMT_RESET} // q{}) . " Please install zsh first.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
exit 1;
    }
if ((-d "$ZSH")) {
        do {
    my $__echo_line = ($ENV{FMT_YELLOW} // q{}) . "The $ZSH folder already exists ($ZSH)." . ($ENV{FMT_RESET} // q{});
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
if ("$custom_zsh" eq yes) {
print "
You ran the installer with the \\$ZSH setting or the \\$ZSH variable is
exported. You have 3 options:

1. Unset the ZSH variable when calling the installer:
   $(fmt_code \"ZSH= sh install.sh\")
2. Install Oh My Zsh to a directory that doesn't exist yet:
   $(fmt_code \"ZSH=path/to/new/ohmyzsh/folder sh install.sh\")
3. (Caution) If the folder doesn't contain important information,
   you can just remove it with $(fmt_code \"rm -r $ZSH\")

";
}
        else {
            print "You'll need to remove it if you want to reinstall.\n";
        }
exit 1;
    }
if ("$ZDOTDIR" ne q{}) {
        use File::Path qw(make_path);
        my $err;
        if ( !-d "$ZDOTDIR" ) {
            make_path( "$ZDOTDIR", { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . "$ZDOTDIR" . ": $err->[0]\n";
            }
        }
    }
    setup_ohmyzsh();
    setup_zshrc();
    setup_shell();
    print_success();
if ($RUNZSH eq no) {
        do {
    my $__echo_line = ($ENV{FMT_YELLOW} // q{}) . "Run zsh to try it out." . ($ENV{FMT_RESET} // q{});
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
exit $main_exit_code;
    }
# Builtin command 'exec' not implemented
    return;
}
main("@ARGV");

exit $main_exit_code;
