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

my $PLYMOUTH_DESTDIR;
my @PLYMOUTH_DESTDIR;
my %PLYMOUTH_DESTDIR;
my $PLYMOUTH_DATADIR;
my @PLYMOUTH_DATADIR;
my %PLYMOUTH_DATADIR;
my $DESTDIR;
my @DESTDIR;
my %DESTDIR;
my $PLYMOUTH_LIBEXECDIR;
my @PLYMOUTH_LIBEXECDIR;
my %PLYMOUTH_LIBEXECDIR;
my $PLYMOUTH_POPULATE_INITRD;
my @PLYMOUTH_POPULATE_INITRD;
my %PLYMOUTH_POPULATE_INITRD;
my $PLYMOUTH_IMAGE_FILE;
my @PLYMOUTH_IMAGE_FILE;
my %PLYMOUTH_IMAGE_FILE;

if (!("$DESTDIR" eq q{})) {
    exit 0;
}
if ("$PLYMOUTH_LIBEXECDIR" eq q{}) {
        $PLYMOUTH_LIBEXECDIR = "/usr/libexec";
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if ("$PLYMOUTH_DATADIR" eq q{}) {
        $PLYMOUTH_DATADIR = "/usr/share";
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if ("$PLYMOUTH_POPULATE_INITRD" eq q{}) {
        $PLYMOUTH_POPULATE_INITRD = ${PLYMOUTH_LIBEXECDIR} . "/plymouth/plymouth-populate-initrd";
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if ("$PLYMOUTH_DESTDIR" eq q{}) {
        $PLYMOUTH_DESTDIR = "/boot";
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if ("$PLYMOUTH_IMAGE_FILE" eq q{}) {
        $PLYMOUTH_IMAGE_FILE = ${PLYMOUTH_DESTDIR} . "/initrd-plymouth.img";
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
my $PLYMOUTH_INITRD_DIR;
my @PLYMOUTH_INITRD_DIR;
my %PLYMOUTH_INITRD_DIR;
$PLYMOUTH_INITRD_DIR = (do { my $_chomp_temp = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'mktemp', '--tmpdir', '-d', 'plymouth-XXXXXXX');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; chomp $_chomp_temp; $_chomp_temp; });
$CHILD_ERROR = 0;
if (($? == 0)) {
        if (do {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('command', '-v', 'pigz') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } == 0) {
                my $gzip;
        my @gzip;
        my %gzip;
        $gzip = 'pigz';
    }
    if ($CHILD_ERROR != 0) {
                $gzip = 'gzip';
    }
    do {
        local %ENV = %ENV;
        my $PLYMOUTH_INITRD_DIR = $PLYMOUTH_INITRD_DIR;
        my $gzip = $gzip;
            chdir($PLYMOUTH_INITRD_DIR);
            $CHILD_ERROR = 0;
my @files_to_remove = glob("lib*/");
foreach my $file_to_remove (@files_to_remove) {
                if ( -e $file_to_remove ) {
                    if ( -d $file_to_remove ) {
                        carp "rm: carping: ", $file_to_remove,
    " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink $file_to_remove ) {
                        }
                        else {
                            local $CHILD_ERROR = 1;
                            carp "rm: carping: could not remove ", $file_to_remove,
    ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
            }
my @files_to_remove = glob("ld*libc*libdl*libm*libz*libpthread*");
foreach my $file_to_remove (@files_to_remove) {
                if ( -e $file_to_remove ) {
                    if ( -d $file_to_remove ) {
                        carp "rm: carping: ", $file_to_remove,
    " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink $file_to_remove ) {
                        }
                        else {
                            local $CHILD_ERROR = 1;
                            carp "rm: carping: could not remove ", $file_to_remove,
    ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
            }
            # Original bash: find | cpio -Hnewc -o | $gzip -9 > $PLYMOUTH_IMAGE_FILE
{
                my $output_1 = q{};
                my $output_printed_1;
                my $pipeline_success_1 = 1;
                                $output_1 = do {
                require File::Find;
                my @find_results;
                File::Find::find(sub { if (1) { push @find_results, $File::Find::name; } }, './');
                my $result = join "\n", @find_results;
                if ($result ne q{}) { $result .= "\n"; }
                $CHILD_ERROR = 0;
                $result;
                };

                                my $cmd_3 = 'cpio';
                my ($in_2, $out_2);
                my $pid_2 = open3($in_2, $out_2, '>&STDERR', $cmd_3, '-Hnewc', '-o');
                print {$in_2} $output_1;
                close $in_2 or croak 'Close failed: $OS_ERROR';
                $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
                close $out_2 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_2, 0;

                                do {
                open my $original_stdout, '>&', STDOUT
                or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', $PLYMOUTH_IMAGE_FILE
                or die "Cannot open file: $OS_ERROR\n";
                my $tmp_redirect_4 = q{};
                my $cmd_7 = 'unknown_command';
                my ($in_6, $out_6);
                my $pid_6 = open3($in_6, $out_6, '>&STDERR', $cmd_7, '-9');
                print {$in_6} $output_1;
                close $in_6 or croak 'Close failed: $OS_ERROR';
                $tmp_redirect_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
                close $out_6 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_6, 0;
                $tmp_redirect_4;
                $output_printed_1 = 1;
                open STDOUT, '>&', $original_stdout
                or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
                or die "Close failed: $OS_ERROR\n";
                };
                if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
                }
        q{};
    };
}
if ( -e "$PLYMOUTH_INITRD_DIR" ) {
    if ( -d "$PLYMOUTH_INITRD_DIR" ) {
        my $err;
        require File::Path;
        File::Path::remove_tree("$PLYMOUTH_INITRD_DIR", {error => \$err});
        if (@{$err}) {
            carp "rm: carping: could not remove ", $PLYMOUTH_INITRD_DIR, ": $err->[0]\n";
        }
        else {
                    }
    }
    else {
        if ( unlink "$PLYMOUTH_INITRD_DIR" ) {
                    }
        else {
            carp "rm: carping: could not remove ", $PLYMOUTH_INITRD_DIR,
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}

exit $main_exit_code;
