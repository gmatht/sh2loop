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

$__set_e = 1;
# set +x not implemented
my $STATIC_SNAP_MOUNT_DIR;
my @STATIC_SNAP_MOUNT_DIR;
my %STATIC_SNAP_MOUNT_DIR;
$STATIC_SNAP_MOUNT_DIR = "/snap";

sub show_help {
my $temp_content = 'Usage: snap-mgmt-selinux.sh [OPTIONS]

A helper script to manage SELinux contexts used by snapd

Arguments:
  --snap-mount-dir=<path>                   Provide a path to be used as $STATIC_SNAP_MOUNT_DIR
  --patch-selinux-mount-context=<context>   Add SELinux context to mount units
  --remove-selinux-mount-context=<context>  Remove SELinux context from mount units
';
use File::Path qw(make_path);
if (!-d q{/tmp}) { make_path(q{/tmp}); }
open my $fh_1, '>', q{/tmp} . '/heredoc_temp' or croak "Cannot create temp file: $OS_ERROR\n";
print $fh_1 $temp_content;
close $fh_1 or croak "Close failed: $OS_ERROR\n";
open STDIN, '<', q{/tmp} . '/heredoc_temp' or croak "Cannot open temp file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
    return;
}
my $SNAP_UNIT_PREFIX;
my @SNAP_UNIT_PREFIX;
my %SNAP_UNIT_PREFIX;
$SNAP_UNIT_PREFIX = (do { my $_chomp_temp = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', "sys" . "tem" . "d-escape", '-p', $STATIC_SNAP_MOUNT_DIR);
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; chomp $_chomp_temp; $_chomp_temp; });

sub patch_selinux_mount_context {
if (!(!(do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'selinuxenabled') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };))) {
return;
    }
if (!(!($main_exit_code = system('bash', 'selinuxenabled') >> 8;))) {
return;
    }
    my $selinux_mount_context;
    my @selinux_mount_context;
    my %selinux_mount_context;
    $selinux_mount_context = "$_[0]";
    my $remove;
    my @remove;
    my %remove;
    $remove = "$_[1]";
if (!(!(# Original bash: echo "$selinux_mount_context" | grep -qE '[a-zA-Z0-9_]+(:[a-zA-Z0-9_]+){2,3}';
{
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
        $output_1 .= $selinux_mount_context . "\n";
if ( !($output_1 =~ m{\n\z}msx) ) { $output_1 .= "\n"; }
$CHILD_ERROR = 0;

                my $grep_result_1_1;
        my @grep_lines_1_1 = split /\n/msx, $output_1;
        my @grep_filtered_1_1 = grep { /[a-zA-Z0-9_]+(:[a-zA-Z0-9_]+){2,3}/msx } @grep_lines_1_1;
        $grep_result_1_1 = join "\n", @grep_filtered_1_1;
        if (!($grep_result_1_1 =~ m{\n\z}msx || $grep_result_1_1 eq q{})) {
        $grep_result_1_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_1_1 > 0 ? 0 : 1;
        $grep_result_1_1 = q{};
        $output_1 = q{};
        if ((scalar @grep_filtered_1_1) == 0) {
            $pipeline_success_1 = 0;
        }
        if ($output_1 ne q{} && !defined $output_printed_1) {
            print $output_1;
            if (!($output_1 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        }))) {
        do {
    my $__echo_line = "invalid mount context '$selinux_mount_context'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
exit 1;
    }
    my $context_opt;
    my @context_opt;
    my %context_opt;
    $context_opt = "context=$selinux_mount_context";
    my $mounts;
    my @mounts;
    my %mounts;
    $mounts = do {
    local $ENV{SNAP_UNIT_PREFIX} = $SNAP_UNIT_PREFIX;
    my $command = q{systemctl list-unit-files --no-legend --full "$SNAP_UNIT_PREFIX-*.mount" | cut -f 1 -d ' ' || true};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
    my $changed_mounts;
    my @changed_mounts;
    my %changed_mounts;
    $changed_mounts = q{};
    my $unit;
    for my $unit ($mounts) {
if (!(!(if (do {
                        my $grep_result_2;
            my @grep_lines_2 = ();
            my @grep_filtered_2 = grep { /What=\/var\/lib\/snapd\/snaps\//msx } @grep_lines_2;
            $grep_result_2 = join "\n", @grep_filtered_2;
                        if (!($grep_result_2 =~ m{\n\z}msx || $grep_result_2 eq q{})) {
                            $grep_result_2 .= "\n";
                        }
            $CHILD_ERROR = scalar @grep_filtered_2 > 0 ? 0 : 1;
            $grep_result_2 = q{};
            $CHILD_ERROR == 0
        }) {
            !(my $grep_result_3;
my @grep_lines_3 = ();
my @grep_filtered_3 = grep { /X-Snappy=yes/msx } @grep_lines_3;
$grep_result_3 = join "\n", @grep_filtered_3;
            if (!($grep_result_3 =~ m{\n\z}msx || $grep_result_3 eq q{})) {
                $grep_result_3 .= "\n";
            }
$CHILD_ERROR = scalar @grep_filtered_3 > 0 ? 0 : 1;
$grep_result_3 = q{};)
        }))) {
            do {
    my $__echo_line = "Skipping non-snapd " . "sys" . "tem" . "d unit $unit";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
next;
        }
if ("$remove" =~ /^""$/msx) {
if (!(open STDIN, '<', "/etc/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/$unit" or croak "Cannot read file: $OS_ERROR\n";
my $grep_result_4;
my @grep_lines_4 = ();
my @grep_filtered_4 = grep { /Options=.*,$context_opt/msx } @grep_lines_4;
$grep_result_4 = join "\n", @grep_filtered_4;
            if (!($grep_result_4 =~ m{\n\z}msx || $grep_result_4 eq q{})) {
                $grep_result_4 .= "\n";
            }
$CHILD_ERROR = scalar @grep_filtered_4 > 0 ? 0 : 1;
$grep_result_4 = q{})) {
next;
            }
if (!(!(my @sed_lines_5 = split /\n/msx, $;
my @sed_result_5;
foreach my $line (@sed_lines_5) {
chomp $line;
push @sed_result_5, $line;
}
$ = join "\n", @sed_result_5;))) {
                do {
    my $__echo_line = "Cannot patch $unit";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            }
            $changed_mounts = "$changed_mounts $unit";
}
        else {
            if ("$remove" =~ /^"remove"$/msx) {
if (!(!(open STDIN, '<', "/etc/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/$unit" or croak "Cannot read file: $OS_ERROR\n";
my $grep_result_6;
my @grep_lines_6 = ();
my @grep_filtered_6 = grep { /Options=.*,$context_opt/msx } @grep_lines_6;
$grep_result_6 = join "\n", @grep_filtered_6;
                if (!($grep_result_6 =~ m{\n\z}msx || $grep_result_6 eq q{})) {
                    $grep_result_6 .= "\n";
                }
$CHILD_ERROR = scalar @grep_filtered_6 > 0 ? 0 : 1;
$grep_result_6 = q{};))) {
next;
                }
if (!(!(my @sed_lines_7 = split /\n/msx, $;
my @sed_result_7;
foreach my $line (@sed_lines_7) {
chomp $line;
push @sed_result_7, $line;
}
$ = join "\n", @sed_result_7;))) {
                    do {
    my $__echo_line = "Cannot patch $unit";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                }
                $changed_mounts = "$changed_mounts $unit";
            }
        }
    }
if ("$changed_mounts" eq q{}) {
return;
    }
    $main_exit_code = system('systemctl', 'daemon-reload') >> 8;
    for my $unit ($changed_mounts) {
if (!(!($main_exit_code = system('systemctl', 'try-restart', "$unit") >> 8;))) {
            do {
    my $__echo_line = "Cannot restart $unit";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
    }
    return;
}
while ( "$1" ne q{} ) {
if ("$_[0]" =~ /^--help$/msx) {
                show_help();
        exit $main_exit_code;
    } elsif ("$_[0]" =~ /^--snap-mount-dir=.*$/msx) {
                $STATIC_SNAP_MOUNT_DIR = $_[0] =~ s/^.*?=//r;
                $SNAP_UNIT_PREFIX = do {
    my ($in_8, $out_8);
    my $pid_8 = open3($in_8, $out_8, '>&STDERR', "sys" . "tem" . "d-escape", '-p', "$STATIC_SNAP_MOUNT_DIR");
    close $in_8 or croak 'Close failed: $OS_ERROR';
    my $result_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
    close $out_8 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_8, 0;
    $result_8
};
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--patch-selinux-mount-context=.*$/msx) {
                patch_selinux_mount_context(($_[0] =~ s/^.*?=//r =~ s/^.*?=//r));
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--remove-selinux-mount-context=.*$/msx) {
                patch_selinux_mount_context(($_[0] =~ s/^.*?=//r =~ s/^.*?=//r), 'remove');
        # Builtin command 'shift' not implemented
    } elsif (1) {
                do {
    my $__echo_line = "Unknown command: $_[0]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        exit 1;
    }
}

exit $main_exit_code;
