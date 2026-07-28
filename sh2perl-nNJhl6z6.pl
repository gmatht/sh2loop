#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $DPKG_ROOT;

$__set_e = 1;
if ("$1" eq remove) {
if (("$(readlink "${DPKG_ROOT}/etc/resolv.conf")" eq "../run/systemd/resolve/stub-resolv.conf" || "$(readlink "${DPKG_ROOT}/etc/resolv.conf")" eq "/run/systemd/resolve/stub-resolv.conf")) {
        say "Removing /etc/resolv.conf symlink to /run/" . "sys" . "tem" . "d/resolve/stub-resolv.conf...";
        if ( -e "${DPKG_ROOT} . "/etc/resolv.conf"" ) {
            if ( -d "${DPKG_ROOT} . "/etc/resolv.conf"" ) {
                carp "rm: carping: ", ${DPKG_ROOT} . "/etc/resolv.conf",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "${DPKG_ROOT} . "/etc/resolv.conf"" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", ${DPKG_ROOT} . "/etc/resolv.conf",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
        if ($CHILD_ERROR != 0) {
                        say "Cannot remove /etc/resolv.conf.";
        }
if ((-f "${DPKG_ROOT}/run/systemd/resolve/resolv.conf")) {
            say "Copying /run/" . "sys" . "tem" . "d/resolve/resolv.conf to /etc/resolv.conf...";
                        use File::Copy qw(copy);
            if ( -e ${DPKG_ROOT} . "/run/" . "sys" . "tem" . "d/resolve/resolv.conf" ) {
                if ( -d ${DPKG_ROOT} . "/etc/resolv.conf" ) {
                    require File::Copy; File::Copy::copy(${DPKG_ROOT} . "/run/" . "sys" . "tem" . "d/resolve/resolv.conf", ${DPKG_ROOT} . "/etc/resolv.conf" . '/' . (${DPKG_ROOT} . "/run/" . "sys" . "tem" . "d/resolve/resolv.conf" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy(${DPKG_ROOT} . "/run/" . "sys" . "tem" . "d/resolve/resolv.conf", ${DPKG_ROOT} . "/etc/resolv.conf");
                }
            } else {
                croak "cp: cannot stat '${DPKG_ROOT}/run/systemd/resolve/resolv.conf': No such file or directory\n";
            }
            if ($CHILD_ERROR != 0) {
                                say "Cannot copy /run/" . "sys" . "tem" . "d/resolve/resolv.conf to /etc/resolv.conf.";
            }
;
if ( -e "${DPKG_ROOT} . "/etc/.resolv.conf." . "sys" . "tem" . "d-resolved.bak"" ) {
                if ( -d "${DPKG_ROOT} . "/etc/.resolv.conf." . "sys" . "tem" . "d-resolved.bak"" ) {
                    carp "rm: carping: ", ${DPKG_ROOT} . "/etc/.resolv.conf." . "sys" . "tem" . "d-resolved.bak",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "${DPKG_ROOT} . "/etc/.resolv.conf." . "sys" . "tem" . "d-resolved.bak"" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", ${DPKG_ROOT} . "/etc/.resolv.conf." . "sys" . "tem" . "d-resolved.bak",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
}
        else {
            if ((-f "${DPKG_ROOT}/etc/.resolv.conf.systemd-resolved.bak")) {
                say "Restoring previous resolv.conf...";
                                my $err;
                my $force = 0;
                if ( -e "${DPKG_ROOT} . "/etc/.resolv.conf." . "sys" . "tem" . "d-resolved.bak"" ) {
                    my $dest = ${DPKG_ROOT} . "/etc/resolv.conf";
                    if ( -e $dest && -d $dest ) {
                        my $source_name = "${DPKG_ROOT} . "/etc/.resolv.conf." . "sys" . "tem" . "d-resolved.bak"";
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
                    if ( File::Copy::move( "${DPKG_ROOT} . "/etc/.resolv.conf." . "sys" . "tem" . "d-resolved.bak"", $dest ) ) {
                    } else {
                        croak
  "mv: cannot move "${DPKG_ROOT} . "/etc/.resolv.conf." . "sys" . "tem" . "d-resolved.bak"" to $dest: $ERRNO\n";
                    }
                } else {
                    croak "mv: "${DPKG_ROOT} . "/etc/.resolv.conf." . "sys" . "tem" . "d-resolved.bak"": No such file or directory\n";
                }
                if ($CHILD_ERROR != 0) {
                                        say "Cannot restore /etc/resolv.conf backup.";
                }
;
}
            else {
                say "Creating an empty /etc/resolv.conf...";
                                if ( -e "${DPKG_ROOT} . "/etc/resolv.conf"" ) {
                    my $current_time = time;
                    utime $current_time, $current_time, "${DPKG_ROOT} . "/etc/resolv.conf"";
                }
                else {
                    if ( open my $fh, '>', "${DPKG_ROOT} . "/etc/resolv.conf"" ) {
                        close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                        croak "touch: cannot create ", "${DPKG_ROOT} . "/etc/resolv.conf"",
                          ": $ERRNO\n";
                    }
                }
                if ($CHILD_ERROR != 0) {
                                        say "Cannot create an empty /etc/resolv.conf.";
                }
            }
        }
    }
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
            $main_exit_code = system('deb-systemd-helper', 'purge', "sys" . "tem" . "d-resolved.service") >> 8;
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
