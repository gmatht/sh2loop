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

my $tab;
my @tab;
my %tab;
$tab = "\t";
my $nl;
my @nl;
my %nl;
$nl = "\n";
my $IFS;
my @IFS;
my %IFS;
$IFS = " $tab$nl";
my $version;
my @version;
my %version;
$version = "gzexe (gzip) 1.12\nCopyright (C) 2007, 2011-2018 Free Software Foundation, Inc.\nThis is free software.  You may redistribute copies of it under the terms of\nthe GNU General Public License <https://www.gnu.org/licenses/gpl.html>.\nThere is NO WARRANTY, to the extent permitted by law.\n\nWritten by Jean-loup Gailly.";
my $usage;
my @usage;
my %usage;
$usage = "Usage: $PROGRAM_NAME [OPTION] FILE...
Replace each executable FILE with a compressed version of itself.
Make a backup FILE~ of the old version of FILE.

  -d             Decompress each FILE instead of compressing it.
      --help     display this help and exit
      --version  output version information and exit

Report bugs to <bug-gzip@gnu.org>.";
my $decomp;
my @decomp;
my %decomp;
$decomp = q{0};
my $res;
my @res;
my %res;
$res = q{0};
while ( $main_exit_code = system('bash', ':') >> 8 ) {
if ($arg1 =~ /^-d$/msx) {
                $decomp = q{1};
        # Builtin command 'shift' not implemented
    } elsif ($arg1 =~ /^--h.*$/msx) {
                printf("%s\n", "$usage");
        if ($CHILD_ERROR != 0) {
            exit 1;
        }
        exit $main_exit_code;
    } elsif ($arg1 =~ /^--v.*$/msx) {
                printf("%s\n", "$version");
        if ($CHILD_ERROR != 0) {
            exit 1;
        }
        exit $main_exit_code;
    } elsif ($arg1 =~ /^--$/msx) {
        # Builtin command 'shift' not implemented
        last;    } elsif (1) {
        last;    }
}
if ((Variable("#", false, None) == 0)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", "$PROGRAM_NAME: missing operand
Try \\" . chr(96) . "$PROGRAM_NAME --help' for more information.");
    };
exit 1;
}
my $tmp;
my @tmp;
my %tmp;
$tmp = q{};
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'res=$?
  test -n "$tmp" && rm -f "$tmp"
  (exit $res); exit $res
 2>&1'; print $end_out if $end_out ne q{}; }
my $mktemp_status;
my @mktemp_status;
my %mktemp_status;
$mktemp_status = q{};
my $i;
for my $i () {
if ($i =~ /^-.*$/msx) {
                my $file;
        my @file;
        my %file;
        $file = './';
                $CHILD_ERROR = 0;
    } elsif (1) {
                $file = $i;
    }
if ((!(    $main_exit_code = system('test', q{!}, '-f', "$file") >> 8) || !(    $main_exit_code = system('test', q{!}, '-r', "$file") >> 8))) {
        $res = $?;
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", "$PROGRAM_NAME: $i is not a readable regular file");
        };
next;
    }
if ((Variable("decomp", false, None) == 0)) {
if (do { my @_qx_cmd = (q{sed -n -e 1d -e '/^skip=[0-9][0-9]*$/p' -e 2q "$file"}); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^skip=\[0-9\]$/msx or do { my @_qx_cmd = (q{sed -n -e 1d -e '/^skip=[0-9][0-9]*$/p' -e 2q "$file"}); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^skip=\[0-9\]\[0-9\]$/msx or do { my @_qx_cmd = (q{sed -n -e 1d -e '/^skip=[0-9][0-9]*$/p' -e 2q "$file"}); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^skip=\[0-9\]\[0-9\]\[0-9\]$/msx) {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", "$PROGRAM_NAME: $i is already gzexe'd");
            };
            next;        }
    }
if ((-u StringInterpolation(StringInterpolation { parts: [Variable("file")] }, None))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", "$PROGRAM_NAME: $i has setuid permission, unchanged");
        };
next;
    }
if ((-g StringInterpolation(StringInterpolation { parts: [Variable("file")] }, None))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", "$PROGRAM_NAME: $i has setgid permission, unchanged");
        };
next;
    }
if ("/$file" =~ /^.*/basename$/msx or "/$file" =~ /^.*/bash$/msx or "/$file" =~ /^.*/cat$/msx or "/$file" =~ /^.*/chmod$/msx or "/$file" =~ /^.*/cp$/msx or "/$file" =~ /^.*/dirname$/msx or "/$file" =~ /^.*/expr$/msx or "/$file" =~ /^.*/gzip$/msx or "/$file" =~ /^.*/ln$/msx or "/$file" =~ /^.*/mkdir$/msx or "/$file" =~ /^.*/mktemp$/msx or "/$file" =~ /^.*/mv$/msx or "/$file" =~ /^.*/printf$/msx or "/$file" =~ /^.*/rm$/msx or "/$file" =~ /^.*/sed$/msx or "/$file" =~ /^.*/sh$/msx or "/$file" =~ /^.*/sleep$/msx or "/$file" =~ /^.*/test$/msx or "/$file" =~ /^.*/tail$/msx) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", "$PROGRAM_NAME: $i might depend on itself");
        };
        next;    }
        my $dir;
    my @dir;
    my %dir;
    $dir = do { use File::Basename qw(dirname); my $dirname_output = dirname("$file"); $CHILD_ERROR = 0; $dirname_output; };
    if ($CHILD_ERROR != 0) {
                $dir = $TMPDIR;
    }
        if (do {
if (do {
$main_exit_code = system('test', '-d', "$dir") >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('test', '-w', "$dir") >> 8;
}
        $CHILD_ERROR == 0
    }) {
                $main_exit_code = system('test', '-x', "$dir") >> 8;
    }
    if ($CHILD_ERROR != 0) {
                $dir = '/tmp';
    }
    if (do {
$main_exit_code = system('test', '-n', "$tmp") >> 8;
        $CHILD_ERROR == 0
    }) {
        if ( -e "$tmp" ) {
            if ( -d "$tmp" ) {
                carp "rm: carping: ", "$tmp",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmp" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmp",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("mktemp_status")] }, None) eq q{}) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('type', 'mktemp') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $mktemp_status = $?;
    }
if ($dir =~ /^.*/$/msx) {
    } elsif (1) {
                $dir = $dir;
                $main_exit_code = system('bash', '/') >> 8;
    }
        if (do {
if ((Variable("mktemp_status", false, None) == 0)) {
    $tmp = do {
    my ($in_8, $out_8);
    my $pid_8 = open3($in_8, $out_8, '>&STDERR', 'mktemp', ${dir} . "gzexeXXXXXXXXX");
    close $in_8 or croak 'Close failed: $OS_ERROR';
    my $result_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
    close $out_8 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_8, 0;
    $result_8
};
}
else {
    $tmp = $dir;
    $main_exit_code = system('gzexe', $$) >> 8;
}
        $CHILD_ERROR == 0
    }) {
                                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                use File::Copy qw(copy);
                if ( -e "$file" ) {
                    if ( -d "$tmp" ) {
                        require File::Copy; File::Copy::copy("$file", "$tmp" . '/' . ("$file" =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy("$file", "$tmp");
                    }
                } else {
                    croak "cp: cannot stat '-p': No such file or directory\n";
                }
            };
            if ($CHILD_ERROR != 0) {
                                use File::Copy qw(copy);
                if ( -e "$file" ) {
                    if ( -d "$tmp" ) {
                        require File::Copy; File::Copy::copy("$file", "$tmp" . '/' . ("$file" =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy("$file", "$tmp");
                    }
                } else {
                    croak "cp: cannot stat '$file': No such file or directory\n";
                }
            }
    }
    if ($CHILD_ERROR != 0) {
                    $res = $?;
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", "$PROGRAM_NAME: cannot copy $file");
            };
next;
    }
if ((-w 'StringInterpolation(StringInterpolation { parts: [Variable("tmp")] }, None)')) {
        my $writable;
        my @writable;
        my %writable;
        $writable = q{1};
}
    else {
        $writable = q{0};
        chmod(oct('u+w'), ("$tmp")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) {
                            $res = $?;
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", "$PROGRAM_NAME: cannot chmod $tmp");
                };
next;
        }
    }
if ((Variable("decomp", false, None) == 0)) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$tmp"
      or die "Cannot open file: $OS_ERROR\n";
            do {
                local %ENV = %ENV;
                my $tab = $tab;
                my $res = $res;
                my $mktemp_status = $mktemp_status;
                my $writable = $writable;
                my $file = $file;
                my $nl = $nl;
                my $version = $version;
                my $i = $i;
                my $IFS = $IFS;
                my $usage = $usage;
                my $tmp = $tmp;
                my $decomp = $decomp;
                my $dir = $dir;
print q[#!/bin/sh
skip=49

tab='	'
nl='
'
IFS=" $tab$nl"

umask=`umask`
umask 77

gztmpdir=
trap 'res=$?
  test -n "$gztmpdir" && rm -fr "$gztmpdir"
  (exit $res); exit $res
' 0 1 2 3 5 10 13 15

case $TMPDIR in
  / | /*/) ;;
  /*) TMPDIR=$TMPDIR/;;
  *) TMPDIR=/tmp/;;
esac
if type mktemp >/dev/null 2>&1; then
  gztmpdir=`mktemp -d "${TMPDIR}gztmpXXXXXXXXX"`
else
  gztmpdir=${TMPDIR}gztmp$$; mkdir $gztmpdir
fi || { (exit 127); exit 127; }

gztmp=$gztmpdir/$0
case $0 in
-* | */*'
') mkdir -p "$gztmp" && rm -r "$gztmp";;
*/*) gztmp=$gztmpdir/`basename "$0"`;;
esac || { (exit 127); exit 127; }

case `printf 'X\n' | tail -n +1 2>/dev/null` in
X) tail_n=-n;;
*) tail_n=;;
esac
if tail $tail_n +$skip <"$0" | gzip -cd > "$gztmp"; then
  umask $umask
  chmod 700 "$gztmp"
  (sleep 5; rm -fr "$gztmpdir") 2>/dev/null &
  "$gztmp" ${1+"$@"}; res=$?
else
  printf >&2 '%s\n' "Cannot decompress $0"
  (exit 127); res=127
fi; exit $res
];
                q{};
            };
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ($CHILD_ERROR != 0) {
                            $res = $?;
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", "$PROGRAM_NAME: compression not possible for $i, file unchanged.");
                };
next;
        }
}
    else {
        my $skip;
        my @skip;
        my %skip;
        $skip = '44';
        my $skip_line;
        my @skip_line;
        my %skip_line;
        $skip_line = do { my @_qx_cmd = ('sed -e 1d -e 2q "$file"'); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ($skip_line =~ /^skip=\[0-9\]$/msx or $skip_line =~ /^skip=\[0-9\]\[0-9\]$/msx or $skip_line =~ /^skip=\[0-9\]\[0-9\]\[0-9\]$/msx) {
            do { my $eval_input = $skip_line; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
        }
if (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_15 = q{};
            my $output_printed_15;
            my $pipeline_success_15 = 1;
            my $output_15;
            {
            local *STDOUT;
            open STDOUT, '>', \$output_15 or die "Cannot redirect STDOUT";
            printf("X\n");
            }
            my @lines = split /\n/msx, $output_15;
            my $num_lines = 1;
            if ($num_lines > scalar @lines) {
            $num_lines = scalar @lines;
            }
            my $start_index = scalar @lines - $num_lines;
            if ($start_index < 0) { $start_index = 0; }
            my @result = @lines[$start_index..$#lines];
            $output_15 = join "\n", @result;
            if ($output_15 ne q{} && !($output_15  =~ m{\n\z}msx)) { $output_15 .= "\n"; }
            if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
            $output_15 =~ s/\n+\z//msx;
            $output_15;
}; $_pipeline_result; } =~ /^X$/msx) {
                        my $tail_n;
            my @tail_n;
            my %tail_n;
            $tail_n = '-n';
        } elsif (1) {
                        $tail_n = q{};
        }
        {
            my $output_16 = q{};
            my $output_printed_16;
            my $pipeline_success_16 = 1;
            my @tail_lines = ();
                        $output_16 = do { my @_qx_cmd = ('tail $tail_n + $skip "$file"'); qx{$_qx_cmd[0]}; };

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$tmp"
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_17 = q{};
            my @results;
            if (-f q{d}) {
            my ($in_19);
            my $pid_19 = open3($in_19, $out_19, $err_19, 'bash', '-c', 'gzip q{d}');
            close $in_19 or croak 'Close failed: $OS_ERROR';
            my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19> };
            close $out_19 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_19, 0;
            if ( $CHILD_ERROR == 0 ) {
            push @results, "Compressed: q{d}";
            } else {
            push @results, "Failed to compress: q{d}";
            }
            } else {
            push @results, "File not found: q{d}";
            }
            output_16 = join "\n", @results;
            $tmp_redirect_17;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_16; }
            $output_printed_16 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_16 ) { $main_exit_code = 1; }
            }
        if ($CHILD_ERROR != 0) {
                            $res = $?;
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", "$PROGRAM_NAME: $i probably not in gzexe format, file unchanged.");
                };
next;
        }
    }
            $main_exit_code = system('test', $writable, '-eq', q{1}) >> 8;
    if ($CHILD_ERROR != 0) {
        chmod(oct('u-w'), ("$tmp")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
    if ($CHILD_ERROR != 0) {
                    $res = $?;
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", "$PROGRAM_NAME: $tmp: cannot chmod");
            };
next;
    }
            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
unlink "$file~";
link "$file", "$file~" or warn "link failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    };
    if ($CHILD_ERROR != 0) {
                    if (do {
if ( -e "$file~" ) {
    if ( -d "$file~" ) {
        carp "rm: carping: ", "$file~",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "$file~" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "$file~",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
                $CHILD_ERROR == 0
            }) {
                                use File::Copy qw(copy);
                if ( -e "$file" ) {
                    if ( -d "$file~" ) {
                        require File::Copy; File::Copy::copy("$file", "$file~" . '/' . ("$file" =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy("$file", "$file~");
                    }
                } else {
                    croak "cp: cannot stat '-p': No such file or directory\n";
                }
            }
    }
    if ($CHILD_ERROR != 0) {
                    $res = $?;
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", "$PROGRAM_NAME: cannot backup $i as $i~");
            };
next;
    }
        my $err;
    my $force = 1;
    if ( -e "$tmp" ) {
        my $dest = "$file";
        if ( -e $dest && -d $dest ) {
            my $source_name = "$tmp";
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
        if ( File::Copy::move( "$tmp", $dest ) ) {
        } else {
            croak
  "mv: cannot move "$tmp" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "$tmp": No such file or directory\n";
    }
    if ($CHILD_ERROR != 0) {
                    $res = $?;
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s\n", "$PROGRAM_NAME: cannot rename $tmp to $i");
            };
next;
    }
    $tmp = q{};
}
do {
    local %ENV = %ENV;
    my $tab = $tab;
    my $mktemp_status = $mktemp_status;
    my $nl = $nl;
    my $tail_n = $tail_n;
    my $err = $err;
    my $tmp = $tmp;
    my $decomp = $decomp;
    my $res = $res;
    my $writable = $writable;
    my $file = $file;
    my $version = $version;
    my $i = $i;
    my $force = $force;
    my $IFS = $IFS;
    my $usage = $usage;
    my $skip = $skip;
    my $skip_line = $skip_line;
    my $dir = $dir;
    q{};
};


exit $main_exit_code;
