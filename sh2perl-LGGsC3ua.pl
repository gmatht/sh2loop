#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $which;

if ((!-e /etc/pcmcia/shared)) {
exit 1;
}

sub pcmcia_shared {
    $main_exit_code = system('.', '/etc/pcmcia/shared') >> 8;
    return;
}
my $iface = "$_[0]";
pcmcia_shared("start", $iface);

sub usage {
exit 1;
    return;
}
$main_exit_code = system('get_info', $iface) >> 8;
my $HWADDR = do {
    do { do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;

    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', '/sbin/ifconfig', );
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
    my @sed_lines_0 = split /\n/, $output_0;
    my @sed_result_0;
    foreach my $line (@sed_lines_0) {
    chomp $line;
    push @sed_result_0, $line;
    }
    $output_0 = join "\n", @sed_result_0;

    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    $output_0 =~ s/\n+\z//msx;
    $output_0;
}; };
};
$which = "";
my $glob;
my $scheme;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $glob = $_fields[0] // q{};
    $scheme = $_fields[1] // q{};
if (("$which")) {
next;
    }
if ("$ENV{SCHEME},$ENV{SOCKET},$ENV{INSTANCE},$HWADDR" =~ /^$glob$/msx) {
                $which = $scheme;
    }
}
if (("$which")) {
    say $which;
exit 0;
}
exit 1;
