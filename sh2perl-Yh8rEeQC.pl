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

my $LC_ALL;
my @LC_ALL;
my %LC_ALL;
$LC_ALL = q{C};
$ENV{LC_ALL} = $LC_ALL;
my $version;
my @version;
my %version;
$version = "znew (gzip) 1.12
Copyright (C) 2010-2018 Free Software Foundation, Inc.
This is free software.  You may redistribute copies of it under the terms of
the GNU General Public License <https://www.gnu.org/licenses/gpl.html>.
There is NO WARRANTY, to the extent permitted by law.

Written by Jean-loup Gailly.";
my $usage;
my @usage;
my %usage;
$usage = "Usage: $PROGRAM_NAME [OPTION]... [FILE]...
Recompress files from .Z (compress) format to .gz (gzip) format.

Options:

  -f     Force recompression even if a .gz file already exists.
  -t     Test the new files before deleting originals.
  -v     Verbose; display name and statistics for each file compressed.
  -9     Use the slowest compression method (optimal compression).
  -P     Use pipes for the conversion to reduce disk space usage.
  -K     Keep a .Z file when it is smaller than the .gz file; implies -t.
      --help     display this help and exit
      --version  output version information and exit

Report bugs to <bug-gzip@gnu.org>.";
my $check;
my @check;
my %check;
$check = q{0};
my $pipe;
my @pipe;
my %pipe;
$pipe = q{0};
my $opt;
my @opt;
my %opt;
$opt = q{};
my $files;
my @files;
my %files;
$files = q{};
my $keep;
my @keep;
my %keep;
$keep = q{0};
my $res;
my @res;
my %res;
$res = q{0};
my $old;
my @old;
my %old;
$old = q{0};
my $new;
my @new;
my %new;
$new = q{0};
my $block;
my @block;
my %block;
$block = '1024';
delete $ENV{GZIP};
my $ext;
my @ext;
my %ext;
$ext = '.gz';
my $arg;
for my $arg () {
if ("$arg" =~ /^--help$/msx) {
                printf("%s\n", "$usage");
        if ($CHILD_ERROR != 0) {
            exit 1;
        }
        exit $main_exit_code;
    } elsif ("$arg" =~ /^--version$/msx) {
                printf("%s\n", "$version");
        if ($CHILD_ERROR != 0) {
            exit 1;
        }
        exit $main_exit_code;
    } elsif ("$arg" =~ /^-.*$/msx) {
                $opt = "$opt $arg";
        # Builtin command 'shift' not implemented
    } elsif (1) {
        last;    }
}
if ((Variable("#", false, None) == 0)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $CHILD_ERROR = 0;
exit 1;
}
$opt = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_2 = q{};
my $output_printed_2;
my $output_3 = q{};
while (my $line = <>) {
    chomp $line;
    # printf doesn't support line-by-line processing
    }
$output_3; };
}; $_pipeline_result; };
if ("$opt" =~ /^.*t.*$/msx) {
        $check = q{1};
        $opt = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_4 = q{};
    my $output_printed_4;
    my $output_5 = q{};
    while (my $line = <>) {
        chomp $line;
        # printf doesn't support line-by-line processing
        $line =~ 's/t//g';
    }
    $output_5; };
}; $_pipeline_result; };
}
if ("$opt" =~ /^.*K.*$/msx) {
        $keep = q{1};
        $check = q{1};
        $opt = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_6 = q{};
    my $output_printed_6;
    my $output_7 = q{};
    while (my $line = <>) {
        chomp $line;
        # printf doesn't support line-by-line processing
        $line =~ 's/K//g';
    }
    $output_7; };
}; $_pipeline_result; };
}
if ("$opt" =~ /^.*P.*$/msx) {
        $pipe = q{1};
        $opt = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_8 = q{};
    my $output_printed_8;
    my $output_9 = q{};
    while (my $line = <>) {
        chomp $line;
        # printf doesn't support line-by-line processing
        $line =~ 's/P//g';
    }
    $output_9; };
}; $_pipeline_result; };
}
if (StringInterpolation(StringInterpolation { parts: [Variable("opt")] }, None) ne q{}) {
    $opt = "-$opt";
}
my $i;
for my $i () {
    my $n;
    my @n;
    my %n;
    $n = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_10 = q{};
    my $output_printed_10;
    my $output_11 = q{};
    while (my $line = <>) {
        chomp $line;
        # printf doesn't support line-by-line processing
        $line =~ 's/.Z$//';
    }
    $output_11; };
}; $_pipeline_result; };
if ((-f '! StringInterpolation(StringInterpolation { parts: [Variable("n"), Literal(".Z")] }, None)')) {
printf("%s\n", "$n.Z not found");
        $res = q{1};
next;
    }
    if (do {
$main_exit_code = system('test', $keep, '-eq', q{1}) >> 8;
        $CHILD_ERROR == 0
    }) {
                $old = do {
    my $wc_file = "$n.Z";
    my $wc_file_opened = 0;
    my $content = do {
        my $result = q{};
        if (open my $fh, '<', $wc_file) {
            $wc_file_opened = 1;
            local $INPUT_RECORD_SEPARATOR = undef;
            $result = <$fh>;
            close $fh or warn "Close failed: $OS_ERROR\n";
        } else {
            warn "Cannot open $wc_file: $OS_ERROR\n";
        }
        $result;
    };
    $wc_file_opened ? do {
        my $wc_bytes = length($content);
        $wc_bytes;
    } : q{};
};
    }
if ((Variable("pipe", false, None) == 1)) {
if (!(        # Original bash: gzip -d < "$n.Z" | gzip $opt > "$n$ext";
{
            my $output_13 = q{};
            my $output_printed_13;
            my $pipeline_success_13 = 1;
                        $output = q{};
            open STDIN, '<', "$n.Z" or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_14 = q{};
my ($in_16);
my $pid_16 = open3($in_16, $out_16, $err_16, 'bash', '-c', 'echo "$output_13" | gunzip 2>/dev/null');
close $in_16 or croak 'Close failed: $OS_ERROR';
my $decompressed = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_16> };
close $out_16 or croak 'Close failed: $OS_ERROR';
waitpid $pid_16, 0;
if (defined $decompressed) {
output_13 = $decompressed;
} else {
output_13 = "gunzip: input not in gzip format\n";
}

$tmp_redirect_14;
            $output_13 = $output;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$n$ext"
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_17 = q{};
            my @results;
            if (-f $opt) {
            my ($in_19);
            my $pid_19 = open3($in_19, $out_19, $err_19, 'bash', '-c', 'gzip $opt');
            close $in_19 or croak 'Close failed: $OS_ERROR';
            my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19> };
            close $out_19 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_19, 0;
            if ( $CHILD_ERROR == 0 ) {
            push @results, "Compressed: $opt";
            } else {
            push @results, "Failed to compress: $opt";
            }
            } else {
            push @results, "File not found: $opt";
            }
            output_13 = join "\n", @results;
            $tmp_redirect_17;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_13; }
            $output_printed_13 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_13 ) { $main_exit_code = 1; }
            })) {
            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
do { my $touch_cmd_str = 'touch -r "$n.Z" -- "$n$ext"'; system $touch_cmd_str; };
            };
            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
$CHILD_ERROR = 0;
            };
}
        else {
printf("%s\n", "error while recompressing $n.Z");
            $res = q{1};
next;
        }
}
    else {
if ((Variable("check", false, None) == 1)) {
if (!(            use File::Copy qw(copy);
            if ( -e "$n.Z" ) {
                if ( -d "$n.$ENV{$}" ) {
                    require File::Copy; File::Copy::copy("$n.Z", "$n.$ENV{$}" . '/' . ("$n.Z" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$n.Z", "$n.$ENV{$}");
                }
            } else {
                croak "cp: cannot stat '-p': No such file or directory\n";
            })) {
                $main_exit_code = system('bash', ':') >> 8;
}
            else {
printf("%s\n", "cannot backup $n.Z");
                $res = q{1};
next;
            }
        }
if (!(my @results;
if (-f "$n.Z") {
if ("$n.Z".gz =~ /[\[].]gz$/msx) {
my ($in_26);
my $pid_26 = open3($in_26, $out_26, $err_26, 'gunzip', '-c', '"$n.Z".gz');
close $in_26 or croak 'Close failed: $OS_ERROR';
my $decompressed = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_26> };
close $out_26 or croak 'Close failed: $OS_ERROR';
waitpid $pid_26, 0;
if (defined $decompressed) {
push @results, "Decompressed: "$n.Z"";
} else {
push @results, "Failed to decompress: "$n.Z"";
}
} else {
push @results, "File not compressed: "$n.Z"";
}
} else {
push @results, "File not found: "$n.Z"";
}
 = join "\n", @results)) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
            if (do {
$main_exit_code = system('test', $check, '-eq', q{1}) >> 8;
                $CHILD_ERROR == 0
            }) {
                                my $err;
                my $force = 0;
                if ( -e "$n.$ENV{$}" ) {
                    my $dest = "$n.Z";
                    if ( -e $dest && -d $dest ) {
                        my $source_name = "$n.$ENV{$}";
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
                    if ( File::Copy::move( "$n.$ENV{$}", $dest ) ) {
                    } else {
                        croak
  "mv: cannot move "$n.$ENV{$}" to $dest: $ERRNO\n";
                    }
                } else {
                    croak "mv: "$n.$ENV{$}": No such file or directory\n";
                }
            }
printf("%s\n", "error while uncompressing $n.Z");
            $res = q{1};
next;
        }
if (!(my @results;
if (-f $opt) {
my ($in_30);
my $pid_30 = open3($in_30, $out_30, $err_30, 'bash', '-c', 'gzip $opt');
close $in_30 or croak 'Close failed: $OS_ERROR';
my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
close $out_30 or croak 'Close failed: $OS_ERROR';
waitpid $pid_30, 0;
if ( $CHILD_ERROR == 0 ) {
push @results, "Compressed: $opt";
} else {
push @results, "Failed to compress: $opt";
}
} else {
push @results, "File not found: $opt";
}
if (-f "$n") {
my ($in_31);
my $pid_31 = open3($in_31, $out_31, $err_31, 'bash', '-c', 'gzip "$n"');
close $in_31 or croak 'Close failed: $OS_ERROR';
my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
close $out_31 or croak 'Close failed: $OS_ERROR';
waitpid $pid_31, 0;
if ( $CHILD_ERROR == 0 ) {
push @results, "Compressed: "$n"";
} else {
push @results, "Failed to compress: "$n"";
}
} else {
push @results, "File not found: "$n"";
}
 = join "\n", @results)) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
if ((Variable("check", false, None) == 1)) {
                if (do {
if ( -e "$n.$ENV{$}" ) {
    my $dest = "$n.Z";
    if ( -e $dest && -d $dest ) {
        my $source_name = "$n.$ENV{$}";
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
    if ( File::Copy::move( "$n.$ENV{$}", $dest ) ) {
    } else {
        croak
  "mv: cannot move "$n.$ENV{$}" to $dest: $ERRNO\n";
    }
} else {
    croak "mv: "$n.$ENV{$}": No such file or directory\n";
}
                    $CHILD_ERROR == 0
                }) {
                    if ( -e "$n" ) {
                        if ( -d "$n" ) {
                            carp "rm: carping: ", "$n",
          " is a directory (use -r to remove recursively)\n";
                        }
                        else {
                            if ( unlink "$n" ) {
                                                            }
                            else {
                                carp "rm: carping: could not remove ", "$n",
              ": $OS_ERROR\n";
                            }
                        }
                    }
                    else {
                        local $CHILD_ERROR = 0;
                    }
                }
printf("%s\n", "error while recompressing $n");
}
            else {
printf("%s\n", "error while recompressing $n, left uncompressed");
            }
            $res = q{1};
next;
        }
    }
    if (do {
$main_exit_code = system('test', $keep, '-eq', q{1}) >> 8;
        $CHILD_ERROR == 0
    }) {
                $new = do {
    my $wc_file = "$n$ext";
    my $wc_file_opened = 0;
    my $content = do {
        my $result = q{};
        if (open my $fh, '<', $wc_file) {
            $wc_file_opened = 1;
            local $INPUT_RECORD_SEPARATOR = undef;
            $result = <$fh>;
            close $fh or warn "Close failed: $OS_ERROR\n";
        } else {
            warn "Cannot open $wc_file: $OS_ERROR\n";
        }
        $result;
    };
    $wc_file_opened ? do {
        my $wc_bytes = length($content);
        $wc_bytes;
    } : q{};
};
    }
if ((!(    $main_exit_code = system('test', $keep, '-eq', q{1}) >> 8) && !(    $main_exit_code = system('test', do { my ($in_35, $out_35); my $pid_35 = open3($in_35, $out_35, '>&STDERR', 'expr', '"\\("', '$old', 'q{+}', '$block', 'q{-}', 'q{1}', '"\\)"', 'q{/}', '$block'); close $in_35 or croak 'Close failed: $OS_ERROR'; my $result_35 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_35> }; close $out_35 or croak 'Close failed: $OS_ERROR'; waitpid $pid_35, 0; $result_35 }, '-lt', do { my ($in_36, $out_36); my $pid_36 = open3($in_36, $out_36, '>&STDERR', 'expr', '"\\("', '$new', 'q{+}', '$block', 'q{-}', 'q{1}', '"\\)"', 'q{/}', '$block'); close $in_36 or croak 'Close failed: $OS_ERROR'; my $result_36 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_36> }; close $out_36 or croak 'Close failed: $OS_ERROR'; waitpid $pid_36, 0; $result_36 }) >> 8))) {
if ((Variable("pipe", false, None) == 1)) {
if ( -e "$n$ext" ) {
                if ( -d "$n$ext" ) {
                    carp "rm: carping: ", "$n$ext",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$n$ext" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$n$ext",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
}
        else {
            if (do {
if ( -e "$n.$ENV{$}" ) {
    my $dest = "$n.Z";
    if ( -e $dest && -d $dest ) {
        my $source_name = "$n.$ENV{$}";
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
    if ( File::Copy::move( "$n.$ENV{$}", $dest ) ) {
    } else {
        croak
  "mv: cannot move "$n.$ENV{$}" to $dest: $ERRNO\n";
    }
} else {
    croak "mv: "$n.$ENV{$}": No such file or directory\n";
}
                $CHILD_ERROR == 0
            }) {
                if ( -e "$n$ext" ) {
                    if ( -d "$n$ext" ) {
                        carp "rm: carping: ", "$n$ext",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$n$ext" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$n$ext",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
            }
        }
printf("%s\n", "$n.Z smaller than $n$ext -- unchanged");
}
    else {
        if ((Variable("check", false, None) == 1)) {
if (!(my @results;
if (-f "$n$ext") {
my ($in_40);
my $pid_40 = open3($in_40, $out_40, $err_40, 'bash', '-c', 'gzip "$n$ext"');
close $in_40 or croak 'Close failed: $OS_ERROR';
my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_40> };
close $out_40 or croak 'Close failed: $OS_ERROR';
waitpid $pid_40, 0;
if ( $CHILD_ERROR == 0 ) {
push @results, "Compressed: "$n$ext"";
} else {
push @results, "Failed to compress: "$n$ext"";
}
} else {
push @results, "File not found: "$n$ext"";
}
 = join "\n", @results)) {
if ( -e "$n.$ENV{$}" ) {
                    if ( -d "$n.$ENV{$}" ) {
                        carp "rm: carping: ", "$n.$ENV{$}",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$n.$ENV{$}" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$n.$ENV{$}",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
if ( -e "$n.Z" ) {
                    if ( -d "$n.Z" ) {
                        carp "rm: carping: ", "$n.Z",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$n.Z" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$n.Z",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
}
            else {
                if (do {
$main_exit_code = system('test', $pipe, '-eq', q{0}) >> 8;
                    $CHILD_ERROR == 0
                }) {
                                        if ( -e "$n.$ENV{$}" ) {
                        my $dest = "$n.Z";
                        if ( -e $dest && -d $dest ) {
                            my $source_name = "$n.$ENV{$}";
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
                        if ( File::Copy::move( "$n.$ENV{$}", $dest ) ) {
                        } else {
                            croak
  "mv: cannot move "$n.$ENV{$}" to $dest: $ERRNO\n";
                        }
                    } else {
                        croak "mv: "$n.$ENV{$}": No such file or directory\n";
                    }
                }
if ( -e "$n$ext" ) {
                    if ( -d "$n$ext" ) {
                        carp "rm: carping: ", "$n$ext",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$n$ext" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$n$ext",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
printf("%s\n", "error while testing $n$ext, $n.Z unchanged");
                $res = q{1};
next;
            }
}
        else {
            if ((Variable("pipe", false, None) == 1)) {
if ( -e "$n.Z" ) {
                    if ( -d "$n.Z" ) {
                        carp "rm: carping: ", "$n.Z",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$n.Z" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$n.Z",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
            }
        }
    }
}


exit $main_exit_code;
