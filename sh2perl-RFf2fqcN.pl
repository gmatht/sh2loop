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

if (do {
if (do {
$main_exit_code = system('test', "X-h", q{=}, "X$_[0]") >> 8;
    $CHILD_ERROR == 0
}) {
        do {
    my $__echo_line = "Usage: $PROGRAM_NAME [tablenr [raw ip args...]]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
}
    $CHILD_ERROR == 0
}) {
    exit 64;
}
if (do {
$main_exit_code = system('test', '-z', "@ARGV") >> 8;
    $CHILD_ERROR == 0
}) {
    # set 0 not implemented
}
{
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
        my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'ip', 'route', 'list', 'table');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;

        my @lines = split /\n/msx, $output_0;
    my $result_0_1 = q{};
    for my $line (@lines) {
    chomp $line;
    my $L = $line;
    # set xx not implemented
    # Builtin command 'shift' not implemented
    my $proto;
    my @proto;
    my %proto;
    $proto = "";
    my $via;
    my @via;
    my %via;
    $via = "";
    my $dev;
    my @dev;
    my %dev;
    $dev = "";
    my $scope;
    my @scope;
    my %scope;
    $scope = "";
    my $src;
    my @src;
    my %src;
    $src = "";
    my $table;
    my @table;
    my %table;
    $table = "";
    if ($network =~ /^broadcast$/msx or $network =~ /^local$/msx or $network =~ /^unreachable$/msx) {
    $via = $network;
    my $network;
    my @network;
    my %network;
    $network = $1;
    # Builtin command 'shift' not implemented
    }
    my $# = 0;
    while ( (!Variable("#", false, None) eq 0) ) {
    if ("$_[0]" =~ /^proto$/msx or "$_[0]" =~ /^via$/msx or "$_[0]" =~ /^dev$/msx or "$_[0]" =~ /^scope$/msx or "$_[0]" =~ /^src$/msx or "$_[0]" =~ /^table$/msx) {
    my $key;
    my @key;
    my %key;
    $key = $1;
    my $val;
    my @val;
    my %val;
    $val = $2;
    do { my $eval_input = $key . "='" . $val . "'"; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^dead$/msx or "$_[0]" =~ /^onlink$/msx or "$_[0]" =~ /^pervasive$/msx or "$_[0]" =~ /^offload$/msx or "$_[0]" =~ /^notify$/msx or "$_[0]" =~ /^linkdown$/msx or "$_[0]" =~ /^unresolved$/msx) {
    # Builtin command 'shift' not implemented
    } elsif (1) {
    # Builtin command 'shift' not implemented
    # Builtin command 'shift' not implemented
    }
    }
    do {
    my $__echo_line = "$network	$via	$src	$proto	$scope	$dev	$table";
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
    $__echo_line .= "\n";
    }
    $output .= $__echo_line;
    };
    $CHILD_ERROR = 0;
    }
    $output_0 = $result_0_1;

        my @lines = split /\n/msx, $output_0;
    my @result;
    foreach my $line (@lines) {
    chomp $line;
    if ($line =~ /^\s*$/msx) { next; }
    my @fields = split /\t/msx, $line;
    if (!(BEGIN)) { next; }
    push @result, (f(format . 'target' . q{} . 'gateway' . 'source' . 'proto' . 'scope' . 'dev' . "tbl");
    }
    { network=$fields[0];
    mask="";
    if(match(network . "/"))
    { mask=" "substr(network . RSTART+1);
    network=substr(network . 0 . RSTART);
    }
    via=$fields[1];
    src=$fields[2];
    proto=$fields[3];
    scope=$fields[4];
    dev=$fields[5];
    table=$fields[6];
    printf(format . network . mask . via . src . proto . scope . dev . table) . "\n");
    }
    $output_0 = join "", @result;
    if ($output_0 ne q{} && !defined $output_printed_0) {
        print $output_0;
        if (!($output_0 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    }

exit $main_exit_code;
