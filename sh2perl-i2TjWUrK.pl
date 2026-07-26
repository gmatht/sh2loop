#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy move);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

$__set_e = 1;
if (!(!(my $grep_result_0;
my @grep_lines_0 = ();
my @grep_filenames_0 = ();
if (-e "/etc/os-release") {
    open my $fh, '<', "/etc/os-release" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_0, $line;
        push @grep_filenames_0, "/etc/os-release";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/os-release: No such file or directory\n"; }
my @grep_filtered_0 = grep { /ID=ubuntu-core/msx } @grep_lines_0;
$grep_result_0 = join "\n", @grep_filtered_0;
if (!($grep_result_0 =~ m{\n\z}msx || $grep_result_0 eq q{})) {
    $grep_result_0 .= "\n";
}
$CHILD_ERROR = scalar @grep_filtered_0 > 0 ? 0 : 1;
$grep_result_0 = q{};))) {
exit 0;
}
if (!(my $grep_result_1;
my @grep_lines_1 = ();
my @grep_filenames_1 = ();
if (-e "=") {
    open my $fh, '<', "=" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_1, $line;
        push @grep_filenames_1, "=";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: =: No such file or directory\n"; }
if (-e "/proc/cmdline") {
    open my $fh, '<', "/proc/cmdline" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_1, $line;
        push @grep_filenames_1, "/proc/cmdline";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/cmdline: No such file or directory\n"; }
my @grep_filtered_1 = grep { /snapd_recovery_mode/msx } @grep_lines_1;
$grep_result_1 = join "\n", @grep_filtered_1;
if (!($grep_result_1 =~ m{\n\z}msx || $grep_result_1 eq q{})) {
    $grep_result_1 .= "\n";
}
$CHILD_ERROR = scalar @grep_filtered_1 > 0 ? 0 : 1;
$grep_result_1 = q{})) {
exit 0;
}
if ((qx'find /boot/uboot -name uboot.env | wc -l' > 1)) {
    print "Corrupted uboot.env file detected\n";
    use File::Copy qw(copy);
    if ( -e '/boot/uboot/uboot.env' ) {
        if ( -d '/boot/uboot/uboot.env.save' ) {
            require File::Copy; File::Copy::copy('/boot/uboot/uboot.env', '/boot/uboot/uboot.env.save' . '/' . ('/boot/uboot/uboot.env' =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy('/boot/uboot/uboot.env', '/boot/uboot/uboot.env.save');
        }
    } else {
        croak "cp: cannot stat '-a': No such file or directory\n";
    }
while (     do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        my @ls_files_3 = ();
        my $ls_all_found_4 = 1;
        my @ls_inputs_5 = ();
        push @ls_inputs_5, '/boot/uboot/uboot.env';
        my @ls_files_6 = ();
        my @ls_dirs_7 = ();
        my $ls_show_headers_8 = scalar(@ls_inputs_5) > 1;
        for my $ls_item_9 (@ls_inputs_5) {
            if ( -f $ls_item_9 ) {
                push @ls_files_6, $ls_item_9;
            }
            elsif ( -d $ls_item_9 ) {
                push @ls_dirs_7, $ls_item_9;
            }
            else {
                $ls_all_found_4 = 0;
            }
        }
        @ls_files_6 = sort { $a cmp $b } @ls_files_6;
        @ls_dirs_7 = sort { $a cmp $b } @ls_dirs_7;
        if (@ls_files_6) {
            push @ls_files_3, join("\n", @ls_files_6);
        }
        for my $ls_dir_10 (@ls_dirs_7) {
            my @ls_dir_entries_11 = ();
            if ( opendir my $dh, $ls_dir_10 ) {
                while ( my $file = readdir $dh ) {
                    next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                    push @ls_dir_entries_11, $file;
                }
                closedir $dh;
                @ls_dir_entries_11 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_11;
                if ( $ls_show_headers_8 ) {
                    if ( @ls_dir_entries_11 ) {
                        push @ls_files_3, $ls_dir_10 . ":\n" . join("\n", @ls_dir_entries_11);
                    } else {
                        push @ls_files_3, $ls_dir_10 . ':';
                    }
                }
                elsif ( @ls_dir_entries_11 ) {
                    push @ls_files_3, join("\n", @ls_dir_entries_11);
                }
            }
            else {
                $ls_all_found_4 = 0;
            }
        }
        if (@ls_files_3) {
            print join "\n", @ls_files_3;
            print "\n";
        }
        if ( $ls_all_found_4 ) {
            local $CHILD_ERROR = 0;
            $ls_success = 1;
        }
        else {
            local $CHILD_ERROR = 2;
            $ls_success = 0;
            $main_exit_code = $CHILD_ERROR;
        }
    } ) {
if ( -e "/boot/uboot/uboot.env" ) {
            if ( -d "/boot/uboot/uboot.env" ) {
                carp "rm: carping: ", "/boot/uboot/uboot.env",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "/boot/uboot/uboot.env" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/boot/uboot/uboot.env",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    my $err;
    my $force = 0;
    if ( -e '/boot/uboot/uboot.env.save' ) {
        my $dest = '/boot/uboot/uboot.env';
        if ( -e $dest && -d $dest ) {
            my $source_name = '/boot/uboot/uboot.env.save';
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
        if ( File::Copy::move( '/boot/uboot/uboot.env.save', $dest ) ) {
        } else {
            croak
  "mv: cannot move '/boot/uboot/uboot.env.save' to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: '/boot/uboot/uboot.env.save': No such file or directory\n";
    }
    $main_exit_code = system('bash', 'sync') >> 8;
}
if ((-f '/var/lib/snapd/device/ownership-change.after')) {
exit 0;
}
if ((!-f /var/lib/snapd/device/ownership-change.before)) {
    use File::Path qw(make_path);
    if ( !-d '/var/lib/snapd/device' ) {
        make_path( '/var/lib/snapd/device', { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . '/var/lib/snapd/device' . ": $err->[0]\n";
        }
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/var/lib/snapd/device/ownership-change.before.tmp'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        require File::Find;
        File::Find::find(sub {     print "$File::Find::name\n"; }, '/etc/cloud');
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', '/var/lib/snapd/device/ownership-change.before.tmp'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        require File::Find;
        File::Find::find(sub {     my $depth = ($File::Find::dir =~ tr/\///) + 1; next if $depth > 0;     print "$File::Find::name\n"; }, "/writable/" . "sys" . "tem" . "-data");
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
    if ( -e '/var/lib/snapd/device/ownership-change.before.tmp' ) {
        my $dest = '/var/lib/snapd/device/ownership-change.before';
        if ( -e $dest && -d $dest ) {
            my $source_name = '/var/lib/snapd/device/ownership-change.before.tmp';
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
        if ( File::Copy::move( '/var/lib/snapd/device/ownership-change.before.tmp', $dest ) ) {
        } else {
            croak
  "mv: cannot move '/var/lib/snapd/device/ownership-change.before.tmp' to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: '/var/lib/snapd/device/ownership-change.before.tmp': No such file or directory\n";
    }
}
my $i;
for my $i ('/etc/cloud', '/var/lib/cloud', '/var/lib/snapd') {
    {
        my $output_17 = q{};
        my $output_printed_17;
        my $pipeline_success_17 = 1;
                $output_17 = do {
        require File::Find;
        my @find_results;
        File::Find::find(sub { if (-l $_) { push @find_results, $File::Find::name; } }, "\\(");
        my $result = join "\n", @find_results;
        if ($result ne q{}) { $result .= "\n"; }
        $CHILD_ERROR = 0;
        $result;
        };

                my @xargs_input_17_1 = grep { $_ ne q{} } split /\s+/msx, $output_17;
        my @xargs_output_17_1;
        for my $i (0..scalar @xargs_input_17_1-1) {
        my @xargs_args_17_1;
        for my $j (0..1-1) {
        push @xargs_args_17_1, $xargs_input_17_1[$i + $j];
        }
        my ($in_17_1, $out_17_1, $err_17_1);
        my $cmd_xargs_17_1 = 'chown';
        my $pid_17_1 = open3($in_17_1, $out_17_1, $err_17_1, $cmd_xargs_17_1, '-c', '--no-dereference', 'root:root', '--', @xargs_args_17_1);
        close $in_17_1 or croak 'Close failed: $OS_ERROR';
        my $xargs_result_17_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17_1> };
        close $out_17_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_17_1, 0;
        chomp $xargs_result_17_1;
        push @xargs_output_17_1, $xargs_result_17_1;
        }
        my $xargs_result_17_1 = join "\n", @xargs_output_17_1;
        if ($xargs_result_17_1 ne q{} && !( $xargs_result_17_1 =~ m{\n\z}msx )) { $xargs_result_17_1 .= "\n"; }
        $output_17 = $xargs_result_17_1;
        $output_17 = $xargs_result_17_1;
        if ($output_17 ne q{} && !defined $output_printed_17) {
            print $output_17;
            if (!($output_17 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_17 ) { $main_exit_code = 1; }
        }
    if ($CHILD_ERROR != 0) {
        1;
    }
}
for my $i ("/writable/" . "sys" . "tem" . "-data", "/writable/" . "sys" . "tem" . "-data/var", "/writable/" . "sys" . "tem" . "-data/var/lib", "/writable/" . "sys" . "tem" . "-data/boot", "/writable/" . "sys" . "tem" . "-data/etc") {
    {
        my $output_19 = q{};
        my $output_printed_19;
        my $pipeline_success_19 = 1;
                $output_19 = do {
        require File::Find;
        my @find_results;
        File::Find::find(sub { my $maxdepth = 0; my $depth = ($File::Find::dir =~ tr/\///) + 1; next if $depth > $maxdepth; if (-l $_) { push @find_results, $File::Find::name; } }, "\\(");
        my $result = join "\n", @find_results;
        if ($result ne q{}) { $result .= "\n"; }
        $CHILD_ERROR = 0;
        $result;
        };

                my @xargs_input_19_1 = grep { $_ ne q{} } split /\s+/msx, $output_19;
        my @xargs_output_19_1;
        for my $i (0..scalar @xargs_input_19_1-1) {
        my @xargs_args_19_1;
        for my $j (0..1-1) {
        push @xargs_args_19_1, $xargs_input_19_1[$i + $j];
        }
        my ($in_19_1, $out_19_1, $err_19_1);
        my $cmd_xargs_19_1 = 'chown';
        my $pid_19_1 = open3($in_19_1, $out_19_1, $err_19_1, $cmd_xargs_19_1, '-c', '--no-dereference', 'root:root', '--', @xargs_args_19_1);
        close $in_19_1 or croak 'Close failed: $OS_ERROR';
        my $xargs_result_19_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19_1> };
        close $out_19_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_19_1, 0;
        chomp $xargs_result_19_1;
        push @xargs_output_19_1, $xargs_result_19_1;
        }
        my $xargs_result_19_1 = join "\n", @xargs_output_19_1;
        if ($xargs_result_19_1 ne q{} && !( $xargs_result_19_1 =~ m{\n\z}msx )) { $xargs_result_19_1 .= "\n"; }
        $output_19 = $xargs_result_19_1;
        $output_19 = $xargs_result_19_1;
        if ($output_19 ne q{} && !defined $output_printed_19) {
            print $output_19;
            if (!($output_19 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_19 ) { $main_exit_code = 1; }
        }
    if ($CHILD_ERROR != 0) {
        1;
    }
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/var/lib/snapd/device/ownership-change.after.tmp'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    require File::Find;
    File::Find::find(sub {     print "$File::Find::name\n"; }, '/etc/cloud');
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>>', '/var/lib/snapd/device/ownership-change.after.tmp'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    require File::Find;
    File::Find::find(sub {     my $depth = ($File::Find::dir =~ tr/\///) + 1; next if $depth > 0;     print "$File::Find::name\n"; }, "/writable/" . "sys" . "tem" . "-data");
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if ( -e '/var/lib/snapd/device/ownership-change.after.tmp' ) {
    my $dest = '/var/lib/snapd/device/ownership-change.after';
    if ( -e $dest && -d $dest ) {
        my $source_name = '/var/lib/snapd/device/ownership-change.after.tmp';
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
    if ( File::Copy::move( '/var/lib/snapd/device/ownership-change.after.tmp', $dest ) ) {
    } else {
        croak
  "mv: cannot move '/var/lib/snapd/device/ownership-change.after.tmp' to $dest: $ERRNO\n";
    }
} else {
    croak "mv: '/var/lib/snapd/device/ownership-change.after.tmp': No such file or directory\n";
}
$main_exit_code = system('bash', 'sync') >> 8;

exit $main_exit_code;
