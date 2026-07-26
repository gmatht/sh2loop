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

my $RAR;
my @RAR;
my %RAR;
my $UNRAR;
my @UNRAR;
my %UNRAR;
my $MC_TEST_EXTFS_UNRAR_VERSION;
my @MC_TEST_EXTFS_UNRAR_VERSION;
my %MC_TEST_EXTFS_UNRAR_VERSION;

my $MAGIC_77 = 77;

$RAR = 'rar';
$UNRAR = do { my @_qx_cmd = ("which unrar 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ($UNRAR eq q{}) {
        $UNRAR = $RAR;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if (((!-x $UNRAR) && (-x $RAR))) {
        $UNRAR = $RAR;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
$UNRAR = (defined ($ENV{MC_TEST_EXTFS_LIST_CMD} // q{}) && ($ENV{MC_TEST_EXTFS_LIST_CMD} // q{}) ne q{} ? ($ENV{MC_TEST_EXTFS_LIST_CMD} // q{}) : '$UNRAR');
if ("$MC_TEST_EXTFS_UNRAR_VERSION" ne q{}) {
    my $UNRAR_VERSION;
    my @UNRAR_VERSION;
    my %UNRAR_VERSION;
    $UNRAR_VERSION = $MC_TEST_EXTFS_UNRAR_VERSION;
}
else {
    $UNRAR_VERSION = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;

        my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'unknown_command', '-c', 'fg-', '-?');
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
        my $grep_result_0_1;
        my @grep_lines_0_1 = split /\n/msx, $output_0;
        my @grep_filtered_0_1 = grep { /Copyright/msx } @grep_lines_0_1;
        $grep_result_0_1 = join "\n", @grep_filtered_0_1;
                if (!($grep_result_0_1 =~ m{\n\z}msx || $grep_result_0_1 eq q{})) {
                    $grep_result_0_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_0_1 > 0 ? 0 : 1;
        $output_0 = $grep_result_0_1;
        my @sed_lines_0 = split /\n/msx, $output_0;
        my @sed_result_0;
        foreach my $line (@sed_lines_0) {
        chomp $line;
        push @sed_result_0, $line;
        }
        $output_0 = join "\n", @sed_result_0;

        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        $output_0 =~ s/\n+\z//msx;
        $output_0;
}; $_pipeline_result; };
}

sub mcrar4fs_list {
    my ($file) = @_;
    # Original bash: $UNRAR v -c- -cfg- "$1" | awk -v uid=`id -u` -v gid=`id -g` '
{
        my $output_2 = q{};
        my $output_printed_2;
        my $pipeline_success_2 = 1;
                my ($in_3, $out_3);
        my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'unknown_command', q{v}, '-c', q{-}, '-c', 'fg-');
        close $in_3 or croak 'Close failed: $OS_ERROR';
        $output_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
        close $out_3 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_3, 0;

                my @lines = split /\n/msx, $output_2;
        my @result;
        foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        if (!(BEGIN)) { next; }
        push @result, (f "%s 1 %s %s %d %02d/%02d/%02d %s ./%s
        " . $fields[5] . uid . gid . $fields[0] . a[2] . a[1] . a[3] . $fields[4] . str . "\n");
        }
        $output_2 = join "", @result;
        if ($output_2 ne q{} && !defined $output_printed_2) {
            print $output_2;
            if (!($output_2 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
        }
    return;
}

sub mcrar5fs_list {
    my ($file) = @_;
    # Original bash: $UNRAR vt -c- -cfg- "$1" | awk -F ':' -v uid=`id -u` -v gid=`id -g` '
{
        my $output_4 = q{};
        my $output_printed_4;
        my $pipeline_success_4 = 1;
                my ($in_5, $out_5);
        my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'unknown_command', 'vt', '-c', q{-}, '-c', 'fg-');
        close $in_5 or croak 'Close failed: $OS_ERROR';
        $output_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
        close $out_5 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_5, 0;

                my @lines = split /\n/msx, $output_4;
        my @result;
        foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /:/msx, $line;
        push @result, (f below
        split (date[1] . date . "-");
        ### mc seems to be able to parse 4 digit years too . so remove if tested
        # sub ("^.." . q{} . date[1]); ### cut year to 2 digits only
        ### check/adjust rights
        if (index (attrs . "D") != 0) {
        attrs = "drwxr-xr-x";
        } else {
        if (index (attrs . ".\") != 0) {\n                attrs = \"-rw-r--r--\";\n            }\n        }\n\n        ### and finally\n        printf (\"%s 1 %s %s %d %02d/%02d/%02d %s ./%s\n" . attrs . uid . gid . size . date[2] . date[3] . date[1] . time . name) . "\n");
        }
        $output_4 = join "", @result;
        if ($output_4 ne q{} && !defined $output_printed_4) {
            print $output_4;
            if (!($output_4 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
        }
    return;
}

sub mcrarfs_list {
        if ((x$UNRAR_VERSION eq x6 || x$UNRAR_VERSION eq x5)) {
                mcrar5fs_list("@ARGV");
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
                mcrar4fs_list("@ARGV");
    }
    return;
}

sub mcrarfs_copyin {
    my ($file) = @_;
    my $pwd;
    my @pwd;
    my %pwd;
    $pwd = do { use Cwd; getcwd(); };
    use File::Path qw(make_path);
    my $err;
    if ( mkdir "$_[2].dir" ) {
        }
    else {
        croak "mkdir: cannot create directory " . "$_[2].dir" . ": File exists\n";
    }
    chdir("$_[2].dir");
    $CHILD_ERROR = 0;
    my $di;
    my @di;
    my %di;
    $di = ( ( dirname($_[1]) ) =~ s|/[^/]*$||sr );
if ((!x StringInterpolation(StringInterpolation { parts: [Variable("di")] }, None) eq x StringInterpolation(StringInterpolation { parts: [ParameterExpansion(ParameterExpansion { variable: "2", operator: Basename, is_mutable: true })] }, None))) {
        use File::Path qw(make_path);
        if ( !-d "$di" ) {
            make_path( "$di", { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . "$di" . ": $err->[0]\n";
            }
        }
    }
    use File::Copy qw(copy);
    if ( -e q{p} ) {
        if ( -d "$_[2].dir/$_[1]" ) {
            require File::Copy; File::Copy::copy(q{p}, "$_[2].dir/$_[1]" . '/' . (q{p} =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy(q{p}, "$_[2].dir/$_[1]");
        }
    } else {
        croak "cp: cannot stat '-f': No such file or directory\n";
    }
    if ( -e "$_[2]" ) {
        if ( -d "$_[2].dir/$_[1]" ) {
            require File::Copy; File::Copy::copy("$_[2]", "$_[2].dir/$_[1]" . '/' . ("$_[2]" =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy("$_[2]", "$_[2].dir/$_[1]");
        }
    } else {
        croak "cp: cannot stat '-f': No such file or directory\n";
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $CHILD_ERROR = 0;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    chdir("$pwd");
    $CHILD_ERROR = 0;
if ( -e "$_[2].dir" ) {
        if ( -d "$_[2].dir" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$_[2].dir", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "$_[2].dir", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$_[2].dir" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$_[2].dir",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}

sub mcrarfs_copyout {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$_[2]"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $CHILD_ERROR = 0;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub mcrarfs_mkdir {
    my ($file) = @_;
    my $pwd;
    my @pwd;
    my %pwd;
    $pwd = do { use Cwd; getcwd(); };
        my $dir;
    my @dir;
    my %dir;
    $dir = do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'mktemp', '-d', (defined (defined ($ENV{MC_TMPDIR} // q{}) && ($ENV{MC_TMPDIR} // q{}) ne q{} ? ($ENV{MC_TMPDIR} // q{}) : '/tmp') && (defined ($ENV{MC_TMPDIR} // q{}) && ($ENV{MC_TMPDIR} // q{}) ne q{} ? ($ENV{MC_TMPDIR} // q{}) : '/tmp') ne q{} ? (defined ($ENV{MC_TMPDIR} // q{}) && ($ENV{MC_TMPDIR} // q{}) ne q{} ? ($ENV{MC_TMPDIR} // q{}) : '/tmp') : '/tmp') . "/mctmpdir-urar.XXXXXX");
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
};
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
    chdir("$dir");
    $CHILD_ERROR = 0;
    use File::Path qw(make_path);
    my $err;
    if ( !-d "$_[1]" ) {
        make_path( "$_[1]", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . "$_[1]" . ": $err->[0]\n";
        }
    }
    if ( -e "$_[1]" ) {
        my $current_time = time;
        utime $current_time, $current_time, "$_[1]";
    }
    else {
        if ( open my $fh, '>', "$_[1]" ) {
            close $fh or croak "Close failed: $ERRNO";
        }
        else {
            croak "touch: cannot create ", "$_[1]",
              ": $ERRNO\n";
        }
    }
    if ( -e "/.rarfs" ) {
        my $current_time = time;
        utime $current_time, $current_time, "/.rarfs";
    }
    else {
        if ( open my $fh, '>', "/.rarfs" ) {
            close $fh or croak "Close failed: $ERRNO";
        }
        else {
            croak "touch: cannot create ", "/.rarfs",
              ": $ERRNO\n";
        }
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $CHILD_ERROR = 0;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $CHILD_ERROR = 0;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    chdir("$pwd");
    $CHILD_ERROR = 0;
if ( -e "$dir" ) {
        if ( -d "$dir" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$dir", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "$dir", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$dir" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$dir",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}

sub mcrarfs_rm {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $CHILD_ERROR = 0;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}
$main_exit_code = system('umask', '077') >> 8;
my $cmd;
my @cmd;
my %cmd;
$cmd = "$_[0]";
# Builtin command 'shift' not implemented
if ("$cmd" =~ /^list$/msx) {
        # Original bash: mcrarfs_list    "$@" | sort -k 8 ;;
{
        my $output_12 = q{};
        my $output_printed_12;
        my $pipeline_success_12 = 1;
                my ($in_13, $out_13);
        my $pid_13 = open3($in_13, $out_13, '>&STDERR', 'mcrarfs_list', );
        close $in_13 or croak 'Close failed: $OS_ERROR';
        $output_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
        close $out_13 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_13, 0;

                my @sort_lines_12_1 = split /\n/msx, $output_12;
        my @sort_sorted_12_1 = sort {
        my @a_fields = split /\s+/msx, $a;
        my @b_fields = split /\s+/msx, $b;
        my $a_key = (scalar @a_fields > 7) ? $a_fields[7] : q{};
        my $b_key = (scalar @b_fields > 7) ? $b_fields[7] : q{};
        $a_key cmp $b_key || $a cmp $b
        } @sort_lines_12_1;
        my $output_12_1 = join "\n", @sort_sorted_12_1;
        if ($output_12_1 ne q{} && !($output_12_1 =~ m{\n\z}msx)) {
        $output_12_1 .= "\n";
        }
        $output_12 = $output_12_1;
        $output_12 = $output_12_1;
        if ($output_12 ne q{} && !defined $output_printed_12) {
            print $output_12;
            if (!($output_12 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
        }
} elsif ("$cmd" =~ /^rm$/msx) {
        mcrarfs_rm("@ARGV");
} elsif ("$cmd" =~ /^rmdir$/msx) {
        mcrarfs_rm("@ARGV");
} elsif ("$cmd" =~ /^mkdir$/msx) {
        mcrarfs_mkdir("@ARGV");
} elsif ("$cmd" =~ /^copyin$/msx) {
        mcrarfs_copyin("@ARGV");
} elsif ("$cmd" =~ /^copyout$/msx) {
        mcrarfs_copyout("@ARGV");
} elsif (1) {
    exit 1;
}
exit 0;

exit $main_exit_code;
