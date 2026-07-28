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

my $SONAME;
my @SONAME;
my %SONAME;
my $SOFILE;
my @SOFILE;
my %SOFILE;

my $DEB_HOST_GNU_TYPE;
my @DEB_HOST_GNU_TYPE;
my %DEB_HOST_GNU_TYPE;
$DEB_HOST_GNU_TYPE = (defined ${DEB_HOST_GNU_TYPE} && ${DEB_HOST_GNU_TYPE} ne q{} ? ${DEB_HOST_GNU_TYPE} : do { my $_result = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'dpkg-architecture', '-qDEB_HOST_GNU_TYPE');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; $_result; });
my $DEB_HOST_MULTIARCH;
my @DEB_HOST_MULTIARCH;
my %DEB_HOST_MULTIARCH;
$DEB_HOST_MULTIARCH = (defined ${DEB_HOST_MULTIARCH} && ${DEB_HOST_MULTIARCH} ne q{} ? ${DEB_HOST_MULTIARCH} : do { my $_result = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'dpkg-architecture', '-qDEB_HOST_MULTIARCH');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
}; $_result; });
$SOFILE = '/usr/lib/';
$CHILD_ERROR = 0;
my $OBJDUMP;
my @OBJDUMP;
my %OBJDUMP;
$OBJDUMP = $DEB_HOST_GNU_TYPE;
$main_exit_code = system('bash', '-objdump') >> 8;
if ((!-r "$SOFILE")) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "Can't read '$SOFILE', aborting";
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
}
if (!(!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = "$OBJDUMP";
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "Can't run '$OBJDUMP', aborting";
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
}
$SONAME = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_3 = q{};
    my $output_printed_3;
    my $pipeline_success_3 = 1;

    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'unknown_command', '-p');
    close $in_4 or croak 'Close failed: $OS_ERROR';
    $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_3 = 0; }
    my $perl_output_5 = q{};
    for my $line (split /\n/msx, $output_3) {
        $_ = "$line\n";
    if (!defined $ENV{SHELL_VAR}) { $ENV{SHELL_VAR} = q{}; }
    /SONAME\s+libssl\.so\.(.+)/ and print $1;
    }
    $output_3 = $perl_output_5;
    if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
    $output_3 =~ s/\n+\z//msx;
    $output_3;
}; $_pipeline_result; };
if (! "$SONAME" ne q{}) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "Could not parse SONAME from the output of '$OBJDUMP' '$SOFILE', aborting";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
exit 2;
}
print $SONAME;
if ( !( ($SONAME) =~ m{\n\z}msx ) ) { print "\n"; }

exit $main_exit_code;
