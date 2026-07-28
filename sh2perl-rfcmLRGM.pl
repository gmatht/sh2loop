#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy move);

my $main_exit_code = 0;
my $output         = q{};
our $CHILD_ERROR;

my $boot;
my $num;
my $next_num;
my $initrd_file;

$__set_e = 1;
# set u not implemented
my $modeenv = "/run/mnt/data/" . "sys" . "tem" . "-data/var/lib/snapd/modeenv";
my $mode = (do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', '/usr/libexec/core/get-mode', 'mode', ${modeenv});
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
});
if ($CHILD_ERROR != 0) {
        $mode = "unknown";
}
my $save_dir;
if (${mode} =~ /^install$/msx or ${mode} =~ /^recover$/msx or ${mode} =~ /^factory-reset$/msx) {
        $save_dir = "/run/mnt/ubuntu-data/" . "sys" . "tem" . "-data/var/log/debug";
} elsif (1) {
        $save_dir = "/run/mnt/data/" . "sys" . "tem" . "-data/var/log/debug";
}
$next_num = q{1};
my $base;
for my $boot (${save_dir}, '/boot*') {
if ((-d "${boot}")) {
        $base = (do { use File::Basename qw(basename); my $basename_output = basename(${boot}); $CHILD_ERROR = 0; $basename_output; });
        $num = (${base} =~ s/^boot//r =~ s/^boot//r);
if ((${num} >= ${next_num})) {
            $next_num = (do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', '${num}+1');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
});
        }
    }
}
$boot = '/boot*';
my $next_dir = ${save_dir} . "/boot" . ${next_num};
use File::Path qw(make_path);
my $err;
if ( !-d ${next_dir} ) {
    make_path( ${next_dir}, { error => \$err } );
    if ( @{$err} ) {
        croak "mkdir: cannot create directory " . ${next_dir} . ": $err->[0]\n";
    }
}
my $force = 0;
if ( -e '/run/log/base/*.svg' ) {
    my $dest = ${next_dir} . "/";
    if ( -e $dest && -d $dest ) {
        my $source_name = '/run/log/base/*.svg';
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
    if ( File::Copy::move( '/run/log/base/*.svg', $dest ) ) {
    } else {
        croak
  "mv: cannot move '/run/log/base/*.svg' to $dest: $ERRNO\n";
    }
} else {
    croak "mv: '/run/log/base/*.svg': No such file or directory\n";
}
for my $initrd_file ('/run/log/*.svg') {
if ((-f "${initrd_file}")) {
        $base = (do { use File::Basename qw(basename); my $basename_output = basename(${initrd_file}); $CHILD_ERROR = 0; $basename_output; });
        if ( -e "${initrd_file}" ) {
            my $dest = ${next_dir} . "/initrd-" . ${base};
            if ( -e $dest && -d $dest ) {
                my $source_name = "${initrd_file}";
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
            if ( File::Copy::move( "${initrd_file}", $dest ) ) {
            } else {
                croak
  "mv: cannot move "${initrd_file}" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "${initrd_file}": No such file or directory\n";
        }
    }
}

exit $main_exit_code;
