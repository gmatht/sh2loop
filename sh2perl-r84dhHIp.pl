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

my $ceph_builtin;
my @ceph_builtin;
my %ceph_builtin;
my $label;
my @label;
my %label;

$__set_e = 1;
# set u not implemented
if ((-d '/sys/kernel/security/apparmor')) {
    $label = (do { my $_chomp_temp = do { my @_qx_cmd = ("cat /proc/self/attr/current 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; });
if (("$label" ne "unconfined" && "${label##*(unconfined)}" ne q{})) {
# Builtin command 'exec' not implemented
    }
}

sub get_bool {
    my $value;
    my @value;
    my %value;
    $value = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ((defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '') : '')) . "\n";
    my $set1_1 = '[:upper:]';
my $set2_1 = '[:lower:]';
my $input_1 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_1 = $set1_1;
my $expanded_set2_1 = $set2_1;
# Handle a-z range in set1
if ($expanded_set1_1 =~ /a-z/msx) {
    $expanded_set1_1 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_1 =~ /A-Z/msx) {
    $expanded_set1_1 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_1 =~ /\[:upper:\]/msx) {
    $expanded_set1_1 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_1 =~ /\[:lower:\]/msx) {
    $expanded_set1_1 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_1 =~ /a-z/msx) {
    $expanded_set2_1 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_1 =~ /A-Z/msx) {
    $expanded_set2_1 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_1 =~ /\[:upper:\]/msx) {
    $expanded_set2_1 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_1 =~ /\[:lower:\]/msx) {
    $expanded_set2_1 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_0 = q{};
for my $char ( split //msx, $input_1 ) {
    my $pos_1 = index $expanded_set1_1, $char;
    if ( $pos_1 >= 0 && $pos_1 < length $expanded_set2_1 ) {
        $tr_result_0 .= substr $expanded_set2_1, $pos_1, 1;
    } else {
        $tr_result_0 .= $char;
    }
}
$tr_result_0
}; $_pipeline_result; };
    my $yes;
    for my $yes ("true", "1", "yes", "on") {
if ("${value}" eq "${yes}") {
            print "true\n";
return;
        }
    }
    my $no;
    for my $no ("false", "0", "no", "off") {
if ("${value}" eq "${no}") {
            print "false\n";
return;
        }
    }
return;
    return;
}
if ((-e "/etc/.lxd_generated")) {
    $ceph_builtin = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'get_bool', (do { my $_chomp_temp = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'snapctl', 'get', 'ceph.builtin');
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
}; chomp $_chomp_temp; $_chomp_temp; }));
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
};
if ("${ceph_builtin:-"false"}" eq "true") {
        use File::Path qw(make_path);
        my $err;
        if ( !-d ($ENV{SNAP_COMMON} // q{}) . "/ceph" ) {
            make_path( ($ENV{SNAP_COMMON} // q{}) . "/ceph", { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . ($ENV{SNAP_COMMON} // q{}) . "/ceph" . ": $err->[0]\n";
            }
        }
symlink 'nf', '/etc/ceph' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
    else {
symlink 'nf', '/etc/ceph' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
}

exit $main_exit_code;
