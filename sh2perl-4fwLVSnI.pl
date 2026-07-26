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
$scriptversion = '2018-03-07.03';
my $nl;
my @nl;
my %nl;
$nl = "\n";
my $IFS;
my @IFS;
my %IFS;
$IFS = " ";
my $file_conv;
my @file_conv;
my %file_conv;
$file_conv = q{};

sub func_file_conv {
    my $file;
    my @file;
    my %file;
    $file = $1;
if ($file =~ /^/$/msx or $file =~ /^/\[!/\].*$/msx) {
        if (StringInterpolation(StringInterpolation { parts: [Variable("file_conv")] }, None) eq q{}) {
if (do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; } =~ /^MINGW.*$/msx) {
                                $file_conv = 'mingw';
            } elsif (do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; } =~ /^CYGWIN.*$/msx or do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; } =~ /^MSYS.*$/msx) {
                                $file_conv = 'cygwin';
            } elsif (1) {
                                $file_conv = 'wine';
            }
        }
        if ("$file_conv/,$_[1]," =~ /^.*,$file_conv,.*$/msx) {
        } elsif ("$file_conv/,$_[1]," =~ /^mingw/.*$/msx) {
                        $file = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_0 = q{};
                my $output_printed_0;
                my $pipeline_success_0 = 1;

                my ($in_1, $out_1);
                my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'cmd', '//C', 'echo');
                close $in_1 or croak 'Close failed: $OS_ERROR';
                $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
                close $out_1 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_1, 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
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
        } elsif ("$file_conv/,$_[1]," =~ /^cygwin/.*$/msx or "$file_conv/,$_[1]," =~ /^msys/.*$/msx) {
                        $file = do {
    my $command = 'cygpath -m "$file" || echo "$file"';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
        } elsif ("$file_conv/,$_[1]," =~ /^wine/.*$/msx) {
                        $file = do {
    my $command = 'winepath -w "$file" || echo "$file"';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
        }
    }
    return;
}

sub func_cl_dashL {
    my ($file) = @_;
    func_file_conv("$_[0]");
if (StringInterpolation(StringInterpolation { parts: [Variable("lib_path")] }, None) eq q{}) {
        my $lib_path;
        my @lib_path;
        my %lib_path;
        $lib_path = $file;
}
    else {
        $lib_path = "$lib_path;$ENV{file}";
    }
    my $linker_opts;
    my @linker_opts;
    my %linker_opts;
    $linker_opts = "$linker_opts -LIBPATH:$ENV{file}";
    return;
}

sub func_cl_dashl {
    my $lib;
    my @lib;
    my %lib;
    $lib = $1;
    my $found;
    my @found;
    my %found;
    $found = 'no';
    my $save_IFS;
    my @save_IFS;
    my %save_IFS;
    $save_IFS = $IFS;
    $IFS = q{;};
    my $dir;
    for my $dir ($lib_path, $LIB) {
        $IFS = $save_IFS;
if ((!(        $CHILD_ERROR = 0) && !(        $main_exit_code = system('test', '-f', "$dir/$lib.dll.lib") >> 8))) {
            $found = 'yes';
            $lib = $dir;
            $main_exit_code = system('/', $lib, '.dll.lib') >> 8;
last;
        }
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("dir"), Literal("/"), Variable("lib"), Literal(".lib")] }, None)')) {
            $found = 'yes';
            $lib = $dir;
            $main_exit_code = system('/', $lib, '.lib') >> 8;
last;
        }
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("dir"), Literal("/lib"), Variable("lib"), Literal(".a")] }, None)')) {
            $found = 'yes';
            $lib = $dir;
            $main_exit_code = system('/lib', $lib, '.a') >> 8;
last;
        }
    }
    $IFS = $save_IFS;
if ((!StringInterpolation(StringInterpolation { parts: [Variable("found")] }, None) eq yes)) {
        $lib = $lib;
        $main_exit_code = system('bash', '.lib') >> 8;
    }
    return;
}

sub func_cl_wrapper {
    my ($file) = @_;
    my $lib_path;
    my @lib_path;
    my %lib_path;
    $lib_path = q{};
    my $shared;
    my @shared;
    my %shared;
    $shared = q{:};
    my $linker_opts;
    my @linker_opts;
    my %linker_opts;
    $linker_opts = q{};
    my $arg;
    for my $arg () {
if (StringInterpolation(StringInterpolation { parts: [Variable("eat")] }, None) ne q{}) {
            my $eat;
            my @eat;
            my %eat;
            $eat = q{};
}
        else {
if ($arg1 =~ /^-o$/msx) {
                                $eat = q{1};
                if ($arg2 =~ /^.*.o$/msx or $arg2 =~ /^.*.\[oO\]\[bB\]\[jJ\]$/msx) {
                                        func_file_conv("$_[1]");
                    # set x not implemented
# set -Fo not implemented
                    # Builtin command 'shift' not implemented
                } elsif (1) {
                                        func_file_conv("$_[1]");
                    # set x not implemented
# set -Fe not implemented
                    # Builtin command 'shift' not implemented
                }
            } elsif ($arg1 =~ /^-I$/msx) {
                                $eat = q{1};
                                func_file_conv("$_[1]", 'mingw');
                # set x not implemented
# set -I not implemented
                # Builtin command 'shift' not implemented
            } elsif ($arg1 =~ /^-I.*$/msx) {
                                func_file_conv(($_[0] =~ s/^-I//r =~ s/^-I//r), 'mingw');
                # set x not implemented
# set -I not implemented
                # Builtin command 'shift' not implemented
            } elsif ($arg1 =~ /^-l$/msx) {
                                $eat = q{1};
                                func_cl_dashl("$_[1]");
                # set x not implemented
                # Builtin command 'shift' not implemented
            } elsif ($arg1 =~ /^-l.*$/msx) {
                                func_cl_dashl(($_[0] =~ s/^-l//r =~ s/^-l//r));
                # set x not implemented
                # Builtin command 'shift' not implemented
            } elsif ($arg1 =~ /^-L$/msx) {
                                $eat = q{1};
                                func_cl_dashL("$_[1]");
            } elsif ($arg1 =~ /^-L.*$/msx) {
                                func_cl_dashL(($_[0] =~ s/^-L//r =~ s/^-L//r));
            } elsif ($arg1 =~ /^-static$/msx) {
                                $shared = 'false';
            } elsif ($arg1 =~ /^-Wl,.*$/msx) {
                                $arg = $_[0] =~ s/^-Wl,//r;
                                my $save_ifs;
                my @save_ifs;
                my %save_ifs;
                $save_ifs = "$IFS";
                                $IFS = q{,};
                                my $flag;
                for my $flag ($arg) {
                    $IFS = "$save_ifs";
                    $linker_opts = "$linker_opts $flag";
                }
                                $IFS = "$save_ifs";
            } elsif ($arg1 =~ /^-Xlinker$/msx) {
                                $eat = q{1};
                                $linker_opts = "$linker_opts $_[1]";
            } elsif ($arg1 =~ /^-.*$/msx) {
                # set x not implemented
                # Builtin command 'shift' not implemented
            } elsif ($arg1 =~ /^.*.cc$/msx or $arg1 =~ /^.*.CC$/msx or $arg1 =~ /^.*.cxx$/msx or $arg1 =~ /^.*.CXX$/msx or $arg1 =~ /^.*.\[cC\]++$/msx) {
                                func_file_conv("$_[0]");
                # set x not implemented
# set -Tp not implemented
                # Builtin command 'shift' not implemented
            } elsif ($arg1 =~ /^.*.c$/msx or $arg1 =~ /^.*.cpp$/msx or $arg1 =~ /^.*.CPP$/msx or $arg1 =~ /^.*.lib$/msx or $arg1 =~ /^.*.LIB$/msx or $arg1 =~ /^.*.Lib$/msx or $arg1 =~ /^.*.OBJ$/msx or $arg1 =~ /^.*.obj$/msx or $arg1 =~ /^.*.\[oO\]$/msx) {
                                func_file_conv("$_[0]", 'mingw');
                # set x not implemented
                # Builtin command 'shift' not implemented
            } elsif (1) {
                # set x not implemented
                # Builtin command 'shift' not implemented
            }
        }
# Builtin command 'shift' not implemented
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("linker_opts")] }, None) ne q{}) {
        $linker_opts = "-link$linker_opts";
    }
# Builtin command 'exec' not implemented
exit 1;
    return;
}
my $eat;
my @eat;
my %eat;
$eat = q{};
if ($arg1 =~ /^$/msx) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "$PROGRAM_NAME: No command.  Try '$PROGRAM_NAME --help' for more information.";
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
} elsif ($arg1 =~ /^-h$/msx or $arg1 =~ /^--h.*$/msx) {
    print q{Usage: compile [--help] [--version] PROGRAM [ARGS]

Wrapper for compilers which do not understand '-c -o'.
Remove '-o dest.o' from ARGS, run PROGRAM with the remaining
arguments, and rename the output as expected.

If you are trying to build a whole package this is not the
right script to run: please start by reading the file 'INSTALL'.

Report bugs to <bug-automake@gnu.org>.
};
    } elsif ($arg1 =~ /^-v$/msx or $arg1 =~ /^--v.*$/msx) {
        do {
    my $__echo_line = "compile $scriptversion";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    } elsif ($arg1 =~ /^cl$/msx or $arg1 =~ /^.*\[/\\\]cl$/msx or $arg1 =~ /^cl.exe$/msx or $arg1 =~ /^.*\[/\\\]cl.exe$/msx or $arg1 =~ /^icl$/msx or $arg1 =~ /^.*\[/\\\]icl$/msx or $arg1 =~ /^icl.exe$/msx or $arg1 =~ /^.*\[/\\\]icl.exe$/msx) {
        func_cl_wrapper("@ARGV");
}
my $ofile;
my @ofile;
my %ofile;
$ofile = q{};
my $cfile;
my @cfile;
my %cfile;
$cfile = q{};
my $arg;
for my $arg () {
if (StringInterpolation(StringInterpolation { parts: [Variable("eat")] }, None) ne q{}) {
        $eat = q{};
}
    else {
if ($arg1 =~ /^-o$/msx) {
                        $eat = q{1};
            if ($arg2 =~ /^.*.o$/msx or $arg2 =~ /^.*.obj$/msx) {
                                $ofile = $2;
            } elsif (1) {
                # set x not implemented
                # Builtin command 'shift' not implemented
            }
        } elsif ($arg1 =~ /^.*.c$/msx) {
                        $cfile = $1;
            # set x not implemented
            # Builtin command 'shift' not implemented
        } elsif (1) {
            # set x not implemented
            # Builtin command 'shift' not implemented
        }
    }
# Builtin command 'shift' not implemented
}
if ((!($main_exit_code = system('test', '-z', "$ofile") >> 8) || !($main_exit_code = system('test', '-z', "$cfile") >> 8))) {
# Builtin command 'exec' not implemented
}
my $cofile;
my @cofile;
my %cofile;
$cofile = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;
    $output_2 .= $cfile . "\n";
    if ( !($output_2 =~ m{\n\z}msx) ) { $output_2 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }
    my @sed_lines_2 = split /\n/msx, $output_2;
    my @sed_result_2;
    foreach my $line (@sed_lines_2) {
    chomp $line;
    push @sed_result_2, $line;
    }
    $output_2 = join "\n", @sed_result_2;

    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
    $output_2 =~ s/\n+\z//msx;
    $output_2;
}; $_pipeline_result; };
my $lockdir;
my @lockdir;
my %lockdir;
$lockdir = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_3 = q{};
    my $output_printed_3;
    my $pipeline_success_3 = 1;
    $output_3 .= $cofile . "\n";
    if ( !($output_3 =~ m{\n\z}msx) ) { $output_3 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_3 = 0; }
    my @sed_lines_3 = split /\n/msx, $output_3;
    my @sed_result_3;
    foreach my $line (@sed_lines_3) {
    chomp $line;
    push @sed_result_3, $line;
    }
    $output_3 = join "\n", @sed_result_3;

    if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
    $output_3 =~ s/\n+\z//msx;
    $output_3;
}; $_pipeline_result; };
$main_exit_code = system('bash', '.d') >> 8;
while ( 1 ) {
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        use File::Path qw(make_path);
        my $err;
        if ( mkdir "$lockdir" ) {
            }
        else {
            croak "mkdir: cannot create directory " . "$lockdir" . ": File exists\n";
        }
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
last;
    }
require Time::HiRes; Time::HiRes::sleep(q{1});
}
# Builtin command 'trap' with dynamic handler not supported
my $ret;
my @ret;
my %ret;
$ret = $?;
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("cofile")] }, None)')) {
        $main_exit_code = system('test', "$cofile", q{=}, "$ofile") >> 8;
    if ($CHILD_ERROR != 0) {
                my $force = 0;
        if ( -e "$cofile" ) {
            my $dest = "$ofile";
            if ( -e $dest && -d $dest ) {
                my $source_name = "$cofile";
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
            if ( File::Copy::move( "$cofile", $dest ) ) {
            } else {
                croak
  "mv: cannot move "$cofile" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "$cofile": No such file or directory\n";
        }
    }
}
else {
    if ((-f 'StringInterpolation(StringInterpolation { parts: [ParameterExpansion(ParameterExpansion { variable: "cofile", operator: None, is_mutable: true }), Literal("bj")] }, None)')) {
                $main_exit_code = system('test', ${cofile} . "bj", q{=}, "$ofile") >> 8;
        if ($CHILD_ERROR != 0) {
                        if ( -e "${cofile} . "bj"" ) {
                my $dest = "$ofile";
                if ( -e $dest && -d $dest ) {
                    my $source_name = "${cofile} . "bj"";
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
                if ( File::Copy::move( "${cofile} . "bj"", $dest ) ) {
                } else {
                    croak
  "mv: cannot move "${cofile} . "bj"" to $dest: $ERRNO\n";
                }
            } else {
                croak "mv: "${cofile} . "bj"": No such file or directory\n";
            }
        }
    }
}
rmdir ("$lockdir") or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;


exit $main_exit_code;
