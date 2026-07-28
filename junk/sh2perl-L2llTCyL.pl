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

my $DONE;
my @DONE;
my %DONE;
my $tempdir;
my @tempdir;
my %tempdir;
my $HELP;
my @HELP;
my %HELP;
my $STATEDIR;
my @STATEDIR;
my %STATEDIR;
my $INPUTFILE;
my @INPUTFILE;
my %INPUTFILE;
my $UNPACK_ONLY;
my @UNPACK_ONLY;
my %UNPACK_ONLY;
my $APPEND;
my @APPEND;
my %APPEND;

my $NO_CLEAN;
my @NO_CLEAN;
my %NO_CLEAN;
$NO_CLEAN = q{0};
$STATEDIR = q{0};
$UNPACK_ONLY = q{0};
$HELP = q{0};
$APPEND = q{1};
$DONE = q{0};
while ( $DONE eq 0 ) {
if ("$_[0]" =~ /^--append-args$/msx) {
                $APPEND = q{1};
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--help$/msx) {
                $HELP = q{1};
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--no-clean$/msx) {
                $NO_CLEAN = q{1};
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--prepend-args$/msx) {
                $APPEND = q{0};
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--really-clean$/msx) {
                $NO_CLEAN = q{0};
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--statedir$/msx) {
                $STATEDIR = q{1};
                $NO_CLEAN = q{1};
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--unpack$/msx) {
                $UNPACK_ONLY = q{1};
        # Builtin command 'shift' not implemented
    } elsif (1) {
                $DONE = q{1};
    }
}
if (((!(do {
    local %ENV = %ENV;
    my $NO_CLEAN = $NO_CLEAN;
    if ($UNPACK_ONLY eq 0) {
        (scalar(@ARGV) < 1)        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    q{};
}) || !(do {
    local %ENV = %ENV;
    my $NO_CLEAN = $NO_CLEAN;
    if ($UNPACK_ONLY eq 1) {
        (scalar(@ARGV) != 1)        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    q{};
})) || $HELP eq 1)) {
    do {
    my $__echo_line = "Usage: $PROGRAM_NAME [options] <input-file> [<program> [arguments ...]]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "\n";
    $CHILD_ERROR = 0;
    print "This command will unpack the given archive of aptitude state\n";
    print "information, then invoke the given program with the given\n";
    print "list of arguments, passing appropriate -o options to cause\n";
    print "aptitude to use the contents of that archive as its global\n";
    print "data store.\n";
    print "\n";
    $CHILD_ERROR = 0;
    print "Options:\n";
    print "  --append-args    Place the generated arguments at the end of\n";
    print "                   the command line (default).\n";
    print "  --help           Display this message and exit.\n";
    print "  --no-clean       Do not remove the temporary directory after\n";
    print "                   invoking aptitude.\n";
    print "  --prepend-args   Place the generated arguments at the beginning\n";
    print "                   of the command line.\n";
    print "  --really-clean   Remove the state directory, even if --statedir\n";
    print "                   was passed as an argument.\n";
    print "  --statedir       The <input-file> is an unpacked aptitude bundle,\n";
    print "                   not a bundle file; implicitly sets --no-clean.\n";
    print "  --unpack         Just unpack the <input-file>, don't run aptitude.\n";
exit 1;
}
$INPUTFILE = "$_[0]";
# Builtin command 'shift' not implemented
if ((scalar(@ARGV) < 1)) {
    my $PROGRAM;
    my @PROGRAM;
    my %PROGRAM;
    $PROGRAM = 'aptitude';
}
else {
    $PROGRAM = "$_[0]";
# Builtin command 'shift' not implemented
}
if ($STATEDIR eq 0) {
        $tempdir = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'mktemp', '-p', (defined ($ENV{TMPDIR} // q{}) && ($ENV{TMPDIR} // q{}) ne q{} ? ($ENV{TMPDIR} // q{}) : '/tmp'), '-d', 'aptitudebug.XXXXXXXXX');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
if ("$tempdir" eq q{}) {
exit 1;
    }
}
else {
    $tempdir = $INPUTFILE;
}
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'
if [ $NO_CLEAN = 1 ]
then echo "Leaving final state in $tempdir"
else echo "Removing $tempdir"; rm -fr $tempdir
fi 2>&1'; print $end_out if $end_out ne q{}; }
if ($STATEDIR eq 0) {
if ((-d "$INPUTFILE")) {
        do {
    my $__echo_line = "Can't use $INPUTFILE as the input bundle: it's a directory.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
exit 1;
    }
if (!(!((-f "$INPUTFILE")))) {
        do {
    my $__echo_line = "Can't use $INPUTFILE as the input bundle: file not found.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
exit 1;
    }
        $main_exit_code = system('tar', '-C', "$tempdir", '-x', q{f}, "$INPUTFILE") >> 8;
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
}
if ($UNPACK_ONLY eq 1) {
exit 0;
}
if ("$APPEND" eq 1) {
    $CHILD_ERROR = 0;
}
else {
    $CHILD_ERROR = 0;
}

exit $main_exit_code;
