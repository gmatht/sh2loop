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

my $SRCHS;
my @SRCHS;
my %SRCHS;
my $part1;
my @part1;
my %part1;
my $script_type;
my @script_type;
my %script_type;
my $part2;
my @part2;
my %part2;
my $dev;
my @dev;
my %dev;

if ((!-x /sbin/resolvconf)) {
    $main_exit_code = system('logger', "[OpenVPN:update-resolve-conf] missing binary /sbin/resolvconf") >> 8;
exit 0;
}
if (!(("$script_type"))) {
    exit 0;
}
if (!(("$dev"))) {
    exit 0;
}

sub split_into_parts {
    $part1 = "$_[0]";
    $part2 = "$_[1]";
    my $part3;
    my @part3;
    my %part3;
    $part3 = "$_[2]";
    return;
}
if ("$script_type" =~ /^up$/msx) {
        my $NMSRVRS;
    my @NMSRVRS;
    my %NMSRVRS;
    $NMSRVRS = "";
        $SRCHS = "";
        my $foreign_options;
    my @foreign_options;
    my %foreign_options;
    $foreign_options = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
        my $output_0;
        {
            local *STDOUT;
            open STDOUT, '>', \$output_0 or die "Cannot redirect STDOUT";
            printf("%s\n", q{});
        }
        if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
        my @sort_lines_0_1 = split /\n/msx, $output_0;
        my @sort_sorted_0_1 = sort {
            my @a_fields = split /_/msx, $a;
            my @b_fields = split /_/msx, $b;
            my $a_key = (scalar @a_fields > 2) ? $a_fields[2] : q{};
            my $b_key = (scalar @b_fields > 2) ? $b_fields[2] : q{};
            $a_key cmp $b_key || $a cmp $b
        } @sort_lines_0_1;
        $output_0 = join "\n", @sort_sorted_0_1;
                if ($output_0 ne q{} && !($output_0 =~ m{\n\z}msx)) {
                    $output_0 .= "\n";
                }
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        $output_0 =~ s/\n+\z//msx;
        $output_0;
}; $_pipeline_result; };
        my $optionvarname;
    for my $optionvarname ($foreign_options) {
        my $option;
        my @option;
        my %option;
        $option = ($ENV{!optionvarname} // q{});
        print $option;
if ( !( ($option) =~ m{\n\z}msx ) ) { print "\n"; }
        split_into_parts($option);
if ("$part1" eq "dhcp-option") {
if ("$part2" eq "DNS") {
                $NMSRVRS = (defined (defined ${NMSRVRS} && ${NMSRVRS} ne q{} ? ${NMSRVRS} : '$NMSRVRS ') && (defined ${NMSRVRS} && ${NMSRVRS} ne q{} ? ${NMSRVRS} : '$NMSRVRS ') ne q{} ? (defined ${NMSRVRS} && ${NMSRVRS} ne q{} ? ${NMSRVRS} : '$NMSRVRS ') : '$NMSRVRS ') . "$ENV{part3}";
}
            else {
                if ("$part2" eq "DOMAIN") {
                    $SRCHS = (defined (defined ${SRCHS} && ${SRCHS} ne q{} ? ${SRCHS} : '$SRCHS ') && (defined ${SRCHS} && ${SRCHS} ne q{} ? ${SRCHS} : '$SRCHS ') ne q{} ? (defined ${SRCHS} && ${SRCHS} ne q{} ? ${SRCHS} : '$SRCHS ') : '$SRCHS ') . "$ENV{part3}";
                }
            }
        }
    }
        my $R;
    my @R;
    my %R;
    $R = "";
        if (("$SRCHS")) {
                $R = "search $SRCHS
";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
        my $NS;
    for my $NS ($NMSRVRS) {
        $R = ${R} . "nameserver $NS
";
    }
        # Original bash: echo -n "$R" | /sbin/resolvconf -a "${dev}.openvpn"
{
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
        $output_1 .= $R . "\n";
$CHILD_ERROR = 0;

                my $cmd_3 = '/sbin/resolvconf';
        my ($in_2, $out_2);
        my $pid_2 = open3($in_2, $out_2, '>&STDERR', $cmd_3, '-a');
        print {$in_2} $output_1;
        close $in_2 or croak 'Close failed: $OS_ERROR';
        $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
        close $out_2 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_2, 0;
        if ($output_1 ne q{} && !defined $output_printed_1) {
            print $output_1;
            if (!($output_1 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        }
} elsif ("$script_type" =~ /^down$/msx) {
        $main_exit_code = system('/sbin/resolvconf', '-d', ${dev} . ".openvpn") >> 8;
}

exit $main_exit_code;
