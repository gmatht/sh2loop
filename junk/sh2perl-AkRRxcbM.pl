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

my $RET;
my @RET;
my %RET;
my $CONFIG;
my @CONFIG;
my %CONFIG;

my $MAGIC_750 = 750;

$__set_e = 1;
$main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;

sub rm_known {
    my ($file) = @_;
if ((-e "$1")) {
if (!(        $main_exit_code = system('egrep', '-q', "^" . (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_0 = q{};
            my $output_printed_0;
            my $pipeline_success_0 = 1;

            my ($in_1, $out_1);
            my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'md5sum', );
            close $in_1 or croak 'Close failed: $OS_ERROR';
            $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
            close $out_1 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_1, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
            my @lines_2 = split /\n/msx, $output_0;
            my @result_2;
            foreach my $line (@lines_2) {
            chomp $line;
            my @fields = split /\ /msx, $line;
            if (@fields > 0) {
                push @result_2, $fields[0];
            }
            }
            $output_0 = join "\n", @result_2;
            if ($output_0 ne q{} && !($output_0  =~ m{\n\z}msx)) { $output_0 .= "\n"; }

            if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
            $output_0 =~ s/\n+\z//msx;
            $output_0;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; }), "$_[1]") >> 8)) {
if ( -e "$_[0]" ) {
                if ( -d "$_[0]" ) {
                    croak "rm: ", "$_[0]",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$_[0]" ) {
                                            }
                    else {
                        croak "rm: cannot remove ", "$_[0]",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 1;
                croak "rm: ", "$_[0]", ": No such file or directory\n";
            }
        }
    }
    return;
}
if ((-d '/var/log/unattended-upgrades')) {
    do {
    my ($owner, $group) = split /:/, 'root:adm', 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ('/var/log/unattended-upgrades') or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
    if ($CHILD_ERROR != 0) {
        1;
    }
chmod(oct('0750'), ('/var/log/unattended-upgrades')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}

sub uu_running {
    $main_exit_code = system('python3', '-c', "import apt; import apt_pkg; import sys; sys.exit(1 if apt_pkg.get_lock(\"/var/run/unattended-upgrades.lock\") >= 0 else 0)") >> 8;
    return;
}
if ("$_[0]" =~ /^configure$/msx) {
    if ((-e '/etc/pm/sleep.d/10_unatteded-upgrades-hibernate')) {
if ( -e "/etc/pm/sleep.d/10_unatteded-upgrades-hibernate" ) {
            if ( -d "/etc/pm/sleep.d/10_unatteded-upgrades-hibernate" ) {
                carp "rm: carping: ", "/etc/pm/sleep.d/10_unatteded-upgrades-hibernate",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "/etc/pm/sleep.d/10_unatteded-upgrades-hibernate" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/etc/pm/sleep.d/10_unatteded-upgrades-hibernate",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
            $main_exit_code = system('db_get', 'unattended-upgrades/enable_auto_updates') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
        $CONFIG = "/etc/apt/apt.conf.d/20auto-upgrades";
    if ("${RET}" eq "true") {
        my $NEWFILE;
        my @NEWFILE;
        my %NEWFILE;
        $NEWFILE = "/usr/share/unattended-upgrades/20auto-upgrades";
        $main_exit_code = system('ucf', '--three-way', '--debconf-ok', "$NEWFILE", "$CONFIG") >> 8;
        $main_exit_code = system('ucfr', 'unattended-upgrades', "$CONFIG") >> 8;
}
    else {
        if (("${RET}" eq "false" && (-e "$CONFIG"))) {
            $NEWFILE = "/usr/share/unattended-upgrades/20auto-upgrades-disabled";
            $main_exit_code = system('ucf', '--three-way', '--debconf-ok', "$NEWFILE", "$CONFIG") >> 8;
            $main_exit_code = system('ucfr', 'unattended-upgrades', "$CONFIG") >> 8;
        }
    }
        $CONFIG = "/etc/apt/apt.conf.d/50unattended-upgrades";
        $NEWFILE = "/usr/share/unattended-upgrades/50unattended-upgrades";
        $main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', $CONFIG, '0.86.4', q{~}, '--', "@ARGV") >> 8;
    if ((!(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', "1.8~") >> 8) && (-e $CONFIG.ucftmp))) {
        $main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', $CONFIG, '--', "@ARGV") >> 8;
        my $err;
        my $force = 0;
        if ( -e "$CONFIG" ) {
            my $dest = $CONFIG;
            if ( -e $dest && -d $dest ) {
                my $source_name = "$CONFIG";
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
            if ( File::Copy::move( "$CONFIG", $dest ) ) {
            } else {
                croak
  "mv: cannot move "$CONFIG" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "$CONFIG": No such file or directory\n";
        }
        if ( -e '.ucftmp' ) {
            my $dest = $CONFIG;
            if ( -e $dest && -d $dest ) {
                my $source_name = '.ucftmp';
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
            if ( File::Copy::move( '.ucftmp', $dest ) ) {
            } else {
                croak
  "mv: cannot move '.ucftmp' to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: '.ucftmp': No such file or directory\n";
        }
        rm_known("$CONFIG.dpkg-bak", "$NEWFILE.md5sum");
        rm_known("$CONFIG.ucf-old", "$NEWFILE.md5sum");
    }
        $main_exit_code = system('ucf', '--three-way', '--debconf-ok', "$NEWFILE", "$CONFIG") >> 8;
        $main_exit_code = system('ucfr', 'unattended-upgrades', "$CONFIG") >> 8;
    if ((!(    do {
        local %ENV = %ENV;
        my $NEWFILE = $NEWFILE;
        my $err = $err;
        my $force = $force;
        if ("$(lsb_release -i -s)" ne "Ubuntu") {
                        do {
                local %ENV = %ENV;
                my $NEWFILE = $NEWFILE;
                my $err = $err;
                my $force = $force;
                                $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', "0.93.1+nmu1") >> 8;
                if ($CHILD_ERROR != 0) {
                                        do {
                        local %ENV = %ENV;
                        my $NEWFILE = $NEWFILE;
                        my $err = $err;
                        my $force = $force;
                        if (do {
$main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'ge', "1.5~") >> 8;
                            $CHILD_ERROR == 0
                        }) {
                                                        $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', "1.7~") >> 8;
                        }
                        q{};
                    };
                }
                q{};
            };
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        q{};
    }) || !(    do {
        local %ENV = %ENV;
        my $NEWFILE = $NEWFILE;
        my $err = $err;
        my $force = $force;
        if ("$(lsb_release -i -s)" eq "Ubuntu") {
                        do {
                local %ENV = %ENV;
                my $NEWFILE = $NEWFILE;
                my $err = $err;
                my $force = $force;
                                                $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', "0.93.1ubuntu3") >> 8;
                if ($CHILD_ERROR != 0) {
                                        do {
                        local %ENV = %ENV;
                        my $NEWFILE = $NEWFILE;
                        my $err = $err;
                        my $force = $force;
                        if (do {
$main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'ge', "1.5ubuntu1~") >> 8;
                            $CHILD_ERROR == 0
                        }) {
                                                        $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', "1.5ubuntu4~") >> 8;
                        }
                        q{};
                    };
                }
                if ($CHILD_ERROR != 0) {
                                        do {
                        local %ENV = %ENV;
                        my $NEWFILE = $NEWFILE;
                        my $err = $err;
                        my $force = $force;
                        if (do {
$main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'ge', "1.7~") >> 8;
                            $CHILD_ERROR == 0
                        }) {
                                                        $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', "1.7ubuntu1~") >> 8;
                        }
                        q{};
                    };
                }
                q{};
            };
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        q{};
    }))) {
if (((-f '/etc/rc0.d/K[0-9][0-9]unattended-upgrades') && (-f '/etc/rc6.d/K[0-9][0-9]unattended-upgrades'))) {
            $main_exit_code = system('update-rc.d', '-f', 'unattended-upgrades', 'remove') >> 8;
        }
if ((-d '/run/systemd/system')) {
if ((!(            $main_exit_code = system('deb-systemd-helper', '--quiet', 'was-enabled', 'unattended-upgrades.service') >> 8) || !(            do {
                local %ENV = %ENV;
                my $NEWFILE = $NEWFILE;
                my $err = $err;
                my $force = $force;
                if (do {
$main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'ge', "1.7~") >> 8;
                    $CHILD_ERROR == 0
                }) {
                                        $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', "1.7ubuntu1~") >> 8;
                }
                q{};
            }))) {
                                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
                    $main_exit_code = system('deb-systemd-helper', 'disable', 'unattended-upgrades.service') >> 8;
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
    }
} elsif ("$_[0]" =~ /^abort-upgrade$/msx or "$_[0]" =~ /^abort-remove$/msx or "$_[0]" =~ /^abort-deconfigure$/msx) {
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "postinst called with unknown argument \\" . chr(96) . "$_[0]'";
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
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('deb-systemd-helper', 'unmask', 'unattended-upgrades.service') >> 8;
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
if (!(    $main_exit_code = system('deb-systemd-helper', '--quiet', 'was-enabled', 'unattended-upgrades.service') >> 8)) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'enable', 'unattended-upgrades.service') >> 8;
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
    else {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'update-state', 'unattended-upgrades.service') >> 8;
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
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
if ((-x "/etc/init.d/unattended-upgrades")) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('update-rc.d', 'unattended-upgrades', 'defaults') >> 8;
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
    }
}
if ("$_[0]" =~ /^configure$/msx) {
    if ((!(    do {
        local %ENV = %ENV;
        my $NEWFILE = $NEWFILE;
        my $err = $err;
        my $force = $force;
                do {
            local %ENV = %ENV;
            my $NEWFILE = $NEWFILE;
            my $err = $err;
            my $force = $force;
            if ("$(lsb_release -i -s)" ne "Ubuntu") {
                                do {
                    local %ENV = %ENV;
                    my $NEWFILE = $NEWFILE;
                    my $err = $err;
                    my $force = $force;
                                        $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', "0.93.1+nmu1") >> 8;
                    if ($CHILD_ERROR != 0) {
                                                do {
                            local %ENV = %ENV;
                            my $NEWFILE = $NEWFILE;
                            my $err = $err;
                            my $force = $force;
                            if (do {
$main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'ge', "1.5~") >> 8;
                                $CHILD_ERROR == 0
                            }) {
                                                                $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', "1.7~") >> 8;
                            }
                            q{};
                        };
                    }
                    q{};
                };
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            q{};
        };
        if ($CHILD_ERROR != 0) {
                        do {
                local %ENV = %ENV;
                my $NEWFILE = $NEWFILE;
                my $err = $err;
                my $force = $force;
                if ("$(lsb_release -i -s)" eq "Ubuntu") {
                                        do {
                        local %ENV = %ENV;
                        my $NEWFILE = $NEWFILE;
                        my $err = $err;
                        my $force = $force;
                                                                        $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', "0.93.1ubuntu3") >> 8;
                        if ($CHILD_ERROR != 0) {
                                                        do {
                                local %ENV = %ENV;
                                my $NEWFILE = $NEWFILE;
                                my $err = $err;
                                my $force = $force;
                                if (do {
$main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'ge', "1.5ubuntu1~") >> 8;
                                    $CHILD_ERROR == 0
                                }) {
                                                                        $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', "1.5ubuntu4~") >> 8;
                                }
                                q{};
                            };
                        }
                        if ($CHILD_ERROR != 0) {
                                                        do {
                                local %ENV = %ENV;
                                my $NEWFILE = $NEWFILE;
                                my $err = $err;
                                my $force = $force;
                                if (do {
$main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'ge', "1.7~") >> 8;
                                    $CHILD_ERROR == 0
                                }) {
                                                                        $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', "1.7ubuntu1~") >> 8;
                                }
                                q{};
                            };
                        }
                        q{};
                    };
                    $CHILD_ERROR = 0;
                } else {
                    $CHILD_ERROR = 1;
                }
                q{};
            };
        }
        q{};
    }) && (-d '/run/systemd/system'))) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            $main_exit_code = system('systemctl', 'enable', 'unattended-upgrades') >> 8;
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
if (!(        uu_running())) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "Skipping starting unattended-upgrades.service because unattended-upgrades is running\n";
            };
}
        else {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                $main_exit_code = system('deb-systemd-invoke', 'start', 'unattended-upgrades.service') >> 8;
            };
            if ($CHILD_ERROR != 0) {
                1;
            }
        }
    }
}
exit 0;

exit $main_exit_code;
