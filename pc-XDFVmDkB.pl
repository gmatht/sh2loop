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

my $DPKG_ROOT;
my @DPKG_ROOT;
my %DPKG_ROOT;

$__set_e = 1;
if (("$1" eq "remove" && (-x "/etc/init.d/nfs-common"))) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
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
    if ($CHILD_ERROR != 0) {
        1;
    }
}
if (("${DPKG_ROOT:-}" eq q{} && "$1" eq "purge")) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('update-rc.d', 'nfs-common', 'remove') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
if (("$1" eq remove && (-d '/run/systemd/system'))) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', "--" . "sys" . "tem", 'daemon-reload') >> 8;
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
}
if ("$1" eq "purge") {
if ((-x "/usr/bin/deb-systemd-helper")) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'purge', 'nfs-client.target') >> 8;
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
    }
}
if ("$_[0]" =~ /^purge$/msx) {
        my $FILE;
    for my $FILE ('/etc/default/nfs-common', '/etc/idmapd.conf', '/etc/nfs.conf') {
        my $ext;
        for my $ext (q{~}, q{%}, '.bak', '.dpkg-tmp', '.dpkg-new', '.dpkg-old', '.dpkg-dist') {
if ( -e "$FILE" ) {
                if ( -d "$FILE" ) {
                    carp "rm: carping: ", $FILE,
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$FILE" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", $FILE,
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
if ( -e "$ext" ) {
                if ( -d "$ext" ) {
                    carp "rm: carping: ", $ext,
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$ext" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", $ext,
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
if ( -e "$FILE" ) {
            if ( -d "$FILE" ) {
                carp "rm: carping: ", $FILE,
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$FILE" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", $FILE,
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ((-x '/usr/bin/ucf')) {
            $main_exit_code = system('ucf', '--purge', $FILE) >> 8;
        }
    }
    if ( -e "/etc/nfs.conf.d/local.conf" ) {
        if ( -d "/etc/nfs.conf.d/local.conf" ) {
            carp "rm: carping: ", "/etc/nfs.conf.d/local.conf",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/nfs.conf.d/local.conf" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/nfs.conf.d/local.conf",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if ( -e "/var/lib/nfs/state" ) {
        if ( -d "/var/lib/nfs/state" ) {
            carp "rm: carping: ", "/var/lib/nfs/state",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/var/lib/nfs/state" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/lib/nfs/state",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
my @files_to_remove = glob("/var/lib/nfs/sm/*");
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
my @files_to_remove = glob("/var/lib/nfs/sm.bak/*");
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
            $main_exit_code = system('dpkg-statoverride', '--remove', '/sbin/mount.nfs') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
}

exit $main_exit_code;
