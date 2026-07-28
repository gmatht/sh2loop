#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

my $main_exit_code = 0;
my $output         = q{};
our $CHILD_ERROR;

my $UKI_DIR;
my $TRIES_FILE;
my $KERNEL_INSTALL_VERBOSE;
my $KERNEL_INSTALL_LAYOUT;
my $KERNEL_IMAGE;
my $KERNEL_INSTALL_STAGING_AREA;

$__set_e = 1;
my $COMMAND = (defined $_[0] && $_[0] ne q{} ? $_[0] : die(''));
my $KERNEL_VERSION = (defined $_[1] && $_[1] ne q{} ? $_[1] : die(''));
my $ENTRY_DIR_ABS = "$_[2]";
$KERNEL_IMAGE = "$_[3]";
if (!("$KERNEL_INSTALL_LAYOUT" eq "uki")) {
    exit 0;
}
my $ENTRY_TOKEN = "$ENV{KERNEL_INSTALL_ENTRY_TOKEN}";
my $BOOT_ROOT = "$ENV{KERNEL_INSTALL_BOOT_ROOT}";
$UKI_DIR = "$BOOT_ROOT/EFI/Linux";
if ("$COMMAND" =~ /^remove$/msx) {
        if (($KERNEL_INSTALL_VERBOSE > 0)) {
                say "Removing $UKI_DIR/$ENTRY_TOKEN-$KERNEL_VERSION*.efi";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    # Builtin command 'exec' not implemented
} elsif ("$COMMAND" =~ /^add$/msx) {
} elsif (1) {
    exit 0;
}
if ((-d "$UKI_DIR")) {
    if (($KERNEL_INSTALL_VERBOSE > 0)) {
                say "creating $UKI_DIR";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    use File::Path qw(make_path);
    my $err;
    if ( !-d "$UKI_DIR" ) {
        make_path( "$UKI_DIR", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . "$UKI_DIR" . ": $err->[0]\n";
        }
    }
;
}
$TRIES_FILE = (defined (defined ($ENV{KERNEL_INSTALL_CONF_ROOT} // q{}) && ($ENV{KERNEL_INSTALL_CONF_ROOT} // q{}) ne q{} ? ($ENV{KERNEL_INSTALL_CONF_ROOT} // q{}) : '/etc/kernel') && (defined ($ENV{KERNEL_INSTALL_CONF_ROOT} // q{}) && ($ENV{KERNEL_INSTALL_CONF_ROOT} // q{}) ne q{} ? ($ENV{KERNEL_INSTALL_CONF_ROOT} // q{}) : '/etc/kernel') ne q{} ? (defined ($ENV{KERNEL_INSTALL_CONF_ROOT} // q{}) && ($ENV{KERNEL_INSTALL_CONF_ROOT} // q{}) ne q{} ? ($ENV{KERNEL_INSTALL_CONF_ROOT} // q{}) : '/etc/kernel') : '/etc/kernel') . "/tries";
my $UKI_FILE;
if ((-f "$TRIES_FILE")) {
open STDIN, '<', "$TRIES_FILE" or croak "Cannot read file: $OS_ERROR\n";
$TRIES = <>;
chomp $TRIES;
$CHILD_ERROR = defined($TRIES) ? 0 : 1;
if (    # Original bash: echo "$TRIES" | grep -q '^[0-9][0-9]*$';
do {
        my $output_2 = q{};
        my $output_printed_2;
        my $pipeline_success_2 = 1;
        $output_2 .= $TRIES . "\n";
if ( !($output_2 =~ m{\n\z}) ) { $output_2 .= "\n"; }

                my $grep_result_2_1;
        my @grep_lines_2_1 = split /\n/msx, $output_2;
        my @grep_filtered_2_1 = grep { /^[0-9][0-9]*$/msx } @grep_lines_2_1;
        $grep_result_2_1 = join "\n", @grep_filtered_2_1;
        if (!($grep_result_2_1 =~ m{\n\z} || $grep_result_2_1 eq q{})) {
        $grep_result_2_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_2_1 > 0 ? 0 : 1;
        $grep_result_2_1 = q{};
        $output_2 = q{};
        if ((scalar @grep_filtered_2_1) == 0) {
            $pipeline_success_2 = 0;
        }
        if ($output_2 ne q{} && !defined $output_printed_2) {
            print $output_2;
            if (!($output_2 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
        }) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            say "$TRIES_FILE does not contain an integer.";
        };
exit 1;
    }
    $UKI_FILE = "$UKI_DIR/$ENTRY_TOKEN-$KERNEL_VERSION+$ENV{TRIES}.efi";
}
else {
    $UKI_FILE = "$UKI_DIR/$ENTRY_TOKEN-$KERNEL_VERSION.efi";
}
if ((-f "$KERNEL_INSTALL_STAGING_AREA/uki.efi")) {
    if (($KERNEL_INSTALL_VERBOSE > 0)) {
                say "Installing $KERNEL_INSTALL_STAGING_AREA/uki.efi as $UKI_FILE";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
        $main_exit_code = system('install', '-m', q{0644}, "$KERNEL_INSTALL_STAGING_AREA/uki.efi", "$UKI_FILE") >> 8;
    if ($CHILD_ERROR != 0) {
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                say "Error: could not copy '$KERNEL_INSTALL_STAGING_AREA/uki.efi' to '$UKI_FILE'.";
            };
exit 1;
    }
;
}
else {
    if ("$KERNEL_IMAGE" ne q{}) {
        if (!((-f "$KERNEL_IMAGE"))) {
                            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    say "Error: UKI '$KERNEL_IMAGE' not a file.";
                };
exit 1;
        }
        if ("$KERNEL_IMAGE" ne "${KERNEL_IMAGE%*.efi}.efi") {
                            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    say "Error: $KERNEL_IMAGE is missing .efi suffix.";
                };
exit 1;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if (($KERNEL_INSTALL_VERBOSE > 0)) {
                        say "Installing $KERNEL_IMAGE as $UKI_FILE";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
                $main_exit_code = system('install', '-m', q{0644}, "$KERNEL_IMAGE", "$UKI_FILE") >> 8;
        if ($CHILD_ERROR != 0) {
                            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    say "Error: could not copy '$KERNEL_IMAGE' to '$UKI_FILE'.";
                };
exit 1;
        }
;
}
    else {
        if (($KERNEL_INSTALL_VERBOSE > 0)) {
                        say "No UKI available. Nothing to do.";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
exit 0;
    }
}
do {
    my ($owner, $group) = split /:/, 'root:root', 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ("$UKI_FILE") or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('bash', ':') >> 8;
}
exit 0;

exit $main_exit_code;
