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

my $EUID;
my @EUID;
my %EUID;

my $MAGIC_3   = 3;
my $MAGIC_644 = 644;

$__set_e = 1;
my $RED;
my @RED;
my %RED;
$RED = "\\033[0;31m";
my $GREEN;
my @GREEN;
my %GREEN;
$GREEN = "\\033[0;32m";
my $YELLOW;
my @YELLOW;
my %YELLOW;
$YELLOW = "\\033[1;33m";
my $NC;
my @NC;
my %NC;
$NC = "\\033[0m";

sub print_status {
    my ($file) = @_;
    do {
    my $__echo_line = "${GREEN}[INFO]${NC} $1";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}

sub print_warning {
    my ($file) = @_;
    do {
    my $__echo_line = "${YELLOW}[WARNING]${NC} $1";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}

sub print_error {
    my ($file) = @_;
    do {
    my $__echo_line = "${RED}[ERROR]${NC} $1";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}
if (($EUID != 0)) {
    print_error("This script must be run as root (use sudo)");
exit 1;
}
if (!(!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('command', '-v', 'btrfs') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};))) {
    print_warning("BTRFS tools not found. Attempting to install...");
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'apt-get') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        if (do {
$main_exit_code = system('apt-get', 'update') >> 8;
            $CHILD_ERROR == 0
        }) {
                        $main_exit_code = system('apt-get', 'install', '-y', 'btrfs-progs') >> 8;
        }
}
    else {
        if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('command', '-v', 'yum') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $main_exit_code = system('yum', 'install', '-y', 'btrfs-progs') >> 8;
}
        else {
            if (!(            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('command', '-v', 'dnf') >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            })) {
                $main_exit_code = system('dnf', 'install', '-y', 'btrfs-progs') >> 8;
}
            else {
                if (!(                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
                    $main_exit_code = system('command', '-v', 'pacman') >> 8;
                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                })) {
                    $main_exit_code = system('pacman', '-S', 'btrfs-progs') >> 8;
}
                else {
                    print_error("Could not install BTRFS tools automatically. Please install btrfs-progs manually.");
exit 1;
                }
            }
        }
    }
}
if (!(!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('command', '-v', 'python3') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};))) {
    print_error("Python 3 is required but not installed.");
exit 1;
}
my $SCRIPT_DIR;
my @SCRIPT_DIR;
my %SCRIPT_DIR;
$SCRIPT_DIR = (do { my $_chomp_temp = do {
    my $left_result_0 = do { chdir((do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname($BASH_SOURCE[0]); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; })); q{} };
;
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_0 = do { use Cwd; getcwd(); };
        $left_result_0 . $right_result_0;
    } else {
        q{};
    }
}; chomp $_chomp_temp; $_chomp_temp; });
my $INSTALL_DIR;
my @INSTALL_DIR;
my %INSTALL_DIR;
$INSTALL_DIR = "/usr/local/bin";
my $CONFIG_DIR;
my @CONFIG_DIR;
my %CONFIG_DIR;
$CONFIG_DIR = "/etc";
my $SERVICE_DIR;
my @SERVICE_DIR;
my %SERVICE_DIR;
$SERVICE_DIR = "/etc/" . "sys" . "tem" . "d/" . "sys" . "tem";
print_status("Installing BTRFS Snapshot Monitor...");
print_status("Copying main script to $INSTALL_DIR...");
use File::Copy qw(copy);
if ( -e "$SCRIPT_DIR/btrfs_snapshot_monitor.py" ) {
    if ( -d "$INSTALL_DIR/" ) {
        require File::Copy; File::Copy::copy("$SCRIPT_DIR/btrfs_snapshot_monitor.py", "$INSTALL_DIR/" . '/' . ("$SCRIPT_DIR/btrfs_snapshot_monitor.py" =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy("$SCRIPT_DIR/btrfs_snapshot_monitor.py", "$INSTALL_DIR/");
    }
} else {
    croak "cp: cannot stat '$SCRIPT_DIR/btrfs_snapshot_monitor.py': No such file or directory\n";
}
chmod(oct('+x'), ("$INSTALL_DIR/btrfs_snapshot_monitor.py")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
print_status("Copying configuration file to $CONFIG_DIR...");
use File::Copy qw(copy);
if ( -e "$SCRIPT_DIR/btrfs_snapshot_monitor.conf" ) {
    if ( -d "$CONFIG_DIR/" ) {
        require File::Copy; File::Copy::copy("$SCRIPT_DIR/btrfs_snapshot_monitor.conf", "$CONFIG_DIR/" . '/' . ("$SCRIPT_DIR/btrfs_snapshot_monitor.conf" =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy("$SCRIPT_DIR/btrfs_snapshot_monitor.conf", "$CONFIG_DIR/");
    }
} else {
    croak "cp: cannot stat '$SCRIPT_DIR/btrfs_snapshot_monitor.conf': No such file or directory\n";
}
print_status("Copying " . "sys" . "tem" . "d service file to $SERVICE_DIR...");
use File::Copy qw(copy);
if ( -e "$SCRIPT_DIR/btrfs-snapshot-monitor.service" ) {
    if ( -d "$SERVICE_DIR/" ) {
        require File::Copy; File::Copy::copy("$SCRIPT_DIR/btrfs-snapshot-monitor.service", "$SERVICE_DIR/" . '/' . ("$SCRIPT_DIR/btrfs-snapshot-monitor.service" =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy("$SCRIPT_DIR/btrfs-snapshot-monitor.service", "$SERVICE_DIR/");
    }
} else {
    croak "cp: cannot stat '$SCRIPT_DIR/btrfs-snapshot-monitor.service': No such file or directory\n";
}
my @sed_lines_5 = split /\n/msx, $;
my @sed_result_5;
foreach my $line (@sed_lines_5) {
chomp $line;
push @sed_result_5, $line;
}
$ = join "\n", @sed_result_5;

print_status("Creating log directory...");
use File::Path qw(make_path);
my $err;
if ( !-d '/var/log' ) {
    make_path( '/var/log', { error => \$err } );
    if ( @{$err} ) {
        croak "mkdir: cannot create directory " . '/var/log' . ": $err->[0]\n";
    }
}
print_status("Setting permissions...");
chmod(oct('644'), ("$CONFIG_DIR/btrfs_snapshot_monitor.conf")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
chmod(oct('644'), ("$SERVICE_DIR/btrfs-snapshot-monitor.service")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
print_status("Reloading " . "sys" . "tem" . "d daemon...");
$main_exit_code = system('systemctl', 'daemon-reload') >> 8;
print_status("Testing the script...");
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('python3', "$INSTALL_DIR/btrfs_snapshot_monitor.py", '--help') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
    print_status("Script test successful!");
}
else {
    print_warning("Script test failed, but continuing installation...");
}
print_status("Installation completed successfully!");
print "\n";
$CHILD_ERROR = 0;
print_status("Next steps:");
do {
    my $__echo_line = "1. Edit the configuration file: sudo nano $CONFIG_DIR/btrfs_snapshot_monitor.conf";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print "2. Enable and start the service:\n";
print "   sudo " . "sys" . "tem" . "ctl enable btrfs-snapshot-monitor.service\n";
print "   sudo " . "sys" . "tem" . "ctl start btrfs-snapshot-monitor.service\n";
print "3. Check service status: sudo " . "sys" . "tem" . "ctl status btrfs-snapshot-monitor.service\n";
print "4. View logs: sudo journalctl -u btrfs-snapshot-monitor.service -f\n";
print "\n";
$CHILD_ERROR = 0;
print_status("For manual testing, run:");
do {
    my $__echo_line = "sudo python3 $INSTALL_DIR/btrfs_snapshot_monitor.py --dry-run";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;

exit $main_exit_code;
