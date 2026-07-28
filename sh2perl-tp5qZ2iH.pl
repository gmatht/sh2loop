#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $localsite;
my $hook;
my $bc;
my $DEBIAN_FRONTEND;
my $files;

$__set_e = 1;
if ((!-f /etc/python3.12/sitecustomize.py)) {
print "\t# Empty sitecustomize.py to avoid a dangling symlink
";
}
my $group;
my $perm;
if ("$_[0]" =~ /^configure$/msx) {
    if ((-e '/etc/staff-group-for-usr-local')) {
        $perm = '2755';
        $group = 'staff';
}
    else {
        $perm = '755';
        $group = 'root';
    }
    if ((!-e /usr/local/lib/python3.12)) {
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
            use File::Path qw(make_path);
            my $err;
            if ( !-d '/usr/local/lib/python3.12' ) {
                make_path( '/usr/local/lib/python3.12', { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . '/usr/local/lib/python3.12' . ": $err->[0]\n";
                }
            }
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
;
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
chmod(oct($perm), ('/usr/local/lib/python3.12')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
;
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
do {
    my ($owner, $group) = split /:/, 'root:', 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ($group, '/usr/local/lib/python3.12') or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
;
    }
        $localsite = '/usr/local/lib/python3.12/dist-packages';
    if ((!-e $localsite)) {
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
            use File::Path qw(make_path);
            if ( !-d $localsite ) {
                make_path( $localsite, { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . $localsite . ": $err->[0]\n";
                }
            }
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
;
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
chmod(oct($perm), ($localsite)) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
;
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
do {
    my ($owner, $group) = split /:/, 'root:', 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ($group, $localsite) or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
;
    }
    if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'update-binfmts') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };)) {
        $main_exit_code = system('update-binfmts', '--import', 'python3.12') >> 8;
    }
}
my $filt;
my $version;
if ("$1" eq configure) {
if ( -e "/etc/python3.12/sysconfig.cfg" ) {
        if ( -d "/etc/python3.12/sysconfig.cfg" ) {
            carp "rm: carping: ", "/etc/python3.12/sysconfig.cfg",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/python3.12/sysconfig.cfg" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/python3.12/sysconfig.cfg",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my @ls_files_12 = ();
        my $ls_all_found_13 = 1;
        my @ls_inputs_14 = ();
        push @ls_inputs_14, '/usr/lib/python3.12/sitecustomize.py';
        my @ls_files_15 = ();
        my @ls_dirs_16 = ();
        my $ls_show_headers_17 = scalar(@ls_inputs_14) > 1;
        for my $ls_item_18 (@ls_inputs_14) {
            if ( -f $ls_item_18 ) {
                push @ls_files_15, $ls_item_18;
            }
            elsif ( -d $ls_item_18 ) {
                push @ls_dirs_16, $ls_item_18;
            }
            else {
                $ls_all_found_13 = 0;
            }
        }
        @ls_files_15 = sort { $a cmp $b } @ls_files_15;
        @ls_dirs_16 = sort { $a cmp $b } @ls_dirs_16;
        if (@ls_files_15) {
            push @ls_files_12, join("\n", @ls_files_15);
        }
        for my $ls_dir_19 (@ls_dirs_16) {
            my @ls_dir_entries_20 = ();
            if ( opendir my $dh, $ls_dir_19 ) {
                while ( my $file = readdir $dh ) {
                    next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/;
                    push @ls_dir_entries_20, $file;
                }
                closedir $dh;
                @ls_dir_entries_20 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}; $s } ] } @ls_dir_entries_20;
                if ( $ls_show_headers_17 ) {
                    if ( @ls_dir_entries_20 ) {
                        push @ls_files_12, $ls_dir_19 . ":\n" . join("\n", @ls_dir_entries_20);
                    } else {
                        push @ls_files_12, $ls_dir_19 . ':';
                    }
                }
                elsif ( @ls_dir_entries_20 ) {
                    push @ls_files_12, join("\n", @ls_dir_entries_20);
                }
            }
            else {
                $ls_all_found_13 = 0;
            }
        }
        if (@ls_files_12) {
            print join "\n", @ls_files_12;
            print "\n";
        }
        if ( $ls_all_found_13 ) {
            local $CHILD_ERROR = 0;
            $ls_success = 1;
        }
        else {
            local $CHILD_ERROR = 2;
            $ls_success = 0;
            $main_exit_code = $CHILD_ERROR;
        }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };)) {
        $filt = 'cat';
}
    else {
        $filt = 'fgrep -v sitecustomize.py';
    }
    $files = do {
    do { do {
        my $output_21 = q{};
        my $output_printed_21;
        my $pipeline_success_21 = 1;

        my ($in_22, $out_22);
        my $pid_22 = open3($in_22, $out_22, '>&STDERR', 'dpkg', '-L', 'libpython3.12-minimal:arm64');
        close $in_22 or croak 'Close failed: $OS_ERROR';
        $output_21 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_22> };
        close $out_22 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_22, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_21 = 0; }
        my @sed_lines_21 = split /\n/, $output_21;
        my @sed_result_21;
        foreach my $line (@sed_lines_21) {
        chomp $line;
        push @sed_result_21, $line;
        }
        $output_21 = join "\n", @sed_result_21;


        my $cmd_24 = 'unknown_command';
        my ($in_23, $out_23);
        my $pid_23 = open3($in_23, $out_23, '>&STDERR', $cmd_24, );
        print {$in_23} $output_21;
        close $in_23 or croak 'Close failed: $OS_ERROR';
        $output_21 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
        close $out_23 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_23, 0;
        if ( !$pipeline_success_21 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_21 =~ s/\n+\z//msx;
        $output_21;
}; };
};
if ("$files" ne q{}) {
        $main_exit_code = system('/usr/bin/python3.12', '-E', '-S', '/usr/lib/python3.12/py_compile.py', $files) >> 8;
if (!(my $grep_result_25;
my @grep_lines_25 = ();
my @grep_filenames_25 = ();
my @glob_files_25 = glob('^byte-compile[^#]*optimize');
for my $glob_file (@glob_files_25) {
    if (-f $glob_file) {
        open my $fh, '<', $glob_file or die "Cannot open $glob_file: $ERRNO";
        while (my $line = <$fh>) {
            chomp $line;
            push @grep_lines_25, $line;
            push @grep_filenames_25, $glob_file;
        }
        close $fh
            or croak "Close failed: $OS_ERROR";
    }
}
if (-e "/etc/python/debian_config") {
    open my $fh, '<', "/etc/python/debian_config" or croak "Cannot access file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_25, $line;
        push @grep_filenames_25, "/etc/python/debian_config";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/python/debian_config: No such file or directory\n"; }
my @grep_filtered_25 = grep { /q/msx } @grep_lines_25;
$grep_result_25 = join "\n", @grep_filtered_25;
        if (!($grep_result_25 =~ m{\n\z} || $grep_result_25 eq q{})) {
            $grep_result_25 .= "\n";
        }
print $grep_result_25;
$CHILD_ERROR = scalar @grep_filtered_25 > 0 ? 0 : 1)) {
            $main_exit_code = system('/usr/bin/python3.12', '-E', '-S', '-O', '/usr/lib/python3.12/py_compile.py', $files) >> 8;
        }
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            say "python3.12-minimal: can't get files for byte-compilation";
        };
    }
    $bc = 'no';
if (my $grep_result_26;
my @grep_lines_26 = ();
my @grep_filenames_26 = ();
my @glob_files_26 = glob('^supported-versions[^#]*python3.12');
for my $glob_file (@glob_files_26) {
    if (-f $glob_file) {
        open my $fh, '<', $glob_file or die "Cannot open $glob_file: $ERRNO";
        while (my $line = <$fh>) {
            chomp $line;
            push @grep_lines_26, $line;
            push @grep_filenames_26, $glob_file;
        }
        close $fh
            or croak "Close failed: $OS_ERROR";
    }
}
if (-e "/usr/share/python/debian_defaults") {
    open my $fh, '<', "/usr/share/python/debian_defaults" or croak "Cannot access file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_26, $line;
        push @grep_filenames_26, "/usr/share/python/debian_defaults";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /usr/share/python/debian_defaults: No such file or directory\n"; }
my @grep_filtered_26 = grep { /q/msx } @grep_lines_26;
$grep_result_26 = join "\n", @grep_filtered_26;
    if (!($grep_result_26 =~ m{\n\z} || $grep_result_26 eq q{})) {
        $grep_result_26 .= "\n";
    }
print $grep_result_26;
$CHILD_ERROR = scalar @grep_filtered_26 > 0 ? 0 : 1) {
        $bc = 'no';
    }
if ("$bc" eq yes) {
if ("$DEBIAN_FRONTEND" ne noninteractive) {
            say "Linking and byte-compiling packages for runtime python3.12...";
        }
        $version = do {
    do { do {
            my $output_27 = q{};
            my $output_printed_27;
            my $pipeline_success_27 = 1;

            my ($in_28, $out_28);
            my $pid_28 = open3($in_28, $out_28, '>&STDERR', 'dpkg', '-s', 'python3.12-minimal');
            close $in_28 or croak 'Close failed: $OS_ERROR';
            $output_27 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_28> };
            close $out_28 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_28, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_27 = 0; }
            my @lines = split /\n/, $output_27;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                if (!(/^Version:/)) { next; }
                push @result, ($fields[1] . "\n");
            }
            $output_27 = join "", @result;

            if ( !$pipeline_success_27 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_27 =~ s/\n+\z//msx;
            $output_27;
}; };
};
        for my $hook ('/usr/share/python3/runtime.d/*.rtinstall') {
            if (!((-x $hook))) {
                next;
            }
            $CHILD_ERROR = 0;
        }
if ((-f '/var/lib/python/python3.12_installed')) {
if ( -e "/var/lib/python/python3.12_installed" ) {
                if ( -d "/var/lib/python/python3.12_installed" ) {
                    carp "rm: carping: ", "/var/lib/python/python3.12_installed",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "/var/lib/python/python3.12_installed" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "/var/lib/python/python3.12_installed",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
rmdir ('/var/lib/python') or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
            };
        }
    }
}
exit 0;
