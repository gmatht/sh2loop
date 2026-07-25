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

my $ALSACTLRUNTIME;
my @ALSACTLRUNTIME;
my %ALSACTLRUNTIME;

if (!((-x '/usr/sbin/alsactl'))) {
    exit 0;
}
my $PATH;
my @PATH;
my %PATH;
$PATH = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';
my $MYNAME;
my @MYNAME;
my %MYNAME;
$MYNAME = '/etc/init.d/alsa-utils';
my $ALSACTLHOME;
my @ALSACTLHOME;
my %ALSACTLHOME;
$ALSACTLHOME = '/run/alsa';
$ALSACTLRUNTIME = ${ALSACTLHOME} . "/runtime";
if (!((-d "$ALSACTLRUNTIME"))) {
        use File::Path qw(make_path);
    my $err;
    if ( !-d "$ALSACTLRUNTIME" ) {
        make_path( "$ALSACTLRUNTIME", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . "$ALSACTLRUNTIME" . ": $err->[0]\n";
        }
    }
}
$main_exit_code = system('.', '/lib/lsb/init-functions') >> 8;
$main_exit_code = system('.', '/usr/share/alsa/utils.sh') >> 8;

sub log_action_end_msg_and_exit {
    my ($file) = @_;
    $main_exit_code = system('log_action_end_msg', "$_[0]", (defined $_[1] && $_[1] ne q{} ? $_[1] : '"$2"')) >> 8;
    return;
}

sub executable {
        if (!((-x '/bin/which'))) {
        (-x '/usr/bin/which')    }
    if ($CHILD_ERROR != 0) {
        return q{1};    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = "$_[0]";
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}
executable('amixer');
if ($CHILD_ERROR != 0) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print ${MYNAME} . ": Error: No amixer program available.";
if ( !( (${MYNAME} . ": Error: No amixer program available.") =~ m{\n\z}msx ) ) { print "\n"; }
        };
exit 1;
}

sub restore_levels {
    if (!((-f '/var/lib/alsa/asound.state'))) {
        return q{1};    }
    my $CARD;
    my @CARD;
    my %CARD;
    $CARD = "$_[0]";
    if ("$1" eq all) {
                $CARD = "";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if ((!(    my $MSG;
    my @MSG;
    my %MSG;
    $MSG = (do { my $_chomp_temp = do { my @_qx_cmd = ("alsactl -E HOME = \"$ALSACTLHOME\" -E XDG_RUNTIME_DIR = \"${ALSACTLRUNTIME}\" restore Variable(\"CARD\", false, None) 2>&1 > /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; })) && (!"$MSG"))) {
return q{0};
}
    else {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('alsactl', '-E', 'HOME', q{=}, "$ALSACTLHOME", '-E', 'XDG_RUNTIME_DIR', q{=}, ${ALSACTLRUNTIME}, '-F', 'restore', $CARD) >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $main_exit_code = system('log_action_cont_msg', "warning: 'alsactl -E HOME=", $ALSACTLHOME, " -E XDG_RUNTIME_DIR=", $ALSACTLRUNTIME, " restore" . (defined (defined ${CARD} && ${CARD} ne q{} ? ${CARD} : ' $CARD') && (defined ${CARD} && ${CARD} ne q{} ? ${CARD} : ' $CARD') ne q{} ? (defined ${CARD} && ${CARD} ne q{} ? ${CARD} : ' $CARD') : ' $CARD') . "' failed with error message '$MSG'") >> 8;
return q{1};
    }
    return;
}

sub store_levels {
    my $CARD;
    my @CARD;
    my %CARD;
    $CARD = "$_[0]";
    if ("$1" eq all) {
                $CARD = "";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if (!(    my $MSG;
    my @MSG;
    my %MSG;
    $MSG = (do { my $_chomp_temp = do { my @_qx_cmd = ("alsactl -E HOME = \"$ALSACTLHOME\" -E XDG_RUNTIME_DIR = \"${ALSACTLRUNTIME}\" store Variable(\"CARD\", false, None) 2>&1"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; }))) {
require Time::HiRes; Time::HiRes::sleep(q{1});
return q{0};
}
    else {
        $main_exit_code = system('log_action_cont_msg', "warning: 'alsactl store" . (defined (defined ${CARD} && ${CARD} ne q{} ? ${CARD} : ' $CARD') && (defined ${CARD} && ${CARD} ne q{} ? ${CARD} : ' $CARD') ne q{} ? (defined ${CARD} && ${CARD} ne q{} ? ${CARD} : ' $CARD') : ' $CARD') . "' -E HOME=", $ALSACTLHOME, " -E XDG_RUNTIME_DIR=", $ALSACTLRUNTIME, " failed with error message '$MSG'") >> 8;
return q{1};
    }
    return;
}

sub mute_and_zero_levels_on_card {
    my $CARDOPT;
    my @CARDOPT;
    my %CARDOPT;
    $CARDOPT = "-c $_[0]";
    my $CTL;
    for my $CTL ('Master', 'PCM', 'Synth', 'CD', 'Line', 'Mic', "PCM,1", 'Wave', 'Music', 'AC97', "Master Digital", 'DAC', "DAC,0", "DAC,1", 'Headphone', 'Speaker', 'Playback') {
        $main_exit_code = system('mute_and_zero_level', "$CTL") >> 8;
    }
return q{0};
    return;
}

sub mute_and_zero_levels {
    my $TTZML_RETURNSTATUS;
    my @TTZML_RETURNSTATUS;
    my %TTZML_RETURNSTATUS;
    $TTZML_RETURNSTATUS = q{0};
if ("$_[0]" =~ /^all$/msx) {
                my $CARD;
        for my $CARD (do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'echo_card_indices');
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
}) {
                        mute_and_zero_levels_on_card("$CARD");
            if ($CHILD_ERROR != 0) {
                                $TTZML_RETURNSTATUS = q{1};
            }
        }
    } elsif (1) {
                        mute_and_zero_levels_on_card("$_[0]");
        if ($CHILD_ERROR != 0) {
                        $TTZML_RETURNSTATUS = q{1};
        }
    }
return $TTZML_RETURNSTATUS;
    return;
}

sub card_OK {
    if (!(("$1"))) {
                $main_exit_code = system('bash', 'bugout') >> 8;
    }
if ("$1" eq all) {
(-d '/proc/asound')
return $?;
}
    else {
        if (!((-d "/proc/asound/card$1"))) {
            (-d "/proc/asound/$1")        }
return $?;
    }
    return;
}
if ("$_[0]" =~ /^start$/msx) {
        my $EXITSTATUS;
    my @EXITSTATUS;
    my %EXITSTATUS;
    $EXITSTATUS = q{0};
        my $TARGET_CARD;
    my @TARGET_CARD;
    my %TARGET_CARD;
    $TARGET_CARD = "$_[1]";
    if ("$TARGET_CARD" =~ /^$/msx or "$TARGET_CARD" =~ /^all$/msx) {
                $TARGET_CARD = 'all';
                $main_exit_code = system('log_action_begin_msg', "Setting up ALSA") >> 8;
    } elsif (1) {
                $main_exit_code = system('log_action_begin_msg', "Setting up ALSA card " . ${TARGET_CARD}) >> 8;
    }
            card_OK("$TARGET_CARD");
    if ($CHILD_ERROR != 0) {
                log_action_end_msg_and_exit((do { my $_chomp_temp = do {
    my $command = q{: 'Complex command not supported in bash string generation'};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; }), "none loaded");
    }
            $main_exit_code = system('preinit_levels', "$TARGET_CARD") >> 8;
    if ($CHILD_ERROR != 0) {
                $EXITSTATUS = q{1};
    }
    if (!(!(restore_levels("$TARGET_CARD");))) {
                $main_exit_code = system('sanify_levels', "$TARGET_CARD") >> 8;
        if ($CHILD_ERROR != 0) {
                        $EXITSTATUS = q{1};
        }
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            restore_levels("$TARGET_CARD");
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ($CHILD_ERROR != 0) {
                        $main_exit_code = system('bash', ':') >> 8;
        }
    }
        log_action_end_msg_and_exit("$EXITSTATUS");
} elsif ("$_[0]" =~ /^stop$/msx) {
        $EXITSTATUS = q{0};
        $TARGET_CARD = "$_[1]";
    if ("$TARGET_CARD" =~ /^$/msx or "$TARGET_CARD" =~ /^all$/msx) {
                $TARGET_CARD = 'all';
                $main_exit_code = system('log_action_begin_msg', "Shutting down ALSA") >> 8;
    } elsif (1) {
                $main_exit_code = system('log_action_begin_msg', "Shutting down ALSA card " . ${TARGET_CARD}) >> 8;
    }
            card_OK("$TARGET_CARD");
    if ($CHILD_ERROR != 0) {
                log_action_end_msg_and_exit((do { my $_chomp_temp = do {
    my $command = q{: 'Complex command not supported in bash string generation'};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; }), "none loaded");
    }
            store_levels("$TARGET_CARD");
    if ($CHILD_ERROR != 0) {
                $EXITSTATUS = q{1};
    }
        log_action_end_msg_and_exit("$EXITSTATUS");
} elsif ("$_[0]" =~ /^restart$/msx or "$_[0]" =~ /^force-reload$/msx) {
        $EXITSTATUS = q{0};
            $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) {
                $EXITSTATUS = q{1};
    }
            $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) {
                $EXITSTATUS = q{1};
    }
    } elsif ("$_[0]" =~ /^reset$/msx) {
        $TARGET_CARD = "$_[1]";
    if ("$TARGET_CARD" =~ /^$/msx or "$TARGET_CARD" =~ /^all$/msx) {
                $TARGET_CARD = 'all';
                $main_exit_code = system('log_action_begin_msg', "Resetting ALSA") >> 8;
    } elsif (1) {
                $main_exit_code = system('log_action_begin_msg', "Resetting ALSA card " . ${TARGET_CARD}) >> 8;
    }
            card_OK("$TARGET_CARD");
    if ($CHILD_ERROR != 0) {
                log_action_end_msg_and_exit((do { my $_chomp_temp = do {
    my $command = q{: 'Complex command not supported in bash string generation'};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; }), "none loaded");
    }
        $main_exit_code = system('preinit_levels', "$TARGET_CARD") >> 8;
        $main_exit_code = system('sanify_levels', "$TARGET_CARD") >> 8;
        log_action_end_msg_and_exit("${\($? >> 8)}");
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "Usage: $MYNAME {start [CARD]|stop [CARD]|restart [CARD]|reset [CARD]}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    exit 3;
}

exit $main_exit_code;
