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

my $TEST_IMPORT;
my @TEST_IMPORT;
my %TEST_IMPORT;
my $rootmnt;
my @rootmnt;
my %rootmnt;

$__set_e = 1;

sub panic {
    print "PANIC: @ARGV\n";
exit 1;
    return;
}

sub sync_dirs {
    my ($file) = @_;
    my $base;
    my @base;
    my %base;
    $base = "$_[0]";
# Builtin command 'source' not implemented
    my $target;
    my @target;
    my %target;
    $target = "$_[2]";
    my $OLD_PWD;
    my @OLD_PWD;
    my %OLD_PWD;
    $OLD_PWD = "$ENV{PWD}";
    chdir("$base");
    $CHILD_ERROR = 0;
    my $file;
    for my $file ("$ENV{source}", '/*') {
        if (((!-e "$base/$file") && (!-L "$base/$file"))) {
            next;            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if (do {
if (((-e "$target/$file") || (-l "$target/$file"))) {
    (!-d "$target/$file")    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
            $CHILD_ERROR == 0
        }) {
            next;        }
if (((!-e "$target/$file") && (!-L "$target/$file"))) {
            use File::Copy qw(copy);
            if (-d "$target/$file") {
                require File::Path; File::Path::make_path("$target/$file" . '/' . ("$base/$file" =~ m|([^/]+)$|)[0]);
                require File::Copy; File::Copy::copy("$base/$file", "$target/$file" . '/' . ("$base/$file" =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy("$base/$file", "$target/$file");
            }
next;
        }
        if ((-d "$file")) {
                        $main_exit_code = system('sync_dirs', "$base", "$file", "$target") >> 8;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    }
    chdir("$OLD_PWD");
    $CHILD_ERROR = 0;
    return;
}

sub handle_writable_paths {
    my ($file) = @_;
    my $writable_paths;
    my @writable_paths;
    my %writable_paths;
    $writable_paths = "$_[0]";
    my $fstab;
    my @fstab;
    my %fstab;
    $fstab = "$_[1]";
    if (!("$writable_paths" ne q{})) {
                panic("need writeable paths");
    }
    if (!((-e "$writable_paths"))) {
                panic("writeable paths does not exist");
    }
    if (!("$fstab" ne q{})) {
                panic("need fstab");
    }
    # Original bash: cat "$writable_paths" | while read line; do
{
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
                $output_1 = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$writable_paths" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$writable_paths" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };

                my @lines = split /\n/msx, $output_1;
        my $result_1_1 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        # set -- not implemented
        if (do {
        do {
        local %ENV = %ENV;
        my $writable_paths = $writable_paths;
        my $fstab = $fstab;
        if (!("$1" eq q{})) {
        "$2" eq q{}    }
        if ($CHILD_ERROR != 0) {
        "$3" eq q{}    }
        if ($CHILD_ERROR != 0) {
        "$4" eq q{}    }
        if ($CHILD_ERROR != 0) {
        "$5" eq q{}    }
        q{};
        };
        $CHILD_ERROR == 0
        }) {
        next;        }
        if ("$_[0]" =~ /^/.*$/msx) {
        } elsif (1) {
        next;        }
        my $dstpath;
        my @dstpath;
        my %dstpath;
        $dstpath = ${rootmnt} . "$_[0]";
        if ((!-e "$dstpath")) {
        next;            $CHILD_ERROR = 0;
        } else {
        $CHILD_ERROR = 1;
        }
        if ("$3" eq "temporary") {
        do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$fstab"
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_2 = q{};
        $tmp_redirect_2 .= "tmpfs $_[0] tmpfs $_[4] 0 0\n";
        if ( !($tmp_redirect_2 =~ m{\n\z}msx) ) { $tmp_redirect_2 .= "\n"; }
        $CHILD_ERROR = 0;
        $tmp_redirect_2;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_1; }
        $output_printed_1 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        }
        else {
        if (("$3" eq "persistent" || "$3" eq "synced")) {
        if ("$2" eq "auto") {
        my $srcpath;
        my @srcpath;
        my %srcpath;
        $srcpath = ${rootmnt} . "/writable/" . "sys" . "tem" . "-data" . $_[0];
        my $path;
        my @path;
        my %path;
        $path = "/writable/" . "sys" . "tem" . "-data" . $_[0];
        }
        else {
        $srcpath = ${rootmnt} . "/writable/$_[1]";
        $path = "/writable/$_[1]";
        }
        if ((!-e "$srcpath")) {
        my $dstown;
        my @dstown;
        my %dstown;
        $dstown = do {
        my ($in_4, $out_4);
        my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'stat', '-c', "%u:%g", "$dstpath");
        close $in_4 or croak 'Close failed: $OS_ERROR';
        my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
        close $out_4 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_4, 0;
        $result_4
        };
        my $dstmode;
        my @dstmode;
        my %dstmode;
        $dstmode = do {
        my ($in_5, $out_5);
        my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'stat', '-c', "%a", "$dstpath");
        close $in_5 or croak 'Close failed: $OS_ERROR';
        my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
        close $out_5 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_5, 0;
        $result_5
        };
        use File::Path qw(make_path);
        my $err;
        if ( !-d dirname(${srcpath}) ) {
        make_path( dirname(${srcpath}), { error => \$err } );
        if ( @{$err} ) {
        croak "mkdir: cannot create directory " . dirname(${srcpath}) . ": $err->[0]\n";
        }
        }
        if ((!-d "$dstpath")) {
        if ("$4" eq "transition") {
        use File::Copy qw(copy);
        if ( -e "$dstpath" ) {
        if ( -d "$srcpath" ) {
        require File::Copy; File::Copy::copy("$dstpath", "$srcpath" . '/' . ("$dstpath" =~ m|([^/]+)$|)[0]);
        } else {
        require File::Copy; File::Copy::copy("$dstpath", "$srcpath");
        }
        } else {
        croak "cp: cannot stat '-a': No such file or directory\n";
        }
        }
        else {
        if ( -e "$srcpath" ) {
        my $current_time = time;
        utime $current_time, $current_time, "$srcpath";
        }
        else {
        if ( open my $fh, '>', "$srcpath" ) {
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        croak "touch: cannot create ", "$srcpath",
        ": $ERRNO\n";
        }
        }
        do {
        my ($owner, $group) = split /:/, "$dstown", 2;
        my $uid = getpwnam($owner);
        my $gid = defined($group) ? getgrnam($group) : -1;
        chown $uid, $gid, ("$srcpath") or warn "chown failed: $OS_ERROR\n";
        $CHILD_ERROR = 0;
        };
        chmod(oct("$dstmode"), ("$srcpath")) or warn "chmod failed: $OS_ERROR\n";
        $CHILD_ERROR = 0;
        }
        }
        else {
        if (("$4" eq "transition" || "$3" eq "synced")) {
        use File::Copy qw(copy);
        if (-d "$srcpath") {
        require File::Path; File::Path::make_path("$srcpath" . '/' . ("$dstpath" =~ m|([^/]+)$|)[0]);
        require File::Copy; File::Copy::copy("$dstpath", "$srcpath" . '/' . ("$dstpath" =~ m|([^/]+)$|)[0]);
        } else {
        require File::Copy; File::Copy::copy("$dstpath", "$srcpath");
        }
        }
        else {
        use File::Path qw(make_path);
        if ( mkdir "$srcpath" ) {
        }
        else {
        croak "mkdir: cannot create directory " . "$srcpath" . ": File exists\n";
        }
        do {
        my ($owner, $group) = split /:/, "$dstown", 2;
        my $uid = getpwnam($owner);
        my $gid = defined($group) ? getgrnam($group) : -1;
        chown $uid, $gid, ("$srcpath") or warn "chown failed: $OS_ERROR\n";
        $CHILD_ERROR = 0;
        };
        chmod(oct("$dstmode"), ("$srcpath")) or warn "chmod failed: $OS_ERROR\n";
        $CHILD_ERROR = 0;
        }
        }
        }
        else {
        if ("$3" eq "synced") {
        sync_dirs("$dstpath", q{.}, "$srcpath");
        }
        }
        if ($arg1 =~ /^/etc.*$/msx) {
        if (!((-e "${rootmnt}/writable/system-data/$1"))) {
        use File::Path qw(make_path);
        if ( !-d ${rootmnt} . "/writable/" . "sys" . "tem" . "-data/$_[0]" ) {
        make_path( ${rootmnt} . "/writable/" . "sys" . "tem" . "-data/$_[0]", { error => \$err } );
        if ( @{$err} ) {
        croak "mkdir: cannot create directory " . ${rootmnt} . "/writable/" . "sys" . "tem" . "-data/$_[0]" . ": $err->[0]\n";
        }
        }
        }
        $main_exit_code = system('mount', '-o', 'bind', ${rootmnt} . "/writable/" . "sys" . "tem" . "-data/$_[0]", ${rootmnt} . "/$_[0]") >> 8;
        } elsif (1) {
        if ("$5" eq "none") {
        do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$fstab"
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_16 = q{};
        $tmp_redirect_16 .= "$path $_[0] none bind 0 0\n";
        if ( !($tmp_redirect_16 =~ m{\n\z}msx) ) { $tmp_redirect_16 .= "\n"; }
        $CHILD_ERROR = 0;
        $tmp_redirect_16;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_1; }
        $output_printed_1 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        }
        else {
        do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$fstab"
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_18 = q{};
        $tmp_redirect_18 .= "$path $_[0] none bind,$_[4] 0 0\n";
        if ( !($tmp_redirect_18 =~ m{\n\z}msx) ) { $tmp_redirect_18 .= "\n"; }
        $CHILD_ERROR = 0;
        $tmp_redirect_18;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_1; }
        $output_printed_1 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        }
        }
        }
        else {
        next;
        }
        }
        }
        $output_1 = $result_1_1;
        if ($output_1 ne q{} && !defined $output_printed_1) {
            print $output_1;
            if (!($output_1 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
    $main_exit_code = system('bash', 'handle_writable_defaults') >> 8;
    return;
}

sub handle_writable_defaults {
    my $srcpath;
    my @srcpath;
    my %srcpath;
    $srcpath = ${rootmnt} . "/writable/" . "sys" . "tem" . "-data/_writable_defaults";
if (((!-d "$srcpath") || (-e "${srcpath}/.done"))) {
return;
    }
    my $dstpath;
    my @dstpath;
    my %dstpath;
    $dstpath = ${rootmnt} . "/writable/" . "sys" . "tem" . "-data";
    my $fileordir;
    for my $fileordir ("$srcpath", '/*') {
        if (do {
if ((!-e "$fileordir")) {
    (!-L "$fileordir")    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
            $CHILD_ERROR == 0
        }) {
            next;        }
        use File::Copy qw(copy);
        if ( -e "$fileordir" ) {
            if ( -d "$dstpath" ) {
                require File::Copy; File::Copy::copy("$fileordir", "$dstpath" . '/' . ("$fileordir" =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy("$fileordir", "$dstpath");
            }
        } else {
            croak "cp: cannot stat '-a': No such file or directory\n";
        }
    }
    if ( -e "$srcpath/.done" ) {
        my $current_time = time;
        utime $current_time, $current_time, "$srcpath/.done";
    }
    else {
        if ( open my $fh, '>', "$srcpath/.done" ) {
            close $fh or croak "Close failed: $ERRNO";
        }
        else {
            croak "touch: cannot create ", "$srcpath/.done",
              ": $ERRNO\n";
        }
    }
    return;
}

sub main {
    my $writable_paths;
    my @writable_paths;
    my %writable_paths;
    $writable_paths = (defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '${rootmnt}/etc/system-image/writable-paths') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '${rootmnt}/etc/system-image/writable-paths') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '${rootmnt}/etc/system-image/writable-paths') : '${rootmnt}/etc/system-image/writable-paths');
    my $fstab;
    my @fstab;
    my %fstab;
    $fstab = (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : '${rootmnt}/etc/fstab') && (defined $_[1] && $_[1] ne q{} ? $_[1] : '${rootmnt}/etc/fstab') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : '${rootmnt}/etc/fstab') : '${rootmnt}/etc/fstab');
if ((-e "$writable_paths")) {
        if ( -e "${rootmnt} . "/run/image.fstab"" ) {
            my $current_time = time;
            utime $current_time, $current_time, "${rootmnt} . "/run/image.fstab"";
        }
        else {
            if ( open my $fh, '>', "${rootmnt} . "/run/image.fstab"" ) {
                close $fh or croak "Close failed: $ERRNO";
            }
            else {
                croak "touch: cannot create ", "${rootmnt} . "/run/image.fstab"",
                  ": $ERRNO\n";
            }
        }
                $main_exit_code = system('mount', '-o', 'bind', ${rootmnt} . "/run/image.fstab", "$fstab") >> 8;
        if ($CHILD_ERROR != 0) {
                        panic("Cannot bind mount fstab");
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$fstab"
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "# Auto-generated by $PROGRAM_NAME";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$fstab"
      or die "Cannot open file: $OS_ERROR\n";
            print "# DO NOT EDIT THIS FILE BY HAND - YOUR CHANGES WILL BE OVERWRITTEN\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$fstab"
      or die "Cannot open file: $OS_ERROR\n";
            print "# (See writable-paths(5) for details)\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$fstab"
      or die "Cannot open file: $OS_ERROR\n";
            print "/dev/root / rootfs defaults,ro 0 0\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        handle_writable_paths("$writable_paths", "$fstab");
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$fstab"
      or die "Cannot open file: $OS_ERROR\n";
            print "/run/mnt/ubuntu-seed /var/lib/snapd/seed none bind,ro 0 0\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    $main_exit_code = system('bash', 'sync') >> 8;
    return;
}
if ("$TEST_IMPORT" eq "1") {
return;
}
$rootmnt = "$_[0]";
if ("$rootmnt" eq q{}) {
    print "need rootmnt as the first argument\n";
exit 1;
}
main("$_[1]", "$_[2]");

exit $main_exit_code;
