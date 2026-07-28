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

my $PATH;
my @PATH;
my %PATH;
$PATH = "/usr/bin:$PATH";
my $x;
my @x;
my %x;
$x = do { use File::Basename qw(basename); my $basename_output = basename($PROGRAM_NAME); $CHILD_ERROR = 0; $basename_output; };
if (Variable("#", false, None) eq 0) {
    print 'compress' . q{ } . 'executables.' . q{ } . 'original' . q{ } . 'file' . q{ } . 'foo' . q{ } . 'is' . q{ } . 'renamed' . q{ } . 'to' . q{ } . 'foo' . q{ } . q{~} . "\n";
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = 'usage:' . q{ } . $x . q{ } . q{[} . q{ } . '-d' . q{ } . q{]} . q{ } . 'files...';
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "   -d  decompress the executables\n";
exit 1;
}
# set -C not implemented
my $tmp;
my @tmp;
my %tmp;
$tmp = 'gz';
# Builtin command 'trap' with dynamic handler not supported
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', $tmp
      or die "Cannot access file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('bash', ':') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if ($CHILD_ERROR != 0) {
    exit 1;
}
my $decomp;
my @decomp;
my %decomp;
$decomp = q{0};
my $res;
my @res;
my %res;
$res = q{0};
if (do {
$main_exit_code = system('test', "$x", q{=}, "ungzexe") >> 8;
    $CHILD_ERROR == 0
}) {
        $decomp = q{1};
}
if (StringInterpolation(StringInterpolation { parts: [Literal("x"), Variable("1")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("x-d")] }, None)) {
    $decomp = q{1};
# Builtin command 'shift' not implemented
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', 'zfoo1'
      or die "Cannot access file: $OS_ERROR\n";
    do {
    my $__echo_line = 'hi' . q{ } . $$;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
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
if ($CHILD_ERROR != 0) {
    exit 1;
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', 'zfoo2'
      or die "Cannot access file: $OS_ERROR\n";
    do {
    my $__echo_line = 'hi' . q{ } . $$;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
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
if ($CHILD_ERROR != 0) {
    exit 1;
}
if (StringInterpolation(StringInterpolation { parts: [CommandSubstitution(Redirect(RedirectCommand { command: Subshell(Simple(SimpleCommand { name: Variable("CPMOD-cpmod", true, None), args: [Literal("zfoo1", None), Variable("$", false, None), Literal("zfoo2", None), Variable("$", false, None)], redirects: [], env_vars: {}, stdout_used: true, stderr_used: true })), redirects: [Redirect { fd: Some(2), operator: StderrOutput, target: Literal("1", None), heredoc_body: None, heredoc_quoted: false }] }))] }, None) eq q{}) {
    my $cpmod;
    my @cpmod;
    my %cpmod;
    $cpmod = $CPMOD-cpmod;
}
if ( -e "zfoo[12]" ) {
    if ( -d "zfoo[12]" ) {
        carp "rm: carping: ", "zfoo[12]",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "zfoo[12]" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "zfoo[12]",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
if ( -e "$$" ) {
    if ( -d "$$" ) {
        carp "rm: carping: ", $$,
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "$$" ) {
                    }
        else {
            carp "rm: carping: could not remove ", $$,
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
my $tail;
my @tail;
my %tail;
$tail = "";
my $IFS;
my @IFS;
my %IFS;
$IFS = ($ENV{IFS= 	} // q{});
my $saveifs;
my @saveifs;
my %saveifs;
$saveifs = "$IFS";
$IFS = ${IFS} . ":";
my $dir;
for my $dir ($PATH) {
    if (do {
$main_exit_code = system('test', '-z', "$dir") >> 8;
        $CHILD_ERROR == 0
    }) {
                $dir = q{.};
    }
if ((-f 'Variable("dir", false, None) /tail')) {
        $tail = "$dir/tail";
last;
    }
}
$IFS = "$saveifs";
if (StringInterpolation(StringInterpolation { parts: [Variable("tail")] }, None) eq q{}) {
    print 'cannot' . q{ } . 'find' . q{ } . 'tail' . "\n";
    $CHILD_ERROR = 0;
exit 1;
}
if (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
    $output_0 .= 'foo' . "\n";
    if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
    $CHILD_ERROR = 0;
    my $cmd_2 = 'unknown_command';
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', $cmd_2, '-n', '+1');
    print {$in_1} $output_0;
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    $output_0 =~ s/\n+\z//msx;
    $output_0;
}; $_pipeline_result; } =~ /^foo$/msx) {
        $tail = "$tail -n";
}
my $i;
for my $i () {
if ((-f '! StringInterpolation(StringInterpolation { parts: [Variable("i")] }, None)')) {
        do {
    my $__echo_line = $x . q{ } . q{:} . q{ } . $i . q{ } . 'not' . q{ } . q{a} . q{ } . 'file';
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        $res = q{1};
next;
    }
if ((Variable("decomp", false, None) == 0)) {
if (!(        # Original bash: sed -e 1d -e 2q "$i" | grep "^skip=[0-9]*$" >/dev/null;
{
            my $output_3 = q{};
            my $output_printed_3;
            my $pipeline_success_3 = 1;
                        my @sed_lines_3 = split /\n/msx, $;
            my @sed_result_3;
            foreach my $line (@sed_lines_3) {
            chomp $line;
            push @sed_result_3, $line;
            }
            $ = join "\n", @sed_result_3;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_4 = q{};
            my $grep_result_5;
            my @grep_lines_5 = split /\n/msx, $output_3;
            my @grep_filtered_5 = grep { /^skip=[0-9]*$/msx } @grep_lines_5;
            $grep_result_5 = join "\n", @grep_filtered_5;
            if (!($grep_result_5 =~ m{\n\z}msx || $grep_result_5 eq q{})) {
            $grep_result_5 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_5 > 0 ? 0 : 1;
            $tmp_redirect_4 = $grep_result_5;
            $tmp_redirect_4;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_3; }
            $output_printed_3 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
            })) {
            print ${x} . ": $i is already gzexe'd";
if ( !( (${x} . ": $i is already gzexe'd") =~ m{\n\z}msx ) ) { print "\n"; }
next;
        }
    }
if (!(    # Original bash: ls -l "$i" | grep '^...[sS]' > /dev/null;
{
        my $output_6 = q{};
        my $output_printed_6;
        my $pipeline_success_6 = 1;
                $output_6 = do { my @_qx_cmd = ('ls -l "$i"'); my $result = qx{$_qx_cmd[0]}; $CHILD_ERROR = $? >> 8; $result; };

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
        or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_7 = q{};
        my $grep_result_8;
        my @grep_lines_8 = split /\n/msx, $output_6;
        my @grep_filtered_8 = grep { /^...[sS]/msx } @grep_lines_8;
        $grep_result_8 = join "\n", @grep_filtered_8;
        if (!($grep_result_8 =~ m{\n\z}msx || $grep_result_8 eq q{})) {
        $grep_result_8 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_8 > 0 ? 0 : 1;
        $tmp_redirect_7 = $grep_result_8;
        $tmp_redirect_7;
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
        })) {
        print ${x} . ": $i has setuid permission, unchanged";
if ( !( (${x} . ": $i has setuid permission, unchanged") =~ m{\n\z}msx ) ) { print "\n"; }
next;
    }
if (!(    # Original bash: ls -l "$i" | grep '^......[sS]' > /dev/null;
{
        my $output_9 = q{};
        my $output_printed_9;
        my $pipeline_success_9 = 1;
                $output_9 = do { my @_qx_cmd = ('ls -l "$i"'); my $result = qx{$_qx_cmd[0]}; $CHILD_ERROR = $? >> 8; $result; };

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
        or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_10 = q{};
        my $grep_result_11;
        my @grep_lines_11 = split /\n/msx, $output_9;
        my @grep_filtered_11 = grep { /^......[sS]/msx } @grep_lines_11;
        $grep_result_11 = join "\n", @grep_filtered_11;
        if (!($grep_result_11 =~ m{\n\z}msx || $grep_result_11 eq q{})) {
        $grep_result_11 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_11 > 0 ? 0 : 1;
        $tmp_redirect_10 = $grep_result_11;
        $tmp_redirect_10;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_9; }
        $output_printed_9 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
        })) {
        print ${x} . ": $i has setgid permission, unchanged";
if ( !( (${x} . ": $i has setgid permission, unchanged") =~ m{\n\z}msx ) ) { print "\n"; }
next;
    }
if ((do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($i); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^bzip2$/msx or (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($i); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^tail$/msx or (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($i); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^sed$/msx or (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($i); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^chmod$/msx or (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($i); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^ln$/msx or (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($i); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^sleep$/msx or (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($i); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^rm$/msx) {
                print ${x} . ": $i would depend on itself";
if ( !( (${x} . ": $i would depend on itself") =~ m{\n\z}msx ) ) { print "\n"; }
        next;    }
if (StringInterpolation(StringInterpolation { parts: [Variable("cpmod")] }, None) eq q{}) {
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
            use File::Copy qw(copy);
            if ( -e "$i" ) {
                if ( -d $tmp ) {
                    require File::Copy; File::Copy::copy("$i", $tmp . '/' . ("$i" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$i", $tmp);
                }
            } else {
                croak "cp: cannot stat '-p': No such file or directory\n";
            }
        };
        if ($CHILD_ERROR != 0) {
                        use File::Copy qw(copy);
            if ( -e "$i" ) {
                if ( -d $tmp ) {
                    require File::Copy; File::Copy::copy("$i", $tmp . '/' . ("$i" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$i", $tmp);
                }
            } else {
                croak "cp: cannot stat '$i': No such file or directory\n";
            }
        }
if (!(        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
            $main_exit_code = system('test', '-w', $tmp) >> 8;
        })) {
            my $writable;
            my @writable;
            my %writable;
            $writable = q{1};
}
        else {
            $writable = q{0};
            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
chmod(oct('u+w'), ($tmp)) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
            };
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $tmp
      or die "Cannot access file: $OS_ERROR\n";
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
if ((Variable("decomp", false, None) == 0)) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $tmp
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
my @sed_lines_15 = split /\n/msx, $;
my @sed_result_15;
foreach my $line (@sed_lines_15) {
chomp $line;
push @sed_result_15, $line;
}
$ = join "\n", @sed_result_15;

            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
my $temp_content = 'skip=23
set -C
umask=`umask`
umask 77
tmpfile=`mktemp ${TMPDIR:-/tmp}/bzexe.XXXXXXXXXX` || exit 1
if tail +$skip "$0" | /bin/bzip2 -cd >> "$tmpfile"; then
  umask $umask
  /bin/chmod 700 $tmpfile
  prog="`echo $0 | /bin/sed \'s|^.*/||\'`"
  if /bin/ln -T $tmpfile "/tmp/$prog" 2>/dev/null; then
    trap \'/bin/rm -f $tmpfile "/tmp/$prog"; exit $res\' 0
    (/bin/sleep 5; /bin/rm -f $tmpfile "/tmp/$prog") 2>/dev/null &
    /tmp/"$prog" ${1+"$@"}; res=$?
  else
    trap \'/bin/rm -f $tmpfile; exit $res\' 0
    (/bin/sleep 5; /bin/rm -f $tmpfile) 2>/dev/null &
    $tmpfile ${1+"$@"}; res=$?
  fi
else
  echo Cannot decompress $0; exit 1
fi; exit $res
';
use File::Path qw(make_path);
if (!-d q{/tmp}) { make_path(q{/tmp}); }
open my $fh_1, '>', q{/tmp} . '/heredoc_temp' or croak "Cannot create temp file: $OS_ERROR\n";
print $fh_1 $temp_content;
close $fh_1 or croak "Close failed: $OS_ERROR\n";
open STDIN, '<', q{/tmp} . '/heredoc_temp' or croak "Cannot open temp file: $OS_ERROR\n";
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $tmp
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
my @sed_lines_16 = split /\n/msx, $;
my @sed_result_16;
foreach my $line (@sed_lines_16) {
chomp $line;
push @sed_result_16, $line;
}
$ = join "\n", @sed_result_16;

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
            open STDOUT, '>>', $tmp
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('bzip2', '-c', 'v9', "$i") >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ($CHILD_ERROR != 0) {
                            $main_exit_code = system('/bin/rm', '-f', $tmp) >> 8;
                do {
    my $__echo_line = $x . q{ } . q{:} . q{ } . 'compression' . q{ } . 'not' . q{ } . 'possible' . q{ } . 'for' . q{ } . $i . q{ } . q{,} . q{ } . 'file' . q{ } . 'unchanged.';
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                $res = q{1};
next;
        }
}
    else {
        my $skip;
        my @skip;
        my %skip;
        $skip = '23';
if (!(        # Original bash: sed -e 1d -e 2q "$i" | grep "^skip=[0-9]*$" >/dev/null;
{
            my $output_17 = q{};
            my $output_printed_17;
            my $pipeline_success_17 = 1;
                        my @sed_lines_17 = split /\n/msx, $;
            my @sed_result_17;
            foreach my $line (@sed_lines_17) {
            chomp $line;
            push @sed_result_17, $line;
            }
            $ = join "\n", @sed_result_17;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_18 = q{};
            my $grep_result_19;
            my @grep_lines_19 = split /\n/msx, $output_17;
            my @grep_filtered_19 = grep { /^skip=[0-9]*$/msx } @grep_lines_19;
            $grep_result_19 = join "\n", @grep_filtered_19;
            if (!($grep_result_19 =~ m{\n\z}msx || $grep_result_19 eq q{})) {
            $grep_result_19 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_19 > 0 ? 0 : 1;
            $tmp_redirect_18 = $grep_result_19;
            $tmp_redirect_18;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_17; }
            $output_printed_17 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_17 ) { $main_exit_code = 1; }
            })) {
do { my $eval_input = do { my @_qx_cmd = ('sed -e 1d -e 2q "$i"'); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
        }
if (!(        # Original bash: tail +$skip "$i" | bzip2 -cd > $tmp;
{
            my $output_20 = q{};
            my $output_printed_20;
            my $pipeline_success_20 = 1;
            my @tail_lines = ();
                        $output_20 = do { my @_qx_cmd = ('tail + $skip "$i"'); qx{$_qx_cmd[0]}; };

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $tmp
            or die "Cannot access file: $OS_ERROR\n";
            my $tmp_redirect_21 = q{};
            my $cmd_24 = 'bzip2';
            my ($in_23, $out_23);
            my $pid_23 = open3($in_23, $out_23, '>&STDERR', $cmd_24, '-c', q{d});
            print {$in_23} $output_20;
            close $in_23 or croak 'Close failed: $OS_ERROR';
            $tmp_redirect_21 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
            close $out_23 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_23, 0;
            $tmp_redirect_21;
            $output_printed_20 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_20 ) { $main_exit_code = 1; }
            })) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
            do {
    my $__echo_line = $x . q{ } . q{:} . q{ } . $i . q{ } . 'probably' . q{ } . 'not' . q{ } . 'in' . q{ } . 'gzexe' . q{ } . 'format,' . q{ } . 'file' . q{ } . 'unchanged.';
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            $res = q{1};
next;
        }
    }
if ( -e "$i~" ) {
        if ( -d "$i~" ) {
            carp "rm: carping: ", "$i~",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$i~" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$i~",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
        my $err;
    my $force = 0;
    if ( -e "$i" ) {
        my $dest = "$i~";
        if ( -e $dest && -d $dest ) {
            my $source_name = "$i";
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
        if ( File::Copy::move( "$i", $dest ) ) {
        } else {
            croak
  "mv: cannot move "$i" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "$i": No such file or directory\n";
    }
    if ($CHILD_ERROR != 0) {
                    do {
    my $__echo_line = $x . q{ } . q{:} . q{ } . 'cannot' . q{ } . 'backup' . q{ } . $i . q{ } . 'as' . q{ } . $i . q{ } . q{~};
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
if ( -e "$tmp" ) {
                if ( -d "$tmp" ) {
                    carp "rm: carping: ", $tmp,
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$tmp" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", $tmp,
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
            $res = q{1};
next;
    }
                if ( -e "$tmp" ) {
        my $dest = "$i";
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
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
            use File::Copy qw(copy);
            if ( -e $tmp ) {
                if ( -d "$i" ) {
                    require File::Copy; File::Copy::copy($tmp, "$i" . '/' . ($tmp =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy($tmp, "$i");
                }
            } else {
                croak "cp: cannot stat '-p': No such file or directory\n";
            }
        };
    }
    if ($CHILD_ERROR != 0) {
                use File::Copy qw(copy);
        if ( -e $tmp ) {
            if ( -d "$i" ) {
                require File::Copy; File::Copy::copy($tmp, "$i" . '/' . ($tmp =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy($tmp, "$i");
            }
        } else {
            croak "cp: cannot stat '$tmp': No such file or directory\n";
        }
    }
    if ($CHILD_ERROR != 0) {
                    do {
    my $__echo_line = $x . q{ } . q{:} . q{ } . 'cannot' . q{ } . 'create' . q{ } . $i;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
if ( -e "$tmp" ) {
                if ( -d "$tmp" ) {
                    carp "rm: carping: ", $tmp,
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$tmp" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", $tmp,
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
            $res = q{1};
next;
    }
if ( -e "$tmp" ) {
        if ( -d "$tmp" ) {
            carp "rm: carping: ", $tmp,
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmp" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $tmp,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("cpmod")] }, None) ne q{}) {
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
            $CHILD_ERROR = 0;
        };
}
    else {
        if ((Variable("writable", false, None) == 0)) {
            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
chmod(oct('u-w'), ($i)) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
            };
        }
    }
}


exit $main_exit_code;
