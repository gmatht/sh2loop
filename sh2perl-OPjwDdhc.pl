#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

$__set_e = 1;

sub remove_logfile {
    my $logdir = "$ENV{DPKG_ROOT}/var/log";
    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
if ( -e "$logdir" ) {
            if ( -d "$logdir" ) {
                carp "rm: carping: ", "$logdir",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$logdir" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$logdir",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "/dpkg.log" ) {
            if ( -d "/dpkg.log" ) {
                carp "rm: carping: ", "/dpkg.log",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "/dpkg.log" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/dpkg.log",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "$logdir" ) {
            if ( -d "$logdir" ) {
                carp "rm: carping: ", "$logdir",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$logdir" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$logdir",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
my @files_to_remove = glob("/dpkg.log.*");
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
    };
    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
if ( -e "$logdir" ) {
            if ( -d "$logdir" ) {
                carp "rm: carping: ", "$logdir",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$logdir" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$logdir",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "/alternatives.log" ) {
            if ( -d "/alternatives.log" ) {
                carp "rm: carping: ", "/alternatives.log",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "/alternatives.log" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/alternatives.log",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "$logdir" ) {
            if ( -d "$logdir" ) {
                carp "rm: carping: ", "$logdir",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$logdir" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$logdir",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
my @files_to_remove = glob("/alternatives.log.*");
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
    };
    return;
}

sub remove_aliases {
    my $prog = "start-stop-daemon";
if ((-l "$DPKG_ROOT/sbin/$prog")) {
if ( -e "$ENV{DPKG_ROOT}/sbin/$prog" ) {
            if ( -d "$ENV{DPKG_ROOT}/sbin/$prog" ) {
                croak "rm: ", "$ENV{DPKG_ROOT}/sbin/$prog",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$ENV{DPKG_ROOT}/sbin/$prog" ) {
                                    }
                else {
                    croak "rm: cannot remove ", "$ENV{DPKG_ROOT}/sbin/$prog",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 1;
            croak "rm: ", "$ENV{DPKG_ROOT}/sbin/$prog", ": No such file or directory\n";
        }
    }
    return;
}

sub fixup_systemd_timer {
if ((-d '/run/systemd/system')) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-invoke', 'restart', 'dpkg-db-backup.timer') >> 8;
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
;
    }
    return;
}
if ("$_[0]" =~ /^remove$/msx) {
        remove_aliases();
} elsif ("$_[0]" =~ /^purge$/msx) {
        remove_logfile();
} elsif ("$_[0]" =~ /^upgrade$/msx) {
    if ((!(system('dpkg', '--compare-versions', "$_[1]", 'gt', '1.22.0', q{~}) >> 8) && !(system('dpkg', '--compare-versions', "$_[1]", 'le', '1.22.1') >> 8))) {
        fixup_systemd_timer();
    }
} elsif ("$_[0]" =~ /^failed-upgrade$/msx or "$_[0]" =~ /^disappear$/msx or "$_[0]" =~ /^abort-install$/msx or "$_[0]" =~ /^abort-upgrade$/msx) {
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        say "$PROGRAM_NAME called with unknown argument '$_[0]'";
    };
    exit 1;
}
if (("$1" eq remove && (-d '/run/systemd/system'))) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
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
;
}
if ("$1" eq "purge") {
if ((-x "/usr/bin/deb-systemd-helper")) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'purge', 'dpkg-db-backup.timer') >> 8;
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
;
    }
}
exit 0;
