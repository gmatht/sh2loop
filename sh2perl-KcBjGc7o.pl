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

if ((Variable("#", false, None) == 0)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "usage: $PROGRAM_NAME shellname [shellname ...]";
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
my $file;
my @file;
my %file;
$file = "$ENV{DPKG_ROOT}/etc/shells";
my $tmpfile;
my @tmpfile;
my %tmpfile;
$tmpfile = ${file} . ".tmp";
my $otmpfile;
my @otmpfile;
my %otmpfile;
$otmpfile = ${file} . ".tmp2";
# set -o noclobber not implemented
# set noclobber not implemented

sub cleanup {
if ( -e "$tmpfile" ) {
        if ( -d "$tmpfile" ) {
            carp "rm: carping: ", "$tmpfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$tmpfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "$otmpfile" ) {
        if ( -d "$otmpfile" ) {
            carp "rm: carping: ", "$otmpfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$otmpfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$otmpfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'cleanup 2>&1'; print $end_out if $end_out ne q{}; }
if (!(!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', "$tmpfile"
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$file" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$file" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};))) {
print "Either another instance of $0 is running, or it was previously interrupted.
Please examine ${tmpfile} to see if it should be moved onto ${file}.
";
exit 1;
}
my $i;
for my $i () {
    my $REALDIR;
    my @REALDIR;
    my %REALDIR;
    $REALDIR = (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname((do { my $_chomp_temp = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'realpath', '-m', "$i");
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
}; chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) . "/" . (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename("$i"); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
    my $j;
    for my $j ("$i", "$REALDIR") {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$otmpfile"
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_2;
my @grep_lines_2 = ();
my @grep_filtered_2 = grep { !/^"\ .\ ${j}\ .\ "$/msx } @grep_lines_2;
$grep_result_2 = join "\n", @grep_filtered_2;
            if (!($grep_result_2 =~ m{\n\z}msx || $grep_result_2 eq q{})) {
                $grep_result_2 .= "\n";
            }
print $grep_result_2;
$CHILD_ERROR = scalar @grep_filtered_2 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
        my $err;
        my $force = 0;
        if ( -e "$otmpfile" ) {
            my $dest = "$tmpfile";
            if ( -e $dest && -d $dest ) {
                my $source_name = "$otmpfile";
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
            if ( File::Copy::move( "$otmpfile", $dest ) ) {
            } else {
                croak
  "mv: cannot move "$otmpfile" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "$otmpfile": No such file or directory\n";
        }
    }
}
$CHILD_ERROR = 0;
if ($CHILD_ERROR != 0) {
    chmod(oct(do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'stat', '-c', '%a', ${file});
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
}), (${tmpfile})) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
$CHILD_ERROR = 0;
if ($CHILD_ERROR != 0) {
    do {
    my ($owner, $group) = split /:/, do {
    my ($in_10, $out_10);
    my $pid_10 = open3($in_10, $out_10, '>&STDERR', 'stat', '-c', '%U', ${file});
    close $in_10 or croak 'Close failed: $OS_ERROR';
    my $result_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
    close $out_10 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_10, 0;
    $result_10
}, 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, (${tmpfile}) or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
}
do {
    my $mv_cmd_str = 'mv -Z "${tmpfile}" "${file}"';
    system $mv_cmd_str;
};
if ($CHILD_ERROR != 0) {
        if ( -e "${tmpfile}" ) {
        my $dest = ${file};
        if ( -e $dest && -d $dest ) {
            my $source_name = "${tmpfile}";
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
        if ( File::Copy::move( "${tmpfile}", $dest ) ) {
        } else {
            croak
  "mv: cannot move "${tmpfile}" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "${tmpfile}": No such file or directory\n";
    }
}
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx' 2>&1'; print $end_out if $end_out ne q{}; }
exit 0;

exit $main_exit_code;
