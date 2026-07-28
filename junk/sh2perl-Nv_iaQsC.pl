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

my $SSH_AUTH_SOCK;
my @SSH_AUTH_SOCK;
my %SSH_AUTH_SOCK;

my $MAGIC_20000 = 20_000;

my $ID;
my @ID;
my %ID;
$ID = 'username';
my $HOST;
my @HOST;
my %HOST;
$HOST = 'hostname.your.net';
if ("X$SSH_AUTH_SOCK" eq "X") {
do { my $eval_input = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'ssh-agent', '-s');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    $main_exit_code = system('ssh-add', $HOME, '/.ssh/id_rsa') >> 8;
}
$ENV{AUTOSSH_POLL} = $AUTOSSH_POLL;
$ENV{AUTOSSH_LOGFILE} = $AUTOSSH_LOGFILE;
$ENV{AUTOSSH_DEBUG} = $AUTOSSH_DEBUG;
$ENV{AUTOSSH_PATH} = $AUTOSSH_PATH;
$ENV{AUTOSSH_GATETIME} = $AUTOSSH_GATETIME;
$ENV{AUTOSSH_PORT} = $AUTOSSH_PORT;
$main_exit_code = system('autossh', '-2', '-f', q{N}, '-M', '20000', '-R', '2200:localhost:22', $ID, q{@}, $HOST) >> 8;

exit $main_exit_code;
