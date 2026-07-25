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

my $PROMPT;
my @PROMPT;
my %PROMPT;

$__set_e = 1;
my $TEXTDOMAIN;
my @TEXTDOMAIN;
my %TEXTDOMAIN;
$TEXTDOMAIN = "apt";
my $CLEAN;
my @CLEAN;
my %CLEAN;
$CLEAN = "prompt";
my $OPTS;
my @OPTS;
my %OPTS;
$OPTS = "";
my $APTGET;
my @APTGET;
my %APTGET;
$APTGET = "/usr/bin/apt-get";
my $APTCACHE;
my @APTCACHE;
my %APTCACHE;
$APTCACHE = "/usr/bin/apt-cache";
my $DPKG;
my @DPKG;
my %DPKG;
$DPKG = "/usr/bin/dpkg";
my $DPKG_OPTS;
my @DPKG_OPTS;
my %DPKG_OPTS;
$DPKG_OPTS = "--admindir=$_[0]";
my $APT_OPT0;
my @APT_OPT0;
my %APT_OPT0;
$APT_OPT0 = "-oDir::State::status=$_[0]/status";
my $APT_OPT1;
my @APT_OPT1;
my %APT_OPT1;
$APT_OPT1 = "-oDPkg::Options::=$DPKG_OPTS";
my $CACHEDIR;
my @CACHEDIR;
my %CACHEDIR;
$CACHEDIR = "/var/cache/apt";
$PROMPT = "false";
my $RES;
my @RES;
my %RES;
$RES = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'apt-config', 'shell', 'CLEAN', 'DSelect::Clean', 'OPTS', 'DSelect::UpdateOptions', 'DPKG', 'Dir::Bin::dpkg/f', 'APTGET', 'Dir::Bin::apt-get/f', 'APTCACHE', 'Dir::Bin::apt-cache/f', 'CACHEDIR', 'Dir::Cache/d', 'PROMPT', 'DSelect::PromptAfterUpdate/b');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
do { my $eval_input = $RES; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
$CACHEDIR = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_1 = q{};
    my $output_printed_1;
    my $pipeline_success_1 = 1;
    $output_1 .= $CACHEDIR . "\n";
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
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_1 =~ s/\n+\z//msx;
    $output_1;
}; $_pipeline_result; };
my $STATUS;
my @STATUS;
my %STATUS;
$STATUS = q{1};
if (!($CHILD_ERROR = 0)) {
    do {
    my $__echo_line = "$\"Merging available information\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if ( -e "$CACHEDIR" ) {
        if ( -d "$CACHEDIR" ) {
            carp "rm: carping: ", $CACHEDIR,
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$CACHEDIR" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $CACHEDIR,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/available" ) {
        if ( -d "/available" ) {
            carp "rm: carping: ", "/available",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/available" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/available",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', $CACHEDIR
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $CHILD_ERROR = 0;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('bash', '/available') >> 8;
    $CHILD_ERROR = 0;
if ( -e "$CACHEDIR" ) {
        if ( -d "$CACHEDIR" ) {
            carp "rm: carping: ", $CACHEDIR,
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$CACHEDIR" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $CACHEDIR,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/available" ) {
        if ( -d "/available" ) {
            carp "rm: carping: ", "/available",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/available" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/available",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ("$CLEAN" =~ /^Pre-Auto$/msx or "$CLEAN" =~ /^PreAuto$/msx or "$CLEAN" =~ /^pre-auto$/msx) {
                $CHILD_ERROR = 0;
    }
    $STATUS = q{0};
}
if (x$PROMPT eq "xtrue") {
    if (do {
do {
    my $__echo_line = "$\"Press [Enter] to continue.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
        $CHILD_ERROR == 0
    }) {
        $RES = <>;
chomp $RES;
$CHILD_ERROR = defined($RES) ? 0 : 1;
    }
}


exit $main_exit_code;
