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

my $CRYPTTAB_TRIED;
my @CRYPTTAB_TRIED;
my %CRYPTTAB_TRIED;
my $CRYPTTAB_KEY;
my @CRYPTTAB_KEY;
my %CRYPTTAB_KEY;
my $KID_;
my @KID_;
my %KID_;


sub die {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
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
    };
exit 1;
    return;
}
if (("${CRYPTTAB_KEY:-}" eq q{} || "$CRYPTTAB_KEY" eq "none")) {
    my $ID_;
    my @ID_;
    my %ID_;
    $ID_ = "cryptsetup";
}
else {
    $ID_ = "cryptsetup:$CRYPTTAB_KEY";
}
my $TIMEOUT_;
my @TIMEOUT_;
my %TIMEOUT_;
$TIMEOUT_ = '60';
my $ASKPASS_;
my @ASKPASS_;
my %ASKPASS_;
$ASKPASS_ = '/lib/cryptsetup/askpass';
my $PROMPT_;
my @PROMPT_;
my %PROMPT_;
$PROMPT_ = "Caching passphrase for " . ($ENV{CRYPTTAB_NAME} // q{}) . ": ";
if (!(!($KID_ = (do { my $_chomp_temp = do { my @_qx_cmd = ("keyctl search @u user \"$ID_\" 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; });
if ($CHILD_ERROR != 0) {
    "$KID_" eq q{}}
if ($CHILD_ERROR != 0) {
    ($CRYPTTAB_TRIED > 0)}))) {
        my $KEY_;
    my @KEY_;
    my %KEY_;
    $KEY_ = (do { my $_chomp_temp = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', $ASKPASS_, "$PROMPT_");
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; chomp $_chomp_temp; $_chomp_temp; });
    if ($CHILD_ERROR != 0) {
                die("Error executing $ASKPASS_");
    }
if ("$KID_" ne q{}) {
        $main_exit_code = system('keyctl', 'unlink', "$KID_", '@u') >> 8;
        $KID_ = "";
    }
    $KID_ = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
        my $output_1;
        {
            local *STDOUT;
            open STDOUT, '>', \$output_1 or die "Cannot redirect STDOUT";
            printf('%s', "$KEY_");
        }
        if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }

        my $cmd_3 = 'keyctl';
        my ($in_2, $out_2);
        my $pid_2 = open3($in_2, $out_2, '>&STDERR', $cmd_3, 'padd', 'user', '@u');
        print {$in_2} $output_1;
        close $in_2 or croak 'Close failed: $OS_ERROR';
        $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
        close $out_2 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_2, 0;
        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        $output_1 =~ s/\n+\z//msx;
        $output_1;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
    if (!("$KID_" ne q{})) {
                die("Error adding passphrase to kernel keyring");
    }
if (!(!($main_exit_code = system('keyctl', 'timeout', "$KID_", "$TIMEOUT_") >> 8;))) {
        $main_exit_code = system('keyctl', 'unlink', "$KID_", '@u') >> 8;
        die("Error setting timeout on key ($KID_), removing");
    }
}
else {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "Using cached passphrase for " . ($ENV{CRYPTTAB_NAME} // q{}) . ".";
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
$main_exit_code = system('keyctl', 'pipe', "$KID_") >> 8;

exit $main_exit_code;
