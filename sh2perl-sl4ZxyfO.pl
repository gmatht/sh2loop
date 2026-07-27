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

my $CONFIG_FILE;
my @CONFIG_FILE;
my %CONFIG_FILE;

my $MAGIC_4096 = 4_096;
my $MAGIC_30   = 30;
my $MAGIC_600  = 600;

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
$CONFIG_FILE = "/etc/reverse_tunnel_daemon.conf";
if ((-f "$CONFIG_FILE")) {
# Builtin command 'source' not implemented
}
else {
    print_warning("Configuration file not found, using defaults");
}
my $REMOTE_HOST;
my @REMOTE_HOST;
my %REMOTE_HOST;
$REMOTE_HOST = (defined ${REMOTE_HOST} && ${REMOTE_HOST} ne q{} ? ${REMOTE_HOST} : '"dansted.org"');
my $REMOTE_USER;
my @REMOTE_USER;
my %REMOTE_USER;
$REMOTE_USER = (defined ${REMOTE_USER} && ${REMOTE_USER} ne q{} ? ${REMOTE_USER} : '"tunnel"');
my $REMOTE_PORT;
my @REMOTE_PORT;
my %REMOTE_PORT;
$REMOTE_PORT = (defined ${REMOTE_PORT} && ${REMOTE_PORT} ne q{} ? ${REMOTE_PORT} : '"22"');
my $LOCAL_PORT;
my @LOCAL_PORT;
my %LOCAL_PORT;
$LOCAL_PORT = (defined ${LOCAL_PORT} && ${LOCAL_PORT} ne q{} ? ${LOCAL_PORT} : '"22"');
my $REMOTE_BIND_PORT;
my @REMOTE_BIND_PORT;
my %REMOTE_BIND_PORT;
$REMOTE_BIND_PORT = (defined ${REMOTE_BIND_PORT} && ${REMOTE_BIND_PORT} ne q{} ? ${REMOTE_BIND_PORT} : '"2222"');
my $SSH_KEY_FILE;
my @SSH_KEY_FILE;
my %SSH_KEY_FILE;
$SSH_KEY_FILE = (defined ${SSH_KEY_FILE} && ${SSH_KEY_FILE} ne q{} ? ${SSH_KEY_FILE} : '"~/.ssh/id_rsa"');
my $LOG_FILE;
my @LOG_FILE;
my %LOG_FILE;
$LOG_FILE = (defined ${LOG_FILE} && ${LOG_FILE} ne q{} ? ${LOG_FILE} : '"/var/log/reverse_tunnel_daemon.log"');
my $AUTOSSH_PORT;
my @AUTOSSH_PORT;
my %AUTOSSH_PORT;
$AUTOSSH_PORT = (defined ${AUTOSSH_PORT} && ${AUTOSSH_PORT} ne q{} ? ${AUTOSSH_PORT} : '"0"');
my $AUTOSSH_GATETIME;
my @AUTOSSH_GATETIME;
my %AUTOSSH_GATETIME;
$AUTOSSH_GATETIME = (defined ${AUTOSSH_GATETIME} && ${AUTOSSH_GATETIME} ne q{} ? ${AUTOSSH_GATETIME} : '"30"');
my $AUTOSSH_POLL;
my @AUTOSSH_POLL;
my %AUTOSSH_POLL;
$AUTOSSH_POLL = (defined ${AUTOSSH_POLL} && ${AUTOSSH_POLL} ne q{} ? ${AUTOSSH_POLL} : '"600"');

sub setup_logging {
    use File::Path qw(make_path);
    my $err;
    if ( !-d (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname("$LOG_FILE"); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) ) {
        make_path( (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname("$LOG_FILE"); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }), { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname("$LOG_FILE"); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) . ": $err->[0]\n";
        }
    }
# Redirect ProcessSubstitutionOutput not yet implemented
# Builtin command 'exec' not implemented
# Redirect ProcessSubstitutionOutput not yet implemented
# Builtin command 'exec' not implemented
    return;
}

sub check_dependencies {
if (!(!(do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'autossh') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };))) {
        print_error("autossh is not installed. Please install it first.");
        print_status("On Ubuntu/Debian: sudo apt-get install autossh");
        print_status("On CentOS/RHEL: sudo yum install autossh");
        print_status("On Arch: sudo pacman -S autossh");
exit 1;
    }
if (!(!(do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'ssh') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };))) {
        print_error("ssh is not installed. Please install openssh-client.");
exit 1;
    }
    return;
}

sub check_ssh_key {
    my $key_file = (($ENV{SSH_KEY_FILE/} // q{}) =~ s/^\~/\$HOME//r =~ s/^\~/\$HOME//r);
if ((!-f "$key_file")) {
        print_error("SSH key file not found: $key_file");
        print_status("Please generate an SSH key pair:");
        print_status("ssh-keygen -t rsa -b 4096 -f $key_file");
exit 1;
    }
    my $key_perms = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'stat', '-c', '%a', "$key_file");
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
};
if ("$key_perms" ne "600") {
        print_warning("SSH key has incorrect permissions ($key_perms), fixing...");
chmod(oct('600'), ("$key_file")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
    return;
}

sub test_ssh_connection {
    print_status("Testing SSH connection to $REMOTE_USER@$REMOTE_HOST...");
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('ssh', '-o', 'ConnectTimeout', q{=}, '10', '-o', 'BatchMode', q{=}, 'yes', '-i', "$SSH_KEY_FILE", "$REMOTE_USER@$REMOTE_HOST", "echo 'SSH connection test successful'") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        print_status("SSH connection test successful");
return q{0};
}
    else {
        print_error("SSH connection test failed");
        print_status("Please ensure:");
        print_status("1. SSH key is added to $REMOTE_USER@$REMOTE_HOST");
        print_status("2. SSH key permissions are correct (600)");
        print_status("3. Network connectivity to $REMOTE_HOST:$REMOTE_PORT");
return q{1};
    }
    return;
}

sub start_tunnel {
    print_status("Starting reverse tunnel...");
    print_status("Local port $LOCAL_PORT -> $REMOTE_HOST:$REMOTE_BIND_PORT");
    my @autossh_cmd = ('autossh', '-M', '$AUTOSSH_PORT', '-f', '-N', '-T', '-R', '$REMOTE_BIND_PORT:localhost:$LOCAL_PORT', '-i', '$SSH_KEY_FILE', '-o', 'ServerAliveInterval=60', '-o', 'ServerAliveCountMax=3', '-o', 'ExitOnForwardFailure=yes', '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null', '$REMOTE_USER@$REMOTE_HOST', '-p', '$REMOTE_PORT');
    print_status("Running: " . $autossh_cmd[eval { int(*) } // ""]);
if (!(    $CHILD_ERROR = 0)) {
        print_status("Reverse tunnel started successfully");
return q{0};
}
    else {
        print_error("Failed to start reverse tunnel");
return q{1};
    }
    return;
}

sub check_tunnel_status {
    my $tunnel_pid = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'pgrep', '-f', "autossh.*$REMOTE_HOST");
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
};
if ("$tunnel_pid" ne q{}) {
        print_status("Tunnel is running (PID: $tunnel_pid)");
return q{0};
}
    else {
        print_warning("Tunnel is not running");
return q{1};
    }
    return;
}

sub stop_tunnel {
    my $tunnel_pid = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'pgrep', '-f', "autossh.*$REMOTE_HOST");
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
};
if ("$tunnel_pid" ne q{}) {
        print_status("Stopping tunnel (PID: $tunnel_pid)...");
my $signal = 'TERM';
my @pids = ("$tunnel_pid");
foreach my $pid (@pids) {
if ($pid =~ /^\\d+$/msx) {
my $result = kill $signal, $pid;
if ($result) {
print "Sent signal $signal to process $pid\n";
} else {
print {*STDERR} "kill: ($pid) - No such process\n";
}
} else {
print {*STDERR} "kill: invalid process id: $pid\n";
}
}
require Time::HiRes; Time::HiRes::sleep(q{2});
if (!(        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $signal = '0';
my @pids = ("$tunnel_pid");
foreach my $pid (@pids) {
if ($pid =~ /^\\d+$/msx) {
my $result = kill $signal, $pid;
if ($result) {
print "Sent signal $signal to process $pid\n";
} else {
print {*STDERR} "kill: ($pid) - No such process\n";
}
} else {
print {*STDERR} "kill: invalid process id: $pid\n";
}
}
        })) {
            print_warning("Force killing tunnel...");
my $signal = '9';
my @pids = ("$tunnel_pid");
foreach my $pid (@pids) {
if ($pid =~ /^\\d+$/msx) {
my $result = kill $signal, $pid;
if ($result) {
print "Sent signal $signal to process $pid\n";
} else {
print {*STDERR} "kill: ($pid) - No such process\n";
}
} else {
print {*STDERR} "kill: invalid process id: $pid\n";
}
}
        }
        print_status("Tunnel stopped");
}
    else {
        print_status("No tunnel process found");
    }
    return;
}

sub restart_tunnel {
    print_status("Restarting tunnel...");
    stop_tunnel();
require Time::HiRes; Time::HiRes::sleep(q{2});
    start_tunnel();
    return;
}

sub daemon_loop {
    print_status("Starting reverse tunnel daemon...");
while ( 1 ) {
if (!(!(check_tunnel_status();))) {
            print_warning("Tunnel is down, attempting to restart...");
if (!(            start_tunnel())) {
                print_status("Tunnel restarted successfully");
}
            else {
                print_error("Failed to restart tunnel");
            }
        }
require Time::HiRes; Time::HiRes::sleep('30');
    }
    return;
}

sub main {
    my ($file) = @_;
    setup_logging();
    print_status("Reverse Tunnel Daemon starting...");
    print_status("Configuration:");
    print_status("  Remote Host: $REMOTE_HOST");
    print_status("  Remote User: $REMOTE_USER");
    print_status("  Remote Port: $REMOTE_PORT");
    print_status("  Local Port: $LOCAL_PORT");
    print_status("  Remote Bind Port: $REMOTE_BIND_PORT");
    print_status("  SSH Key: $SSH_KEY_FILE");
    print_status("  Log File: $LOG_FILE");
    check_dependencies();
    check_ssh_key();
if ((defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '') : '') =~ /^start$/msx) {
        if (!(        test_ssh_connection())) {
            start_tunnel();
}
        else {
exit 1;
        }
    } elsif ((defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '') : '') =~ /^stop$/msx) {
                stop_tunnel();
    } elsif ((defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '') : '') =~ /^restart$/msx) {
                restart_tunnel();
    } elsif ((defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '') : '') =~ /^status$/msx) {
                check_tunnel_status();
    } elsif ((defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '') : '') =~ /^test$/msx) {
                test_ssh_connection();
    } elsif ((defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '') : '') =~ /^daemon$/msx) {
                daemon_loop();
    } elsif (1) {
                print_status("Usage: $PROGRAM_NAME {start|stop|restart|status|test|daemon}");
                print_status("");
                print_status("Commands:");
                print_status("  start   - Start the reverse tunnel");
                print_status("  stop    - Stop the reverse tunnel");
                print_status("  restart - Restart the reverse tunnel");
                print_status("  status  - Check tunnel status");
                print_status("  test    - Test SSH connection");
                print_status("  daemon  - Run as daemon with auto-restart");
        exit 1;
    }
    return;
}
main("@ARGV");

exit $main_exit_code;
