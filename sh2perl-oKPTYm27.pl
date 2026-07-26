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

my $f;
my @f;
my %f;

$__set_e = 1;
if ("$1" eq "purge") {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('deluser', '--quiet', "--" . "sys" . "tem", 'avahi-autoipd') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('delgroup', '--quiet', "--" . "sys" . "tem", 'avahi-autoipd') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
    $f = '/var/lib/avahi-autoipd';
if ((-d "$f")) {
if ( -e "$f" ) {
            if ( -d "$f" ) {
                carp "rm: carping: ", "$f",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$f" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$f",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
my @files_to_remove = glob("/??\:??\:??\:??\:??\:??");
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
        rmdir ("$f") or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) {
                            if (do {
do {
    my ($owner, $group) = split /:/, 'root:root', 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ("$f") or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
                    $CHILD_ERROR == 0
                }) {
                    chmod(oct('00700'), ("$f")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
                }
        }
    }
}

exit $main_exit_code;
