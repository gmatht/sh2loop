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

my $CHECKDIR;
my @CHECKDIR;
my %CHECKDIR;
my $RES;
my @RES;
my %RES;
my $OLDLS;
my @OLDLS;
my %OLDLS;
my $ARCHIVES;
my @ARCHIVES;
my %ARCHIVES;
my $WAIT;
my @WAIT;
my %WAIT;
my $NEWLS;
my @NEWLS;
my %NEWLS;

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
my $DSELECT_UPGRADE_OPTS;
my @DSELECT_UPGRADE_OPTS;
my %DSELECT_UPGRADE_OPTS;
$DSELECT_UPGRADE_OPTS = "-f";
my $APTGET;
my @APTGET;
my %APTGET;
$APTGET = "/usr/bin/apt-get";
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
$__set_e = 1;
$RES = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'apt-config', 'shell', 'CLEAN', 'DSelect::Clean', 'OPTS', 'DSelect::Options', 'DPKG', 'Dir::Bin::dpkg/f', 'APTGET', 'Dir::Bin::apt-get/f', 'ARCHIVES', 'Dir::Cache::Archives/d', 'WAIT', 'DSelect::WaitAfterDownload/b', 'CHECKDIR', 'DSelect::CheckDir/b');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
do { my $eval_input = $RES; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
# set +e not implemented

sub yesno {
    my $ans;
    my $def;
    my $defp;
if (("$2")) {
if ($arg2 =~ /^Y$/msx or $arg2 =~ /^y$/msx) {
                            $def = q{y};
                $defp = "[Y/n]";
        } elsif ($arg2 =~ /^N$/msx or $arg2 =~ /^n$/msx) {
                            $def = q{n};
                $defp = "[y/N]";
        } elsif (1) {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "$\"Bad default setting!\"";
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
}
    else {
            $def = q{n};
            $defp = "[y/N]";
    }
while (     $main_exit_code = system('bash', ':') >> 8 ) {
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            print "$_[0] $defp ";
        };
$ans = <>;
chomp $ans;
$CHILD_ERROR = defined($ans) ? 0 : 1;
if ($ans =~ /^Y$/msx or $ans =~ /^y$/msx or $ans =~ /^N$/msx or $ans =~ /^n$/msx) {
            last;        } elsif ($ans =~ /^$/msx) {
                        $ans = $def;
            last;        }
        print "\n";
        $CHILD_ERROR = 0;
    }
    # Original bash: echo $ans | tr YN yn
{
        my $output_2 = q{};
        my $output_printed_2;
        my $pipeline_success_2 = 1;
        $output_2 .= $ans . "\n";
if ( !($output_2 =~ m{\n\z}msx) ) { $output_2 .= "\n"; }
$CHILD_ERROR = 0;

                my $set1_3 = 'YN';
        my $set2_3 = 'yn';
        my $input_3 = $output_2;
        # Expand character ranges for tr command
        my $expanded_set1_3 = $set1_3;
        my $expanded_set2_3 = $set2_3;
        # Handle a-z range in set1
        if ($expanded_set1_3 =~ /a-z/msx) {
        $expanded_set1_3 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_3 =~ /A-Z/msx) {
        $expanded_set1_3 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_3 =~ /\[:upper:\]/msx) {
        $expanded_set1_3 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_3 =~ /\[:lower:\]/msx) {
        $expanded_set1_3 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_3 =~ /a-z/msx) {
        $expanded_set2_3 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_3 =~ /A-Z/msx) {
        $expanded_set2_3 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_3 =~ /\[:upper:\]/msx) {
        $expanded_set2_3 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_3 =~ /\[:lower:\]/msx) {
        $expanded_set2_3 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_2_1 = q{};
        for my $char ( split //msx, $input_3 ) {
        my $pos_3 = index $expanded_set1_3, $char;
        if ( $pos_3 >= 0 && $pos_3 < length $expanded_set2_3 ) {
        $tr_result_2_1 .= substr $expanded_set2_3, $pos_3, 1;
        } else {
        $tr_result_2_1 .= $char;
        }
        }
        if (!($tr_result_2_1 =~ m{\n\z}msx || $tr_result_2_1 eq q{})) {
        $tr_result_2_1 .= "\n";
        }
        $output_2 = $tr_result_2_1;
        $output_2 = $tr_result_2_1;
        if ($output_2 ne q{} && !defined $output_printed_2) {
            print $output_2;
            if (!($output_2 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
    return;
}
if ("$WAIT" eq "true") {
    $CHILD_ERROR = 0;
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
    $CHILD_ERROR = 0;
    $RES = $?;
}
else {
    $CHILD_ERROR = 0;
    $RES = $?;
}
if (($RES == 1)) {
exit 0;
}
if (($RES == 0)) {
if ((qx'ls $ARCHIVES $ARCHIVES/partial | grep -E -v "^lock$|^partial$" | wc -l' == 0)) {
exit 0;
    }
    $NEWLS = do { my @_qx_cmd = ('ls -ld $ARCHIVES'); my $result = qx{$_qx_cmd[0]}; $CHILD_ERROR = $? >> 8; $result; };
if ("$CHECKDIR" eq "true") {
if ("$OLDLS" eq "$NEWLS") {
exit 0;
        }
    }
if (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ($CLEAN) . "\n";
    my $set1_6 = '[:upper:]';
my $set2_6 = '[:lower:]';
my $input_6 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_6 = $set1_6;
my $expanded_set2_6 = $set2_6;
# Handle a-z range in set1
if ($expanded_set1_6 =~ /a-z/msx) {
    $expanded_set1_6 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_6 =~ /A-Z/msx) {
    $expanded_set1_6 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_6 =~ /\[:upper:\]/msx) {
    $expanded_set1_6 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_6 =~ /\[:lower:\]/msx) {
    $expanded_set1_6 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_6 =~ /a-z/msx) {
    $expanded_set2_6 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_6 =~ /A-Z/msx) {
    $expanded_set2_6 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_6 =~ /\[:upper:\]/msx) {
    $expanded_set2_6 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_6 =~ /\[:lower:\]/msx) {
    $expanded_set2_6 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_5 = q{};
for my $char ( split //msx, $input_6 ) {
    my $pos_6 = index $expanded_set1_6, $char;
    if ( $pos_6 >= 0 && $pos_6 < length $expanded_set2_6 ) {
        $tr_result_5 .= substr $expanded_set2_6, $pos_6, 1;
    } else {
        $tr_result_5 .= $char;
    }
}
$tr_result_5
}; $_pipeline_result; } =~ /^auto$/msx) {
                if (do {
if (do {
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
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
}
    $CHILD_ERROR == 0
}) {
    $RES = <>;
chomp $RES;
$CHILD_ERROR = defined($RES) ? 0 : 1;
}
            $CHILD_ERROR == 0
        }) {
            exit 0;
        }
    } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ($CLEAN) . "\n";
    my $set1_9 = '[:upper:]';
my $set2_9 = '[:lower:]';
my $input_9 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_9 = $set1_9;
my $expanded_set2_9 = $set2_9;
# Handle a-z range in set1
if ($expanded_set1_9 =~ /a-z/msx) {
    $expanded_set1_9 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_9 =~ /A-Z/msx) {
    $expanded_set1_9 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_9 =~ /\[:upper:\]/msx) {
    $expanded_set1_9 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_9 =~ /\[:lower:\]/msx) {
    $expanded_set1_9 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_9 =~ /a-z/msx) {
    $expanded_set2_9 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_9 =~ /A-Z/msx) {
    $expanded_set2_9 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_9 =~ /\[:upper:\]/msx) {
    $expanded_set2_9 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_9 =~ /\[:lower:\]/msx) {
    $expanded_set2_9 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_8 = q{};
for my $char ( split //msx, $input_9 ) {
    my $pos_9 = index $expanded_set1_9, $char;
    if ( $pos_9 >= 0 && $pos_9 < length $expanded_set2_9 ) {
        $tr_result_8 .= substr $expanded_set2_9, $pos_9, 1;
    } else {
        $tr_result_8 .= $char;
    }
}
$tr_result_8
}; $_pipeline_result; } =~ /^always$/msx) {
                if (do {
if (do {
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
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
}
    $CHILD_ERROR == 0
}) {
    $RES = <>;
chomp $RES;
$CHILD_ERROR = defined($RES) ? 0 : 1;
}
            $CHILD_ERROR == 0
        }) {
            exit 0;
        }
    } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ($CLEAN) . "\n";
    my $set1_12 = '[:upper:]';
my $set2_12 = '[:lower:]';
my $input_12 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_12 = $set1_12;
my $expanded_set2_12 = $set2_12;
# Handle a-z range in set1
if ($expanded_set1_12 =~ /a-z/msx) {
    $expanded_set1_12 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_12 =~ /A-Z/msx) {
    $expanded_set1_12 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_12 =~ /\[:upper:\]/msx) {
    $expanded_set1_12 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_12 =~ /\[:lower:\]/msx) {
    $expanded_set1_12 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_12 =~ /a-z/msx) {
    $expanded_set2_12 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_12 =~ /A-Z/msx) {
    $expanded_set2_12 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_12 =~ /\[:upper:\]/msx) {
    $expanded_set2_12 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_12 =~ /\[:lower:\]/msx) {
    $expanded_set2_12 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_11 = q{};
for my $char ( split //msx, $input_12 ) {
    my $pos_12 = index $expanded_set1_12, $char;
    if ( $pos_12 >= 0 && $pos_12 < length $expanded_set2_12 ) {
        $tr_result_11 .= substr $expanded_set2_12, $pos_12, 1;
    } else {
        $tr_result_11 .= $char;
    }
}
$tr_result_11
}; $_pipeline_result; } =~ /^prompt$/msx) {
                do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
        };
                print "$\"Do you want to erase any previously downloaded .deb files?\"";
        if ($(yesno "" y) eq y) {
            if (do {
if (do {
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
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
}
    $CHILD_ERROR == 0
}) {
    $RES = <>;
chomp $RES;
$CHILD_ERROR = defined($RES) ? 0 : 1;
}
                $CHILD_ERROR == 0
            }) {
                exit 0;
            }
        }
    } elsif (1) {
    }
}
else {
    do {
    my $__echo_line = "$\"Some errors occurred while unpacking. Packages that were installed\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"will be configured. This may result in duplicate errors\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"or errors caused by missing dependencies. This is OK, only the errors\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"above this message are important. Please fix them and run [I]nstall again\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
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
    if (do {
$RES = <>;
chomp $RES;
$CHILD_ERROR = defined($RES) ? 0 : 1;
        $CHILD_ERROR == 0
    }) {
                $CHILD_ERROR = 0;
    }
exit 100;
}


exit $main_exit_code;
