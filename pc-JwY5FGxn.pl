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

my $WELCOME;
my @WELCOME;
my %WELCOME;
my $DMIDECODE;
my @DMIDECODE;
my %DMIDECODE;
my $PAINST;
my @PAINST;
my %PAINST;
my $JACKINST;
my @JACKINST;
my %JACKINST;
my $PASTEBIN;
my @PASTEBIN;
my %PASTEBIN;
my $KERNEL_VERSION;
my @KERNEL_VERSION;
my %KERNEL_VERSION;
my $SNDOPTIONS;
my @SNDOPTIONS;
my %SNDOPTIONS;
my $DIALOG;
my @DIALOG;
my %DIALOG;
my $LSPCI;
my @LSPCI;
my %LSPCI;
my $UPLOAD;
my @UPLOAD;
my %UPLOAD;
my $DIALOG_EXIT_CODE;
my @DIALOG_EXIT_CODE;
my %DIALOG_EXIT_CODE;
my $ESDINST;
my @ESDINST;
my %ESDINST;
my $JACK2INST;
my @JACK2INST;
my %JACK2INST;
my $PROCEED;
my @PROCEED;
my %PROCEED;
my $ACPI_STATUS;
my @ACPI_STATUS;
my %ACPI_STATUS;
my $TPUT;
my @TPUT;
my %TPUT;
my $CONFIRM;
my @CONFIRM;
my %CONFIRM;
my $PWINST;
my @PWINST;
my %PWINST;
my $NFILE;
my @NFILE;
my %NFILE;
my $TEMPDIR;
my @TEMPDIR;
my %TEMPDIR;
my $SYSFS;
my @SYSFS;
my %SYSFS;
my $REPEAT;
my @REPEAT;
my %REPEAT;
my $ARTSINST;
my @ARTSINST;
my %ARTSINST;
my $path;
my @path;
my %path;
my $WITHALL;
my @WITHALL;
my %WITHALL;
my $ROARINST;
my @ROARINST;
my %ROARINST;

my $MAGIC_20  = 20;
my $MAGIC_5   = 5;
my $MAGIC_70  = 70;
my $MAGIC_100 = 100;
my $MAGIC_10  = 10;
my $MAGIC_80  = 80;
my $MAGIC_60  = 60;
my $MAGIC_25  = 25;
my $MAGIC_6   = 6;

my $SCRIPT_VERSION;
my @SCRIPT_VERSION;
my %SCRIPT_VERSION;
$SCRIPT_VERSION = '0.5.3';
my $CHANGELOG;
my @CHANGELOG;
my %CHANGELOG;
$CHANGELOG = 'https://www.alsa-project.org/alsa-info.sh.changelog';
$ENV{LC_ALL} = 'C';
my $PATH;
my @PATH;
my %PATH;
$PATH = "$PATH:/bin:/sbin:/usr/bin:/usr/sbin";
my $BGTITLE;
my @BGTITLE;
my %BGTITLE;
$BGTITLE = "ALSA-Info v $SCRIPT_VERSION";
my $PASTEBINKEY;
my @PASTEBINKEY;
my %PASTEBINKEY;
$PASTEBINKEY = 'C9cRIO8m/9y8Cs0nVs0FraRx7U0pHsuc';
my $WGET;
my @WGET;
my %WGET;
$WGET = (do { my $_chomp_temp = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'command', '-v', 'wget');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; chomp $_chomp_temp; $_chomp_temp; });
my $REQUIRES;
my @REQUIRES = ('mktemp', 'grep', 'pgrep', 'awk', 'date', 'uname', 'cat', 'sort', 'dmesg', 'amixer', 'alsactl');
my %REQUIRES;

sub update {
    my ($file) = @_;
    if (do {
$main_exit_code = system('test', '-z', "$WGET") >> 8;
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('test', q{!}, '-x', "$WGET") >> 8;
}
        $CHILD_ERROR == 0
    }) {
        return;    }
        my $SHFILE;
    my @SHFILE;
    my %SHFILE;
    $SHFILE = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'mktemp', '-t', 'alsa-info.XXXXXXXXXX');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
};
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
use LWP::Simple;
my $url = "https://www.alsa-project.org/alsa-info.sh";
my $output_file = $SHFILE;
my $content = get($url);
if (defined $content) {
open my $fh, '>', $output_file or die "Cannot open $output_file: $ERRNO";
print {$fh} $content;
close $fh or croak "Close failed: $ERRNO";
print "Downloaded to $output_file\n";
} else {
die "Failed to download $url\n";
}
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    my $REMOTE_VERSION;
    my @REMOTE_VERSION;
    my %REMOTE_VERSION;
    $REMOTE_VERSION = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_3 = q{};
    my $output_printed_3;
    my $head_line_count = 0;
    my $output_4 = q{};
    while (my $line = <>) {
        chomp $line;
                if (!($line =~ /SCRIPT_VERSION/msx)) {
            next;
        }
        if ($head_line_count < 1) {
    $output_4 .= $line . "\n";
    ++$head_line_count;
} else {
    $line = q{}; # Clear line to prevent printing
    last; # Break out of the yes loop when head limit is reached
}
        $line =~ 's/.*=//';
    }
    $output_4; };
}; $_pipeline_result; };
if ((((-s "$SHFILE") > 0) && "$REMOTE_VERSION" ne "$SCRIPT_VERSION")) {
if ($DIALOG ne q{}) {
            my $OVERWRITE;
            my @OVERWRITE;
            my %OVERWRITE;
            $OVERWRITE = q{};
if ((-w $0)) {
                $main_exit_code = system('dialog', '--yesno', "Newer version of ALSA-Info has been found\n\nDo you wish to install it?\nNOTICE: The original file $PROGRAM_NAME will be overwritten!", q{0}, q{0}) >> 8;
                $DIALOG_EXIT_CODE = $?;
if ($DIALOG_EXIT_CODE eq 0) {
                    $OVERWRITE = 'yes';
                }
            }
if ("$OVERWRITE" eq q{}) {
                $main_exit_code = system('dialog', '--yesno', "Newer version of ALSA-Info has been found\n\nDo you wish to download it?", q{0}, q{0}) >> 8;
                $DIALOG_EXIT_CODE = $?;
            }
if ($DIALOG_EXIT_CODE eq 0) {
                do {
    my $__echo_line = "Newer version detected: $REMOTE_VERSION";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                do {
    my $__echo_line = "To view the ChangeLog, please visit $CHANGELOG";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
if ("$OVERWRITE" eq "yes") {
                    use File::Copy qw(copy);
                    if ( -e $SHFILE ) {
                        if ( -d $PROGRAM_NAME ) {
                            require File::Copy; File::Copy::copy($SHFILE, $PROGRAM_NAME . '/' . ($SHFILE =~ m|([^/]+)$|)[0]);
                        } else {
                            require File::Copy; File::Copy::copy($SHFILE, $PROGRAM_NAME);
                        }
                    } else {
                        croak "cp: cannot stat '$SHFILE': No such file or directory\n";
                    }
                    do {
    my $__echo_line = "ALSA-Info script has been updated to v $REMOTE_VERSION";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    print "Please re-run the script\n";
                    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
if ( -e "$SHFILE" ) {
                            if ( -d "$SHFILE" ) {
                                croak "rm: ", $SHFILE,
          " is a directory (use -r to remove recursively)\n";
                            }
                            else {
                                if ( unlink "$SHFILE" ) {
                                                                    }
                                else {
                                    croak "rm: cannot remove ", $SHFILE,
              ": $OS_ERROR\n";
                                }
                            }
                        }
                        else {
                            local $CHILD_ERROR = 1;
                            croak "rm: ", $SHFILE, ": No such file or directory\n";
                        }
                    };
}
                else {
                    do {
    my $__echo_line = "ALSA-Info script has been downloaded as $SHFILE.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    print "Please re-run the script from new location.\n";
                }
exit $main_exit_code;
}
            else {
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
if ( -e "$SHFILE" ) {
                        if ( -d "$SHFILE" ) {
                            croak "rm: ", $SHFILE,
          " is a directory (use -r to remove recursively)\n";
                        }
                        else {
                            if ( unlink "$SHFILE" ) {
                                                            }
                            else {
                                croak "rm: cannot remove ", $SHFILE,
              ": $OS_ERROR\n";
                            }
                        }
                    }
                    else {
                        local $CHILD_ERROR = 1;
                        croak "rm: ", $SHFILE, ": No such file or directory\n";
                    }
                };
            }
}
        else {
            do {
    my $__echo_line = "Newer version detected: $REMOTE_VERSION";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            do {
    my $__echo_line = "To view the ChangeLog, please visit $CHANGELOG";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
if ((-w $0)) {
                do {
    my $__echo_line = "The original file $PROGRAM_NAME will be overwritten!";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                print "If you do not like to proceed, press Ctrl-C now..";
$inp = <>;
chomp $inp;
$CHILD_ERROR = defined($inp) ? 0 : 1;
                use File::Copy qw(copy);
                if ( -e $SHFILE ) {
                    if ( -d $PROGRAM_NAME ) {
                        require File::Copy; File::Copy::copy($SHFILE, $PROGRAM_NAME . '/' . ($SHFILE =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy($SHFILE, $PROGRAM_NAME);
                    }
                } else {
                    croak "cp: cannot stat '$SHFILE': No such file or directory\n";
                }
                print "ALSA-Info script has been updated. Please re-run it.\n";
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
if ( -e "$SHFILE" ) {
                        if ( -d "$SHFILE" ) {
                            croak "rm: ", $SHFILE,
          " is a directory (use -r to remove recursively)\n";
                        }
                        else {
                            if ( unlink "$SHFILE" ) {
                                                            }
                            else {
                                croak "rm: cannot remove ", $SHFILE,
              ": $OS_ERROR\n";
                            }
                        }
                    }
                    else {
                        local $CHILD_ERROR = 1;
                        croak "rm: ", $SHFILE, ": No such file or directory\n";
                    }
                };
}
            else {
                do {
    my $__echo_line = "ALSA-Info script has been downloaded $SHFILE.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                print "Please, re-run it from new location.\n";
            }
exit $main_exit_code;
        }
}
    else {
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
if ( -e "$SHFILE" ) {
                if ( -d "$SHFILE" ) {
                    croak "rm: ", $SHFILE,
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$SHFILE" ) {
                                            }
                    else {
                        croak "rm: cannot remove ", $SHFILE,
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 1;
                croak "rm: ", $SHFILE, ": No such file or directory\n";
            }
        };
    }
    return;
}

sub cleanup {
if (("$TEMPDIR" ne q{} && "$KEEP_FILES" ne "yes")) {
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
if ( -e "$TEMPDIR" ) {
                if ( -d "$TEMPDIR" ) {
                    my $err;
                    require File::Path;
                    File::Path::remove_tree("$TEMPDIR", {error => \$err});
                    if (@{$err}) {
                        carp "rm: carping: could not remove ", "$TEMPDIR", ": $err->[0]\n";
                    }
                    else {
                                            }
                }
                else {
                    if ( unlink "$TEMPDIR" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$TEMPDIR",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        };
    }
        $main_exit_code = system('test', '-n', "$ENV{KEEP_OUTPUT}") >> 8;
    if ($CHILD_ERROR != 0) {
        if ( -e "$NFILE" ) {
            if ( -d "$NFILE" ) {
                carp "rm: carping: ", "$NFILE",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$NFILE" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$NFILE",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    return;
}

sub withaplay {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "!!Aplay/Arecord output\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "!!--------------------\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "APLAY\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('aplay', '-l') >> 8;
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
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "ARECORD\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('arecord', '-l') >> 8;
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
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub withmodules {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "!!All Loaded Modules\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "!!------------------\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    # Original bash: awk '{print $1}' < /proc/modules | sort >> "$FILE"
{
        my $output_8 = q{};
        my $output_printed_8;
        my $pipeline_success_8 = 1;
                $output = q{};
        open STDIN, '<', '/proc/modules' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_9 = q{};
my @lines = split /\n/msx, $output_8;
my @result;
foreach my $line (@lines) {
    chomp $line;
    if ($line =~ /^\s*$/msx) { next; }
    my @fields = split /\s+/msx, $line;
    push @result, ($fields[0] . "\n");
}
$output_8 = join "", @result;

$tmp_redirect_9;
        $output_8 = $output;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_11 = q{};
        my @sort_lines_12 = split /\n/msx, $output_8;
        my @sort_sorted_12 = sort @sort_lines_12;
        $tmp_redirect_11 = join "\n", @sort_sorted_12;
        if ($tmp_redirect_11 ne q{} && !($tmp_redirect_11 =~ m{\n\z}msx)) {
        $tmp_redirect_11 .= "\n";
        }
        $output_8 = $tmp_redirect_11;
        $tmp_redirect_11;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_8; }
        $output_printed_8 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
        }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub withamixer {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "!!Amixer output\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "!!-------------\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    my $f;
    for my $f ('/proc/asound/card*/id') {
                if ((-f "$f")) {
            open STDIN, '<', "$f" or croak "Cannot open file: $OS_ERROR\n";
$CARD_NAME = <>;
chomp $CARD_NAME;
$CHILD_ERROR = defined($CARD_NAME) ? 0 : 1;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
            next;        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "!!-------Mixer controls for card $ENV{CARD_NAME}";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('amixer', '-c', "$ENV{CARD_NAME}", 'info') >> 8;
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
            open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('amixer', '-c', "$ENV{CARD_NAME}") >> 8;
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
            open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub withalsactl {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "!!Alsactl output\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "!!--------------\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('alsactl', '-f', "$TEMPDIR/alsactl.tmp", 'store') >> 8;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "--startcollapse--\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$TEMPDIR/alsactl.tmp" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$TEMPDIR/alsactl.tmp" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "--endcollapse--\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub withdevices {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "!!ALSA Device nodes\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "!!-----------------\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        my @ls_files_15 = ();
        my $ls_all_found_16 = 1;
        my @ls_inputs_17 = ();
        my @ls_glob_ls_inputs_17_0 = glob('/dev/snd/*');
        if ( !@ls_glob_ls_inputs_17_0 ) {
            push @ls_inputs_17, '/dev/snd/*';
            $ls_all_found_16 = 0;
        } else {
            push @ls_inputs_17, @ls_glob_ls_inputs_17_0;
        }
        my @ls_files_18 = ();
        my @ls_dirs_19 = ();
        my $ls_show_headers_20 = scalar(@ls_inputs_17) > 1;
        for my $ls_item_21 (@ls_inputs_17) {
            if ( -f $ls_item_21 ) {
                push @ls_files_18, $ls_item_21;
            }
            elsif ( -d $ls_item_21 ) {
                push @ls_dirs_19, $ls_item_21;
            }
            else {
                $ls_all_found_16 = 0;
            }
        }
        @ls_files_18 = sort { $a cmp $b } @ls_files_18;
        @ls_dirs_19 = sort { $a cmp $b } @ls_dirs_19;
        if (@ls_files_18) {
            push @ls_files_15, join("\n", @ls_files_18);
        }
        for my $ls_dir_22 (@ls_dirs_19) {
            my @ls_dir_entries_23 = ();
            if ( opendir my $dh, $ls_dir_22 ) {
                while ( my $file = readdir $dh ) {
                    push @ls_dir_entries_23, $file;
                }
                closedir $dh;
                @ls_dir_entries_23 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_23;
                if ( $ls_show_headers_20 ) {
                    if ( @ls_dir_entries_23 ) {
                        push @ls_files_15, $ls_dir_22 . ":\n" . join("\n", @ls_dir_entries_23);
                    } else {
                        push @ls_files_15, $ls_dir_22 . ':';
                    }
                }
                elsif ( @ls_dir_entries_23 ) {
                    push @ls_files_15, join("\n", @ls_dir_entries_23);
                }
            }
            else {
                $ls_all_found_16 = 0;
            }
        }
        if (@ls_files_15) {
            print join "\n", @ls_files_15;
            print "\n";
        }
        if ( $ls_all_found_16 ) {
            local $CHILD_ERROR = 0;
            $ls_success = 1;
        }
        else {
            local $CHILD_ERROR = 2;
            $ls_success = 0;
            $main_exit_code = $CHILD_ERROR;
        }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub withconfigs {
if ((((-e "$HOME/.asoundrc") || (-e "/etc/asound.conf")) || (-e "$HOME/.asoundrc.asoundconf"))) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
            print "!!ALSA configuration files\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
            print "!!------------------------\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
if ((-e "$HOME/.asoundrc")) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                print "!!User specific config file (~/.asoundrc)\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$ENV{HOME}/.asoundrc" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$ENV{HOME}/.asoundrc" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
if ((-e "$HOME/.asoundrc.asoundconf")) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                print "!!asoundconf-generated config file\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$ENV{HOME}/.asoundrc.asoundconf" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$ENV{HOME}/.asoundrc.asoundconf" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
if ((-e '/etc/asound.conf')) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                print "!!System wide config file (/etc/asound.conf)\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/asound.conf' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/asound.conf' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
    }
    return;
}

sub withsysfs {
    my $i;
    my $f;
    my $printed = "";
    for my $i ('/sys/class/sound/*') {
if ("$i" =~ /^.*/hwC.D.$/msx) {
            if ((-f "$i/init_pin_configs")) {
if ("$printed" eq q{}) {
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                        print "!!Sysfs Files\n";
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                        print "!!-----------\n";
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                        print "\n";
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                }
                for my $f ('init_pin_configs', 'driver_pin_configs', 'user_pin_configs', 'init_verbs', 'hints') {
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                        do {
    my $__echo_line = "$i/$f:";
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
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$i/$f" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$i/$f" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
                        print "\n";
                        $CHILD_ERROR = 0;
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                }
                $printed = 'yes';
            }
        }
    }
if ("$printed" ne q{}) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    return;
}

sub withdmesg {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "!!ALSA/HDA dmesg\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "!!--------------\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    # Original bash: dmesg | grep -C1 -E 'ALSA|HDA|HDMI|snd[_-]|sound|audio|hda.codec|hda.intel' >> "$FILE"
{
        my $output_28 = q{};
        my $output_printed_28;
        my $pipeline_success_28 = 1;
                my ($in_29, $out_29);
        my $pid_29 = open3($in_29, $out_29, '>&STDERR', 'dmesg', );
        close $in_29 or croak 'Close failed: $OS_ERROR';
        $output_28 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_29> };
        close $out_29 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_29, 0;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_30 = q{};
        my $grep_result_31;
        my @grep_lines_31 = split /\n/msx, $output_28;
        my @grep_filtered_31 = grep { /ALSA|HDA|HDMI|snd[_-]|sound|audio|hda.codec|hda.intel/msx } @grep_lines_31;
        $grep_result_31 = join "\n", @grep_filtered_31;
        if (!($grep_result_31 =~ m{\n\z}msx || $grep_result_31 eq q{})) {
        $grep_result_31 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_31 > 0 ? 0 : 1;
        $tmp_redirect_30 = $grep_result_31;
        $tmp_redirect_30;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_28; }
        $output_printed_28 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_28 ) { $main_exit_code = 1; }
        }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub withpackages {
    my $RPM;
    my $DPKG;
    $RPM = (do { my $_chomp_temp = do {
    my ($in_32, $out_32);
    my $pid_32 = open3($in_32, $out_32, '>&STDERR', 'command', '-v', 'rpmquery');
    close $in_32 or croak 'Close failed: $OS_ERROR';
    my $result_32 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_32> };
    close $out_32 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_32, 0;
    $result_32
}; chomp $_chomp_temp; $_chomp_temp; });
    $DPKG = (do { my $_chomp_temp = do {
    my ($in_33, $out_33);
    my $pid_33 = open3($in_33, $out_33, '>&STDERR', 'command', '-v', 'dpkg');
    close $in_33 or croak 'Close failed: $OS_ERROR';
    my $result_33 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_33> };
    close $out_33 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_33, 0;
    $result_33
}; chomp $_chomp_temp; $_chomp_temp; });
    if (!("$RPM$DPKG" ne q{})) {
        return;    }
    my $PATTERN = "(alsa-(lib|oss|plugins|tools|(topology|ucm)-conf|utils|sof-firmware)|libalsa|tinycompress|sof-firmware)";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$ENV{FILE}"
      or die "Cannot open file: $OS_ERROR\n";
            print "!!Packages installed\n";
            print "!!--------------------\n";
            print "\n";
            # Original bash: #!/bin/bash
{
                my $output_34 = q{};
                my $output_printed_34;
                my $pipeline_success_34 = 1;
                                my @_pcmd_36 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
                my ($in_35);
                my $pid_35 = open3($in_35, $out_35, '>&STDERR', @_pcmd_36);
                close $in_35 or croak 'Close failed: $OS_ERROR';
                my $temp_result;
                $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_35> };
                $output_34 = $temp_result;
                close $out_35 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_35, 0;

                                my $grep_result_34_1;
                my @grep_lines_34_1 = split /\n/msx, $output_34;
                my @grep_filtered_34_1 = grep { /$PATTERN/msx } @grep_lines_34_1;
                $grep_result_34_1 = join "\n", @grep_filtered_34_1;
                if (!($grep_result_34_1 =~ m{\n\z}msx || $grep_result_34_1 eq q{})) {
                $grep_result_34_1 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_34_1 > 0 ? 0 : 1;
                $output_34 = $grep_result_34_1;
                $output_34 = $grep_result_34_1;
                if ((scalar @grep_filtered_34_1) == 0) {
                    $pipeline_success_34 = 0;
                }
                if ($output_34 ne q{} && !defined $output_printed_34) {
                    print $output_34;
                    if (!($output_34 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_34 ) { $main_exit_code = 1; }
                }
            print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub withall {
    withdevices();
    withconfigs();
    withaplay();
    withamixer();
    withalsactl();
    withmodules();
    withsysfs();
    withdmesg();
    withpackages();
    $WITHALL = 'no';
    return;
}

sub get_alsa_library_version {
    my $ALSA_LIB_VERSION;
    my @ALSA_LIB_VERSION;
    my %ALSA_LIB_VERSION;
    $ALSA_LIB_VERSION = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_37 = q{};
        my $output_printed_37;
        my $pipeline_success_37 = 1;
        my $grep_result_37_0;
        my @grep_lines_37_0 = ();
        my @grep_filenames_37_0 = ();
        if (-e "/usr/include/alsa/version.h") {
        open my $fh, '<', "/usr/include/alsa/version.h" or croak "Cannot open file: $ERRNO";
        while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_37_0, $line;
        push @grep_filenames_37_0, "/usr/include/alsa/version.h";
        }
        close $fh
        or croak "Close failed: $OS_ERROR";
        }
        else { print {*STDERR} "grep: /usr/include/alsa/version.h: No such file or directory\n"; }
        my @grep_filtered_37_0 = grep { /VERSION_STR/msx } @grep_lines_37_0;
        $grep_result_37_0 = join "\n", @grep_filtered_37_0;
        if (!($grep_result_37_0 =~ m{\n\z}msx || $grep_result_37_0 eq q{})) {
        $grep_result_37_0 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_37_0 > 0 ? 0 : 1;
        $output_37 = $grep_result_37_0;
        my @lines = split /\n/msx, $output_37;
        my @result;
        foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($fields[2] . "\n");
        }
        $output_37 = join "", @result;
        my @sed_lines_37 = split /\n/msx, $output_37;
        my @sed_result_37;
        foreach my $line (@sed_lines_37) {
        chomp $line;
        $line =~ s/"//gmsx;
        push @sed_result_37, $line;
        }
        $output_37 = join "\n", @sed_result_37;
        if ( !$pipeline_success_37 ) { $main_exit_code = 1; }
        $output_37 =~ s/\n+\z//msx;
        $output_37;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
if ("$ALSA_LIB_VERSION" eq q{}) {
if ((-f '/etc/lsb-release')) {
            $main_exit_code = system('.', '/etc/lsb-release') >> 8;
if ("$ENV{DISTRIB_ID}" =~ /^Ubuntu$/msx) {
                if (!(                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
                    $main_exit_code = system('command', '-v', 'dpkg') >> 8;
                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                })) {
                    $ALSA_LIB_VERSION = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                        my $output_38 = q{};
                        my $output_printed_38;
                        my $pipeline_success_38 = 1;

                        my ($in_39, $out_39);
                        my $pid_39 = open3($in_39, $out_39, '>&STDERR', 'dpkg', '-l', 'libasound2');
                        close $in_39 or croak 'Close failed: $OS_ERROR';
                        $output_38 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_39> };
                        close $out_39 or croak 'Close failed: $OS_ERROR';
                        waitpid $pid_39, 0;
                        if ($CHILD_ERROR != 0) { $pipeline_success_38 = 0; }
                        my @lines = split /\n/msx, $output_38;
                        my $num_lines = 1;
                        if ($num_lines > scalar @lines) {
                        $num_lines = scalar @lines;
                        }
                        my $start_index = scalar @lines - $num_lines;
                        if ($start_index < 0) { $start_index = 0; }
                        my @result = @lines[$start_index..$#lines];
                        $output_38 = join "\n", @result;
                        if ($output_38 ne q{} && !($output_38  =~ m{\n\z}msx)) { $output_38 .= "\n"; }

                        my @lines = split /\n/msx, $output_38;
                        my @result;
                        foreach my $line (@lines) {
                            chomp $line;
                            if ($line =~ /^\s*$/msx) { next; }
                            my @fields = split /\s+/msx, $line;
                            push @result, ($fields[2] . "\n");
                        }
                        $output_38 = join "", @result;

                        my @lines_40 = split /\n/msx, $output_38;
                        my @result_40;
                        foreach my $line (@lines_40) {
                        chomp $line;
                        my @fields = split /-/msx, $line;
                        if (@fields > 0) {
                            push @result_40, $fields[0];
                        }
                        }
                        $output_38 = join "\n", @result_40;
                        if ($output_38 ne q{} && !($output_38  =~ m{\n\z}msx)) { $output_38 .= "\n"; }

                        if ( !$pipeline_success_38 ) { $main_exit_code = 1; }
                        $output_38 =~ s/\n+\z//msx;
                        $output_38;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
                }
                if ("$ALSA_LIB_VERSION" eq '<none>') {
                    $ALSA_LIB_VERSION = "";
                }
                return;            } elsif (1) {
                return;            }
}
        else {
            if ((-f '/etc/debian_version')) {
if (!(                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
                    $main_exit_code = system('command', '-v', 'dpkg') >> 8;
                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                })) {
                    $ALSA_LIB_VERSION = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                        my $output_41 = q{};
                        my $output_printed_41;
                        my $pipeline_success_41 = 1;

                        my ($in_42, $out_42);
                        my $pid_42 = open3($in_42, $out_42, '>&STDERR', 'dpkg', '-l', 'libasound2');
                        close $in_42 or croak 'Close failed: $OS_ERROR';
                        $output_41 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_42> };
                        close $out_42 or croak 'Close failed: $OS_ERROR';
                        waitpid $pid_42, 0;
                        if ($CHILD_ERROR != 0) { $pipeline_success_41 = 0; }
                        my @lines = split /\n/msx, $output_41;
                        my $num_lines = 1;
                        if ($num_lines > scalar @lines) {
                        $num_lines = scalar @lines;
                        }
                        my $start_index = scalar @lines - $num_lines;
                        if ($start_index < 0) { $start_index = 0; }
                        my @result = @lines[$start_index..$#lines];
                        $output_41 = join "\n", @result;
                        if ($output_41 ne q{} && !($output_41  =~ m{\n\z}msx)) { $output_41 .= "\n"; }

                        my @lines = split /\n/msx, $output_41;
                        my @result;
                        foreach my $line (@lines) {
                            chomp $line;
                            if ($line =~ /^\s*$/msx) { next; }
                            my @fields = split /\s+/msx, $line;
                            push @result, ($fields[2] . "\n");
                        }
                        $output_41 = join "", @result;

                        my @lines_43 = split /\n/msx, $output_41;
                        my @result_43;
                        foreach my $line (@lines_43) {
                        chomp $line;
                        my @fields = split /-/msx, $line;
                        if (@fields > 0) {
                            push @result_43, $fields[0];
                        }
                        }
                        $output_41 = join "\n", @result_43;
                        if ($output_41 ne q{} && !($output_41  =~ m{\n\z}msx)) { $output_41 .= "\n"; }

                        if ( !$pipeline_success_41 ) { $main_exit_code = 1; }
                        $output_41 =~ s/\n+\z//msx;
                        $output_41;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
                }
if ("$ALSA_LIB_VERSION" eq '<none>') {
                    $ALSA_LIB_VERSION = "";
                }
return;
            }
        }
    }
    return;
}
my $prg;
for my $prg (@REQUIRES) {
    my $t;
    my @t;
    my %t;
    $t = "$(command -v ";
    $CHILD_ERROR = 0;
if (StringInterpolation(StringInterpolation { parts: [Variable("t")] }, None) eq q{}) {
        do {
    my $__echo_line = "This script requires $prg utility to continue.";
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
}
$LSPCI = (do { my $_chomp_temp = do {
    my ($in_44, $out_44);
    my $pid_44 = open3($in_44, $out_44, '>&STDERR', 'command', '-v', 'lspci');
    close $in_44 or croak 'Close failed: $OS_ERROR';
    my $result_44 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_44> };
    close $out_44 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_44, 0;
    $result_44
}; chomp $_chomp_temp; $_chomp_temp; });
$TPUT = (do { my $_chomp_temp = do {
    my ($in_45, $out_45);
    my $pid_45 = open3($in_45, $out_45, '>&STDERR', 'command', '-v', 'tput');
    close $in_45 or croak 'Close failed: $OS_ERROR';
    my $result_45 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_45> };
    close $out_45 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_45, 0;
    $result_45
}; chomp $_chomp_temp; $_chomp_temp; });
$DIALOG = (do { my $_chomp_temp = do {
    my ($in_46, $out_46);
    my $pid_46 = open3($in_46, $out_46, '>&STDERR', 'command', '-v', 'dialog');
    close $in_46 or croak 'Close failed: $OS_ERROR';
    my $result_46 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_46> };
    close $out_46 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_46, 0;
    $result_46
}; chomp $_chomp_temp; $_chomp_temp; });
$SYSFS = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_47 = q{};
    my $output_printed_47;
    my $pipeline_success_47 = 1;

    my ($in_48, $out_48);
    my $pid_48 = open3($in_48, $out_48, '>&STDERR', 'mount', );
    close $in_48 or croak 'Close failed: $OS_ERROR';
    $output_47 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_48> };
    close $out_48 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_48, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_47 = 0; }
    my $grep_result_47_1;
    my @grep_lines_47_1 = split /\n/msx, $output_47;
    my @grep_filtered_47_1 = grep { /sysfs/msx } @grep_lines_47_1;
    $grep_result_47_1 = join "\n", @grep_filtered_47_1;
        if (!($grep_result_47_1 =~ m{\n\z}msx || $grep_result_47_1 eq q{})) {
            $grep_result_47_1 .= "\n";
        }
    $CHILD_ERROR = scalar @grep_filtered_47_1 > 0 ? 0 : 1;
    $output_47 = $grep_result_47_1;
    my @lines = split /\n/msx, $output_47;
    my @result;
    foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($fields[2] . "\n");
    }
    $output_47 = join "", @result;

    if ( !$pipeline_success_47 ) { $main_exit_code = 1; }
    $output_47 =~ s/\n+\z//msx;
    $output_47;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
$SNDOPTIONS = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_49 = q{};
    my $output_printed_49;
    my $pipeline_success_49 = 1;

    my ($in_50, $out_50);
    my $pid_50 = open3($in_50, $out_50, '>&STDERR', 'modprobe', '-c');
    close $in_50 or croak 'Close failed: $OS_ERROR';
    $output_49 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_50> };
    close $out_50 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_50, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_49 = 0; }
    my @sed_lines_49 = split /\n/msx, $output_49;
    my @sed_result_49;
    foreach my $line (@sed_lines_49) {
    chomp $line;
    push @sed_result_49, $line;
    }
    $output_49 = join "\n", @sed_result_49;

    if ( !$pipeline_success_49 ) { $main_exit_code = 1; }
    $output_49 =~ s/\n+\z//msx;
    $output_49;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
my $KEEP_OUTPUT;
my @KEEP_OUTPUT;
my %KEEP_OUTPUT;
$KEEP_OUTPUT = q{};
$NFILE = "";
$PASTEBIN = "";
my $WWWSERVICE;
my @WWWSERVICE;
my %WWWSERVICE;
$WWWSERVICE = 'www.alsa-project.org';
$WELCOME = 'yes';
$PROCEED = 'yes';
$UPLOAD = 'ask';
$REPEAT = "";
while ( "$REPEAT" eq q{} ) {
    $REPEAT = 'no';
if ("$_[0]" =~ /^--update$/msx or "$_[0]" =~ /^--help$/msx or "$_[0]" =~ /^--about$/msx) {
                $WELCOME = 'no';
                $PROCEED = 'no';
    } elsif ("$_[0]" =~ /^--upload$/msx) {
                $UPLOAD = 'yes';
                $WELCOME = 'no';
    } elsif ("$_[0]" =~ /^--no-upload$/msx) {
                $UPLOAD = 'no';
                $WELCOME = 'no';
    } elsif ("$_[0]" =~ /^--pastebin$/msx) {
                $PASTEBIN = 'yes';
                $WWWSERVICE = 'pastebin';
    } elsif ("$_[0]" =~ /^--no-dialog$/msx) {
                $DIALOG = "";
                $REPEAT = "";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--stdout$/msx) {
                $DIALOG = "";
                $WELCOME = 'no';
    }
}
if ("$WELCOME" eq yes) {
    my $greeting_message;
    my @greeting_message;
    my %greeting_message;
    $greeting_message = "\

This script visits the following commands/files to collect diagnostic
information about your ALSA installation and sound related hardware.

  dmesg
  lspci
  aplay
  amixer
  alsactl
  rpm, dpkg
  /proc/asound/
  /sys/class/sound/
  ~/.asoundrc (etc.)

See '$PROGRAM_NAME --help' for command line options.
";
if ("$DIALOG" ne q{}) {
        $main_exit_code = system('dialog', '--backtitle', "$BGTITLE", '--title', "ALSA-Info script v $SCRIPT_VERSION", '--msgbox', "$greeting_message", '20', '80') >> 8;
}
    else {
        do {
    my $__echo_line = "ALSA Information Script v $SCRIPT_VERSION";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print "--------------------------------\n";
        print $greeting_message;
if ( !( ($greeting_message) =~ m{\n\z}msx ) ) { print "\n"; }
    }
}
$TEMPDIR = (do { my $_chomp_temp = do {
    my ($in_51, $out_51);
    my $pid_51 = open3($in_51, $out_51, '>&STDERR', 'mktemp', '-t', '-d', 'alsa-info.XXXXXXXXXX');
    close $in_51 or croak 'Close failed: $OS_ERROR';
    my $result_51 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_51> };
    close $out_51 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_51, 0;
    $result_51
}; chomp $_chomp_temp; $_chomp_temp; });
if ($CHILD_ERROR != 0) {
    exit 1;
}
my $FILE;
my @FILE;
my %FILE;
$FILE = "$TEMPDIR/alsa-info.txt";
if ("$NFILE" eq q{}) {
        $NFILE = (do { my $_chomp_temp = do {
    my ($in_52, $out_52);
    my $pid_52 = open3($in_52, $out_52, '>&STDERR', 'mktemp', '-t', 'alsa-info.txt.XXXXXXXXXX');
    close $in_52 or croak 'Close failed: $OS_ERROR';
    my $result_52 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_52> };
    close $out_52 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_52, 0;
    $result_52
}; chomp $_chomp_temp; $_chomp_temp; });
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
}
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'cleanup 2>&1'; print $end_out if $end_out ne q{}; }
if ("$PROCEED" eq yes) {
if ("$LSPCI" eq q{}) {
if ((-d '/sys/bus/pci')) {
            print "This script requires lspci. Please install it, and re-run this script.\n";
        }
    }
    my $TSTAMP;
    my @TSTAMP;
    my %TSTAMP;
    $TSTAMP = do {
local $ENV{LANG} = q{C};
local $ENV{TZ} = 'UTC';
require POSIX; POSIX::strftime('%a %b %e %H:%M:%S %Z %Y', localtime(time())) . "\n"
};
    my $DISTRO;
    my @DISTRO;
    my %DISTRO;
    $DISTRO = do { my $grep_result_53;
my @grep_lines_53 = ();
my @grep_filenames_53 = ();
if (-e "/etc/") {
    open my $fh, '<', "/etc/" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_53, $line;
        push @grep_filenames_53, "/etc/";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/: No such file or directory\n"; }
my @grep_filtered_53 = grep { /buntu|SUSE|Fedora|PCLinuxOS|MEPIS|Mandriva|Debian|Damn|Sabayon|Slackware|KNOPPIX|Gentoo|Zenwalk|Mint|Kubuntu|FreeBSD|Puppy|Freespire|Vector|Dreamlinux|CentOS|Arch|Xandros|Elive|SLAX|Red|BSD|KANOTIX|Nexenta|Foresight|GeeXboX|Frugalware|64|SystemRescue|Novell|Solaris|BackTrack|KateOS|Pardus|ALT/msxi } @grep_lines_53;
$grep_result_53 = join "\n", @grep_filtered_53;
    if (!($grep_result_53 =~ m{\n\z}msx || $grep_result_53 eq q{})) {
        $grep_result_53 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_53 > 0 ? 0 : 1;
 $grep_result_53; };
    my $temp_file_ps_fh_1 = q{/tmp} . '/process_sub_fh_1.tmp';
    my $output_ps_fh_1;
    {
        local *STDOUT;
        open STDOUT, '>', \$output_ps_fh_1 or croak "Cannot redirect STDOUT";
        my $output_54 = q{};
        my $output_printed_54;
        $main_exit_code = system('/bin/uname', '-r', 'pmo') >> 8;
    if ($output_54 ne q{} && !$output_printed_54) {
        print $output_54;
    }
    }
    use File::Path qw(make_path);
    my $temp_dir_fh_1 = dirname($temp_file_ps_fh_1);
    if (!-d $temp_dir_fh_1) { make_path($temp_dir_fh_1); }
    open my $fh_ps_fh_1, '>', $temp_file_ps_fh_1 or croak "Cannot create temp file: $ERRNO\n";
    print {$fh_ps_fh_1} $output_ps_fh_1;
    close $fh_ps_fh_1 or croak "Close failed: $ERRNO\n";
    open STDIN, '<', $temp_file_ps_fh_1 or croak "Cannot open process substitution: $ERRNO\n";
$KERNEL_RELEASE = <>;
chomp $KERNEL_RELEASE;
$CHILD_ERROR = defined($KERNEL_RELEASE) ? 0 : 1;
    my $temp_file_ps_fh_2 = q{/tmp} . '/process_sub_fh_2.tmp';
    my $output_ps_fh_2;
    {
        local *STDOUT;
        open STDOUT, '>', \$output_ps_fh_2 or croak "Cannot redirect STDOUT";
        my $output_56 = q{};
        my $output_printed_56;
        $main_exit_code = system('/bin/uname', '-v') >> 8;
    if ($output_56 ne q{} && !$output_printed_56) {
        print $output_56;
    }
    }
    use File::Path qw(make_path);
    my $temp_dir_fh_2 = dirname($temp_file_ps_fh_2);
    if (!-d $temp_dir_fh_2) { make_path($temp_dir_fh_2); }
    open my $fh_ps_fh_2, '>', $temp_file_ps_fh_2 or croak "Cannot create temp file: $ERRNO\n";
    print {$fh_ps_fh_2} $output_ps_fh_2;
    close $fh_ps_fh_2 or croak "Close failed: $ERRNO\n";
    open STDIN, '<', $temp_file_ps_fh_2 or croak "Cannot open process substitution: $ERRNO\n";
$KERNEL_VERSION = <>;
chomp $KERNEL_VERSION;
$CHILD_ERROR = defined($KERNEL_VERSION) ? 0 : 1;
if ("$KERNEL_VERSION" eq *SMP*) {
        my $KERNEL_SMP;
        my @KERNEL_SMP;
        my %KERNEL_SMP;
        $KERNEL_SMP = 'Yes';
}
    else {
        $KERNEL_SMP = 'No';
    }
    my $ALSA_DRIVER_VERSION;
    my @ALSA_DRIVER_VERSION;
    my %ALSA_DRIVER_VERSION;
    $ALSA_DRIVER_VERSION = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_58 = q{};
        my $output_printed_58;
        my $pipeline_success_58 = 1;
        $output_58 = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/asound/version' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/asound/version' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        if ($CHILD_ERROR != 0) { $pipeline_success_58 = 0; }
        my $num_lines       = 1;
        my $head_line_count = 0;
        my $result          = q{};
        my $input           = $output_58;
        my $pos             = 0;

        while ( $pos < length $input && $head_line_count < $num_lines ) {
            my $line_end = index $input, "\n", $pos;
            if ( $line_end == -1 ) {
                $line_end = length $input;
            }
            my $head_line = substr $input, $pos, $line_end - $pos;
            $result .= $head_line . "\n";
            $pos = $line_end + 1;
            ++$head_line_count;
        }
        $output_58 = $result;

        my @lines = split /\n/msx, $output_58;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\s+/msx, $line;
            push @result, ($fields[6] . "\n");
        }
        $output_58 = join "", @result;

        my @sed_lines_58 = split /\n/msx, $output_58;
        my @sed_result_58;
        foreach my $line (@sed_lines_58) {
        chomp $line;
        $line =~ s/\.$//gmsx;
        push @sed_result_58, $line;
        }
        $output_58 = join "\n", @sed_result_58;

        if ( !$pipeline_success_58 ) { $main_exit_code = 1; }
        $output_58 =~ s/\n+\z//msx;
        $output_58;
}; $_pipeline_result; };
    get_alsa_library_version();
    my $ALSA_UTILS_VERSION;
    my @ALSA_UTILS_VERSION;
    my %ALSA_UTILS_VERSION;
    $ALSA_UTILS_VERSION = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_59 = q{};
        my $output_printed_59;
        my $pipeline_success_59 = 1;

        my ($in_60, $out_60);
        my $pid_60 = open3($in_60, $out_60, '>&STDERR', 'amixer', '-v');
        close $in_60 or croak 'Close failed: $OS_ERROR';
        $output_59 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_60> };
        close $out_60 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_60, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_59 = 0; }
        my @lines = split /\n/msx, $output_59;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\s+/msx, $line;
            push @result, ($fields[2] . "\n");
        }
        $output_59 = join "", @result;

        if ( !$pipeline_success_59 ) { $main_exit_code = 1; }
        $output_59 =~ s/\n+\z//msx;
        $output_59;
}; $_pipeline_result; };
    $ESDINST = do {
    my ($in_61, $out_61);
    my $pid_61 = open3($in_61, $out_61, '>&STDERR', 'command', '-v', 'esd');
    close $in_61 or croak 'Close failed: $OS_ERROR';
    my $result_61 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_61> };
    close $out_61 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_61, 0;
    $result_61
};
    $PWINST = do {
    my ($in_62, $out_62);
    my $pid_62 = open3($in_62, $out_62, '>&STDERR', 'command', '-v', 'pipewire');
    close $in_62 or croak 'Close failed: $OS_ERROR';
    my $result_62 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_62> };
    close $out_62 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_62, 0;
    $result_62
};
    $PAINST = do {
    my ($in_63, $out_63);
    my $pid_63 = open3($in_63, $out_63, '>&STDERR', 'command', '-v', 'pulseaudio');
    close $in_63 or croak 'Close failed: $OS_ERROR';
    my $result_63 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_63> };
    close $out_63 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_63, 0;
    $result_63
};
    $ARTSINST = do {
    my ($in_64, $out_64);
    my $pid_64 = open3($in_64, $out_64, '>&STDERR', 'command', '-v', 'artsd');
    close $in_64 or croak 'Close failed: $OS_ERROR';
    my $result_64 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_64> };
    close $out_64 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_64, 0;
    $result_64
};
    $JACKINST = do {
    my ($in_65, $out_65);
    my $pid_65 = open3($in_65, $out_65, '>&STDERR', 'command', '-v', 'jackd');
    close $in_65 or croak 'Close failed: $OS_ERROR';
    my $result_65 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_65> };
    close $out_65 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_65, 0;
    $result_65
};
    $JACK2INST = do {
    my ($in_66, $out_66);
    my $pid_66 = open3($in_66, $out_66, '>&STDERR', 'command', '-v', 'jackdbus');
    close $in_66 or croak 'Close failed: $OS_ERROR';
    my $result_66 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_66> };
    close $out_66 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_66, 0;
    $result_66
};
    $ROARINST = do {
    my ($in_67, $out_67);
    my $pid_67 = open3($in_67, $out_67, '>&STDERR', 'command', '-v', 'roard');
    close $in_67 or croak 'Close failed: $OS_ERROR';
    my $result_67 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_67> };
    close $out_67 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_67, 0;
    $result_67
};
    $DMIDECODE = do {
    my ($in_68, $out_68);
    my $pid_68 = open3($in_68, $out_68, '>&STDERR', 'command', '-v', 'dmidecode');
    close $in_68 or croak 'Close failed: $OS_ERROR';
    my $result_68 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_68> };
    close $out_68 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_68, 0;
    $result_68
};
if ((-d '/sys/class/dmi/id')) {
        my $DMI_SYSTEM_MANUFACTURER;
        my @DMI_SYSTEM_MANUFACTURER;
        my %DMI_SYSTEM_MANUFACTURER;
        $DMI_SYSTEM_MANUFACTURER = do { my @_qx_cmd = ("cat /sys/class/dmi/id/sys_vendor 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        my $DMI_SYSTEM_PRODUCT_NAME;
        my @DMI_SYSTEM_PRODUCT_NAME;
        my %DMI_SYSTEM_PRODUCT_NAME;
        $DMI_SYSTEM_PRODUCT_NAME = do { my @_qx_cmd = ("cat /sys/class/dmi/id/product_name 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        my $DMI_SYSTEM_PRODUCT_VERSION;
        my @DMI_SYSTEM_PRODUCT_VERSION;
        my %DMI_SYSTEM_PRODUCT_VERSION;
        $DMI_SYSTEM_PRODUCT_VERSION = do { my @_qx_cmd = ("cat /sys/class/dmi/id/product_version 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        my $DMI_SYSTEM_FIRMWARE_VERSION;
        my @DMI_SYSTEM_FIRMWARE_VERSION;
        my %DMI_SYSTEM_FIRMWARE_VERSION;
        $DMI_SYSTEM_FIRMWARE_VERSION = do { my @_qx_cmd = ("cat /sys/class/dmi/id/bios_version 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        my $DMI_SYSTEM_SKU;
        my @DMI_SYSTEM_SKU;
        my %DMI_SYSTEM_SKU;
        $DMI_SYSTEM_SKU = do { my @_qx_cmd = ("cat /sys/class/dmi/id/product_sku 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        my $DMI_BOARD_VENDOR;
        my @DMI_BOARD_VENDOR;
        my %DMI_BOARD_VENDOR;
        $DMI_BOARD_VENDOR = do { my @_qx_cmd = ("cat /sys/class/dmi/id/board_vendor 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        my $DMI_BOARD_NAME;
        my @DMI_BOARD_NAME;
        my %DMI_BOARD_NAME;
        $DMI_BOARD_NAME = do { my @_qx_cmd = ("cat /sys/class/dmi/id/board_name 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
}
    else {
        if ((-x $DMIDECODE)) {
            $DMI_SYSTEM_MANUFACTURER = do { my @_qx_cmd = ("$DMIDECODE -s system-manufacturer 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            $DMI_SYSTEM_PRODUCT_NAME = do { my @_qx_cmd = ("$DMIDECODE -s system-product-name 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            $DMI_SYSTEM_PRODUCT_VERSION = do { my @_qx_cmd = ("$DMIDECODE -s system-version 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            $DMI_SYSTEM_FIRMWARE_VERSION = do { my @_qx_cmd = ("$DMIDECODE -s bios-version 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            $DMI_SYSTEM_SKU = do { my @_qx_cmd = ("$DMIDECODE -s system-sku-number 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            $DMI_BOARD_VENDOR = do { my @_qx_cmd = ("$DMIDECODE -s baseboard-manufacturer 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            $DMI_BOARD_NAME = do { my @_qx_cmd = ("$DMIDECODE -s baseboard-product-name 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        }
    }
if ((-d '/sys/bus/acpi/devices')) {
        my $f;
        for my $f ('/sys/bus/acpi/devices/*/status') {
            $ACPI_STATUS = do { my @_qx_cmd = ("cat Variable(\"f\", false, None) 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if (($ACPI_STATUS != 0)) {
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', $TEMPDIR
      or die "Cannot open file: $OS_ERROR\n";
                    do {
    my $__echo_line = $f . q{ } . "\t" . q{ } . $ACPI_STATUS . q{ } . '/acpidevicestatus.tmp';
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
            }
        }
    }
open STDIN, '<', '/proc/asound/modules' or croak "Cannot open file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', $TEMPDIR
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
my @lines = split /\n/msx, $;
my @result;
foreach my $line (@lines) {
    chomp $line;
    if ($line =~ /^\s*$/msx) { next; }
    my @fields = split /\s+/msx, $line;
    push @result, ($fields[1] . " (card " . $fields[0] . ")" . "\n");
}
$ = join "", @result;

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
        open STDOUT, '>', $TEMPDIR
      or die "Cannot open file: $OS_ERROR\n";
print (do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/asound/cards' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/asound/cards' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/alsacards.tmp' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/alsacards.tmp' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
if (! "$LSPCI" eq q{}) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $TEMPDIR
      or die "Cannot open file: $OS_ERROR\n";
            my $class;
            for my $class ('0401', '0402', '0403') {
                # Original bash: lspci -vvnn -d "::$class" | sed -n '/^[^\t]/,+1p'
{
                    my $output_71 = q{};
                    my $output_printed_71;
                    my $pipeline_success_71 = 1;
                                        my ($in_72, $out_72);
                    my $pid_72 = open3($in_72, $out_72, '>&STDERR', 'lspci', '-vvnn', '-d');
                    close $in_72 or croak 'Close failed: $OS_ERROR';
                    $output_71 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_72> };
                    close $out_72 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_72, 0;

                                        my @sed_lines_71 = split /\n/msx, $output_71;
                    my @sed_result_71;
                    foreach my $line (@sed_lines_71) {
                    chomp $line;
                    push @sed_result_71, $line;
                    }
                    $output_71 = join "\n", @sed_result_71;
                    if ($output_71 ne q{} && !defined $output_printed_71) {
                        print $output_71;
                        if (!($output_71 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_71 ) { $main_exit_code = 1; }
                    }
            }
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $main_exit_code = system('bash', '/lspci.tmp') >> 8;
    }
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "/proc/asound/card*/codec\\#* > $TEMPDIR/alsa-hda-intel.tmp 2> /dev/null" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "/proc/asound/card*/codec\\#* > $TEMPDIR/alsa-hda-intel.tmp 2> /dev/null" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "/proc/asound/card*/codec97\\#0/ac97\\#0-0 > $TEMPDIR/alsa-ac97.tmp 2> /dev/null" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "/proc/asound/card*/codec97\\#0/ac97\\#0-0 > $TEMPDIR/alsa-ac97.tmp 2> /dev/null" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "/proc/asound/card*/codec97\\#0/ac97\\#0-0+regs > $TEMPDIR/alsa-ac97-regs.tmp 2> /dev/null" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "/proc/asound/card*/codec97\\#0/ac97\\#0-0+regs > $TEMPDIR/alsa-ac97-regs.tmp 2> /dev/null" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
if ((-x '/usr/bin/lsusb')) {
        for my $f ('/proc/asound/card[0-9]*/usbbus') {
                        $main_exit_code = system('test', '-f', "$f") >> 8;
            if ($CHILD_ERROR != 0) {
                next;            }
            my $id;
            my @id;
            my %id;
            $id = do { my @_qx_cmd = ('sed s@/@:@ $f'); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $TEMPDIR
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('lsusb', '-v', '-s', $id, '/lsusb.tmp') >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', $TEMPDIR
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
print (do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/asound/card*/stream[0-9]*' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/asound/card*/stream[0-9]*' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/alsa-usbstream.tmp' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/alsa-usbstream.tmp' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', $TEMPDIR
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
print (do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/asound/card*/usbmixer' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/asound/card*/usbmixer' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/alsa-usbmixer.tmp' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/alsa-usbmixer.tmp' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
if ($PASTEBIN eq q{}) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "upload=true&script=true&cardinfo=\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
}
    else {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "name=$ENV{USER}&type=33&description=/tmp/alsa-info.txt&expiry=&s=Submit+Post&content=";
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
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!################################\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "!!ALSA Information Script v $SCRIPT_VERSION";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!################################\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "!!Script ran on: $TSTAMP";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!Linux Distribution\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!------------------\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print $DISTRO;
if ( !( ($DISTRO) =~ m{\n\z}msx ) ) { print "\n"; }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!DMI Information\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!---------------\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Manufacturer:      $DMI_SYSTEM_MANUFACTURER";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Product Name:      $DMI_SYSTEM_PRODUCT_NAME";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Product Version:   $DMI_SYSTEM_PRODUCT_VERSION";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Firmware Version:  $DMI_SYSTEM_FIRMWARE_VERSION";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "System SKU:        $DMI_SYSTEM_SKU";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Board Vendor:      $DMI_BOARD_VENDOR";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Board Name:        $DMI_BOARD_NAME";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!ACPI Device Status Information\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!---------------\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
print (do { my $cat_chunk = q{}; if ( open my $fh, '<', $TEMPDIR ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $TEMPDIR . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/acpidevicestatus.tmp' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/acpidevicestatus.tmp' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!Kernel Information\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!------------------\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Kernel release:    $KERNEL_VERSION";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Operating System:  $ENV{KERNEL_OS}";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Architecture:      $ENV{KERNEL_MACHINE}";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Processor:         $ENV{KERNEL_PROCESSOR}";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "SMP Enabled:       $KERNEL_SMP";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!ALSA Version\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!------------\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Driver version:     $ALSA_DRIVER_VERSION";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Library version:    $ENV{ALSA_LIB_VERSION}";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Utilities version:  $ALSA_UTILS_VERSION";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!Loaded ALSA modules\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!-------------------\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
print (do { my $cat_chunk = q{}; if ( open my $fh, '<', $TEMPDIR ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $TEMPDIR . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/alsamodules.tmp' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/alsamodules.tmp' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!Sound Servers on this " . "sys" . "tem\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!----------------------------\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
if ($PWINST ne q{}) {
                if ((qx'pgrep '^(.*/)?pipewire$'' ne q{})) {
                        my $PWRUNNING;
            my @PWRUNNING;
            my %PWRUNNING;
            $PWRUNNING = "Yes";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
                        $PWRUNNING = "No";
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "PipeWire:\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "      Installed - Yes ($PWINST)";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "      Running - $PWRUNNING";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if ($PAINST ne q{}) {
                if ((qx'pgrep '^(.*/)?pulseaudio$'' ne q{})) {
                        my $PARUNNING;
            my @PARUNNING;
            my %PARUNNING;
            $PARUNNING = "Yes";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
                        $PARUNNING = "No";
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "Pulseaudio:\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "      Installed - Yes ($PAINST)";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "      Running - $PARUNNING";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if ($ESDINST ne q{}) {
                if ((qx'pgrep '^(.*/)?esd$'' ne q{})) {
                        my $ESDRUNNING;
            my @ESDRUNNING;
            my %ESDRUNNING;
            $ESDRUNNING = "Yes";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
                        $ESDRUNNING = "No";
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "ESound Daemon:\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "      Installed - Yes ($ESDINST)";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "      Running - $ESDRUNNING";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if ($ARTSINST ne q{}) {
                if ((qx'pgrep '^(.*/)?artsd$'' ne q{})) {
                        my $ARTSRUNNING;
            my @ARTSRUNNING;
            my %ARTSRUNNING;
            $ARTSRUNNING = "Yes";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
                        $ARTSRUNNING = "No";
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "aRts:\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "      Installed - Yes ($ARTSINST)";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "      Running - $ARTSRUNNING";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if ($JACKINST ne q{}) {
                if ((qx'pgrep '^(.*/)?jackd$'' ne q{})) {
                        my $JACKRUNNING;
            my @JACKRUNNING;
            my %JACKRUNNING;
            $JACKRUNNING = "Yes";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
                        $JACKRUNNING = "No";
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "Jack:\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "      Installed - Yes ($JACKINST)";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "      Running - $JACKRUNNING";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if ($JACK2INST ne q{}) {
                if ((qx'pgrep '^(.*/)?jackdbus$'' ne q{})) {
                        my $JACK2RUNNING;
            my @JACK2RUNNING;
            my %JACK2RUNNING;
            $JACK2RUNNING = "Yes";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
                        $JACK2RUNNING = "No";
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "Jack2:\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "      Installed - Yes ($JACK2INST)";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "      Running - $JACK2RUNNING";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if ($ROARINST ne q{}) {
                if ((qx'pgrep '^(.*/)?roard$'' ne q{})) {
                        my $ROARRUNNING;
            my @ROARRUNNING;
            my %ROARRUNNING;
            $ROARRUNNING = "Yes";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
                        $ROARRUNNING = "No";
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "RoarAudio:\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "      Installed - Yes ($ROARINST)";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "      Running - $ROARRUNNING";
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
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if (0) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "No sound servers found.\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!Soundcards recognised by ALSA\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "!!-----------------------------\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
print (do { my $cat_chunk = q{}; if ( open my $fh, '<', $TEMPDIR ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $TEMPDIR . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/alsacards.tmp' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/alsacards.tmp' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
if (! "$LSPCI" eq q{}) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!PCI Soundcards installed in the " . "sys" . "tem\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!--------------------------------------\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
print (do { my $cat_chunk = q{}; if ( open my $fh, '<', $TEMPDIR ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $TEMPDIR . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/lspci.tmp' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/lspci.tmp' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if (("$SNDOPTIONS")) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!Modprobe options (Sound related)\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!--------------------------------\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        # Original bash: modprobe -c|sed -n 's/^options \(snd[-_][^ ]*\)/\1:/p' >> $FILE
{
            my $output_82 = q{};
            my $output_printed_82;
            my $pipeline_success_82 = 1;
                        my ($in_83, $out_83);
            my $pid_83 = open3($in_83, $out_83, '>&STDERR', 'modprobe', '-c');
            close $in_83 or croak 'Close failed: $OS_ERROR';
            $output_82 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_83> };
            close $out_83 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_83, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_84 = q{};
            my @sed_lines_85 = split /\n/msx, $output_82;
            my @sed_result_85;
            foreach my $line (@sed_lines_85) {
            chomp $line;
            push @sed_result_85, $line;
            }
            $output_82 = join "\n", @sed_result_85;
            $tmp_redirect_84;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_82; }
            $output_printed_82 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_82 ) { $main_exit_code = 1; }
            }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if ((-d "$SYSFS")) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!Loaded sound module options\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!---------------------------\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        my $mod;
        for my $mod (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_86 = q{};
            my $output_printed_86;
            my $pipeline_success_86 = 1;
            $output_86 = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/asound/modules' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/asound/modules' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            if ($CHILD_ERROR != 0) { $pipeline_success_86 = 0; }
            my @lines = split /\n/msx, $output_86;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                push @result, ($fields[1] . "\n");
            }
            $output_86 = join "", @result;

            if ( !$pipeline_success_86 ) { $main_exit_code = 1; }
            $output_86 =~ s/\n+\z//msx;
            $output_86;
}; $_pipeline_result; }) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "!!Module: $mod";
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
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
                my $params;
                for my $params (($SYSFS . q{ } . '/module/' . q{ } . $mod . q{ } . '/parameters/*')) {
                    print '-ne' . q{ } . "\t" . "\n";
                    $CHILD_ERROR = 0;
                    my $value;
                    my @value;
                    my %value;
                    $value = do { my $cat_chunk = q{}; if ( open my $fh, '<', $params ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $params . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                    # Original bash: echo "$params : $value" | sed 's:.*/::'
{
                        my $output_87 = q{};
                        my $output_printed_87;
                        my $pipeline_success_87 = 1;
                        $output_87 .= "$params : $value\n";
if ( !($output_87 =~ m{\n\z}msx) ) { $output_87 .= "\n"; }
$CHILD_ERROR = 0;

                                                my @sed_lines_87 = split /\n/msx, $output_87;
                        my @sed_result_87;
                        foreach my $line (@sed_lines_87) {
                        chomp $line;
                        push @sed_result_87, $line;
                        }
                        $output_87 = join "\n", @sed_result_87;
                        if ($output_87 ne q{} && !defined $output_printed_87) {
                            print $output_87;
                            if (!($output_87 =~ m{\n\z}msx)) {
                                print "\n";
                            }
                        }
                        if ( !$pipeline_success_87 ) { $main_exit_code = 1; }
                        }
                }
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!Sysfs card info\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!---------------\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        my $cdir;
        for my $cdir (($SYSFS . q{ } . '/class/sound/card*')) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "!!Card: $cdir";
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
            my $driver;
            my @driver;
            my %driver;
            $driver = do {
    my ($in_88, $out_88);
    my $pid_88 = open3($in_88, $out_88, '>&STDERR', 'readlink', '-f', "$cdir/device/driver");
    close $in_88 or croak 'Close failed: $OS_ERROR';
    my $result_88 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_88> };
    close $out_88 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_88, 0;
    $result_88
};
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "Driver: $driver";
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
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
                print "Tree:\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            # Original bash: tree --noreport $cdir -L 2 | sed -e 's/^/\t/g' >> $FILE
{
                my $output_89 = q{};
                my $output_printed_89;
                my $pipeline_success_89 = 1;
                                my ($in_90, $out_90);
                my $pid_90 = open3($in_90, $out_90, '>&STDERR', 'tree', '--noreport', '-L', q{2});
                close $in_90 or croak 'Close failed: $OS_ERROR';
                $output_89 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_90> };
                close $out_90 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_90, 0;

                                do {
                open my $original_stdout, '>&', STDOUT
                or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $FILE
                or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                my $tmp_redirect_91 = q{};
                my @sed_lines_92 = split /\n/msx, $output_89;
                my @sed_result_92;
                foreach my $line (@sed_lines_92) {
                chomp $line;
                push @sed_result_92, $line;
                }
                $output_89 = join "\n", @sed_result_92;
                $tmp_redirect_91;
                };
                print $tmp;
                if ($tmp eq q{}) { print $output_89; }
                $output_printed_89 = 1;
                open STDOUT, '>&', $original_stdout
                or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
                or die "Close failed: $OS_ERROR\n";
                };
                if ( !$pipeline_success_89 ) { $main_exit_code = 1; }
                }
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
if ((-d $SYSFS/class/sound/ctl-led)) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
                print "!!Sysfs ctl-led info\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
                print "!!---------------\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            for my $path (($SYSFS . q{ } . '/class/sound/ctl-led/[ms][ip]*/card*')) {
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
                    do {
    my $__echo_line = "!!CTL-LED: $path";
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
if ((-r "$path/list")) {
                    my $list;
                    my @list;
                    my %list;
                    $list = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$path/list" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$path/list" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
                        do {
    my $__echo_line = "List: $list";
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
                }
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
                    print "\n";
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
            }
        }
    }
if (((-s "$TEMPDIR/alsa-hda-intel.tmp") > 0)) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!HDA-Intel Codec information\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!---------------------------\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "--startcollapse--\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
print (do { my $cat_chunk = q{}; if ( open my $fh, '<', $TEMPDIR ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $TEMPDIR . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/alsa-hda-intel.tmp' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/alsa-hda-intel.tmp' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "--endcollapse--\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if (((-s "$TEMPDIR/alsa-ac97.tmp") > 0)) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!AC97 Codec information\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!----------------------\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "--startcollapse--\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
print (do { my $cat_chunk = q{}; if ( open my $fh, '<', $TEMPDIR ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $TEMPDIR . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/alsa-ac97.tmp' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/alsa-ac97.tmp' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
print (do { my $cat_chunk = q{}; if ( open my $fh, '<', $TEMPDIR ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $TEMPDIR . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/alsa-ac97-regs.tmp' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/alsa-ac97-regs.tmp' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "--endcollapse--\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if (((-s "$TEMPDIR/lsusb.tmp") > 0)) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!USB Descriptors\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!---------------\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "--startcollapse--\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
print (do { my $cat_chunk = q{}; if ( open my $fh, '<', $TEMPDIR ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $TEMPDIR . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/lsusb.tmp' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/lsusb.tmp' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "--endcollapse--\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if (((-s "$TEMPDIR/alsa-usbstream.tmp") > 0)) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!USB Stream information\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!----------------------\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "--startcollapse--\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
print (do { my $cat_chunk = q{}; if ( open my $fh, '<', $TEMPDIR ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $TEMPDIR . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/alsa-usbstream.tmp' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/alsa-usbstream.tmp' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "--endcollapse--\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if (((-s "$TEMPDIR/alsa-usbmixer.tmp") > 0)) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!USB Mixer information\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "!!---------------------\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "--startcollapse--\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
print (do { my $cat_chunk = q{}; if ( open my $fh, '<', $TEMPDIR ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $TEMPDIR . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/alsa-usbmixer.tmp' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/alsa-usbmixer.tmp' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "--endcollapse--\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $FILE
      or die "Cannot open file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
}
if ("$1" ne q{}) {
until ( "$1" eq q{} ) {
if ("$_[0]" =~ /^--pastebin$/msx) {
        } elsif ("$_[0]" =~ /^--update$/msx) {
                        update();
            exit $main_exit_code;
        } elsif ("$_[0]" =~ /^--upload$/msx) {
                        $UPLOAD = 'yes';
        } elsif ("$_[0]" =~ /^--no-upload$/msx) {
                        $UPLOAD = 'no';
        } elsif ("$_[0]" =~ /^--output$/msx) {
            # Builtin command 'shift' not implemented
                        $NFILE = "$_[0]";
                        $KEEP_OUTPUT = 'yes';
        } elsif ("$_[0]" =~ /^--debug$/msx) {
                        do {
    my $__echo_line = "Debugging enabled. $FILE and $TEMPDIR will not be deleted";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
                        my $KEEP_FILES;
            my @KEEP_FILES;
            my %KEEP_FILES;
            $KEEP_FILES = 'yes';
                        print "\n";
        } elsif ("$_[0]" =~ /^--with-all$/msx) {
                        withall();
        } elsif ("$_[0]" =~ /^--with-aplay$/msx) {
                        withaplay();
                        $WITHALL = 'no';
        } elsif ("$_[0]" =~ /^--with-amixer$/msx) {
                        withamixer();
                        $WITHALL = 'no';
        } elsif ("$_[0]" =~ /^--with-alsactl$/msx) {
                        withalsactl();
                        $WITHALL = 'no';
        } elsif ("$_[0]" =~ /^--with-devices$/msx) {
                        withdevices();
                        $WITHALL = 'no';
        } elsif ("$_[0]" =~ /^--with-dmesg$/msx) {
                        withdmesg();
                        $WITHALL = 'no';
        } elsif ("$_[0]" =~ /^--with-configs$/msx) {
                        withconfigs();
                        $WITHALL = 'no';
        } elsif ("$_[0]" =~ /^--with-packages$/msx) {
                        withpackages();
                        $WITHALL = 'no';
        } elsif ("$_[0]" =~ /^--stdout$/msx) {
                        $UPLOAD = 'no';
            if ("$WITHALL" eq q{}) {
                withall();
            }
            print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$FILE" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$FILE" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            if ( -e "$FILE" ) {
                if ( -d "$FILE" ) {
                    croak "rm: ", "$FILE",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$FILE" ) {
                                            }
                    else {
                        croak "rm: cannot remove ", "$FILE",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 1;
                croak "rm: ", "$FILE", ": No such file or directory\n";
            }
            exit $main_exit_code;
        } elsif ("$_[0]" =~ /^--about$/msx) {
                        print "Written/Tested by the following users of #alsa on irc.freenode.net:\n";
                        print "\n";
                        print "	wishie - Script author and developer / Testing\n";
                        print "	crimsun - Various script ideas / Testing\n";
                        print "	gnubien - Various script ideas / Testing\n";
                        print "	GrueMaster - HDA Intel specific items / Testing\n";
                        print "	olegfink - Script update function\n";
                        print "  TheMuso - display to stdout functionality\n";
            exit 0;
        } elsif (1) {
                        do {
    my $__echo_line = "alsa-info.sh version $SCRIPT_VERSION";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
                        print "\n";
                        print "Available options:\n";
                        print "	--with-aplay (includes the output of aplay -l)\n";
                        print "	--with-amixer (includes the output of amixer)\n";
                        print "	--with-alsactl (includes the output of alsactl)\n";
                        print "	--with-configs (includes the output of ~/.asoundrc and\n";
                        print "	    /etc/asound.conf if they exist)\n";
                        print "	--with-devices (shows the device nodes in /dev/snd/)\n";
                        print "	--with-dmesg (shows the ALSA/HDA kernel messages)\n";
                        print "	--with-packages (includes known packages installed)\n";
                        print "\n";
                        print "	--output FILE (specify the file to output for no-upload mode)\n";
                        print "	--update (check server for script updates)\n";
                        print "	--upload (upload contents to remote server)\n";
                        print "	--no-upload (do not upload contents to remote server)\n";
                        print "	--pastebin (use 'https://pastebin.ca') as remote server\n";
                        print "	    instead www.alsa-project.org\n";
                        print "	--stdout (print alsa information to standard output\n";
                        print "	    instead of a file)\n";
                        print "	--about (show some information about the script)\n";
                        print "	--debug (will run the script as normal, but will not\n";
                        do {
    my $__echo_line = "	     delete " . ${FILE} . ")";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            exit 0;
        }
# Builtin command 'shift' not implemented
    }
}
if ("$PROCEED" eq no) {
exit 1;
}
if ("$WITHALL" eq q{}) {
    withall();
}
if (!(!(# Original bash: wget --help 2>/dev/null | grep -q post-file;
{
    my $output_100 = q{};
    my $output_printed_100;
    my $pipeline_success_100 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_101 = q{};
use LWP::Simple;
my $url = '--help';
my $content = get($url);
if (defined $content) {
print $content;
} else {
die "Failed to download $url\n";
}
$tmp_redirect_101;
    };
    $output_100 = $output;

        my $grep_result_100_1;
    my @grep_lines_100_1 = split /\n/msx, $output_100;
    my @grep_filtered_100_1 = grep { /post-file/msx } @grep_lines_100_1;
    $grep_result_100_1 = join "\n", @grep_filtered_100_1;
    if (!($grep_result_100_1 =~ m{\n\z}msx || $grep_result_100_1 eq q{})) {
    $grep_result_100_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_100_1 > 0 ? 0 : 1;
    $grep_result_100_1 = q{};
    $output_100 = q{};
    if ((scalar @grep_filtered_100_1) == 0) {
        $pipeline_success_100 = 0;
    }
    if ($output_100 ne q{} && !defined $output_printed_100) {
        print $output_100;
        if (!($output_100 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_100 ) { $main_exit_code = 1; }
    }))) {
if ("$UPLOAD" ne yes) {
        $main_exit_code = system('bash', ':') >> 8;
}
    else {
        if ("$DIALOG" ne q{}) {
if ("$PASTEBIN" eq q{}) {
                $main_exit_code = system('dialog', '--backtitle', "$BGTITLE", '--msgbox', "Could not automatically upload output to 'https://www.alsa-project.org'.\nPossible reasons are:\n\n    1. Couldn't find 'wget' in your PATH\n    2. Your version of wget is less than 1.8.2\n\nPlease manually upload $NFILE to 'https://www.alsa-project.org/cardinfo-db' and submit your post.", '25', '100') >> 8;
}
            else {
                $main_exit_code = system('dialog', '--backtitle', "$BGTITLE", '--msgbox', "Could not automatically upload output to 'https://www.pastebin.ca'.\nPossible reasons are:\n\n    1. Couldn't find 'wget' in your PATH\n    2. Your version of wget is less than 1.8.2\n\nPlease manually upload $NFILE to 'https://www.pastebin.ca/upload.php' and submit your post.", '25', '100') >> 8;
            }
}
        else {
if ("$PASTEBIN" eq q{}) {
                print "\n";
                print "Could not automatically upload output to 'https://www.alsa-project.org'\n";
                print "Possible reasons are:\n";
                print "    1. Couldn't find 'wget' in your PATH\n";
                print "    2. Your version of wget is less than 1.8.2\n";
                print "\n";
                do {
    my $__echo_line = "Please manually upload $NFILE to 'https://www.alsa-project.org/cardinfo-db' and submit your post.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                print "\n";
}
            else {
                print "\n";
                print "Could not automatically upload output to 'https://www.pastebin.ca'\n";
                print "Possible reasons are:\n";
                print "    1. Couldn't find 'wget' in your PATH\n";
                print "    2. Your version of wget is less than 1.8.2\n";
                print "\n";
                do {
    my $__echo_line = "Please manually upload $NFILE to 'https://www.pastebin.ca/upload.php' and submit your post.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                print "\n";
            }
        }
    }
    $UPLOAD = 'no';
}
if ("$UPLOAD" eq ask) {
if ("$DIALOG" ne q{}) {
        $main_exit_code = system('dialog', '--backtitle', "$BGTITLE", '--title', "Information collected", '--yes-label', " UPLOAD / SHARE ", '--no-label', " SAVE LOCALLY ", '--defaultno', '--yesno', "\n\nAutomatically upload ALSA information to $WWWSERVICE?", '10', '80') >> 8;
        $DIALOG_EXIT_CODE = "${\($? >> 8)}";
if ("$DIALOG_EXIT_CODE" ne 0) {
            $UPLOAD = 'no';
}
        else {
            $UPLOAD = 'yes';
        }
}
    else {
        print "Automatically upload ALSA information to $WWWSERVICE? [y/N] : ";
$CONFIRM = <>;
chomp $CONFIRM;
$CHILD_ERROR = defined($CONFIRM) ? 0 : 1;
if ("$CONFIRM" ne y) {
            $UPLOAD = 'no';
}
        else {
            $UPLOAD = 'yes';
        }
    }
}
if ("$UPLOAD" eq no) {
        my $err;
    my $force = 1;
    if ( -e "$FILE" ) {
        my $dest = "$NFILE";
        if ( -e $dest && -d $dest ) {
            my $source_name = "$FILE";
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
        if ( File::Copy::move( "$FILE", $dest ) ) {
        } else {
            croak
  "mv: cannot move "$FILE" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "$FILE": No such file or directory\n";
    }
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
    $KEEP_OUTPUT = 'yes';
if ("$DIALOG" ne q{}) {
        $main_exit_code = system('dialog', '--backtitle', "$BGTITLE", '--title', "Information collected", '--msgbox', "\n\nYour ALSA information is in $NFILE", '10', '60') >> 8;
}
    else {
        print "\n";
        do {
    my $__echo_line = "Your ALSA information is in $NFILE";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print "\n";
    }
exit $main_exit_code;
}
if ("$DIALOG" ne q{}) {
    $main_exit_code = system('dialog', '--backtitle', "$BGTITLE", '--infobox', "Uploading information to $WWWSERVICE ...", q{6}, '70') >> 8;
}
else {
    print "Uploading information to $WWWSERVICE ...";
}
if ("$PASTEBIN" eq q{}) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$TEMPDIR/wget.tmp"
      or die "Cannot open file: $OS_ERROR\n";
use LWP::Simple;
my $url = 'https://www.alsa-project.org/cardinfo-db/';
my $output_file = q{-};
my $content = get($url);
if (defined $content) {
open my $fh, '>', $output_file or die "Cannot open $output_file: $ERRNO";
print {$fh} $content;
close $fh or croak "Close failed: $ERRNO";
print "Downloaded to $output_file\n";
} else {
die "Failed to download $url\n";
}
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
else {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$TEMPDIR/wget.tmp"
      or die "Cannot open file: $OS_ERROR\n";
use LWP::Simple;
my $url = '&encrypt=t&encryptpw=blahblah';
my $output_file = q{-};
my $content = get($url);
if (defined $content) {
open my $fh, '>', $output_file or die "Cannot open $output_file: $ERRNO";
print {$fh} $content;
close $fh or croak "Close failed: $ERRNO";
print "Downloaded to $output_file\n";
} else {
die "Failed to download $url\n";
}
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
if (($? != 0)) {
        if ( -e "$FILE" ) {
        my $dest = "$NFILE";
        if ( -e $dest && -d $dest ) {
            my $source_name = "$FILE";
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
        if ( File::Copy::move( "$FILE", $dest ) ) {
        } else {
            croak
  "mv: cannot move "$FILE" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "$FILE": No such file or directory\n";
    }
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
    $KEEP_OUTPUT = 'yes';
if ("$DIALOG" ne q{}) {
        $main_exit_code = system('dialog', '--backtitle', "$BGTITLE", '--title', "Information not uploaded", '--msgbox', "An error occurred while contacting $WWWSERVICE.\n Your information was NOT automatically uploaded.\n\nYour ALSA information is in $NFILE", '10', '100') >> 8;
}
    else {
        print "\n";
        do {
    my $__echo_line = "An error occurred while contacting $WWWSERVICE.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print "Your information was NOT automatically uploaded.\n";
        print "\n";
        do {
    my $__echo_line = "Your ALSA information is in $NFILE";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print "\n";
    }
exit $main_exit_code;
}
if ("$DIALOG" ne q{}) {
    $main_exit_code = system('dialog', '--backtitle', "$BGTITLE", '--title', "Information uploaded", '--yesno', "Would you like to see the uploaded information?", q{5}, '100') >> 8;
    $DIALOG_EXIT_CODE = "${\($? >> 8)}";
if ("$DIALOG_EXIT_CODE" eq 0) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$TEMPDIR/uploaded.txt"
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_108;
my @grep_lines_108 = ();
my @grep_filtered_108 = grep { !/alsa-info.txt/msx } @grep_lines_108;
$grep_result_108 = join "\n", @grep_filtered_108;
            if (!($grep_result_108 =~ m{\n\z}msx || $grep_result_108 eq q{})) {
                $grep_result_108 .= "\n";
            }
print $grep_result_108;
$CHILD_ERROR = scalar @grep_filtered_108 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $main_exit_code = system('dialog', '--backtitle', "$BGTITLE", '--textbox', "$TEMPDIR/uploaded.txt", q{0}, q{0}) >> 8;
    }
    $main_exit_code = system('bash', 'clear') >> 8;
}
else {
    print " Done!\n";
    print "\n";
}
if ("$PASTEBIN" eq q{}) {
    my $FINAL_URL;
    my @FINAL_URL;
    my %FINAL_URL;
    $FINAL_URL = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_109 = q{};
    my $output_printed_109;
    my $output_110 = q{};
    while (my $line = <>) {
        chomp $line;
                if (!($line =~ /SUCCESS:/msx)) {
            next;
        }
        my @fields = split /\ /msx, $line;
if (@fields > 1) {
    $line = $fields[1];
}
    }
    $output_110; };
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
}
else {
    $FINAL_URL = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_111 = q{};
    my $output_printed_111;
    my $output_112 = q{};
    while (my $line = <>) {
        chomp $line;
                if (!($line =~ /SUCCESS:/msx)) {
            next;
        }
        $line =~ "s/.*\\:\\([0-9]\\+\\).*/https:\\/\\/pastebin.ca\\/\\1/p";
    }
    $output_112; };
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
}
if ((-x "$TPUT")) {
    $FINAL_URL = (do { my $_chomp_temp = do {
    my ($in_113, $out_113);
    my $pid_113 = open3($in_113, $out_113, '>&STDERR', 'tput', 'setaf', q{1});
    close $in_113 or croak 'Close failed: $OS_ERROR';
    my $result_113 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_113> };
    close $out_113 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_113, 0;
    $result_113
}; chomp $_chomp_temp; $_chomp_temp; });
}
do {
    my $__echo_line = "Your ALSA information is located at $FINAL_URL";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print "Please inform the person helping you.\n";
print "\n";

exit $main_exit_code;
