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

my $scriptversion;
my @scriptversion;
my %scriptversion;
$scriptversion = '2020-11-14.01';
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
my $doit;
my @doit;
my %doit;
$doit = $DOITPROG-;
my $doit_exec;
my @doit_exec;
my %doit_exec;
$doit_exec = (defined ${doit} && ${doit} ne q{} ? ${doit} : 'exec');
my $chgrpprog;
my @chgrpprog;
my %chgrpprog;
$chgrpprog = $CHGRPPROG-chgrp;
my $chmodprog;
my @chmodprog;
my %chmodprog;
$chmodprog = $CHMODPROG-chmod;
my $chownprog;
my @chownprog;
my %chownprog;
$chownprog = $CHOWNPROG-chown;
my $cmpprog;
my @cmpprog;
my %cmpprog;
$cmpprog = $CMPPROG-cmp;
my $cpprog;
my @cpprog;
my %cpprog;
$cpprog = $CPPROG-cp;
my $mkdirprog;
my @mkdirprog;
my %mkdirprog;
$mkdirprog = $MKDIRPROG-mkdir;
my $mvprog;
my @mvprog;
my %mvprog;
$mvprog = $MVPROG-mv;
my $rmprog;
my @rmprog;
my %rmprog;
$rmprog = $RMPROG-rm;
my $stripprog;
my @stripprog;
my %stripprog;
$stripprog = $STRIPPROG-strip;
my $posix_mkdir;
my @posix_mkdir;
my %posix_mkdir;
$posix_mkdir = q{};
my $mode;
my @mode;
my %mode;
$mode = '0755';
my $mkdir_umask;
my @mkdir_umask;
my %mkdir_umask;
$mkdir_umask = '22';
my $backupsuffix;
my @backupsuffix;
my %backupsuffix;
$backupsuffix = q{};
my $chgrpcmd;
my @chgrpcmd;
my %chgrpcmd;
$chgrpcmd = q{};
my $chmodcmd;
my @chmodcmd;
my %chmodcmd;
$chmodcmd = $chmodprog;
my $chowncmd;
my @chowncmd;
my %chowncmd;
$chowncmd = q{};
my $mvcmd;
my @mvcmd;
my %mvcmd;
$mvcmd = $mvprog;
my $rmcmd;
my @rmcmd;
my %rmcmd;
$rmcmd = "$rmprog -f";
my $stripcmd;
my @stripcmd;
my %stripcmd;
$stripcmd = q{};
my $src;
my @src;
my %src;
$src = q{};
my $dst;
my @dst;
my %dst;
$dst = q{};
my $dir_arg;
my @dir_arg;
my %dir_arg;
$dir_arg = q{};
my $dst_arg;
my @dst_arg;
my %dst_arg;
$dst_arg = q{};
my $copy_on_change;
my @copy_on_change;
my %copy_on_change;
$copy_on_change = 'false';
my $is_target_a_directory;
my @is_target_a_directory;
my %is_target_a_directory;
$is_target_a_directory = 'possibly';
my $usage;
my @usage;
my %usage;
$usage = "\
Usage: $PROGRAM_NAME [OPTION]... [-T] SRCFILE DSTFILE
   or: $PROGRAM_NAME [OPTION]... SRCFILES... DIRECTORY
   or: $PROGRAM_NAME [OPTION]... -t DIRECTORY SRCFILES...
   or: $PROGRAM_NAME [OPTION]... -d DIRECTORIES...

In the 1st form, copy SRCFILE to DSTFILE.
In the 2nd and 3rd, copy all SRCFILES to DIRECTORY.
In the 4th, create DIRECTORIES.

Options:
     --help     display this help and exit.
     --version  display version info and exit.

  -c            (ignored)
  -C            install only if different (preserve data modification time)
  -d            create directories instead of installing files.
  -g GROUP      $chgrpprog installed files to GROUP.
  -m MODE       $chmodprog installed files to MODE.
  -o USER       $chownprog installed files to USER.
  -p            pass -p to $cpprog.
  -s            $stripprog installed files.
  -S SUFFIX     attempt to back up existing files, with suffix SUFFIX.
  -t DIRECTORY  install into DIRECTORY.
  -T            report an error if DSTFILE is a directory.

Environment variables override the default commands:
  CHGRPPROG CHMODPROG CHOWNPROG CMPPROG CPPROG MKDIRPROG MVPROG
  RMPROG STRIPPROG

By default, rm is invoked with -f; when overridden with RMPROG,
it's up to you to specify -f if you want it.

If -S is not specified, no backups are attempted.

Email bug reports to bug-automake@gnu.org.
Automake home page: https://www.gnu.org/software/automake/
";
my $# = 0;
while ( (Variable("#", false, None) != 0) ) {
if ($arg1 =~ /^-c$/msx) {
    } elsif ($arg1 =~ /^-C$/msx) {
                $copy_on_change = 'true';
    } elsif ($arg1 =~ /^-d$/msx) {
                $dir_arg = 'true';
    } elsif ($arg1 =~ /^-g$/msx) {
                $chgrpcmd = "$chgrpprog $_[1]";
        # Builtin command 'shift' not implemented
    } elsif ($arg1 =~ /^--help$/msx) {
                print $usage;
if ( !( ($usage) =~ m{\n\z}msx ) ) { print "\n"; }
            } elsif ($arg1 =~ /^-m$/msx) {
                $mode = $2;
        if ($mode =~ /^.*' '.*$/msx or $mode =~ /^.*"$tab".*$/msx or $mode =~ /^.*"$nl".*$/msx or $mode =~ /^.*'.*'.*$/msx or $mode =~ /^.*'.'.*$/msx or $mode =~ /^.*'\['.*$/msx) {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "$PROGRAM_NAME: invalid mode: $mode";
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
    } elsif ($arg1 =~ /^-o$/msx) {
                $chowncmd = "$chownprog $_[1]";
        # Builtin command 'shift' not implemented
    } elsif ($arg1 =~ /^-p$/msx) {
                $cpprog = "$cpprog -p";
    } elsif ($arg1 =~ /^-s$/msx) {
                $stripcmd = $stripprog;
    } elsif ($arg1 =~ /^-S$/msx) {
                $backupsuffix = "$_[1]";
        # Builtin command 'shift' not implemented
    } elsif ($arg1 =~ /^-t$/msx) {
                $is_target_a_directory = 'always';
                $dst_arg = $2;
        if ($dst_arg =~ /^-.*$/msx or $dst_arg =~ /^\[=\(\)!\]$/msx) {
                        $dst_arg = './';
                        $CHILD_ERROR = 0;
        }
        # Builtin command 'shift' not implemented
    } elsif ($arg1 =~ /^-T$/msx) {
                $is_target_a_directory = 'never';
    } elsif ($arg1 =~ /^--version$/msx) {
                do {
    my $__echo_line = "$PROGRAM_NAME $scriptversion";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
            } elsif ($arg1 =~ /^--$/msx) {
        # Builtin command 'shift' not implemented
        last;    } elsif ($arg1 =~ /^-.*$/msx) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$PROGRAM_NAME: invalid option: $_[0]";
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
    } elsif (1) {
        last;    }
# Builtin command 'shift' not implemented
}
if (StringInterpolation(StringInterpolation { parts: [Variable("dir_arg")] }, None) ne q{}) {
if (StringInterpolation(StringInterpolation { parts: [Variable("dst_arg")] }, None) ne q{}) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$PROGRAM_NAME: target directory not allowed when installing a directory.";
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
}
if ((!($main_exit_code = system('test', scalar(@ARGV), '-ne', q{0}) >> 8) && !($main_exit_code = system('test', '-z', "$dir_arg$dst_arg") >> 8))) {
    my $arg;
    for my $arg () {
if (StringInterpolation(StringInterpolation { parts: [Variable("dst_arg")] }, None) ne q{}) {
# set fnord not implemented
# Builtin command 'shift' not implemented
        }
# Builtin command 'shift' not implemented
        $dst_arg = $arg;
if ($dst_arg =~ /^-.*$/msx or $dst_arg =~ /^\[=\(\)!\]$/msx) {
                        $dst_arg = './';
                        $CHILD_ERROR = 0;
        }
    }
}
if ((Variable("#", false, None) == 0)) {
if (StringInterpolation(StringInterpolation { parts: [Variable("dir_arg")] }, None) eq q{}) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$PROGRAM_NAME: no input file specified.";
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
exit 0;
}
if (StringInterpolation(StringInterpolation { parts: [Variable("dir_arg")] }, None) eq q{}) {
if ((!(    $main_exit_code = system('test', scalar(@ARGV), '-gt', q{1}) >> 8) || !(    $main_exit_code = system('test', "$is_target_a_directory", q{=}, 'always') >> 8))) {
if ((-d '! StringInterpolation(StringInterpolation { parts: [Variable("dst_arg")] }, None)')) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "$PROGRAM_NAME: $dst_arg: Is not a directory.";
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
    }
}
if (StringInterpolation(StringInterpolation { parts: [Variable("dir_arg")] }, None) eq q{}) {
    my $do_exit;
    my @do_exit;
    my %do_exit;
    $do_exit = '(exit $ret); exit $ret';
# Builtin command 'trap' with dynamic handler not supported
# Builtin command 'trap' with dynamic handler not supported
# Builtin command 'trap' with dynamic handler not supported
# Builtin command 'trap' with dynamic handler not supported
if ($mode =~ /^.*644$/msx) {
                my $cp_umask;
        my @cp_umask;
        my %cp_umask;
        $cp_umask = '133';
    } elsif ($mode =~ /^.*755$/msx) {
                $cp_umask = '22';
    } elsif ($mode =~ /^.*\[0-7\]$/msx) {
        if (StringInterpolation(StringInterpolation { parts: [Variable("stripcmd")] }, None) eq q{}) {
            my $u_plus_rw;
            my @u_plus_rw;
            my %u_plus_rw;
            $u_plus_rw = q{};
}
        else {
            $u_plus_rw = '% 200';
        }
                $cp_umask = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'expr', q{(}, '777', q{-}, $mode, q{%}, '1000', q{)}, $u_plus_rw);
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
    } elsif (1) {
        if (StringInterpolation(StringInterpolation { parts: [Variable("stripcmd")] }, None) eq q{}) {
            $u_plus_rw = q{};
}
        else {
            $u_plus_rw = ',u+rw';
        }
                $cp_umask = $mode;
                $CHILD_ERROR = 0;
    }
}
for my $src () {
if ($src =~ /^-.*$/msx or $src =~ /^\[=\(\)!\]$/msx) {
                $src = './';
                $CHILD_ERROR = 0;
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("dir_arg")] }, None) ne q{}) {
        $dst = $src;
        my $dstdir;
        my @dstdir;
        my %dstdir;
        $dstdir = $dst;
        $main_exit_code = system('test', '-d', "$dstdir") >> 8;
        my $dstdir_status;
        my @dstdir_status;
        my %dstdir_status;
        $dstdir_status = $?;
if (Variable("dstdir_status", false, None) eq 0) {
            $chowncmd = "";
        }
}
    else {
if ((!(        $main_exit_code = system('test', q{!}, '-f', "$src") >> 8) && !(        $main_exit_code = system('test', q{!}, '-d', "$src") >> 8))) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "$PROGRAM_NAME: $src does not exist.";
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
if (StringInterpolation(StringInterpolation { parts: [Variable("dst_arg")] }, None) eq q{}) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "$PROGRAM_NAME: no destination specified.";
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
        $dst = $dst_arg;
if ((-d 'StringInterpolation(StringInterpolation { parts: [Variable("dst")] }, None)')) {
if (StringInterpolation(StringInterpolation { parts: [Variable("is_target_a_directory")] }, None) eq never) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "$PROGRAM_NAME: $dst_arg: Is a directory";
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
            $dstdir = $dst;
            my $dstbase;
            my @dstbase;
            my %dstbase;
            $dstbase = do { use File::Basename qw(basename); my $basename_output = basename("$src"); $CHILD_ERROR = 0; $basename_output; };
if ($dst =~ /^.*/$/msx) {
                                $dst = $dst;
                                $CHILD_ERROR = 0;
            } elsif (1) {
                                $dst = $dst;
                                $main_exit_code = system('/', $dstbase) >> 8;
            }
            $dstdir_status = q{0};
}
        else {
            $dstdir = do { use File::Basename qw(dirname); my $dirname_output = dirname("$dst"); $CHILD_ERROR = 0; $dirname_output; };
            $main_exit_code = system('test', '-d', "$dstdir") >> 8;
            $dstdir_status = $?;
        }
    }
if ($dstdir =~ /^.*/$/msx) {
                my $dstdirslash;
        my @dstdirslash;
        my %dstdirslash;
        $dstdirslash = $dstdir;
    } elsif (1) {
                $dstdirslash = $dstdir;
                $main_exit_code = system('bash', '/') >> 8;
    }
    my $obsolete_mkdir_used;
    my @obsolete_mkdir_used;
    my %obsolete_mkdir_used;
    $obsolete_mkdir_used = 'false';
if ((!Variable("dstdir_status", false, None) eq 0)) {
if ($posix_mkdir =~ /^$/msx) {
            if (StringInterpolation(StringInterpolation { parts: [Variable("dir_arg")] }, None) ne q{}) {
                my $mkdir_mode;
                my @mkdir_mode;
                my %mkdir_mode;
                $mkdir_mode = '-m';
                $CHILD_ERROR = 0;
}
            else {
                $mkdir_mode = q{};
            }
                        $posix_mkdir = 'false';
                        my $tmpdir;
            my @tmpdir;
            my %tmpdir;
            $tmpdir = $TMPDIR-/tmp;
                        $main_exit_code = system('/ins', $RANDOM, q{-}, $$) >> 8;
            END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'
	  ret=$?
	  rmdir "$tmpdir/a/b" "$tmpdir/a" "$tmpdir" 2>/dev/null
	  exit $ret
	 2>&1'; print $end_out if $end_out ne q{}; }
            if (!(            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                do {
                    local %ENV = %ENV;
                    my $obsolete_mkdir_used = $obsolete_mkdir_used;
                    my $stripprog = $stripprog;
                    my $nl = $nl;
                    my $chmodcmd = $chmodcmd;
                    my $mvprog = $mvprog;
                    my $doit = $doit;
                    my $# = $#;
                    my $dstbase = $dstbase;
                    my $mvcmd = $mvcmd;
                    my $scriptversion = $scriptversion;
                    my $copy_on_change = $copy_on_change;
                    my $usage = $usage;
                    my $dst_arg = $dst_arg;
                    my $mkdir_mode = $mkdir_mode;
                    my $dst = $dst;
                    my $do_exit = $do_exit;
                    my $rmcmd = $rmcmd;
                    my $stripcmd = $stripcmd;
                    my $dir_arg = $dir_arg;
                    my $posix_mkdir = $posix_mkdir;
                    my $mode = $mode;
                    my $src = $src;
                    my $is_target_a_directory = $is_target_a_directory;
                    my $u_plus_rw = $u_plus_rw;
                    my $mkdirprog = $mkdirprog;
                    my $dstdir = $dstdir;
                    my $IFS = $IFS;
                    my $chgrpcmd = $chgrpcmd;
                    my $cp_umask = $cp_umask;
                    my $dstdir_status = $dstdir_status;
                    my $cpprog = $cpprog;
                    my $mkdir_umask = $mkdir_umask;
                    my $cmpprog = $cmpprog;
                    my $chownprog = $chownprog;
                    my $chmodprog = $chmodprog;
                    my $rmprog = $rmprog;
                    my $tmpdir = $tmpdir;
                    my $doit_exec = $doit_exec;
                    my $backupsuffix = $backupsuffix;
                    my $tab = $tab;
                    my $dstdirslash = $dstdirslash;
                    my $arg = $arg;
                    my $chowncmd = $chowncmd;
                    my $chgrpprog = $chgrpprog;
                    if (do {
if (do {
$main_exit_code = system('umask', $mkdir_umask) >> 8;
    $CHILD_ERROR == 0
}) {
        $CHILD_ERROR = 0;
}
                        $CHILD_ERROR == 0
                    }) {
                        # Builtin command 'exec' not implemented
                    }
                    q{};
                };
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            })) {
if ((!(                $main_exit_code = system('test', '-z', "$dir_arg") >> 8) || !(                    my $test_tmpdir;
                    my @test_tmpdir;
                    my %test_tmpdir;
                    $test_tmpdir = "$tmpdir/a";
                    my $ls_ld_tmpdir;
                    my @ls_ld_tmpdir;
                    my %ls_ld_tmpdir;
                    $ls_ld_tmpdir = do { my @_qx_cmd = ('ls -ld "$test_tmpdir"'); my $result = qx{$_qx_cmd[0]}; $CHILD_ERROR = $? >> 8; $result; };
                    if (do {
if (do {
if ($ls_ld_tmpdir =~ /^d....-.r-.*$/msx) {
        my $different_mode;
    my @different_mode;
    my %different_mode;
    $different_mode = '700';
} elsif ($ls_ld_tmpdir =~ /^d....-.--.*$/msx) {
        $different_mode = '755';
} elsif (1) {
    exit 1;
}
    $CHILD_ERROR == 0
}) {
        $CHILD_ERROR = 0;
}
                        $CHILD_ERROR == 0
                    }) {
                                                    my $ls_ld_tmpdir_1;
                            my @ls_ld_tmpdir_1;
                            my %ls_ld_tmpdir_1;
                            $ls_ld_tmpdir_1 = do { my @_qx_cmd = ('ls -ld "$test_tmpdir"'); my $result = qx{$_qx_cmd[0]}; $CHILD_ERROR = $? >> 8; $result; };
                            $main_exit_code = system('test', "$ls_ld_tmpdir", q{=}, "$ls_ld_tmpdir_1") >> 8;
                    }))) {
                    $posix_mkdir = q{:};
                }
rmdir ("$tmpdir/a/b", "$tmpdir/a", "$tmpdir") or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
            else {
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
rmdir ('./', $mkdir_mode, './', './--', "$tmpdir") or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
                };
            }
            END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx' 2>&1'; print $end_out if $end_out ne q{}; }
        }
if ((!(        $CHILD_ERROR = 0) && !(        do {
            local %ENV = %ENV;
            my $obsolete_mkdir_used = $obsolete_mkdir_used;
            my $stripprog = $stripprog;
            my $nl = $nl;
            my $chmodcmd = $chmodcmd;
            my $mvprog = $mvprog;
            my $doit = $doit;
            my $# = $#;
            my $dstbase = $dstbase;
            my $mvcmd = $mvcmd;
            my $scriptversion = $scriptversion;
            my $copy_on_change = $copy_on_change;
            my $usage = $usage;
            my $dst_arg = $dst_arg;
            my $mkdir_mode = $mkdir_mode;
            my $dst = $dst;
            my $do_exit = $do_exit;
            my $ls_ld_tmpdir = $ls_ld_tmpdir;
            my $rmcmd = $rmcmd;
            my $stripcmd = $stripcmd;
            my $dir_arg = $dir_arg;
            my $posix_mkdir = $posix_mkdir;
            my $mode = $mode;
            my $src = $src;
            my $is_target_a_directory = $is_target_a_directory;
            my $u_plus_rw = $u_plus_rw;
            my $mkdirprog = $mkdirprog;
            my $dstdir = $dstdir;
            my $IFS = $IFS;
            my $chgrpcmd = $chgrpcmd;
            my $cp_umask = $cp_umask;
            my $dstdir_status = $dstdir_status;
            my $test_tmpdir = $test_tmpdir;
            my $ls_ld_tmpdir_1 = $ls_ld_tmpdir_1;
            my $cpprog = $cpprog;
            my $mkdir_umask = $mkdir_umask;
            my $cmpprog = $cmpprog;
            my $chownprog = $chownprog;
            my $chmodprog = $chmodprog;
            my $rmprog = $rmprog;
            my $different_mode = $different_mode;
            my $tmpdir = $tmpdir;
            my $doit_exec = $doit_exec;
            my $backupsuffix = $backupsuffix;
            my $tab = $tab;
            my $dstdirslash = $dstdirslash;
            my $arg = $arg;
            my $chowncmd = $chowncmd;
            my $chgrpprog = $chgrpprog;
            if (do {
$main_exit_code = system('umask', $mkdir_umask) >> 8;
                $CHILD_ERROR == 0
            }) {
                                $CHILD_ERROR = 0;
            }
            q{};
        }))) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
if ($dstdir =~ /^/.*$/msx) {
                                my $prefix;
                my @prefix;
                my %prefix;
                $prefix = q{/};
            } elsif ($dstdir =~ /^\[-=\(\)!\].*$/msx) {
                                $prefix = './';
            } elsif (1) {
                                $prefix = q{};
            }
            my $oIFS;
            my @oIFS;
            my %oIFS;
            $oIFS = $IFS;
            $IFS = q{/};
# set -f not implemented
# set fnord not implemented
# Builtin command 'shift' not implemented
# set +f not implemented
            $IFS = $oIFS;
            my $prefixes;
            my @prefixes;
            my %prefixes;
            $prefixes = q{};
            my $d;
            for my $d () {
                if (do {
$main_exit_code = system('test', q{X}, "$d", q{=}, q{X}) >> 8;
                    $CHILD_ERROR == 0
                }) {
                    next;                }
                $prefix = $prefix;
                $CHILD_ERROR = 0;
if ((-d 'StringInterpolation(StringInterpolation { parts: [Variable("prefix")] }, None)')) {
                    $prefixes = q{};
}
                else {
if (!(                    $CHILD_ERROR = 0)) {
                        if (do {
do {
    local %ENV = %ENV;
    my $obsolete_mkdir_used = $obsolete_mkdir_used;
    my $stripprog = $stripprog;
    my $nl = $nl;
    my $oIFS = $oIFS;
    my $chmodcmd = $chmodcmd;
    my $mvprog = $mvprog;
    my $doit = $doit;
    my $# = $#;
    my $dstbase = $dstbase;
    my $mvcmd = $mvcmd;
    my $scriptversion = $scriptversion;
    my $copy_on_change = $copy_on_change;
    my $usage = $usage;
    my $dst_arg = $dst_arg;
    my $mkdir_mode = $mkdir_mode;
    my $dst = $dst;
    my $do_exit = $do_exit;
    my $ls_ld_tmpdir = $ls_ld_tmpdir;
    my $prefixes = $prefixes;
    my $rmcmd = $rmcmd;
    my $stripcmd = $stripcmd;
    my $dir_arg = $dir_arg;
    my $posix_mkdir = $posix_mkdir;
    my $mode = $mode;
    my $src = $src;
    my $is_target_a_directory = $is_target_a_directory;
    my $u_plus_rw = $u_plus_rw;
    my $mkdirprog = $mkdirprog;
    my $dstdir = $dstdir;
    my $IFS = $IFS;
    my $chgrpcmd = $chgrpcmd;
    my $cp_umask = $cp_umask;
    my $dstdir_status = $dstdir_status;
    my $test_tmpdir = $test_tmpdir;
    my $ls_ld_tmpdir_1 = $ls_ld_tmpdir_1;
    my $cpprog = $cpprog;
    my $mkdir_umask = $mkdir_umask;
    my $cmpprog = $cmpprog;
    my $chownprog = $chownprog;
    my $chmodprog = $chmodprog;
    my $prefix = $prefix;
    my $rmprog = $rmprog;
    my $different_mode = $different_mode;
    my $tmpdir = $tmpdir;
    my $d = $d;
    my $doit_exec = $doit_exec;
    my $backupsuffix = $backupsuffix;
    my $tab = $tab;
    my $dstdirslash = $dstdirslash;
    my $arg = $arg;
    my $chowncmd = $chowncmd;
    my $chgrpprog = $chgrpprog;
    if (do {
$main_exit_code = system('umask', $mkdir_umask) >> 8;
        $CHILD_ERROR == 0
    }) {
                $CHILD_ERROR = 0;
    }
    q{};
};
                            $CHILD_ERROR == 0
                        }) {
                            last;                        }
                                                $main_exit_code = system('test', '-d', "$prefix") >> 8;
                        if ($CHILD_ERROR != 0) {
                            exit 1;
                        }
}
                    else {
if ($prefix =~ /^.*\'.*$/msx) {
                                                        my $qprefix;
                            my @qprefix;
                            my %qprefix;
                            $qprefix = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                                my $output_4 = q{};
                                my $output_printed_4;
                                my $pipeline_success_4 = 1;
                                $output_4 .= $prefix . "\n";
                                if ( !($output_4 =~ m{\n\z}msx) ) { $output_4 .= "\n"; }
                                $CHILD_ERROR = 0;
                                if ($CHILD_ERROR != 0) { $pipeline_success_4 = 0; }
                                my @sed_lines_4 = split /\n/msx, $output_4;
                                my @sed_result_4;
                                foreach my $line (@sed_lines_4) {
                                chomp $line;
                                push @sed_result_4, $line;
                                }
                                $output_4 = join "\n", @sed_result_4;

                                if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
                                $output_4 =~ s/\n+\z//msx;
                                $output_4;
}; $_pipeline_result; };
                        } elsif (1) {
                                                        $qprefix = $prefix;
                        }
                        $prefixes = "$prefixes '$qprefix'";
                    }
                }
                $prefix = $prefix;
                $main_exit_code = system('bash', '/') >> 8;
            }
if (StringInterpolation(StringInterpolation { parts: [Variable("prefixes")] }, None) ne q{}) {
                                                do {
                    local %ENV = %ENV;
                    my $obsolete_mkdir_used = $obsolete_mkdir_used;
                    my $stripprog = $stripprog;
                    my $nl = $nl;
                    my $oIFS = $oIFS;
                    my $chmodcmd = $chmodcmd;
                    my $mvprog = $mvprog;
                    my $doit = $doit;
                    my $# = $#;
                    my $dstbase = $dstbase;
                    my $mvcmd = $mvcmd;
                    my $scriptversion = $scriptversion;
                    my $copy_on_change = $copy_on_change;
                    my $usage = $usage;
                    my $dst_arg = $dst_arg;
                    my $mkdir_mode = $mkdir_mode;
                    my $dst = $dst;
                    my $do_exit = $do_exit;
                    my $ls_ld_tmpdir = $ls_ld_tmpdir;
                    my $prefixes = $prefixes;
                    my $rmcmd = $rmcmd;
                    my $stripcmd = $stripcmd;
                    my $dir_arg = $dir_arg;
                    my $posix_mkdir = $posix_mkdir;
                    my $mode = $mode;
                    my $src = $src;
                    my $is_target_a_directory = $is_target_a_directory;
                    my $u_plus_rw = $u_plus_rw;
                    my $mkdirprog = $mkdirprog;
                    my $dstdir = $dstdir;
                    my $IFS = $IFS;
                    my $chgrpcmd = $chgrpcmd;
                    my $cp_umask = $cp_umask;
                    my $dstdir_status = $dstdir_status;
                    my $test_tmpdir = $test_tmpdir;
                    my $ls_ld_tmpdir_1 = $ls_ld_tmpdir_1;
                    my $cpprog = $cpprog;
                    my $mkdir_umask = $mkdir_umask;
                    my $cmpprog = $cmpprog;
                    my $chownprog = $chownprog;
                    my $chmodprog = $chmodprog;
                    my $prefix = $prefix;
                    my $rmprog = $rmprog;
                    my $different_mode = $different_mode;
                    my $tmpdir = $tmpdir;
                    my $d = $d;
                    my $qprefix = $qprefix;
                    my $doit_exec = $doit_exec;
                    my $backupsuffix = $backupsuffix;
                    my $tab = $tab;
                    my $dstdirslash = $dstdirslash;
                    my $arg = $arg;
                    my $chowncmd = $chowncmd;
                    my $chgrpprog = $chgrpprog;
                    if (do {
$main_exit_code = system('umask', $mkdir_umask) >> 8;
                        $CHILD_ERROR == 0
                    }) {
                        do { my $eval_input = "$doit_exec $mkdirprog " . $prefixes; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
                    }
                    q{};
                };
                if ($CHILD_ERROR != 0) {
                                        $main_exit_code = system('test', '-d', "$dstdir") >> 8;
                }
                if ($CHILD_ERROR != 0) {
                    exit 1;
                }
                $obsolete_mkdir_used = 'true';
            }
        }
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("dir_arg")] }, None) ne q{}) {
                if (do {
if (do {
        $main_exit_code = system('test', '-z', "$chowncmd") >> 8;
    if ($CHILD_ERROR != 0) {
                $CHILD_ERROR = 0;
    }
    $CHILD_ERROR == 0
}) {
                    $main_exit_code = system('test', '-z', "$chgrpcmd") >> 8;
        if ($CHILD_ERROR != 0) {
                        $CHILD_ERROR = 0;
        }
}
            $CHILD_ERROR == 0
        }) {
                                                            $main_exit_code = system('test', "$obsolete_mkdir_used$chowncmd$chgrpcmd", q{=}, 'false') >> 8;
                if ($CHILD_ERROR != 0) {
                                        $main_exit_code = system('test', '-z', "$chmodcmd") >> 8;
                }
                if ($CHILD_ERROR != 0) {
                                        $CHILD_ERROR = 0;
                }
        }
        if ($CHILD_ERROR != 0) {
            exit 1;
        }
}
    else {
        my $dsttmp = $dstdirslash;
        $main_exit_code = system('_inst.', $$, q{_}) >> 8;
        my $rmtmp = $dstdirslash;
        $main_exit_code = system('_rm.', $$, q{_}) >> 8;
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'ret=$?; rm -f "$dsttmp" "$rmtmp" && exit $ret 2>&1'; print $end_out if $end_out ne q{}; }
                if (do {
if (do {
if (do {
if (do {
if (do {
do {
    local %ENV = %ENV;
    my $obsolete_mkdir_used = $obsolete_mkdir_used;
    my $stripprog = $stripprog;
    my $nl = $nl;
    my $oIFS = $oIFS;
    my $chmodcmd = $chmodcmd;
    my $mvprog = $mvprog;
    my $doit = $doit;
    my $# = $#;
    my $dstbase = $dstbase;
    my $mvcmd = $mvcmd;
    my $scriptversion = $scriptversion;
    my $copy_on_change = $copy_on_change;
    my $usage = $usage;
    my $dst_arg = $dst_arg;
    my $mkdir_mode = $mkdir_mode;
    my $dst = $dst;
    my $dsttmp = $dsttmp;
    my $rmtmp = $rmtmp;
    my $do_exit = $do_exit;
    my $ls_ld_tmpdir = $ls_ld_tmpdir;
    my $prefixes = $prefixes;
    my $rmcmd = $rmcmd;
    my $stripcmd = $stripcmd;
    my $dir_arg = $dir_arg;
    my $posix_mkdir = $posix_mkdir;
    my $mode = $mode;
    my $src = $src;
    my $is_target_a_directory = $is_target_a_directory;
    my $u_plus_rw = $u_plus_rw;
    my $mkdirprog = $mkdirprog;
    my $dstdir = $dstdir;
    my $IFS = $IFS;
    my $chgrpcmd = $chgrpcmd;
    my $cp_umask = $cp_umask;
    my $dstdir_status = $dstdir_status;
    my $test_tmpdir = $test_tmpdir;
    my $ls_ld_tmpdir_1 = $ls_ld_tmpdir_1;
    my $cpprog = $cpprog;
    my $mkdir_umask = $mkdir_umask;
    my $cmpprog = $cmpprog;
    my $chownprog = $chownprog;
    my $chmodprog = $chmodprog;
    my $prefix = $prefix;
    my $rmprog = $rmprog;
    my $different_mode = $different_mode;
    my $tmpdir = $tmpdir;
    my $d = $d;
    my $qprefix = $qprefix;
    my $doit_exec = $doit_exec;
    my $backupsuffix = $backupsuffix;
    my $tab = $tab;
    my $dstdirslash = $dstdirslash;
    my $arg = $arg;
    my $chowncmd = $chowncmd;
    my $chgrpprog = $chgrpprog;
    if (do {
if (do {
$main_exit_code = system('umask', $cp_umask) >> 8;
    $CHILD_ERROR == 0
}) {
                    $main_exit_code = system('test', '-z', "$stripcmd") >> 8;
        if ($CHILD_ERROR != 0) {
            if (StringInterpolation(StringInterpolation { parts: [Variable("doit")] }, None) eq q{}) {
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', "$dsttmp"
      or die "Cannot open file: $OS_ERROR\n";
                        my $tmp = do {
                        $main_exit_code = system('bash', ':') >> 8;
                        };
                        print $tmp;
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
}
                else {
                    $CHILD_ERROR = 0;
                }
        }
}
        $CHILD_ERROR == 0
    }) {
                $CHILD_ERROR = 0;
    }
    q{};
};
    $CHILD_ERROR == 0
}) {
                    $main_exit_code = system('test', '-z', "$chowncmd") >> 8;
        if ($CHILD_ERROR != 0) {
                        $CHILD_ERROR = 0;
        }
}
    $CHILD_ERROR == 0
}) {
                    $main_exit_code = system('test', '-z', "$chgrpcmd") >> 8;
        if ($CHILD_ERROR != 0) {
                        $CHILD_ERROR = 0;
        }
}
    $CHILD_ERROR == 0
}) {
                    $main_exit_code = system('test', '-z', "$stripcmd") >> 8;
        if ($CHILD_ERROR != 0) {
                        $CHILD_ERROR = 0;
        }
}
    $CHILD_ERROR == 0
}) {
                    $main_exit_code = system('test', '-z', "$chmodcmd") >> 8;
        if ($CHILD_ERROR != 0) {
                        $CHILD_ERROR = 0;
        }
}
            $CHILD_ERROR == 0
        }) {
            if (((((((((((!(            $CHILD_ERROR = 0) && !(            my $old;
            my @old;
            my %old;
            $old = do { my @_qx_cmd = ("ls -d lL \"$dst\" 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; })) && !(            my $new;
            my @new;
            my %new;
            $new = do { my @_qx_cmd = ("ls -d lL \"$dsttmp\" 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; })) && !(# set -f not implemented)) && !(# set X not implemented)) && !(            $old = q{:};
            $CHILD_ERROR = 0)) && !(# set X not implemented)) && !(            $new = q{:};
            $CHILD_ERROR = 0)) && !(# set +f not implemented)) && !(            $main_exit_code = system('test', "$old", q{=}, "$new") >> 8)) && !(            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $CHILD_ERROR = 0;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            }))) {
if ( -e "$dsttmp" ) {
                    if ( -d "$dsttmp" ) {
                        carp "rm: carping: ", "$dsttmp",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$dsttmp" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$dsttmp",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
}
            else {
if ((!(                $main_exit_code = system('test', '-n', "$backupsuffix") >> 8) && !(                $main_exit_code = system('test', '-f', "$dst") >> 8))) {
                    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                        $CHILD_ERROR = 0;
                    };
                }
                                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                    $CHILD_ERROR = 0;
                };
                if ($CHILD_ERROR != 0) {
                                            if (do {
                $main_exit_code = system('test', q{!}, '-f', "$dst") >> 8;
    if ($CHILD_ERROR != 0) {
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            $CHILD_ERROR = 0;
        };
    }
    if ($CHILD_ERROR != 0) {
                    if (do {
                                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                    $CHILD_ERROR = 0;
                };
            } == 0) {
                                    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                        $CHILD_ERROR = 0;
                    };
                    $main_exit_code = system('bash', ':') >> 8;
            }
    }
    if ($CHILD_ERROR != 0) {
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "$PROGRAM_NAME: cannot unlink or rename $dst";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
            do {
                local %ENV = %ENV;
                my $stripprog = $stripprog;
                my $oIFS = $oIFS;
                my $# = $#;
                my $copy_on_change = $copy_on_change;
                my $dst_arg = $dst_arg;
                my $dst = $dst;
                my $dsttmp = $dsttmp;
                my $do_exit = $do_exit;
                my $prefixes = $prefixes;
                my $u_plus_rw = $u_plus_rw;
                my $stripcmd = $stripcmd;
                my $posix_mkdir = $posix_mkdir;
                my $mkdirprog = $mkdirprog;
                my $IFS = $IFS;
                my $ls_ld_tmpdir_1 = $ls_ld_tmpdir_1;
                my $d = $d;
                my $mkdir_umask = $mkdir_umask;
                my $new = $new;
                my $chownprog = $chownprog;
                my $chmodprog = $chmodprog;
                my $tmpdir = $tmpdir;
                my $qprefix = $qprefix;
                my $backupsuffix = $backupsuffix;
                my $tab = $tab;
                my $dstdirslash = $dstdirslash;
                my $arg = $arg;
                my $chowncmd = $chowncmd;
                my $obsolete_mkdir_used = $obsolete_mkdir_used;
                my $nl = $nl;
                my $chmodcmd = $chmodcmd;
                my $mvprog = $mvprog;
                my $doit = $doit;
                my $dstbase = $dstbase;
                my $mvcmd = $mvcmd;
                my $scriptversion = $scriptversion;
                my $usage = $usage;
                my $mkdir_mode = $mkdir_mode;
                my $rmtmp = $rmtmp;
                my $ls_ld_tmpdir = $ls_ld_tmpdir;
                my $rmcmd = $rmcmd;
                my $dir_arg = $dir_arg;
                my $mode = $mode;
                my $src = $src;
                my $is_target_a_directory = $is_target_a_directory;
                my $dstdir = $dstdir;
                my $chgrpcmd = $chgrpcmd;
                my $cp_umask = $cp_umask;
                my $dstdir_status = $dstdir_status;
                my $test_tmpdir = $test_tmpdir;
                my $cpprog = $cpprog;
                my $cmpprog = $cmpprog;
                my $prefix = $prefix;
                my $rmprog = $rmprog;
                my $different_mode = $different_mode;
                my $old = $old;
                my $doit_exec = $doit_exec;
                my $chgrpprog = $chgrpprog;
exit 1;
                q{};
            };
exit 1;
    }
                            $CHILD_ERROR == 0
                        }) {
                                                        $CHILD_ERROR = 0;
                        }
                }
            }
        }
        if ($CHILD_ERROR != 0) {
            exit 1;
        }
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx' 2>&1'; print $end_out if $end_out ne q{}; }
    }
}

exit $main_exit_code;
