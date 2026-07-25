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

my $MAGIC_7 = 7;

my $USAGE;
my @USAGE;
my %USAGE;
$USAGE = '<orig blob> <our blob> <their blob> <path>';
$USAGE = "$USAGE <orig mode> <our mode> <their mode>";
my $LONG_USAGE;
my @LONG_USAGE;
my %LONG_USAGE;
$LONG_USAGE = "usage: git merge-one-file $USAGE

Blob ids and modes should be empty for missing files.";
my $SUBDIRECTORY_OK;
my @SUBDIRECTORY_OK;
my %SUBDIRECTORY_OK;
$SUBDIRECTORY_OK = 'Yes';
$main_exit_code = system('.', 'git-sh-setup') >> 8;
$main_exit_code = system('bash', 'cd_to_toplevel') >> 8;
$main_exit_code = system('bash', 'require_work_tree') >> 8;
if ((!Variable("#", false, None) eq 7)) {
    print $LONG_USAGE;
if ( !( ($LONG_USAGE) =~ m{\n\z}msx ) ) { print "\n"; }
exit 1;
}
if ((defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') : '.') . (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') && (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') : '.') . (defined (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') && (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') ne q{} ? (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') : '.') =~ /^$1..$/msx or (defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') : '.') . (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') && (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') : '.') . (defined (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') && (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') ne q{} ? (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') : '.') =~ /^$1.$1$/msx or (defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') : '.') . (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') && (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') : '.') . (defined (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') && (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') ne q{} ? (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') : '.') =~ /^$1$1.$/msx) {
    if ((!(        if (do {
$main_exit_code = system('test', '-z', "$_[5]") >> 8;
            $CHILD_ERROR == 0
        }) {
                        $main_exit_code = system('test', "$_[4]", q{!}, q{=}, "$_[6]") >> 8;
        }) || !(        if (do {
$main_exit_code = system('test', '-z', "$_[6]") >> 8;
            $CHILD_ERROR == 0
        }) {
                        $main_exit_code = system('test', "$_[4]", q{!}, q{=}, "$_[5]") >> 8;
        }))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "ERROR: File $_[3] deleted on one branch but had its";
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
            print "ERROR: permissions changed on the other.\n";
        };
exit 1;
    }
    if (StringInterpolation(StringInterpolation { parts: [Variable("2")] }, None) ne q{}) {
        do {
    my $__echo_line = "Removing $_[3]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
}
    else {
# Builtin command 'exec' not implemented
    }
        if (do {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("4")] }, None)')) {
        if (do {
do { my $rm_cmd_str = 'rm -f -- "$4"'; system $rm_cmd_str; };
        $CHILD_ERROR == 0
    }) {
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
rmdir ((do { my $_chomp_temp = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'expr', "z$_[3]", q{:}, "z\\(.*\\)/");
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
}; chomp $_chomp_temp; $_chomp_temp; })) or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        };
    }
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('bash', ':') >> 8;
    }
}
        $CHILD_ERROR == 0
    }) {
        # Builtin command 'exec' not implemented
    }
} elsif ((defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') : '.') . (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') && (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') : '.') . (defined (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') && (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') ne q{} ? (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') : '.') =~ /^.$2.$/msx) {
    # Builtin command 'exec' not implemented
} elsif ((defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') : '.') . (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') && (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') : '.') . (defined (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') && (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') ne q{} ? (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') : '.') =~ /^..$3$/msx) {
        do {
    my $__echo_line = "Adding $_[3]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("4")] }, None)')) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "ERROR: untracked $_[3] is overwritten by the merge.";
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
        if (do {
$main_exit_code = system('git', 'update-index', '--add', '--cacheinfo', "$_[6]", "$_[2]", "$_[3]") >> 8;
        $CHILD_ERROR == 0
    }) {
        # Builtin command 'exec' not implemented
    }
} elsif ((defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') : '.') . (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') && (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') : '.') . (defined (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') && (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') ne q{} ? (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') : '.') =~ /^.$3$2$/msx) {
    if ((!StringInterpolation(StringInterpolation { parts: [Variable("6")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("7")] }, None))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "ERROR: File $_[3] added identically in both branches,";
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
    my $__echo_line = "ERROR: but permissions conflict $_[5]->$_[6].";
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
        do {
    my $__echo_line = "Adding $_[3]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
        if (do {
$main_exit_code = system('git', 'update-index', '--add', '--cacheinfo', "$_[5]", "$_[1]", "$_[3]") >> 8;
        $CHILD_ERROR == 0
    }) {
        # Builtin command 'exec' not implemented
    }
} elsif ((defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') : '.') . (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') && (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') : '.') . (defined (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') && (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') ne q{} ? (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') : '.') =~ /^$1$2$3$/msx or (defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '.') : '.') . (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') && (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : '.') : '.') . (defined (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') && (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') ne q{} ? (defined $_[2] && $_[2] ne q{} ? $_[2] : '.') : '.') =~ /^.$2$3$/msx) {
    if (",$_[5],$_[6]," =~ /^.*,120000,.*$/msx) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "ERROR: $_[3]: Not merging symbolic link changes.";
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
    } elsif (",$_[5],$_[6]," =~ /^.*,160000,.*$/msx) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "ERROR: $_[3]: Not merging conflicting submodule changes.";
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
        my $src1;
    my @src1;
    my %src1;
    $src1 = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'git', 'unpack-file', $2);
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
        my $src2;
    my @src2;
    my %src2;
    $src2 = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'git', 'unpack-file', $3);
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
};
    if ("$_[0]" =~ /^$/msx) {
                do {
    my $__echo_line = "Added $_[3] in both, but differently.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
                my $orig;
        my @orig;
        my %orig;
        $orig = do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'git', 'unpack-file', do { my ($in_4, $out_4); my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'git', ''hash-object'', ''/dev/null''); close $in_4 or croak 'Close failed: $OS_ERROR'; my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> }; close $out_4 or croak 'Close failed: $OS_ERROR'; waitpid $pid_4, 0; $result_4 });
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
};
    } elsif (1) {
                do {
    my $__echo_line = "Auto-merging $_[3]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
                $orig = do {
    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'git', 'unpack-file', $1);
    close $in_6 or croak 'Close failed: $OS_ERROR';
    my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    $result_6
};
    }
        $main_exit_code = system('git', 'merge-file', "$src1", "$orig", "$src2") >> 8;
        my $ret;
    my @ret;
    my %ret;
    $ret = $?;
        my $msg;
    my @msg;
    my %msg;
    $msg = q{};
    if ((!(    $main_exit_code = system('test', $ret, q{!}, q{=}, q{0}) >> 8) || !(    $main_exit_code = system('test', '-z', "$_[0]") >> 8))) {
        $msg = 'content conflict';
        $ret = q{1};
    }
            if (do {
$main_exit_code = system('git', 'checkout-index', '-f', '--stage=2', '--', "$_[3]") >> 8;
        $CHILD_ERROR == 0
    }) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[3]"
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$src1" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$src1" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
    do { my $rm_cmd_str = 'rm -f -- "$orig" "$src1" "$src2"'; system $rm_cmd_str; };
    if ((!StringInterpolation(StringInterpolation { parts: [Variable("6")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("7")] }, None))) {
if (StringInterpolation(StringInterpolation { parts: [Variable("msg")] }, None) ne q{}) {
            $msg = "$msg, ";
        }
        $msg = ${msg} . "permissions conflict: $_[4]->$_[5],$_[6]";
        $ret = q{1};
    }
    if ((!Variable("ret", false, None) eq 0)) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "ERROR: $msg in $_[3]";
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
    # Builtin command 'exec' not implemented
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "ERROR: $_[3]: Not handling case $_[0] -> $_[1] -> $_[2]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
}
exit 1;

exit $main_exit_code;
