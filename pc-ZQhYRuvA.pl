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

my $DPKG_MAINTSCRIPT_PACKAGE;
my @DPKG_MAINTSCRIPT_PACKAGE;
my %DPKG_MAINTSCRIPT_PACKAGE;
my $update_initramfs;
my @update_initramfs;
my %update_initramfs;
my $version_list;
my @version_list;
my %version_list;
my $BOOTDIR;
my @BOOTDIR;
my %BOOTDIR;
my $CONF;
my @CONF;
my %CONF;
my $mode;
my @mode;
my %mode;
my $verbose;
my @verbose;
my %verbose;
my $version;
my @version;
my %version;

$BOOTDIR = '/boot';
$CONF = '/etc/initramfs-tools/update-initramfs.conf';
$mode = "";
$version = "";
$update_initramfs = 'yes';
my $backup_initramfs;
my @backup_initramfs;
my %backup_initramfs;
$backup_initramfs = 'no';
$__set_e = 1;
if ((-r ${CONF})) {
        $main_exit_code = system('.', $CONF) >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if ((("$DPKG_MAINTSCRIPT_PACKAGE" ne q{} && $# eq 1) && "$1" eq -u)) {
if (!(    $main_exit_code = system('dpkg-trigger', '--no-await', 'update-initramfs') >> 8)) {
        print "update-initramfs: deferring update (trigger activated)\n";
exit 0;
    }
}

sub usage {
print "
Usage: update-initramfs {-c|-d|-u} [-k version] [-v] [-b directory]

Options:
 -k version\tSpecify kernel version or 'all'
 -c\t\tCreate a new initramfs
 -u\t\tUpdate an existing initramfs
 -d\t\tRemove an existing initramfs
 -b directory\tSet alternate boot directory
 -v\t\tBe verbose

See update-initramfs(8) for further details.

";
    return;
}

sub usage_error {
if ("${1:-}" ne q{}) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n\n", ${*});
        };
    }
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        usage();
    };
exit 2;
    return;
}

sub mild_panic {
if ("${1:-}" ne q{}) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", ${*});
        };
    }
exit 0;
    return;
}

sub panic {
if ("${1:-}" ne q{}) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", ${*});
        };
    }
exit 1;
    return;
}

sub verbose {
if ("${verbose}" eq 1) {
printf("%s\n", ${*});
    }
    return;
}

sub set_initramfs {
    my $initramfs;
    my @initramfs;
    my %initramfs;
    $initramfs = ${BOOTDIR} . "/initrd.img-" . ${version};
    return;
}

sub backup_initramfs {
    if ((!-r "${initramfs}")) {
        return q{0};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $initramfs_bak;
    my @initramfs_bak;
    my %initramfs_bak;
    $initramfs_bak = ($ENV{initramfs} // q{}) . ".dpkg-bak";
    if ((-r "${initramfs_bak}")) {
        if ( -e "${initramfs_bak}" ) {
            if ( -d "${initramfs_bak}" ) {
                carp "rm: carping: ", ${initramfs_bak},
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "${initramfs_bak}" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", ${initramfs_bak},
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    unlink ${initramfs_bak};
link ($ENV{initramfs} // q{}), ${initramfs_bak} or warn "link failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) {
                use File::Copy qw(copy);
        if ( -e ($ENV{initramfs} // q{}) ) {
            if ( -d ${initramfs_bak} ) {
                require File::Copy; File::Copy::copy(($ENV{initramfs} // q{}), ${initramfs_bak} . '/' . (($ENV{initramfs} // q{}) =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy(($ENV{initramfs} // q{}), ${initramfs_bak});
            }
        } else {
            croak "cp: cannot stat '-a': No such file or directory\n";
        }
    }
    verbose("Keeping " . ${initramfs_bak});
    return;
}

sub backup_booted_initramfs {
    my $initramfs_bak;
    my @initramfs_bak;
    my %initramfs_bak;
    $initramfs_bak = ($ENV{initramfs} // q{}) . ".dpkg-bak";
    if ((!-r "${initramfs_bak}")) {
        return q{0};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if (do {
if ((!-r /proc/uptime)) {
    if ( -e "${initramfs_bak}" ) {
        if ( -d "${initramfs_bak}" ) {
            carp "rm: carping: ", ${initramfs_bak},
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "${initramfs_bak}" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ${initramfs_bak},
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
        $CHILD_ERROR == 0
    }) {
        return q{0};    }
    if (do {
if ("${backup_initramfs}" eq "no") {
    if ( -e "${initramfs_bak}" ) {
        if ( -d "${initramfs_bak}" ) {
            carp "rm: carping: ", ${initramfs_bak},
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "${initramfs_bak}" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ${initramfs_bak},
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
        $CHILD_ERROR == 0
    }) {
        return q{0};    }
if ((!-r "${initramfs}.bak")) {
        my $err;
        my $force = 1;
        if ( -e "${initramfs_bak}" ) {
            my $dest = ($ENV{initramfs} // q{}) . ".bak";
            if ( -e $dest && -d $dest ) {
                my $source_name = "${initramfs_bak}";
                $source_name =~ s{^.*[\/]}{};
                $dest = "$dest/$source_name";
            }
            if ( -e $dest && !$force ) {
                croak "mv: $dest: File exists (use -f to force overwrite)\n";
            }
            my $dest_dir = $dest;
            $dest_dir =~ s/\/[^\/]*$//msx;
            if ( $dest_dir eq $dest ) {
                $dest_dir = q{};
            }
            if ( $dest_dir ne q{} && !-d $dest_dir ) {
                my $err;
                make_path( $dest_dir, { error => \$err } );
                if ( @{$err} ) {
                    croak "mv: cannot create directory $dest_dir: $err->[0]\n";
                }
            }
            require File::Copy;
            if ( File::Copy::move( "${initramfs_bak}", $dest ) ) {
            } else {
                croak
  "mv: cannot move "${initramfs_bak}" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "${initramfs_bak}": No such file or directory\n";
        }
        verbose("Backup " . ($ENV{initramfs} // q{}) . ".bak");
return q{0};
    }
    my $boot_initramfs;
    my @boot_initramfs;
    my %boot_initramfs;
    $boot_initramfs = q{};
    my $uptime_days;
    my @uptime_days;
    my %uptime_days;
    $uptime_days = do { my @_qx_cmd = (q(awk '{printf "%d", $1 / 3600 / 24}' /proc/uptime)); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ("$uptime_days" ne q{}) {
        $boot_initramfs = do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { if (1) { push @find_results, $File::Find::name; } }, './');
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
};
    }
if ("${boot_initramfs}" ne q{}) {
        if ( -e "${initramfs_bak}" ) {
            my $dest = ($ENV{initramfs} // q{}) . ".bak";
            if ( -e $dest && -d $dest ) {
                my $source_name = "${initramfs_bak}";
                $source_name =~ s{^.*[\/]}{};
                $dest = "$dest/$source_name";
            }
            if ( -e $dest && !$force ) {
                croak "mv: $dest: File exists (use -f to force overwrite)\n";
            }
            my $dest_dir = $dest;
            $dest_dir =~ s/\/[^\/]*$//msx;
            if ( $dest_dir eq $dest ) {
                $dest_dir = q{};
            }
            if ( $dest_dir ne q{} && !-d $dest_dir ) {
                my $err;
                make_path( $dest_dir, { error => \$err } );
                if ( @{$err} ) {
                    croak "mv: cannot create directory $dest_dir: $err->[0]\n";
                }
            }
            require File::Copy;
            if ( File::Copy::move( "${initramfs_bak}", $dest ) ) {
            } else {
                croak
  "mv: cannot move "${initramfs_bak}" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "${initramfs_bak}": No such file or directory\n";
        }
        verbose("Backup " . ($ENV{initramfs} // q{}) . ".bak");
return q{0};
    }
    verbose("Removing current backup " . ${initramfs_bak});
if ( -e "${initramfs_bak}" ) {
        if ( -d "${initramfs_bak}" ) {
            carp "rm: carping: ", ${initramfs_bak},
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "${initramfs_bak}" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ${initramfs_bak},
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}

sub remove_initramfs_bak {
    if ("${initramfs_bak:-}" eq q{}) {
        return q{0};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if ( -e "($ENV{initramfs_bak} // q{})" ) {
        if ( -d "($ENV{initramfs_bak} // q{})" ) {
            carp "rm: carping: ", ($ENV{initramfs_bak} // q{}),
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "($ENV{initramfs_bak} // q{})" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ($ENV{initramfs_bak} // q{}),
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    verbose("Removing " . ($ENV{initramfs_bak} // q{}));
    return;
}

sub generate_initramfs {
    do {
    my $__echo_line = "update-initramfs: Generating " . ($ENV{initramfs} // q{});
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    my $OPTS;
    my @OPTS;
    my %OPTS;
    $OPTS = "-o";
if ("${verbose}" eq 1) {
        $OPTS = "-v " . ${OPTS};
    }
if (!(    $main_exit_code = system('mkinitramfs', $OPTS, ($ENV{initramfs} // q{}) . ".new", ${version}) >> 8)) {
        my $err;
        my $force = 1;
        if ( -e "($ENV{initramfs} // q{}) . ".new"" ) {
            my $dest = ($ENV{initramfs} // q{});
            if ( -e $dest && -d $dest ) {
                my $source_name = "($ENV{initramfs} // q{}) . ".new"";
                $source_name =~ s{^.*[\/]}{};
                $dest = "$dest/$source_name";
            }
            if ( -e $dest && !$force ) {
                croak "mv: $dest: File exists (use -f to force overwrite)\n";
            }
            my $dest_dir = $dest;
            $dest_dir =~ s/\/[^\/]*$//msx;
            if ( $dest_dir eq $dest ) {
                $dest_dir = q{};
            }
            if ( $dest_dir ne q{} && !-d $dest_dir ) {
                my $err;
                make_path( $dest_dir, { error => \$err } );
                if ( @{$err} ) {
                    croak "mv: cannot create directory $dest_dir: $err->[0]\n";
                }
            }
            require File::Copy;
            if ( File::Copy::move( "($ENV{initramfs} // q{}) . ".new"", $dest ) ) {
            } else {
                croak
  "mv: cannot move "($ENV{initramfs} // q{}) . ".new"" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "($ENV{initramfs} // q{}) . ".new"": No such file or directory\n";
        }
        $main_exit_code = system('sync', '-f', ($ENV{initramfs} // q{})) >> 8;
}
    else {
        my $mkinitramfs_return;
        my @mkinitramfs_return;
        my %mkinitramfs_return;
        $mkinitramfs_return = "${\($? >> 8)}";
        remove_initramfs_bak();
if ( -e "($ENV{initramfs} // q{}) . ".new"" ) {
            if ( -d "($ENV{initramfs} // q{}) . ".new"" ) {
                carp "rm: carping: ", ($ENV{initramfs} // q{}) . ".new",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "($ENV{initramfs} // q{}) . ".new"" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", ($ENV{initramfs} // q{}) . ".new",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "update-initramfs: failed for " . ($ENV{initramfs} // q{}) . " with $mkinitramfs_return.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
    }
    return;
}

sub run_bootloader {
if ((-d '/etc/initramfs/post-update.d/')) {
        $main_exit_code = system('run-parts', '--arg=${version}', '--arg=${initramfs}', '/etc/initramfs/post-update.d/') >> 8;
return q{0};
    }
    return;
}

sub ro_boot_check {
if (((!-r /proc/mounts) || !(    $main_exit_code = system('bash', 'ischroot') >> 8))) {
return q{0};
    }
    my $boot_opts;
    my @boot_opts;
    my %boot_opts;
    $boot_opts = do { my @_qx_cmd = (q[awk "/boot/{if ((match(\$4, /^ro/) || match(\$4, /,ro/)) \\
		&& \$2 == \"/boot\") print \"ro\"}" /proc/mounts]); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ("${boot_opts}" ne q{}) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "W: /boot is ro mounted.\n";
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "W: update-initramfs: Not updating " . ($ENV{initramfs} // q{});
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
exit 0;
    }
    return;
}

sub get_sorted_versions {
    $version_list = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { # Original bash: linux-version list |
do {
        my $output_9 = q{};
        my $output_printed_9;
        my $pipeline_success_9 = 1;
        my ($in_10, $out_10);
        my $pid_10 = open3($in_10, $out_10, '>&STDERR', 'linux-version', 'list');
        close $in_10 or croak 'Close failed: $OS_ERROR';
        $output_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
        close $out_10 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_10, 0;
        my @lines = split /\n/msx, $output_9;
        my $result_9_1 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        if (do {
        $main_exit_code = system('test', '-e', ${BOOTDIR} . "/initrd.img-$version") >> 8;
        $CHILD_ERROR == 0
        }) {
        print $version;
        if ( !( ($version) =~ m{\n\z}msx ) ) { print "\n"; }
        }
        }
        $output_9 = $result_9_1;
        my $cmd_12 = 'linux-version';
        my ($in_11, $out_11);
        my $pid_11 = open3($in_11, $out_11, '>&STDERR', $cmd_12, 'sort', '--reverse');
        print {$in_11} $output_9;
        close $in_11 or croak 'Close failed: $OS_ERROR';
        $output_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
        close $out_11 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_11, 0;
        if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_9 =~ s/\n+\z//msx;
        $output_9;
} };
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
    verbose("Available versions: " . ${version_list});
    return;
}

sub set_current_version {
if ((-f "/boot/initrd.img-$(uname -r)")) {
        $version = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; };
    }
    return;
}

sub set_linked_version {
    my $linktarget;
    my @linktarget;
    my %linktarget;
    $linktarget = q{};
if (((-e '/initrd.img') && (-l '/initrd.img'))) {
        $linktarget = (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename((do { my $_chomp_temp = do {
    my ($in_13, $out_13);
    my $pid_13 = open3($in_13, $out_13, '>&STDERR', 'readlink', '/initrd.img');
    close $in_13 or croak 'Close failed: $OS_ERROR';
    my $result_13 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
    close $out_13 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_13, 0;
    $result_13
}; chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
    }
if (((-e '/boot/initrd.img') && (-l '/boot/initrd.img'))) {
        $linktarget = (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename((do { my $_chomp_temp = do {
    my ($in_14, $out_14);
    my $pid_14 = open3($in_14, $out_14, '>&STDERR', 'readlink', '/boot/initrd.img');
    close $in_14 or croak 'Close failed: $OS_ERROR';
    my $result_14 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_14> };
    close $out_14 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_14, 0;
    $result_14
}; chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
    }
if ("${linktarget}" eq q{}) {
return;
    }
    $version = (${linktarget} =~ s/^initrd\.img-//sr =~ s/^initrd\.img-//sr);
    return;
}

sub set_highest_version {
    get_sorted_versions();
if ("${version_list}" eq q{}) {
        $version = q{};
return;
    }
# set -- not implemented
    $version = $1;
    return;
}

sub create {
if ("${version}" eq q{}) {
        usage_error("Create mode requires a version argument");
    }
    set_initramfs();
    generate_initramfs();
    run_bootloader();
    return;
}

sub update {
if ("${update_initramfs}" eq "no") {
        print "update-initramfs: Not updating initramfs.\n";
exit 0;
    }
if ("${version}" eq q{}) {
        set_highest_version();
    }
if ("${version}" eq q{}) {
        set_linked_version();
    }
if ("${version}" eq q{}) {
        set_current_version();
    }
if ("${version}" eq q{}) {
        verbose("Nothing to do, exiting.");
exit 0;
    }
    set_initramfs();
    ro_boot_check();
    backup_initramfs();
    generate_initramfs();
    run_bootloader();
    backup_booted_initramfs();
    return;
}

sub delete {
if ("${version}" eq q{}) {
        usage_error("Delete mode requires a version argument");
    }
    set_initramfs();
    do {
    my $__echo_line = "update-initramfs: Deleting " . ($ENV{initramfs} // q{});
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if ( -e "($ENV{initramfs} // q{})" ) {
        if ( -d "($ENV{initramfs} // q{})" ) {
            carp "rm: carping: ", ($ENV{initramfs} // q{}),
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "($ENV{initramfs} // q{})" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ($ENV{initramfs} // q{}),
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "($ENV{initramfs} // q{}) . ".bak"" ) {
        if ( -d "($ENV{initramfs} // q{}) . ".bak"" ) {
            carp "rm: carping: ", ($ENV{initramfs} // q{}) . ".bak",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "($ENV{initramfs} // q{}) . ".bak"" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ($ENV{initramfs} // q{}) . ".bak",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}
$verbose = q{0};
my $OPTIONS;
my @OPTIONS;
my %OPTIONS;
$OPTIONS = do {
    my ($in_15, $out_15);
    my $pid_15 = open3($in_15, $out_15, '>&STDERR', 'getopt', '-o', "k:cudvtb:h?", '--long', 'help', '-n', "$PROGRAM_NAME", '--', "@ARGV");
    close $in_15 or croak 'Close failed: $OS_ERROR';
    my $result_15 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_15> };
    close $out_15 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_15, 0;
    $result_15
};
if ($CHILD_ERROR != 0) {
        usage_error();
}
do { my $eval_input = "set" . "--" . $OPTIONS; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
while ( 1 ) {
if ("$_[0]" =~ /^-k$/msx) {
                $version = "$_[1]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-c$/msx) {
                $mode = "c";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-d$/msx) {
                $mode = "d";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-u$/msx) {
                $mode = "u";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-v$/msx) {
                $verbose = "1";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-t$/msx) {
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-b$/msx) {
                $BOOTDIR = "$_[1]";
        if ((!-d "${BOOTDIR}")) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "E: " . ${BOOTDIR} . " is not a directory.";
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
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-h$/msx or "$_[0]" =~ /^-\.$/msx or "$_[0]" =~ /^--help$/msx) {
                usage();
        exit 0;
    } elsif ("$_[0]" =~ /^--$/msx) {
        # Builtin command 'shift' not implemented
        last;    }
}
if ((scalar(@ARGV) != 0)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("Extra argument '%s'\n\n", "$_[0]");
    };
    usage_error();
}
if ("${mode}" eq q{}) {
    usage_error("You must specify at least one of -c, -u, or -d.");
}
if (("${version}" eq "all" || !(    if ("${update_initramfs}" eq "all") {
        "${version}" eq q{}        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }))) {
if (${mode} =~ /^c$/msx) {
                $version_list = (do { my $_chomp_temp = do {
    my ($in_18, $out_18);
    my $pid_18 = open3($in_18, $out_18, '>&STDERR', 'linux-version', 'list');
    close $in_18 or croak 'Close failed: $OS_ERROR';
    my $result_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_18> };
    close $out_18 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_18, 0;
    $result_18
}; chomp $_chomp_temp; $_chomp_temp; });
    } elsif (${mode} =~ /^d$/msx or ${mode} =~ /^u$/msx) {
                get_sorted_versions();
    }
if ("${version_list}" eq q{}) {
        verbose("Nothing to do, exiting.");
exit 0;
    }
    my $OPTS;
    my @OPTS;
    my %OPTS;
    $OPTS = "-b " . ${BOOTDIR};
if ("${verbose}" eq "1") {
        $OPTS = ${OPTS} . " -v";
    }
    my $u_version;
    for my $u_version ($version_list) {
        verbose("Execute: " . $_[0] . " -" . ${mode} . " -k \"" . ${u_version} . "\" " . ${OPTS});
        $CHILD_ERROR = 0;
    }
exit 0;
}
if (${mode} =~ /^c$/msx) {
        create();
} elsif (${mode} =~ /^d$/msx) {
        delete();
} elsif (${mode} =~ /^u$/msx) {
        update();
}

exit $main_exit_code;
