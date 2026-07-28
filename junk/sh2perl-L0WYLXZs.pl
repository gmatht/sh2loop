#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $scriptversion;
my @scriptversion;
my %scriptversion;
$scriptversion = '2018-03-07.03';
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
    print q{Usage: depcomp [--help] [--version] PROGRAM [ARGS]

Run PROGRAMS ARGS to compile a file, generating dependencies
as side-effects.

Environment variables:
  depmode     Dependency tracking mode.
  source      Source file read by 'PROGRAMS ARGS'.
  object      Object file output by 'PROGRAMS ARGS'.
  DEPDIR      directory where to store dependencies.
  depfile     Dependency file to output.
  tmpdepfile  Temporary file to use when outputting dependencies.
  libtool     Whether libtool is used (yes/no).

Report bugs to <bug-automake@gnu.org>.
};
    } elsif ($arg1 =~ /^-v$/msx or $arg1 =~ /^--v.*$/msx) {
        do {
    my $__echo_line = "depcomp $scriptversion";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    }

sub set_dir_from {
if ($arg1 =~ /^.*/.*$/msx) {
                my $dir;
        my @dir;
        my %dir;
        $dir = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_0 = q{};
            my $output_printed_0;
            my $pipeline_success_0 = 1;
            $output_0 .= $1 . "\n";
            if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
            $CHILD_ERROR = 0;
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
    } elsif (1) {
                $dir = q{};
    }
    return;
}

sub set_base_from {
    my $base;
    my @base;
    my %base;
    $base = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
        $output_1 .= $1 . "\n";
        if ( !($output_1 =~ m{\n\z}msx) ) { $output_1 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
        my @sed_lines_1 = split /\n/msx, $output_1;
        my @sed_result_1;
        foreach my $line (@sed_lines_1) {
        chomp $line;
        push @sed_result_1, $line;
        }
        $output_1 = join "\n", @sed_result_1;

        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        $output_1 =~ s/\n+\z//msx;
        $output_1;
}; $_pipeline_result; };
    return;
}

sub make_dummy_depfile {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$ENV{depfile}"
      or die "Cannot open file: $OS_ERROR\n";
        print "#dummy\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub aix_post_process_depfile {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("tmpdepfile")] }, None)')) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$ENV{depfile}"
      or die "Cannot open file: $OS_ERROR\n";
open STDIN, '<', "$ENV{tmpdepfile}" or croak "Cannot open file: $OS_ERROR\n";
my @sed_lines_2 = split /\n/msx, $;
my @sed_result_2;
foreach my $line (@sed_lines_2) {
chomp $line;
push @sed_result_2, $line;
}
$ = join "\n", @sed_result_2;

open STDIN, '<', "$ENV{tmpdepfile}" or croak "Cannot open file: $OS_ERROR\n";
my @sed_lines_3 = split /\n/msx, $;
my @sed_result_3;
foreach my $line (@sed_lines_3) {
chomp $line;
push @sed_result_3, $line;
}
$ = join "\n", @sed_result_3;

            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
if ( -e "$ENV{tmpdepfile}" ) {
            if ( -d "$ENV{tmpdepfile}" ) {
                carp "rm: carping: ", "$ENV{tmpdepfile}",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$ENV{tmpdepfile}" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$ENV{tmpdepfile}",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
}
    else {
        make_dummy_depfile();
    }
    return;
}
my $tab;
my @tab;
my %tab;
$tab = "\t";
my $nl;
my @nl;
my %nl;
$nl = "\n";
my $upper;
my @upper;
my %upper;
$upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
my $lower;
my @lower;
my %lower;
$lower = 'abcdefghijklmnopqrstuvwxyz';
my $digits;
my @digits;
my %digits;
$digits = '0123456789';
my $alpha;
my @alpha;
my %alpha;
$alpha = $upper;
if (((!($main_exit_code = system('test', '-z', "$ENV{depmode}") >> 8) || !($main_exit_code = system('test', '-z', "$ENV{source}") >> 8)) || !($main_exit_code = system('test', '-z', "$ENV{object}") >> 8))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "depcomp: Variables source, object and depmode must be set\n";
    };
exit 1;
}
my $depfile;
my @depfile;
my %depfile;
$depfile = q{};
my $tmpdepfile;
my @tmpdepfile;
my %tmpdepfile;
$tmpdepfile = q{};
if ( -e "$tmpdepfile" ) {
    if ( -d "$tmpdepfile" ) {
        carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "$tmpdepfile" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
my $gccflag;
my @gccflag;
my %gccflag;
$gccflag = q{};
my $dashmflag;
my @dashmflag;
my %dashmflag;
$dashmflag = q{};
if (StringInterpolation(StringInterpolation { parts: [Variable("depmode")] }, None) eq hp) {
    $gccflag = '-M';
    my $depmode;
    my @depmode;
    my %depmode;
    $depmode = 'gcc';
}
if (StringInterpolation(StringInterpolation { parts: [Variable("depmode")] }, None) eq dashXmstdout) {
    $dashmflag = '-x';
    $main_exit_code = system('bash', 'M') >> 8;
    $depmode = 'dashmstdout';
}
my $cygpath_u;
my @cygpath_u;
my %cygpath_u;
$cygpath_u = "cygpath -u -f -";
if (StringInterpolation(StringInterpolation { parts: [Variable("depmode")] }, None) eq msvcmsys) {
    $cygpath_u = "sed s,\\\\\\\\,/,g";
    $depmode = 'msvisualcpp';
}
if (StringInterpolation(StringInterpolation { parts: [Variable("depmode")] }, None) eq msvc7msys) {
    $cygpath_u = "sed s,\\\\\\\\,/,g";
    $depmode = 'msvc7';
}
if (StringInterpolation(StringInterpolation { parts: [Variable("depmode")] }, None) eq xlc) {
    $gccflag = '-qmakedep';
    $CHILD_ERROR = 0;
    $depmode = 'gcc';
}
if ("$depmode" =~ /^gcc3$/msx) {
        my $arg;
    for my $arg () {
if ($arg =~ /^-c$/msx) {
            # set fnord not implemented
# set -MT not implemented
# set -MD not implemented
# set -MP not implemented
# set -MF not implemented
        } elsif (1) {
            # set fnord not implemented
        }
# Builtin command 'shift' not implemented
# Builtin command 'shift' not implemented
    }
        $CHILD_ERROR = 0;
        my $stat;
    my @stat;
    my %stat;
    $stat = $?;
    if ((Variable("stat", false, None) != 0)) {
if ( -e "$tmpdepfile" ) {
            if ( -d "$tmpdepfile" ) {
                carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmpdepfile" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmpdepfile",
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
    if ( -e "$tmpdepfile" ) {
        my $dest = "$depfile";
        if ( -e $dest && -d $dest ) {
            my $source_name = "$tmpdepfile";
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
        if ( File::Copy::move( "$tmpdepfile", $dest ) ) {
        } else {
            croak
  "mv: cannot move "$tmpdepfile" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "$tmpdepfile": No such file or directory\n";
    }
} elsif ("$depmode" =~ /^gcc$/msx) {
    if (StringInterpolation(StringInterpolation { parts: [Variable("gccflag")] }, None) eq q{}) {
        $gccflag = '-MD,';
    }
        $CHILD_ERROR = 0;
        $stat = $?;
    if ((Variable("stat", false, None) != 0)) {
if ( -e "$tmpdepfile" ) {
            if ( -d "$tmpdepfile" ) {
                carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmpdepfile" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    if ( -e "$depfile" ) {
        if ( -d "$depfile" ) {
            carp "rm: carping: ", "$depfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$depfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$depfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "$ENV{object} : \";
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
    open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
my @sed_lines_5 = split /\n/msx, $;
my @sed_result_5;
foreach my $line (@sed_lines_5) {
chomp $line;
push @sed_result_5, $line;
}
$ = join "\n", @sed_result_5;

        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
        # Original bash: tr ' ' "$nl" < "$tmpdepfile" \
{
        my $output_6 = q{};
        my $output_printed_6;
        my $pipeline_success_6 = 1;
                $output = q{};
        open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_7 = q{};
my $set1_9 = q{ };
my $set2_9 = "$nl";
my $input_9 = $output_6;
# Expand character ranges for tr command
my $expanded_set1_9 = $set1_9;
my $expanded_set2_9 = $set2_9;
# Handle a-z range in set1
if ($expanded_set1_9 =~ /a-z/msx) {
    $expanded_set1_9 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_9 =~ /A-Z/msx) {
    $expanded_set1_9 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_9 =~ /\[:upper:\]/msx) {
    $expanded_set1_9 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_9 =~ /\[:lower:\]/msx) {
    $expanded_set1_9 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_9 =~ /a-z/msx) {
    $expanded_set2_9 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_9 =~ /A-Z/msx) {
    $expanded_set2_9 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_9 =~ /\[:upper:\]/msx) {
    $expanded_set2_9 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_9 =~ /\[:lower:\]/msx) {
    $expanded_set2_9 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_8 = q{};
for my $char ( split //msx, $input_9 ) {
    my $pos_9 = index $expanded_set1_9, $char;
    if ( $pos_9 >= 0 && $pos_9 < length $expanded_set2_9 ) {
        $tr_result_8 .= substr $expanded_set2_9, $pos_9, 1;
    } else {
        $tr_result_8 .= $char;
    }
}
        if (!($tr_result_8 =~ m{\n\z}msx || $tr_result_8 eq q{})) {
            $tr_result_8 .= "\n";
        }
        $output_6 = $tr_result_8;
$tmp_redirect_7;
        $output_6 = $output;

                my @sed_lines_6 = split /\n/msx, $output_6;
        my @sed_result_6;
        foreach my $line (@sed_lines_6) {
        chomp $line;
        push @sed_result_6, $line;
        }
        $output_6 = join "\n", @sed_result_6;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$depfile"
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_10 = q{};
        my @sed_lines_11 = split /\n/msx, $output_6;
        my @sed_result_11;
        foreach my $line (@sed_lines_11) {
        chomp $line;
        push @sed_result_11, $line;
        }
        $output_6 = join "\n", @sed_result_11;
        $tmp_redirect_10;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_6; }
        $output_printed_6 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
        }
    if ( -e "$tmpdepfile" ) {
        if ( -d "$tmpdepfile" ) {
            carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpdepfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
} elsif ("$depmode" =~ /^hp$/msx) {
    exit 1;
} elsif ("$depmode" =~ /^sgi$/msx) {
    if (StringInterpolation(StringInterpolation { parts: [Variable("libtool")] }, None) eq yes) {
        $CHILD_ERROR = 0;
}
    else {
        $CHILD_ERROR = 0;
    }
        $stat = $?;
    if ((Variable("stat", false, None) != 0)) {
if ( -e "$tmpdepfile" ) {
            if ( -d "$tmpdepfile" ) {
                carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmpdepfile" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    if ( -e "$depfile" ) {
        if ( -d "$depfile" ) {
            carp "rm: carping: ", "$depfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$depfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$depfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("tmpdepfile")] }, None)')) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "$ENV{object} : \";
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
        # Original bash: tr ' ' "$nl" < "$tmpdepfile" \
{
            my $output_12 = q{};
            my $output_printed_12;
            my $pipeline_success_12 = 1;
                        $output = q{};
            open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_13 = q{};
my $set1_15 = q{ };
my $set2_15 = "$nl";
my $input_15 = $output_12;
# Expand character ranges for tr command
my $expanded_set1_15 = $set1_15;
my $expanded_set2_15 = $set2_15;
# Handle a-z range in set1
if ($expanded_set1_15 =~ /a-z/msx) {
    $expanded_set1_15 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_15 =~ /A-Z/msx) {
    $expanded_set1_15 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_15 =~ /\[:upper:\]/msx) {
    $expanded_set1_15 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_15 =~ /\[:lower:\]/msx) {
    $expanded_set1_15 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_15 =~ /a-z/msx) {
    $expanded_set2_15 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_15 =~ /A-Z/msx) {
    $expanded_set2_15 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_15 =~ /\[:upper:\]/msx) {
    $expanded_set2_15 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_15 =~ /\[:lower:\]/msx) {
    $expanded_set2_15 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_14 = q{};
for my $char ( split //msx, $input_15 ) {
    my $pos_15 = index $expanded_set1_15, $char;
    if ( $pos_15 >= 0 && $pos_15 < length $expanded_set2_15 ) {
        $tr_result_14 .= substr $expanded_set2_15, $pos_15, 1;
    } else {
        $tr_result_14 .= $char;
    }
}
            if (!($tr_result_14 =~ m{\n\z}msx || $tr_result_14 eq q{})) {
                $tr_result_14 .= "\n";
            }
            $output_12 = $tr_result_14;
$tmp_redirect_13;
            $output_12 = $output;

                        my @sed_lines_12 = split /\n/msx, $output_12;
            my @sed_result_12;
            foreach my $line (@sed_lines_12) {
            chomp $line;
            push @sed_result_12, $line;
            }
            $output_12 = join "\n", @sed_result_12;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$depfile"
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_16 = q{};
            my $set1_18 = "$nl";
            my $set2_18 = q{ };
            my $input_18 = $output_12;
            # Expand character ranges for tr command
            my $expanded_set1_18 = $set1_18;
            my $expanded_set2_18 = $set2_18;
            # Handle a-z range in set1
            if ($expanded_set1_18 =~ /a-z/msx) {
            $expanded_set1_18 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle A-Z range in set1
            if ($expanded_set1_18 =~ /A-Z/msx) {
            $expanded_set1_18 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:upper:] POSIX class in set1
            if ($expanded_set1_18 =~ /\[:upper:\]/msx) {
            $expanded_set1_18 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:lower:] POSIX class in set1
            if ($expanded_set1_18 =~ /\[:lower:\]/msx) {
            $expanded_set1_18 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle a-z range in set2
            if ($expanded_set2_18 =~ /a-z/msx) {
            $expanded_set2_18 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle A-Z range in set2
            if ($expanded_set2_18 =~ /A-Z/msx) {
            $expanded_set2_18 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:upper:] POSIX class in set2
            if ($expanded_set2_18 =~ /\[:upper:\]/msx) {
            $expanded_set2_18 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:lower:] POSIX class in set2
            if ($expanded_set2_18 =~ /\[:lower:\]/msx) {
            $expanded_set2_18 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
            }
            my $tr_result_17 = q{};
            for my $char ( split //msx, $input_18 ) {
            my $pos_18 = index $expanded_set1_18, $char;
            if ( $pos_18 >= 0 && $pos_18 < length $expanded_set2_18 ) {
            $tr_result_17 .= substr $expanded_set2_18, $pos_18, 1;
            } else {
            $tr_result_17 .= $char;
            }
            }
            if (!($tr_result_17 =~ m{\n\z}msx || $tr_result_17 eq q{})) {
            $tr_result_17 .= "\n";
            }
            $output_12 = $tr_result_17;
            $tmp_redirect_16;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_12; }
            $output_printed_12 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
            }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        # Original bash: tr ' ' "$nl" < "$tmpdepfile" \
{
            my $output_19 = q{};
            my $output_printed_19;
            my $pipeline_success_19 = 1;
                        $output = q{};
            open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_20 = q{};
my $set1_22 = q{ };
my $set2_22 = "$nl";
my $input_22 = $output_19;
# Expand character ranges for tr command
my $expanded_set1_22 = $set1_22;
my $expanded_set2_22 = $set2_22;
# Handle a-z range in set1
if ($expanded_set1_22 =~ /a-z/msx) {
    $expanded_set1_22 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_22 =~ /A-Z/msx) {
    $expanded_set1_22 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_22 =~ /\[:upper:\]/msx) {
    $expanded_set1_22 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_22 =~ /\[:lower:\]/msx) {
    $expanded_set1_22 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_22 =~ /a-z/msx) {
    $expanded_set2_22 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_22 =~ /A-Z/msx) {
    $expanded_set2_22 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_22 =~ /\[:upper:\]/msx) {
    $expanded_set2_22 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_22 =~ /\[:lower:\]/msx) {
    $expanded_set2_22 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_21 = q{};
for my $char ( split //msx, $input_22 ) {
    my $pos_22 = index $expanded_set1_22, $char;
    if ( $pos_22 >= 0 && $pos_22 < length $expanded_set2_22 ) {
        $tr_result_21 .= substr $expanded_set2_22, $pos_22, 1;
    } else {
        $tr_result_21 .= $char;
    }
}
            if (!($tr_result_21 =~ m{\n\z}msx || $tr_result_21 eq q{})) {
                $tr_result_21 .= "\n";
            }
            $output_19 = $tr_result_21;
$tmp_redirect_20;
            $output_19 = $output;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$depfile"
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_23 = q{};
            my @sed_lines_24 = split /\n/msx, $output_19;
            my @sed_result_24;
            foreach my $line (@sed_lines_24) {
            chomp $line;
            push @sed_result_24, $line;
            }
            $output_19 = join "\n", @sed_result_24;
            $tmp_redirect_23;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_19; }
            $output_printed_19 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_19 ) { $main_exit_code = 1; }
            }
}
    else {
        make_dummy_depfile();
    }
    if ( -e "$tmpdepfile" ) {
        if ( -d "$tmpdepfile" ) {
            carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpdepfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
} elsif ("$depmode" =~ /^xlc$/msx) {
    exit 1;
} elsif ("$depmode" =~ /^aix$/msx) {
        set_dir_from("$ENV{object}");
        set_base_from("$ENV{object}");
    if (StringInterpolation(StringInterpolation { parts: [Variable("libtool")] }, None) eq yes) {
        my $tmpdepfile1;
        my @tmpdepfile1;
        my %tmpdepfile1;
        $tmpdepfile1 = $dir;
        $CHILD_ERROR = 0;
        my $tmpdepfile2;
        my @tmpdepfile2;
        my %tmpdepfile2;
        $tmpdepfile2 = "$ENV{base}.u";
        my $tmpdepfile3;
        my @tmpdepfile3;
        my %tmpdepfile3;
        $tmpdepfile3 = "$ENV{dir}.libs";
        $main_exit_code = system('/', "$ENV{base}.u") >> 8;
        $CHILD_ERROR = 0;
}
    else {
        $tmpdepfile1 = $dir;
        $CHILD_ERROR = 0;
        $tmpdepfile2 = $dir;
        $CHILD_ERROR = 0;
        $tmpdepfile3 = $dir;
        $CHILD_ERROR = 0;
        $CHILD_ERROR = 0;
    }
        $stat = $?;
    if ((Variable("stat", false, None) != 0)) {
if ( -e "$tmpdepfile1" ) {
            if ( -d "$tmpdepfile1" ) {
                carp "rm: carping: ", "$tmpdepfile1",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmpdepfile1" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmpdepfile1",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "$tmpdepfile2" ) {
            if ( -d "$tmpdepfile2" ) {
                carp "rm: carping: ", "$tmpdepfile2",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmpdepfile2" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmpdepfile2",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "$tmpdepfile3" ) {
            if ( -d "$tmpdepfile3" ) {
                carp "rm: carping: ", "$tmpdepfile3",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmpdepfile3" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmpdepfile3",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
        for my $tmpdepfile ("$tmpdepfile1", "$tmpdepfile2", "$tmpdepfile3") {
        if (do {
$main_exit_code = system('test', '-f', "$tmpdepfile") >> 8;
            $CHILD_ERROR == 0
        }) {
            last;        }
    }
        aix_post_process_depfile();
} elsif ("$depmode" =~ /^tcc$/msx) {
        $CHILD_ERROR = 0;
        $stat = $?;
    if ((Variable("stat", false, None) != 0)) {
if ( -e "$tmpdepfile" ) {
            if ( -d "$tmpdepfile" ) {
                carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmpdepfile" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    if ( -e "$depfile" ) {
        if ( -d "$depfile" ) {
            carp "rm: carping: ", "$depfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$depfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$depfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
my @sed_lines_25 = split /\n/msx, $;
my @sed_result_25;
foreach my $line (@sed_lines_25) {
chomp $line;
push @sed_result_25, $line;
}
$ = join "\n", @sed_result_25;

        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
my @sed_lines_26 = split /\n/msx, $;
my @sed_result_26;
foreach my $line (@sed_lines_26) {
chomp $line;
push @sed_result_26, $line;
}
$ = join "\n", @sed_result_26;

        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ( -e "$tmpdepfile" ) {
        if ( -d "$tmpdepfile" ) {
            carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpdepfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
} elsif ("$depmode" =~ /^pgcc$/msx) {
        set_dir_from("$ENV{object}");
        set_base_from("$ENV{source}");
        $tmpdepfile = "$ENV{base}.d";
        my $lockdir;
    my @lockdir;
    my %lockdir;
    $lockdir = "$ENV{base}.d-lock";
    # Builtin command 'trap' with dynamic handler not supported
        my $numtries;
    my @numtries;
    my %numtries;
    $numtries = '100';
        my $i;
    my @i;
    my %i;
    $i = $numtries;
    while ( (Variable("i", false, None) > 0) ) {
if (!(        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            use File::Path qw(make_path);
            if ( mkdir "$lockdir" ) {
                }
            else {
                croak "mkdir: cannot create directory " . "$lockdir" . ": File exists\n";
            }
        })) {
            $CHILD_ERROR = 0;
            $stat = $?;
rmdir ("$lockdir") or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
last;
}
        else {
while (1) {
                last unless do {
                    $main_exit_code = system('test', '-d', "$lockdir") >> 8;
                    $CHILD_ERROR == 0
                };
                last unless do {
                    $main_exit_code = system('test', $i, '-gt', q{0}) >> 8;
                    $CHILD_ERROR == 0
                };
require Time::HiRes; Time::HiRes::sleep(q{1});
                $i = do {
    my ($in_30, $out_30);
    my $pid_30 = open3($in_30, $out_30, '>&STDERR', 'expr', $i, q{-}, q{1});
    close $in_30 or croak 'Close failed: $OS_ERROR';
    my $result_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
    close $out_30 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_30, 0;
    $result_30
};
            }
        }
        $i = do {
    my ($in_31, $out_31);
    my $pid_31 = open3($in_31, $out_31, '>&STDERR', 'expr', $i, q{-}, q{1});
    close $in_31 or croak 'Close failed: $OS_ERROR';
    my $result_31 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
    close $out_31 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_31, 0;
    $result_31
};
    }
    $SIG{1} = sub { qx'-'; };
    if ((Variable("i", false, None) <= 0)) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$PROGRAM_NAME: failed to acquire lock after $numtries attempts";
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
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$PROGRAM_NAME: check lockdir '$lockdir'";
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
    if ((Variable("stat", false, None) != 0)) {
if ( -e "$tmpdepfile" ) {
            if ( -d "$tmpdepfile" ) {
                carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmpdepfile" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    if ( -e "$depfile" ) {
        if ( -d "$depfile" ) {
            carp "rm: carping: ", "$depfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$depfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$depfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
my @sed_lines_32 = split /\n/msx, $;
my @sed_result_32;
foreach my $line (@sed_lines_32) {
chomp $line;
push @sed_result_32, $line;
}
$ = join "\n", @sed_result_32;

        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
        # Original bash: sed 's,^[^:]*: \(.*\)$,\1,;s/^\\$//;/^$/d;/:$/d' < "$tmpdepfile" \
{
        my $output_33 = q{};
        my $output_printed_33;
        my $pipeline_success_33 = 1;
                $output = q{};
        open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_34 = q{};
my @sed_lines_35 = split /\n/msx, $output_33;
my @sed_result_35;
foreach my $line (@sed_lines_35) {
chomp $line;
push @sed_result_35, $line;
}
$output_33 = join "\n", @sed_result_35;

$tmp_redirect_34;
        $output_33 = $output;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$depfile"
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_36 = q{};
        my @sed_lines_37 = split /\n/msx, $output_33;
        my @sed_result_37;
        foreach my $line (@sed_lines_37) {
        chomp $line;
        push @sed_result_37, $line;
        }
        $output_33 = join "\n", @sed_result_37;
        $tmp_redirect_36;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_33; }
        $output_printed_33 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_33 ) { $main_exit_code = 1; }
        }
    if ( -e "$tmpdepfile" ) {
        if ( -d "$tmpdepfile" ) {
            carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpdepfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
} elsif ("$depmode" =~ /^hp2$/msx) {
        set_dir_from("$ENV{object}");
        set_base_from("$ENV{object}");
    if (StringInterpolation(StringInterpolation { parts: [Variable("libtool")] }, None) eq yes) {
        $tmpdepfile1 = $dir;
        $CHILD_ERROR = 0;
        $tmpdepfile2 = "$ENV{dir}.libs";
        $main_exit_code = system('/', "$ENV{base}.d") >> 8;
        $CHILD_ERROR = 0;
}
    else {
        $tmpdepfile1 = $dir;
        $CHILD_ERROR = 0;
        $tmpdepfile2 = $dir;
        $CHILD_ERROR = 0;
        $CHILD_ERROR = 0;
    }
        $stat = $?;
    if ((Variable("stat", false, None) != 0)) {
if ( -e "$tmpdepfile1" ) {
            if ( -d "$tmpdepfile1" ) {
                carp "rm: carping: ", "$tmpdepfile1",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmpdepfile1" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmpdepfile1",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "$tmpdepfile2" ) {
            if ( -d "$tmpdepfile2" ) {
                carp "rm: carping: ", "$tmpdepfile2",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmpdepfile2" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmpdepfile2",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
        for my $tmpdepfile ("$tmpdepfile1", "$tmpdepfile2") {
        if (do {
$main_exit_code = system('test', '-f', "$tmpdepfile") >> 8;
            $CHILD_ERROR == 0
        }) {
            last;        }
    }
    if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("tmpdepfile")] }, None)')) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
my @sed_lines_38 = split /\n/msx, $;
my @sed_result_38;
foreach my $line (@sed_lines_38) {
chomp $line;
push @sed_result_38, $line;
}
$ = join "\n", @sed_result_38;

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
            open STDOUT, '>>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
my @sed_lines_39 = split /\n/msx, $;
my @sed_result_39;
foreach my $line (@sed_lines_39) {
chomp $line;
push @sed_result_39, $line;
}
$ = join "\n", @sed_result_39;

            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
}
    else {
        make_dummy_depfile();
    }
    if ( -e "$tmpdepfile" ) {
        if ( -d "$tmpdepfile" ) {
            carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpdepfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "$tmpdepfile2" ) {
        if ( -d "$tmpdepfile2" ) {
            carp "rm: carping: ", "$tmpdepfile2",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpdepfile2" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$tmpdepfile2",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
} elsif ("$depmode" =~ /^tru64$/msx) {
        set_dir_from("$ENV{object}");
        set_base_from("$ENV{object}");
    if (StringInterpolation(StringInterpolation { parts: [Variable("libtool")] }, None) eq yes) {
        $tmpdepfile1 = $dir;
        $CHILD_ERROR = 0;
        $tmpdepfile2 = "$ENV{dir}.libs";
        $main_exit_code = system('/', "$ENV{base}.o", '.d') >> 8;
        $tmpdepfile3 = "$ENV{dir}.libs";
        $main_exit_code = system('/', "$ENV{base}.d") >> 8;
        $CHILD_ERROR = 0;
}
    else {
        $tmpdepfile1 = $dir;
        $CHILD_ERROR = 0;
        $tmpdepfile2 = $dir;
        $CHILD_ERROR = 0;
        $tmpdepfile3 = $dir;
        $CHILD_ERROR = 0;
        $CHILD_ERROR = 0;
    }
        $stat = $?;
    if ((Variable("stat", false, None) != 0)) {
if ( -e "$tmpdepfile1" ) {
            if ( -d "$tmpdepfile1" ) {
                carp "rm: carping: ", "$tmpdepfile1",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmpdepfile1" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmpdepfile1",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "$tmpdepfile2" ) {
            if ( -d "$tmpdepfile2" ) {
                carp "rm: carping: ", "$tmpdepfile2",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmpdepfile2" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmpdepfile2",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "$tmpdepfile3" ) {
            if ( -d "$tmpdepfile3" ) {
                carp "rm: carping: ", "$tmpdepfile3",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmpdepfile3" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmpdepfile3",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
        for my $tmpdepfile ("$tmpdepfile1", "$tmpdepfile2", "$tmpdepfile3") {
        if (do {
$main_exit_code = system('test', '-f', "$tmpdepfile") >> 8;
            $CHILD_ERROR == 0
        }) {
            last;        }
    }
        aix_post_process_depfile();
} elsif ("$depmode" =~ /^msvc7$/msx) {
    if (StringInterpolation(StringInterpolation { parts: [Variable("libtool")] }, None) eq yes) {
        my $showIncludes;
        my @showIncludes;
        my %showIncludes;
        $showIncludes = '-Wc,';
        $main_exit_code = system('-s', 'howIncludes') >> 8;
}
    else {
        $showIncludes = '-s';
        $main_exit_code = system('bash', 'howIncludes') >> 8;
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$tmpdepfile"
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
        $stat = $?;
    my $grep_result_40;
my @grep_lines_40 = ();
my @grep_filtered_40 = grep { !/^Note:\ including\ file:\ /msx } @grep_lines_40;
$grep_result_40 = join "\n", @grep_filtered_40;
    if (!($grep_result_40 =~ m{\n\z}msx || $grep_result_40 eq q{})) {
        $grep_result_40 .= "\n";
    }
print $grep_result_40;
$CHILD_ERROR = scalar @grep_filtered_40 > 0 ? 0 : 1;
    if ((Variable("stat", false, None) != 0)) {
if ( -e "$tmpdepfile" ) {
            if ( -d "$tmpdepfile" ) {
                carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$tmpdepfile" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    if ( -e "$depfile" ) {
        if ( -d "$depfile" ) {
            carp "rm: carping: ", "$depfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$depfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$depfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "$ENV{object} : \";
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
    open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
my @sed_lines_41 = split /\n/msx, $;
my @sed_result_41;
foreach my $line (@sed_lines_41) {
chomp $line;
push @sed_result_41, $line;
}
$ = join "\n", @sed_result_41;

        # Original bash: -n '
{
        my $output_42 = q{};
        my $output_printed_42;
        my $pipeline_success_42 = 1;
                my ($in_43, $out_43);
        my $pid_43 = open3($in_43, $out_43, '>&STDERR', '-n', "\n/^Note: including file:  *\\(.*\\)/ {\n  s//\\1/\n  s/\\\\/\\\\\\\\/g\n  p\n}");
        close $in_43 or croak 'Close failed: $OS_ERROR';
        $output_42 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_43> };
        close $out_43 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_43, 0;

                my $cmd_45 = 'unknown_command';
        my ($in_44, $out_44);
        my $pid_44 = open3($in_44, $out_44, '>&STDERR', $cmd_45, );
        print {$in_44} $output_42;
        close $in_44 or croak 'Close failed: $OS_ERROR';
        $output_42 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_44> };
        close $out_44 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_44, 0;

                my @sort_lines_42_2 = split /\n/msx, $output_42;
        my @sort_sorted_42_2 = sort @sort_lines_42_2;
        my $output_42_2 = join "\n", @sort_sorted_42_2;
        if ($output_42_2 ne q{} && !($output_42_2 =~ m{\n\z}msx)) {
        $output_42_2 .= "\n";
        }
        $output_42 = $output_42_2;
        $output_42 = $output_42_2;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$depfile"
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_46 = q{};
        my @sed_lines_47 = split /\n/msx, $output_42;
        my @sed_result_47;
        foreach my $line (@sed_lines_47) {
        chomp $line;
        push @sed_result_47, $line;
        }
        $output_42 = join "\n", @sed_result_47;
        $tmp_redirect_46;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_42; }
        $output_printed_42 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_42 ) { $main_exit_code = 1; }
        }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ( -e "$tmpdepfile" ) {
        if ( -d "$tmpdepfile" ) {
            carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpdepfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
} elsif ("$depmode" =~ /^msvc7msys$/msx) {
    exit 1;
} elsif ("$depmode" =~ /^dashmstdout$/msx) {
            $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) {
            }
    if (StringInterpolation(StringInterpolation { parts: [Variable("libtool")] }, None) eq yes) {
while ( (!StringInterpolation(StringInterpolation { parts: [Literal("X"), Variable("1")] }, None) eq X--mode=compile) ) {
# Builtin command 'shift' not implemented
        }
# Builtin command 'shift' not implemented
    }
        my $IFS;
    my @IFS;
    my %IFS;
    $IFS = " ";
        for my $arg () {
if ($arg =~ /^-o$/msx) {
            # Builtin command 'shift' not implemented
        } elsif ($arg =~ /^$object$/msx) {
            # Builtin command 'shift' not implemented
        } elsif (1) {
            # set fnord not implemented
            # Builtin command 'shift' not implemented
            # Builtin command 'shift' not implemented
        }
    }
        if (do {
$main_exit_code = system('test', '-z', "$dashmflag") >> 8;
        $CHILD_ERROR == 0
    }) {
                $dashmflag = '-M';
    }
        # Original bash: "$@" $dashmflag |
{
        my $output_48 = q{};
        my $output_printed_48;
        my $pipeline_success_48 = 1;
                my ($in_49, $out_49);
        my $pid_49 = open3($in_49, $out_49, '>&STDERR', 'unknown_command', );
        close $in_49 or croak 'Close failed: $OS_ERROR';
        $output_48 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_49> };
        close $out_49 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_49, 0;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$tmpdepfile"
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_50 = q{};
        my @sed_lines_51 = split /\n/msx, $output_48;
        my @sed_result_51;
        foreach my $line (@sed_lines_51) {
        chomp $line;
        push @sed_result_51, $line;
        }
        $output_48 = join "\n", @sed_result_51;
        $tmp_redirect_50;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_48; }
        $output_printed_48 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_48 ) { $main_exit_code = 1; }
        }
    if ( -e "$depfile" ) {
        if ( -d "$depfile" ) {
            carp "rm: carping: ", "$depfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$depfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$depfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
my $cat_stdin = do { local $INPUT_RECORD_SEPARATOR = undef; <STDIN> };
print $cat_stdin;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
        # Original bash: tr ' ' "$nl" < "$tmpdepfile" \
{
        my $output_53 = q{};
        my $output_printed_53;
        my $pipeline_success_53 = 1;
                $output = q{};
        open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_54 = q{};
my $set1_56 = q{ };
my $set2_56 = "$nl";
my $input_56 = $output_53;
# Expand character ranges for tr command
my $expanded_set1_56 = $set1_56;
my $expanded_set2_56 = $set2_56;
# Handle a-z range in set1
if ($expanded_set1_56 =~ /a-z/msx) {
    $expanded_set1_56 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_56 =~ /A-Z/msx) {
    $expanded_set1_56 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_56 =~ /\[:upper:\]/msx) {
    $expanded_set1_56 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_56 =~ /\[:lower:\]/msx) {
    $expanded_set1_56 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_56 =~ /a-z/msx) {
    $expanded_set2_56 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_56 =~ /A-Z/msx) {
    $expanded_set2_56 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_56 =~ /\[:upper:\]/msx) {
    $expanded_set2_56 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_56 =~ /\[:lower:\]/msx) {
    $expanded_set2_56 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_55 = q{};
for my $char ( split //msx, $input_56 ) {
    my $pos_56 = index $expanded_set1_56, $char;
    if ( $pos_56 >= 0 && $pos_56 < length $expanded_set2_56 ) {
        $tr_result_55 .= substr $expanded_set2_56, $pos_56, 1;
    } else {
        $tr_result_55 .= $char;
    }
}
        if (!($tr_result_55 =~ m{\n\z}msx || $tr_result_55 eq q{})) {
            $tr_result_55 .= "\n";
        }
        $output_53 = $tr_result_55;
$tmp_redirect_54;
        $output_53 = $output;

                my @sed_lines_53 = split /\n/msx, $output_53;
        my @sed_result_53;
        foreach my $line (@sed_lines_53) {
        chomp $line;
        push @sed_result_53, $line;
        }
        $output_53 = join "\n", @sed_result_53;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$depfile"
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_57 = q{};
        my @sed_lines_58 = split /\n/msx, $output_53;
        my @sed_result_58;
        foreach my $line (@sed_lines_58) {
        chomp $line;
        push @sed_result_58, $line;
        }
        $output_53 = join "\n", @sed_result_58;
        $tmp_redirect_57;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_53; }
        $output_printed_53 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_53 ) { $main_exit_code = 1; }
        }
    if ( -e "$tmpdepfile" ) {
        if ( -d "$tmpdepfile" ) {
            carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpdepfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
} elsif ("$depmode" =~ /^dashXmstdout$/msx) {
    exit 1;
} elsif ("$depmode" =~ /^makedepend$/msx) {
            $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) {
            }
    if (StringInterpolation(StringInterpolation { parts: [Variable("libtool")] }, None) eq yes) {
while ( (!StringInterpolation(StringInterpolation { parts: [Literal("X"), Variable("1")] }, None) eq X--mode=compile) ) {
# Builtin command 'shift' not implemented
        }
# Builtin command 'shift' not implemented
    }
    # Builtin command 'shift' not implemented
        my $cleared;
    my @cleared;
    my %cleared;
    $cleared = 'no';
        my $eat;
    my @eat;
    my %eat;
    $eat = 'no';
        for my $arg () {
if ($cleared =~ /^no$/msx) {
                        # Builtin command 'shift' not implemented
                        $cleared = 'yes';
        }
if (Variable("eat", false, None) eq yes) {
            $eat = 'no';
next;
        }
if ("$arg" =~ /^-D.*$/msx or "$arg" =~ /^-I.*$/msx) {
            # set fnord not implemented
            # Builtin command 'shift' not implemented
        } elsif ("$arg" =~ /^-arch$/msx) {
                        $eat = 'yes';
        } elsif ("$arg" =~ /^-.*$/msx or "$arg" =~ /^$object$/msx) {
        } elsif (1) {
            # set fnord not implemented
            # Builtin command 'shift' not implemented
        }
    }
        my $obj_suffix;
    my @obj_suffix;
    my %obj_suffix;
    $obj_suffix = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_59 = q{};
        my $output_printed_59;
        my $pipeline_success_59 = 1;
        $output_59 .= $object . "\n";
        if ( !($output_59 =~ m{\n\z}msx) ) { $output_59 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_59 = 0; }
        my @sed_lines_59 = split /\n/msx, $output_59;
        my @sed_result_59;
        foreach my $line (@sed_lines_59) {
        chomp $line;
        $line =~ s/^.*\././gmsx;
        push @sed_result_59, $line;
        }
        $output_59 = join "\n", @sed_result_59;

        if ( !$pipeline_success_59 ) { $main_exit_code = 1; }
        $output_59 =~ s/\n+\z//msx;
        $output_59;
}; $_pipeline_result; };
        if ( -e "$tmpdepfile" ) {
        my $current_time = time;
        utime $current_time, $current_time, "$tmpdepfile";
    }
    else {
        if ( open my $fh, '>', "$tmpdepfile" ) {
            close $fh or croak "Close failed: $ERRNO";
        }
        else {
            croak "touch: cannot create ", "$tmpdepfile",
              ": $ERRNO\n";
        }
    }
        $CHILD_ERROR = 0;
    if ( -e "$depfile" ) {
        if ( -d "$depfile" ) {
            carp "rm: carping: ", "$depfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$depfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$depfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
my @sed_lines_61 = split /\n/msx, $;
my @sed_result_61;
foreach my $line (@sed_lines_61) {
chomp $line;
push @sed_result_61, $line;
}
$ = join "\n", @sed_result_61;

        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
        # Original bash: sed '1,2d' "$tmpdepfile" \
{
        my $output_62 = q{};
        my $output_printed_62;
        my $pipeline_success_62 = 1;
                my @sed_lines_62 = split /\n/msx, $;
        my @sed_result_62;
        foreach my $line (@sed_lines_62) {
        chomp $line;
        push @sed_result_62, $line;
        }
        $ = join "\n", @sed_result_62;

                my $set1_63 = q{ };
        my $set2_63 = "$nl";
        my $input_63 = $output_62;
        # Expand character ranges for tr command
        my $expanded_set1_63 = $set1_63;
        my $expanded_set2_63 = $set2_63;
        # Handle a-z range in set1
        if ($expanded_set1_63 =~ /a-z/msx) {
        $expanded_set1_63 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_63 =~ /A-Z/msx) {
        $expanded_set1_63 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_63 =~ /\[:upper:\]/msx) {
        $expanded_set1_63 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_63 =~ /\[:lower:\]/msx) {
        $expanded_set1_63 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_63 =~ /a-z/msx) {
        $expanded_set2_63 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_63 =~ /A-Z/msx) {
        $expanded_set2_63 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_63 =~ /\[:upper:\]/msx) {
        $expanded_set2_63 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_63 =~ /\[:lower:\]/msx) {
        $expanded_set2_63 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_62_1 = q{};
        for my $char ( split //msx, $input_63 ) {
        my $pos_63 = index $expanded_set1_63, $char;
        if ( $pos_63 >= 0 && $pos_63 < length $expanded_set2_63 ) {
        $tr_result_62_1 .= substr $expanded_set2_63, $pos_63, 1;
        } else {
        $tr_result_62_1 .= $char;
        }
        }
        if (!($tr_result_62_1 =~ m{\n\z}msx || $tr_result_62_1 eq q{})) {
        $tr_result_62_1 .= "\n";
        }
        $output_62 = $tr_result_62_1;
        $output_62 = $tr_result_62_1;

                my @sed_lines_62 = split /\n/msx, $output_62;
        my @sed_result_62;
        foreach my $line (@sed_lines_62) {
        chomp $line;
        push @sed_result_62, $line;
        }
        $output_62 = join "\n", @sed_result_62;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$depfile"
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_64 = q{};
        my @sed_lines_65 = split /\n/msx, $output_62;
        my @sed_result_65;
        foreach my $line (@sed_lines_65) {
        chomp $line;
        push @sed_result_65, $line;
        }
        $output_62 = join "\n", @sed_result_65;
        $tmp_redirect_64;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_62; }
        $output_printed_62 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_62 ) { $main_exit_code = 1; }
        }
    if ( -e "$tmpdepfile" ) {
        if ( -d "$tmpdepfile" ) {
            carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpdepfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "$tmpdepfile" ) {
        if ( -d "$tmpdepfile" ) {
            carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpdepfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e ".bak" ) {
        if ( -d ".bak" ) {
            carp "rm: carping: ", ".bak",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink ".bak" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ".bak",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
} elsif ("$depmode" =~ /^cpp$/msx) {
            $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) {
            }
    if (StringInterpolation(StringInterpolation { parts: [Variable("libtool")] }, None) eq yes) {
while ( (!StringInterpolation(StringInterpolation { parts: [Literal("X"), Variable("1")] }, None) eq X--mode=compile) ) {
# Builtin command 'shift' not implemented
        }
# Builtin command 'shift' not implemented
    }
        $IFS = " ";
        for my $arg () {
if ($arg =~ /^-o$/msx) {
            # Builtin command 'shift' not implemented
        } elsif ($arg =~ /^$object$/msx) {
            # Builtin command 'shift' not implemented
        } elsif (1) {
            # set fnord not implemented
            # Builtin command 'shift' not implemented
            # Builtin command 'shift' not implemented
        }
    }
        # Original bash: "$@" -E \
{
        my $output_66 = q{};
        my $output_printed_66;
        my $pipeline_success_66 = 1;
                my ($in_67, $out_67);
        my $pid_67 = open3($in_67, $out_67, '>&STDERR', 'unknown_command', '-E');
        close $in_67 or croak 'Close failed: $OS_ERROR';
        $output_66 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_67> };
        close $out_67 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_67, 0;

                my @sed_lines_66 = split /\n/msx, $output_66;
        my @sed_result_66;
        foreach my $line (@sed_lines_66) {
        chomp $line;
        push @sed_result_66, $line;
        }
        $output_66 = join "\n", @sed_result_66;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$tmpdepfile"
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_68 = q{};
        my @sed_lines_69 = split /\n/msx, $output_66;
        my @sed_result_69;
        foreach my $line (@sed_lines_69) {
        chomp $line;
        push @sed_result_69, $line;
        }
        $output_66 = join "\n", @sed_result_69;
        $tmp_redirect_68;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_66; }
        $output_printed_66 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_66 ) { $main_exit_code = 1; }
        }
    if ( -e "$depfile" ) {
        if ( -d "$depfile" ) {
            carp "rm: carping: ", "$depfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$depfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$depfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "$ENV{object} : \";
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
    open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
my $cat_stdin = do { local $INPUT_RECORD_SEPARATOR = undef; <STDIN> };
print $cat_stdin;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
my @sed_lines_71 = split /\n/msx, $;
my @sed_result_71;
foreach my $line (@sed_lines_71) {
chomp $line;
push @sed_result_71, $line;
}
$ = join "\n", @sed_result_71;

        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('bash', '/^$/d;s/^ //;s/ \\$//;s/$/ :/') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ( -e "$tmpdepfile" ) {
        if ( -d "$tmpdepfile" ) {
            carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpdepfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
} elsif ("$depmode" =~ /^msvisualcpp$/msx) {
            $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) {
            }
    if (StringInterpolation(StringInterpolation { parts: [Variable("libtool")] }, None) eq yes) {
while ( (!StringInterpolation(StringInterpolation { parts: [Literal("X"), Variable("1")] }, None) eq X--mode=compile) ) {
# Builtin command 'shift' not implemented
        }
# Builtin command 'shift' not implemented
    }
        $IFS = " ";
        for my $arg () {
if ("$arg" =~ /^-o$/msx) {
            # Builtin command 'shift' not implemented
        } elsif ("$arg" =~ /^$object$/msx) {
            # Builtin command 'shift' not implemented
        } elsif ("$arg" =~ /^-Gm$/msx or "$arg" =~ /^/Gm$/msx or "$arg" =~ /^-Gi$/msx or "$arg" =~ /^/Gi$/msx or "$arg" =~ /^-ZI$/msx or "$arg" =~ /^/ZI$/msx) {
            # set fnord not implemented
            # Builtin command 'shift' not implemented
            # Builtin command 'shift' not implemented
        } elsif (1) {
            # set fnord not implemented
            # Builtin command 'shift' not implemented
            # Builtin command 'shift' not implemented
        }
    }
        # Original bash: "$@" -E 2>/dev/null |
{
        my $output_72 = q{};
        my $output_printed_72;
        my $pipeline_success_72 = 1;
                $output = q{};
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_73 = q{};

my $cmd_76 = 'unknown_command';
my ($in_75, $out_75);
my $pid_75 = open3($in_75, $out_75, '>&STDERR', $cmd_76, '-E');
print {$in_75} $output_72;
close $in_75 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_73 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_75> };
close $out_75 or croak 'Close failed: $OS_ERROR';
waitpid $pid_75, 0;
$tmp_redirect_73;
        };
        $output_72 = $output;

                my @sed_lines_72 = split /\n/msx, $output_72;
        my @sed_result_72;
        foreach my $line (@sed_lines_72) {
        chomp $line;
        push @sed_result_72, $line;
        }
        $output_72 = join "\n", @sed_result_72;

                my $cmd_78 = 'unknown_command';
        my ($in_77, $out_77);
        my $pid_77 = open3($in_77, $out_77, '>&STDERR', $cmd_78, );
        print {$in_77} $output_72;
        close $in_77 or croak 'Close failed: $OS_ERROR';
        $output_72 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_77> };
        close $out_77 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_77, 0;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$tmpdepfile"
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_79 = q{};
        my @sort_lines_80 = split /\n/msx, $output_72;
        my @sort_sorted_80 = sort @sort_lines_80;
        $tmp_redirect_79 = join "\n", @sort_sorted_80;
        if ($tmp_redirect_79 ne q{} && !($tmp_redirect_79 =~ m{\n\z}msx)) {
        $tmp_redirect_79 .= "\n";
        }
        $output_72 = $tmp_redirect_79;
        $tmp_redirect_79;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_72; }
        $output_printed_72 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_72 ) { $main_exit_code = 1; }
        }
    if ( -e "$depfile" ) {
        if ( -d "$depfile" ) {
            carp "rm: carping: ", "$depfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$depfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$depfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "$ENV{object} : \";
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
    open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
my @sed_lines_81 = split /\n/msx, $;
my @sed_result_81;
foreach my $line (@sed_lines_81) {
chomp $line;
push @sed_result_81, $line;
}
$ = join "\n", @sed_result_81;

        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('-n', '-e', "s% %\\\\ %g", '-e', "/^\\(.*\\)$/ s::", "$tab", "\\1 \\\\:p") >> 8;
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
        open STDOUT, '>>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
        print $tab;
if ( !( ($tab) =~ m{\n\z}msx ) ) { print "\n"; }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    open STDIN, '<', "$tmpdepfile" or croak "Cannot open file: $OS_ERROR\n";
my @sed_lines_82 = split /\n/msx, $;
my @sed_result_82;
foreach my $line (@sed_lines_82) {
chomp $line;
push @sed_result_82, $line;
}
$ = join "\n", @sed_result_82;

        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$depfile"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('-n', '-e', "s% %\\\\ %g", '-e', "/^\\(.*\\)$/ s::\\1\\::p") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ( -e "$tmpdepfile" ) {
        if ( -d "$tmpdepfile" ) {
            carp "rm: carping: ", "$tmpdepfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpdepfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$tmpdepfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
} elsif ("$depmode" =~ /^msvcmsys$/msx) {
    exit 1;
} elsif ("$depmode" =~ /^none$/msx) {
    # Builtin command 'exec' not implemented
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "Unknown depmode $depmode";
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

exit $main_exit_code;
