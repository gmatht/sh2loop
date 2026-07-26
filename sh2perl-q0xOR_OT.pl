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

my $FIX_UNMANAGED;
my @FIX_UNMANAGED;
my %FIX_UNMANAGED;
my $NO_DNSMASQ;
my @NO_DNSMASQ;
my %NO_DNSMASQ;
my $SHARE_METHOD;
my @SHARE_METHOD;
my %SHARE_METHOD;
my $INTERNET_IFACE;
my @INTERNET_IFACE;
my %INTERNET_IFACE;
my $CHANNEL;
my @CHANNEL;
my %CHANNEL;
my $ARGS;
my @ARGS;
my %ARGS;
my $MAC_FILTER;
my @MAC_FILTER;
my %MAC_FILTER;
my $DHCP_DNS;
my @DHCP_DNS;
my %DHCP_DNS;
my $LIST_RUNNING;
my @LIST_RUNNING;
my %LIST_RUNNING;
my $NO_HAVEGED;
my @NO_HAVEGED;
my %NO_HAVEGED;
my $WIFI_IFACE;
my @WIFI_IFACE;
my %WIFI_IFACE;
my $OLD_MACADDR;
my @OLD_MACADDR;
my %OLD_MACADDR;
my $STORE_CONFIG;
my @STORE_CONFIG;
my %STORE_CONFIG;
my $PASSPHRASE;
my @PASSPHRASE;
my %PASSPHRASE;
my $IEEE80211N;
my @IEEE80211N;
my %IEEE80211N;
my $LIST_CLIENTS_ID;
my @LIST_CLIENTS_ID;
my %LIST_CLIENTS_ID;
my $DAEMONIZE;
my @DAEMONIZE;
my %DAEMONIZE;
my $MTU;
my @MTU;
my %MTU;
my $ISOLATE_CLIENTS;
my @ISOLATE_CLIENTS;
my %ISOLATE_CLIENTS;
my $DAEMON_PIDFILE;
my @DAEMON_PIDFILE;
my %DAEMON_PIDFILE;
my $NO_VIRT;
my @NO_VIRT;
my %NO_VIRT;
my $x;
my @x;
my %x;
my $WIFI_IFACE_CHANNEL;
my @WIFI_IFACE_CHANNEL;
my %WIFI_IFACE_CHANNEL;
my $LOAD_CONFIG;
my @LOAD_CONFIG;
my %LOAD_CONFIG;
my $FREQ_BAND;
my @FREQ_BAND;
my %FREQ_BAND;
my $USE_PSK;
my @USE_PSK;
my %USE_PSK;
my $HOSTAPD;
my @HOSTAPD;
my %HOSTAPD;
my $NEW_MACADDR;
my @NEW_MACADDR;
my %NEW_MACADDR;
my $WPA_VERSION;
my @WPA_VERSION;
my %WPA_VERSION;
my $IEEE80211AC;
my @IEEE80211AC;
my %IEEE80211AC;
my $ETC_HOSTS;
my @ETC_HOSTS;
my %ETC_HOSTS;
my $NO_DNS;
my @NO_DNS;
my %NO_DNS;
my $PASSPHRASE2;
my @PASSPHRASE2;
my %PASSPHRASE2;
my $REDIRECT_TO_LOCALHOST;
my @REDIRECT_TO_LOCALHOST;
my %REDIRECT_TO_LOCALHOST;
my $STOP_ID;
my @STOP_ID;
my %STOP_ID;
my $RUNNING_AS_DAEMON;
my @RUNNING_AS_DAEMON;
my %RUNNING_AS_DAEMON;
my $DRIVER;
my @DRIVER;
my %DRIVER;
my $COUNTRY;
my @COUNTRY;
my %COUNTRY;
my $HIDDEN;
my @HIDDEN;
my %HIDDEN;
my $ADDN_HOSTS;
my @ADDN_HOSTS;
my %ADDN_HOSTS;
my $VHT_CAPAB;
my @VHT_CAPAB;
my %VHT_CAPAB;
my $MIN_REQUIRED_ARGS;
my @MIN_REQUIRED_ARGS;
my %MIN_REQUIRED_ARGS;
my $USE_IWCONFIG;
my @USE_IWCONFIG;
my %USE_IWCONFIG;
my $NM_OLDER_VERSION;
my @NM_OLDER_VERSION;
my %NM_OLDER_VERSION;

my $MAX_LOOP_255 = 255;
my $MAGIC_58320  = 58_320;
my $MAGIC_755    = 755;
my $MAGIC_444    = 444;
my $MAGIC_64800  = 64_800;
my $MAGIC_555    = 555;
my $MAGIC_1000   = 1_000;
my $MAGIC_1024   = 1_024;
my $MAGIC_33     = 33;
my $MAGIC_3      = 3;
my $MAGIC_4910   = 4_910;
my $MAGIC_53     = 53;
my $MAGIC_4980   = 4_980;
my $MAGIC_32     = 32;
my $MAGIC_5      = 5;
my $MAGIC_2484   = 2_484;
my $MAGIC_67     = 67;
my $MAGIC_4      = 4;
my $MAGIC_14     = 14;
my $MAGIC_64     = 64;
my $MAGIC_45000  = 45_000;

my $VERSION;
my @VERSION;
my %VERSION;
$VERSION = '0.4.6';
my $PROGNAME;
my @PROGNAME;
my %PROGNAME;
$PROGNAME = (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($PROGRAM_NAME); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
$ENV{LC_ALL} = 'C';
my $SCRIPT_UMASK;
my @SCRIPT_UMASK;
my %SCRIPT_UMASK;
$SCRIPT_UMASK = '0077';
$main_exit_code = system('umask', $SCRIPT_UMASK) >> 8;

sub usage {
    do {
    my $__echo_line = "Usage: " . q{ } . $PROGNAME . q{ } . " [options] <wifi-interface> [<interface-with-internet>] [<access-point-name> [<passphrase>]]";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "\n";
    $CHILD_ERROR = 0;
    print "Options:\n";
    print "  -h, --help              Show this help\n";
    print "  --version               Print version number\n";
    print "  -c <channel>            Channel number (default: 1)\n";
    print "  -w <WPA version>        Use 1 for WPA, use 2 for WPA2, use 1+2 for both (default: 1+2)\n";
    print "  -n                      Disable Internet sharing (if you use this, don't pass\n";
    print "                          the <interface-with-internet> argument)\n";
    print "  -m <method>             Method for Internet sharing.\n";
    print "                          Use: 'nat' for NAT (default)\n";
    print "                               'bridge' for bridging\n";
    print "                               'none' for no Internet sharing (equivalent to -n)\n";
    print "  --psk                   Use 64 hex digits pre-shared-key instead of passphrase\n";
    print "  --hidden                Make the Access Point hidden (do not broadcast the SSID)\n";
    print "  --mac-filter            Enable MAC address filtering\n";
    print "  --mac-filter-accept     Location of MAC address filter list (defaults to /etc/hostapd/hostapd.accept)\n";
    print "  --redirect-to-localhost If -n is set, redirect every web request to localhost (useful for public information networks)\n";
    print "  --hostapd-debug <level> With level between 1 and 2, passes arguments -d or -dd to hostapd for debugging.\n";
    print "  --isolate-clients       Disable communication between clients\n";
    print "  --ieee80211n            Enable IEEE 802.11n (HT)\n";
    print "  --ieee80211ac           Enable IEEE 802.11ac (VHT)\n";
    print "  --ht_capab <HT>         HT capabilities (default: [HT40+])\n";
    print "  --vht_capab <VHT>       VHT capabilities\n";
    print "  --country <code>        Set two-letter country code for regularity (example: US)\n";
    print "  --freq-band <GHz>       Set frequency band. Valid inputs: 2.4, 5 (default: 2.4)\n";
    print "  --driver                Choose your WiFi adapter driver (default: nl80211)\n";
    print "  --no-virt               Do not create virtual interface\n";
    print "  --no-haveged            Do not run 'haveged' automatically when needed\n";
    print "  --fix-unmanaged         If NetworkManager shows your interface as unmanaged after you\n";
    print "                          close create_ap, then use this option to switch your interface\n";
    print "                          back to managed\n";
    print "  --mac <MAC>             Set MAC address\n";
    print "  --dhcp-dns <IP1[,IP2]>  Set DNS returned by DHCP\n";
    print "  --daemon                Run create_ap in the background\n";
    print "  --pidfile <pidfile>     Save daemon PID to file\n";
    print "  --logfile <logfile>     Save daemon messages to file\n";
    print "  --stop <id>             Send stop command to an already running create_ap. For an <id>\n";
    print "                          you can put the PID of create_ap or the WiFi interface. You can\n";
    print "                          get them with --list-running\n";
    print "  --list-running          Show the create_ap processes that are already running\n";
    print "  --list-clients <id>     List the clients connected to create_ap instance associated with <id>.\n";
    print "                          For an <id> you can put the PID of create_ap or the WiFi interface.\n";
    print "                          If virtual WiFi interface was created, then use that one.\n";
    print "                          You can get them with --list-running\n";
    print "  --mkconfig <conf_file>  Store configs in conf_file\n";
    print "  --config <conf_file>    Load configs from conf_file\n";
    print "\n";
    $CHILD_ERROR = 0;
    print "Non-Bridging Options:\n";
    print "  --no-dns                Disable dnsmasq DNS server\n";
    print "  --no-dnsmasq            Disable dnsmasq server completely\n";
    print "  -g <gateway>            IPv4 Gateway for the Access Point (default: 192.168.12.1)\n";
    print "  -d                      DNS server will take into account /etc/hosts\n";
    print "  -e <hosts_file>         DNS server will take into account additional hosts file\n";
    print "\n";
    $CHILD_ERROR = 0;
    print "Useful informations:\n";
    print "  * If you're not using the --no-virt option, then you can create an AP with the same\n";
    print "    interface you are getting your Internet connection.\n";
    print "  * You can pass your SSID and password through pipe or through arguments (see examples).\n";
    print "  * On bridge method if the <interface-with-internet> is not a bridge interface, then\n";
    print "    a bridge interface is created automatically.\n";
    print "\n";
    $CHILD_ERROR = 0;
    print "Examples:\n";
    do {
    my $__echo_line = "  " . q{ } . $PROGNAME . q{ } . " wlan0 eth0 MyAccessPoint MyPassPhrase";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  echo -e 'MyAccessPoint\nMyPassPhrase' | " . q{ } . $PROGNAME . q{ } . " wlan0 eth0";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  " . q{ } . $PROGNAME . q{ } . " wlan0 eth0 MyAccessPoint";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  echo 'MyAccessPoint' | " . q{ } . $PROGNAME . q{ } . " wlan0 eth0";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  " . q{ } . $PROGNAME . q{ } . " wlan0 wlan0 MyAccessPoint MyPassPhrase";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  " . q{ } . $PROGNAME . q{ } . " -n wlan0 MyAccessPoint MyPassPhrase";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  " . q{ } . $PROGNAME . q{ } . " -m bridge wlan0 eth0 MyAccessPoint MyPassPhrase";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  " . q{ } . $PROGNAME . q{ } . " -m bridge wlan0 br0 MyAccessPoint MyPassPhrase";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  " . q{ } . $PROGNAME . q{ } . " --driver rtl871xdrv wlan0 eth0 MyAccessPoint MyPassPhrase";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  " . q{ } . $PROGNAME . q{ } . " --daemon wlan0 eth0 MyAccessPoint MyPassPhrase";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  " . q{ } . $PROGNAME . q{ } . " --stop wlan0";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}
if (!(# Original bash: cp --help 2>&1 | grep -q -- --no-clobber;
{
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_1 = q{};
        croak "cp: missing file operand\n";
$tmp_redirect_1;
    };
    $output_0 = $output;

        carp "grep: no pattern specified";
    exit 1;
    $output_0 = q{};
    if ((scalar @grep_filtered_0_1) == 0) {
        $pipeline_success_0 = 0;
    }
    if ($output_0 ne q{} && !defined $output_printed_0) {
        print $output_0;
        if (!($output_0 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    })) {

sub cp_n {
        croak "cp: missing file operand\n";
        return;
}
}
else {

sub cp_n {
        # Original bash: yes n | cp -i "$@"
{
            my $output_4 = q{};
            my $output_printed_4;
            my $pipeline_success_4 = 1;
                        my $string = q{n};
            $output_4 = q{};
            for (my $i = 0; $i < 1000; $i++) {
            $output_4 .= "$string\n";
            }
            $output_4;

                        croak "cp: missing file operand\n";
            if ($output_4 ne q{} && !defined $output_printed_4) {
                print $output_4;
                if (!($output_4 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
            }
        return;
}
}

sub get_avail_fd {
    my $x;
    for my $x (do { my $first; my $last; $first = q{1}; $last = do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'ulimit', '-n');
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
}; join "\n", $first..$last; }) {
if (((!) && ("/proc/$BASHPID/fd/$x"))) {
            print $x;
if ( !( ($x) =~ m{\n\z}msx ) ) { print "\n"; }
return;
        }
    }
    $x = $last; };
    print q{0} . "\n";
    $CHILD_ERROR = 0;
    return;
}
my $COUNTER_LOCK_FILE;
my @COUNTER_LOCK_FILE;
my %COUNTER_LOCK_FILE;
$COUNTER_LOCK_FILE = '/tmp/create_ap.';
$CHILD_ERROR = 0;

sub cleanup_lock {
if ( -e "$COUNTER_LOCK_FILE" ) {
        if ( -d "$COUNTER_LOCK_FILE" ) {
            carp "rm: carping: ", $COUNTER_LOCK_FILE,
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$COUNTER_LOCK_FILE" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $COUNTER_LOCK_FILE,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}

sub init_lock {
    my $LOCK_FILE = "/tmp/create_ap.all.lock";
    if (($LOCK_FD != 0)) {
        return q{0};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $LOCK_FD;
    my @LOCK_FD;
    my %LOCK_FD;
    $LOCK_FD = do {
    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'get_avail_fd');
    close $in_6 or croak 'Close failed: $OS_ERROR';
    my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    $result_6
};
    if (($LOCK_FD == 0)) {
        return q{1};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    $main_exit_code = system('umask', '0555') >> 8;
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
do { my $eval_input = "exec " . $LOCK_FD . ">" . $LOCK_FILE; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        return q{1};    }
    $main_exit_code = system('umask', $SCRIPT_UMASK) >> 8;
    if ((qx'id -u' == 0)) {
        do {
    my ($owner, $group) = split /:/, '0:0', 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ($LOCK_FILE) or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', $COUNTER_LOCK_FILE
      or die "Cannot open file: $OS_ERROR\n";
        print q{0} . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
return $?;
    return;
}

sub mutex_lock {
    my $counter_mutex_fd;
    my $counter;
    $counter_mutex_fd = do {
    my ($in_8, $out_8);
    my $pid_8 = open3($in_8, $out_8, '>&STDERR', 'get_avail_fd');
    close $in_8 or croak 'Close failed: $OS_ERROR';
    my $result_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
    close $out_8 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_8, 0;
    $result_8
};
if (($counter_mutex_fd != 0)) {
do { my $eval_input = "exec " . $counter_mutex_fd . "<>" . $COUNTER_LOCK_FILE; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
        $main_exit_code = system('flock', $counter_mutex_fd) >> 8;
$counter = <>;
chomp $counter;
$CHILD_ERROR = defined($counter) ? 0 : 1;
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "Failed to lock mutex counter\n";
        };
return q{1};
    }
    if (($counter == 0)) {
                $main_exit_code = system('flock', $LOCK_FD) >> 8;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    $counter = eval { int( $counter + 1 ) } // "";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/proc/'
      or die "Cannot open file: $OS_ERROR\n";
        print $counter;
if ( !( ($counter) =~ m{\n\z}msx ) ) { print "\n"; }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $CHILD_ERROR = 0;
do { my $eval_input = "exec " . ${counter_mutex_fd} . "<&-"; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
return q{0};
    return;
}

sub mutex_unlock {
    my $counter_mutex_fd;
    my $counter;
    $counter_mutex_fd = do {
    my ($in_10, $out_10);
    my $pid_10 = open3($in_10, $out_10, '>&STDERR', 'get_avail_fd');
    close $in_10 or croak 'Close failed: $OS_ERROR';
    my $result_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
    close $out_10 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_10, 0;
    $result_10
};
if (($counter_mutex_fd != 0)) {
do { my $eval_input = "exec " . $counter_mutex_fd . "<>" . $COUNTER_LOCK_FILE; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
        $main_exit_code = system('flock', $counter_mutex_fd) >> 8;
$counter = <>;
chomp $counter;
$CHILD_ERROR = defined($counter) ? 0 : 1;
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "Failed to lock mutex counter\n";
        };
return q{1};
    }
if (($counter > 0)) {
        $counter = eval { int( $counter - 1 ) } // "";
        if (($counter == 0)) {
                        $main_exit_code = system('flock', '-u', $LOCK_FD) >> 8;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/proc/'
      or die "Cannot open file: $OS_ERROR\n";
        print $counter;
if ( !( ($counter) =~ m{\n\z}msx ) ) { print "\n"; }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $CHILD_ERROR = 0;
do { my $eval_input = "exec " . ${counter_mutex_fd} . "<&-"; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
return q{0};
    return;
}

sub version_cmp {
    my $V1;
    my $V2;
    my $VN;
    my $x;
    if (!$1 =~ /^[0-9]+([.][0-9]+)*$/msx) {
                $main_exit_code = system('die', "Wrong version format!") >> 8;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if (!$2 =~ /^[0-9]+([.][0-9]+)*$/msx) {
                $main_exit_code = system('die', "Wrong version format!") >> 8;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    @V1 = (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ($1) . "\n";
    my $set1_13 = q{.};
my $set2_13 = q{ };
my $input_13 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_13 = $set1_13;
my $expanded_set2_13 = $set2_13;
# Handle a-z range in set1
if ($expanded_set1_13 =~ /a-z/msx) {
    $expanded_set1_13 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_13 =~ /A-Z/msx) {
    $expanded_set1_13 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_13 =~ /\[:upper:\]/msx) {
    $expanded_set1_13 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_13 =~ /\[:lower:\]/msx) {
    $expanded_set1_13 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_13 =~ /a-z/msx) {
    $expanded_set2_13 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_13 =~ /A-Z/msx) {
    $expanded_set2_13 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_13 =~ /\[:upper:\]/msx) {
    $expanded_set2_13 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_13 =~ /\[:lower:\]/msx) {
    $expanded_set2_13 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_12 = q{};
for my $char ( split //msx, $input_13 ) {
    my $pos_13 = index $expanded_set1_13, $char;
    if ( $pos_13 >= 0 && $pos_13 < length $expanded_set2_13 ) {
        $tr_result_12 .= substr $expanded_set2_13, $pos_13, 1;
    } else {
        $tr_result_12 .= $char;
    }
}
$tr_result_12
}; $_pipeline_result; });
    @V2 = (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ($2) . "\n";
    my $set1_15 = q{.};
my $set2_15 = q{ };
my $input_15 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_15 = $set1_15;
my $expanded_set2_15 = $set2_15;
# Handle a-z range in set1
if ($expanded_set1_15 =~ /a-z/msx) {
    $expanded_set1_15 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_15 =~ /A-Z/msx) {
    $expanded_set1_15 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_15 =~ /\[:upper:\]/msx) {
    $expanded_set1_15 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_15 =~ /\[:lower:\]/msx) {
    $expanded_set1_15 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_15 =~ /a-z/msx) {
    $expanded_set2_15 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_15 =~ /A-Z/msx) {
    $expanded_set2_15 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_15 =~ /\[:upper:\]/msx) {
    $expanded_set2_15 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_15 =~ /\[:lower:\]/msx) {
    $expanded_set2_15 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_14 = q{};
for my $char ( split //msx, $input_15 ) {
    my $pos_15 = index $expanded_set1_15, $char;
    if ( $pos_15 >= 0 && $pos_15 < length $expanded_set2_15 ) {
        $tr_result_14 .= substr $expanded_set2_15, $pos_15, 1;
    } else {
        $tr_result_14 .= $char;
    }
}
$tr_result_14
}; $_pipeline_result; });
    $VN = scalar(@V1);
    if (($VN < ${#V2[@]})) {
                $VN = scalar(@V2);
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    for (eval { int($x = 0) } // ""; eval { int($x < $VN) } // ""; eval { int($x++) } // "") {
            if ((${V1[x]} < ${V2[x]})) {
                return q{1};                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            if ((${V1[x]} > ${V2[x]})) {
                return q{2};                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
    }
return q{0};
    return;
}
$USE_IWCONFIG = q{0};

sub is_interface {
    if ("$1" eq q{}) {
        return q{1};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
(-d "/sys/class/net/${1}")
    return;
}

sub is_wifi_interface {
    if (do {
if (do {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'iw';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
} == 0) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('iw', 'dev', $1, 'info') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
        $CHILD_ERROR == 0
    }) {
        return q{0};    }
if ((!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'iwconfig';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }) && !(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('iwconfig', $1) >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }))) {
        $USE_IWCONFIG = q{1};
return q{0};
    }
return q{1};
    return;
}

sub is_bridge_interface {
    if ("$1" eq q{}) {
        return q{1};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
(-d "/sys/class/net/${1}/bridge")
    return;
}

sub get_phy_device {
    my $x;
    for my $x ('/sys/class/ieee80211/*') {
        if ((!-e "$x")) {
            next;            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
if ("${x##*/}" eq "$1") {
            print $1;
if ( !( ($1) =~ m{\n\z}msx ) ) { print "\n"; }
return q{0};
}
        else {
            if ((-e "$x/device/net/$1")) {
                do {
    my $__echo_line = basename(${x});
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
return q{0};
}
            else {
                if ((-e "$x/device/net:$1")) {
                    do {
    my $__echo_line = basename(${x});
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
return q{0};
}
                else {
if ((-e "/sys/class/net/$1")) {
                        my $phy;
                        my @phy;
                        my %phy;
                        $phy = do {
    my ($in_18, $out_18);
    my $pid_18 = open3($in_18, $out_18, '>&STDERR', 'readlink', '-f', '/sys/class/net/', $1, '/phy80211');
    close $in_18 or croak 'Close failed: $OS_ERROR';
    my $result_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_18> };
    close $out_18 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_18, 0;
    $result_18
};
                        my $phy1;
                        my @phy1;
                        my %phy1;
                        $phy1 = do {
    my ($in_19, $out_19);
    my $pid_19 = open3($in_19, $out_19, '>&STDERR', 'readlink', '-f', $x);
    close $in_19 or croak 'Close failed: $OS_ERROR';
    my $result_19 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19> };
    close $out_19 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_19, 0;
    $result_19
};
if ($phy =~ /^[$]phy1$/msx) {
                            do {
    my $__echo_line = basename(${x});
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                            $CHILD_ERROR = 0;
return q{0};
                        }
                    }
                }
            }
        }
    }
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "Failed to get phy interface\n";
    };
return q{1};
    return;
}

sub get_adapter_info {
    my $PHY;
    $PHY = do {
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', 'get_phy_device', "$_[0]");
    close $in_20 or croak 'Close failed: $OS_ERROR';
    my $result_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    $result_20
};
    if (($? != 0)) {
        return q{1};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    $main_exit_code = system('iw', 'phy', $PHY, 'info') >> 8;
    return;
}

sub get_adapter_kernel_module {
    my $MODULE;
    $MODULE = do {
    my ($in_21, $out_21);
    my $pid_21 = open3($in_21, $out_21, '>&STDERR', 'readlink', '-f', "/sys/class/net/$_[0]/device/driver/module");
    close $in_21 or croak 'Close failed: $OS_ERROR';
    my $result_21 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_21> };
    close $out_21 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_21, 0;
    $result_21
};
    do {
    my $__echo_line = basename(${MODULE});
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

sub can_be_sta_and_ap {
    if (($USE_IWCONFIG == 1)) {
        return q{1};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if ("$(get_adapter_kernel_module "$1")" =~ /^"brcmfmac"$/msx) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "WARN: brmfmac driver doesn't work properly with virtual interfaces and\n";
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "      it can cause kernel panic. For this reason we disallow virtual\n";
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "      interfaces for your adapter.\n";
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "      For more info: https://github.com/oblique/create_ap/issues/203\n";
        };
return q{1};
    }
    if (do {
{
    my $output_22 = q{};
    my $output_printed_22;
    my $pipeline_success_22 = 1;
        my ($in_23, $out_23);
    my $pid_23 = open3($in_23, $out_23, '>&STDERR', 'get_adapter_info', );
    close $in_23 or croak 'Close failed: $OS_ERROR';
    $output_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
    close $out_23 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_23, 0;

        my $grep_result_22_1;
    my @grep_lines_22_1 = split /\n/msx, $output_22;
    my @grep_filtered_22_1 = grep { /{.*\ managed.*\ AP.*}/msx } @grep_lines_22_1;
    $grep_result_22_1 = join "\n", @grep_filtered_22_1;
    if (!($grep_result_22_1 =~ m{\n\z}msx || $grep_result_22_1 eq q{})) {
    $grep_result_22_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_22_1 > 0 ? 0 : 1;
    $output_22 = $grep_result_22_1;
    if ( !$pipeline_success_22 ) { $main_exit_code = 1; }
    }
        $CHILD_ERROR == 0
    }) {
        return q{0};    }
    if (do {
{
    my $output_24 = q{};
    my $output_printed_24;
    my $pipeline_success_24 = 1;
        my ($in_25, $out_25);
    my $pid_25 = open3($in_25, $out_25, '>&STDERR', 'get_adapter_info', );
    close $in_25 or croak 'Close failed: $OS_ERROR';
    $output_24 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_25> };
    close $out_25 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_25, 0;

        my $grep_result_24_1;
    my @grep_lines_24_1 = split /\n/msx, $output_24;
    my @grep_filtered_24_1 = grep { /{.*\ AP.*\ managed.*}/msx } @grep_lines_24_1;
    $grep_result_24_1 = join "\n", @grep_filtered_24_1;
    if (!($grep_result_24_1 =~ m{\n\z}msx || $grep_result_24_1 eq q{})) {
    $grep_result_24_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_24_1 > 0 ? 0 : 1;
    $output_24 = $grep_result_24_1;
    if ( !$pipeline_success_24 ) { $main_exit_code = 1; }
    }
        $CHILD_ERROR == 0
    }) {
        return q{0};    }
return q{1};
    return;
}

sub can_be_ap {
    if (($USE_IWCONFIG == 1)) {
        return q{0};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if (do {
{
    my $output_26 = q{};
    my $output_printed_26;
    my $pipeline_success_26 = 1;
        my ($in_27, $out_27);
    my $pid_27 = open3($in_27, $out_27, '>&STDERR', 'get_adapter_info', );
    close $in_27 or croak 'Close failed: $OS_ERROR';
    $output_26 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_27> };
    close $out_27 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_27, 0;

        my $grep_result_26_1;
    my @grep_lines_26_1 = split /\n/msx, $output_26;
    my @grep_filtered_26_1 = grep { /[*]\ AP$/msx } @grep_lines_26_1;
    $grep_result_26_1 = join "\n", @grep_filtered_26_1;
    if (!($grep_result_26_1 =~ m{\n\z}msx || $grep_result_26_1 eq q{})) {
    $grep_result_26_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_26_1 > 0 ? 0 : 1;
    $output_26 = $grep_result_26_1;
    if ( !$pipeline_success_26 ) { $main_exit_code = 1; }
    }
        $CHILD_ERROR == 0
    }) {
        return q{0};    }
return q{1};
    return;
}

sub can_transmit_to_channel {
    my $IFACE;
    my $CHANNEL_NUM;
    my $CHANNEL_INFO;
    $IFACE = $1;
    $CHANNEL_NUM = $2;
if (($USE_IWCONFIG == 0)) {
if ($FREQ_BAND =~ /^2[.]4$/msx) {
            $CHANNEL_INFO = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_28 = q{};
                my $output_printed_28;
                my $pipeline_success_28 = 1;

                my ($in_29, $out_29);
                my $pid_29 = open3($in_29, $out_29, '>&STDERR', 'get_adapter_info', );
                close $in_29 or croak 'Close failed: $OS_ERROR';
                $output_28 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_29> };
                close $out_29 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_29, 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_28 = 0; }
                my $grep_result_28_1;
                my @grep_lines_28_1 = split /\n/msx, $output_28;
                my @grep_filtered_28_1 = grep { /\ (24[0-9][0-9]|24[0-9][0-9].[0-9])\ MHz\ [\[]"\ .\ ${CHANNEL_NUM}\ .\ "[\]]/msx } @grep_lines_28_1;
                $grep_result_28_1 = join "\n", @grep_filtered_28_1;
                                if (!($grep_result_28_1 =~ m{\n\z}msx || $grep_result_28_1 eq q{})) {
                                    $grep_result_28_1 .= "\n";
                                }
                $CHILD_ERROR = scalar @grep_filtered_28_1 > 0 ? 0 : 1;
                $output_28 = $grep_result_28_1;
                if ((scalar @grep_filtered_28_1) == 0) {
                    $pipeline_success_28 = 0;
                }
                if ( !$pipeline_success_28 ) { $main_exit_code = 1; }
                $output_28 =~ s/\n+\z//msx;
                $output_28;
}; $_pipeline_result; };
}
        else {
            $CHANNEL_INFO = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_30 = q{};
                my $output_printed_30;
                my $pipeline_success_30 = 1;

                my ($in_31, $out_31);
                my $pid_31 = open3($in_31, $out_31, '>&STDERR', 'get_adapter_info', );
                close $in_31 or croak 'Close failed: $OS_ERROR';
                $output_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
                close $out_31 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_31, 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_30 = 0; }
                my $grep_result_30_1;
                my @grep_lines_30_1 = split /\n/msx, $output_30;
                my @grep_filtered_30_1 = grep { /\ (49[0-9][0-9].[0-9]|5[0-9]{3}.[0-9]|49[0-9][0-9]|5[0-9]{3})\ MHz\ [\[]"\ .\ ${CHANNEL_NUM}\ .\ "[\]]/msx } @grep_lines_30_1;
                $grep_result_30_1 = join "\n", @grep_filtered_30_1;
                                if (!($grep_result_30_1 =~ m{\n\z}msx || $grep_result_30_1 eq q{})) {
                                    $grep_result_30_1 .= "\n";
                                }
                $CHILD_ERROR = scalar @grep_filtered_30_1 > 0 ? 0 : 1;
                $output_30 = $grep_result_30_1;
                if ((scalar @grep_filtered_30_1) == 0) {
                    $pipeline_success_30 = 0;
                }
                if ( !$pipeline_success_30 ) { $main_exit_code = 1; }
                $output_30 =~ s/\n+\z//msx;
                $output_30;
}; $_pipeline_result; };
        }
        if ("${CHANNEL_INFO}" eq q{}) {
            return q{1};            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ("${CHANNEL_INFO}" =~ /^.*no\IR.*$/msx) {
            return q{1};            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ("${CHANNEL_INFO}" =~ /^.*disabled.*$/msx) {
            return q{1};            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
return q{0};
}
    else {
        $CHANNEL_NUM = sprintf('%02d', $CHANNEL_NUM);
;
        $CHANNEL_INFO = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_32 = q{};
            my $output_printed_32;
            my $pipeline_success_32 = 1;

            my ($in_33, $out_33);
            my $pid_33 = open3($in_33, $out_33, '>&STDERR', 'iwlist', 'channel');
            close $in_33 or croak 'Close failed: $OS_ERROR';
            $output_32 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_33> };
            close $out_33 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_33, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_32 = 0; }
            my $grep_result_32_1;
            my @grep_lines_32_1 = split /\n/msx, $output_32;
            my @grep_filtered_32_1 = grep { /Channel[[:blank:]]"\ .\ ${CHANNEL_NUM}\ .\ "[[:blank:]]?:/msx } @grep_lines_32_1;
            $grep_result_32_1 = join "\n", @grep_filtered_32_1;
                        if (!($grep_result_32_1 =~ m{\n\z}msx || $grep_result_32_1 eq q{})) {
                            $grep_result_32_1 .= "\n";
                        }
            $CHILD_ERROR = scalar @grep_filtered_32_1 > 0 ? 0 : 1;
            $output_32 = $grep_result_32_1;
            if ((scalar @grep_filtered_32_1) == 0) {
                $pipeline_success_32 = 0;
            }
            if ( !$pipeline_success_32 ) { $main_exit_code = 1; }
            $output_32 =~ s/\n+\z//msx;
            $output_32;
}; $_pipeline_result; };
        if ("${CHANNEL_INFO}" eq q{}) {
            return q{1};            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
return q{0};
    }
    return;
}

sub ieee80211_frequency_to_channel {
    my $FREQ = $_[0];
if (($FREQ == $MAGIC_2$MAGIC_48$MAGIC_4)) {
        print '14' . "\n";
        $CHILD_ERROR = 0;
}
    else {
        if (($FREQ < $MAGIC_2$MAGIC_48$MAGIC_4)) {
            do {
    my $__echo_line = eval { int( ($FREQ - 2407) / 5 ) } // "";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
}
        else {
            if ((($FREQ >= $MAGIC_$MAGIC_4910) && ($FREQ <= $MAGIC_$MAGIC_4980))) {
                do {
    my $__echo_line = eval { int( ($FREQ - 4000) / 5 ) } // "";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
}
            else {
                if (($FREQ <= $MAGIC_4$MAGIC_5000)) {
                    do {
    my $__echo_line = eval { int( ($FREQ - 5000) / 5 ) } // "";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
}
                else {
                    if ((($FREQ >= $MAGIC_$MAGIC_58$MAGIC_$MAGIC_320) && ($FREQ <= $MAGIC_6$MAGIC_4800))) {
                        do {
    my $__echo_line = eval { int( ($FREQ - 56160) / 2160 ) } // "";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
}
                    else {
                        print q{0} . "\n";
                        $CHILD_ERROR = 0;
                    }
                }
            }
        }
    }
    return;
}

sub is_5ghz_frequency {
$ENV{1} =~ /^(49[0-9]{2})|(5[0-9]{3})$/msx
    return;
}

sub is_wifi_connected {
if (($USE_IWCONFIG == 0)) {
        if (do {
{
    my $output_34 = q{};
    my $output_printed_34;
    my $pipeline_success_34 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_35 = q{};

my $cmd_38 = 'iw';
my ($in_37, $out_37);
my $pid_37 = open3($in_37, $out_37, '>&STDERR', $cmd_38, 'dev', 'link');
print {$in_37} $output_34;
close $in_37 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_35 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_37> };
close $out_37 or croak 'Close failed: $OS_ERROR';
waitpid $pid_37, 0;
$tmp_redirect_35;
    };
    $output_34 = $output;

        my $grep_result_34_1;
    my @grep_lines_34_1 = split /\n/msx, $output_34;
    my @grep_filtered_34_1 = grep { /^Connected\ to/msx } @grep_lines_34_1;
    $grep_result_34_1 = join "\n", @grep_filtered_34_1;
    if (!($grep_result_34_1 =~ m{\n\z}msx || $grep_result_34_1 eq q{})) {
    $grep_result_34_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_34_1 > 0 ? 0 : 1;
    $output_34 = $grep_result_34_1;
    if ( !$pipeline_success_34 ) { $main_exit_code = 1; }
    }
            $CHILD_ERROR == 0
        }) {
            return q{0};        }
}
    else {
        if (do {
{
    my $output_39 = q{};
    my $output_printed_39;
    my $pipeline_success_39 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_40 = q{};

my $cmd_43 = 'iwconfig';
my ($in_42, $out_42);
my $pid_42 = open3($in_42, $out_42, '>&STDERR', $cmd_43, );
print {$in_42} $output_39;
close $in_42 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_40 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_42> };
close $out_42 or croak 'Close failed: $OS_ERROR';
waitpid $pid_42, 0;
$tmp_redirect_40;
    };
    $output_39 = $output;

        my $grep_result_39_1;
    my @grep_lines_39_1 = split /\n/msx, $output_39;
    my @grep_filtered_39_1 = grep { /Access\ Point:\ [0-9a-fA-F]{2}:/msx } @grep_lines_39_1;
    $grep_result_39_1 = join "\n", @grep_filtered_39_1;
    if (!($grep_result_39_1 =~ m{\n\z}msx || $grep_result_39_1 eq q{})) {
    $grep_result_39_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_39_1 > 0 ? 0 : 1;
    $output_39 = $grep_result_39_1;
    if ( !$pipeline_success_39 ) { $main_exit_code = 1; }
    }
            $CHILD_ERROR == 0
        }) {
            return q{0};        }
    }
return q{1};
    return;
}

sub is_macaddr {
    my ($file) = @_;
    # Original bash: echo "$1" | grep -E "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$" > /dev/null 2>&1
{
        my $output_44 = q{};
        my $output_printed_44;
        my $pipeline_success_44 = 1;
        $output_44 .= $1 . "\n";
if ( !($output_44 =~ m{\n\z}msx) ) { $output_44 .= "\n"; }
$CHILD_ERROR = 0;

                my $grep_result_44_1;
        my @grep_lines_44_1 = split /\n/msx, $output_44;
        my @grep_filtered_44_1 = grep { /^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/msx } @grep_lines_44_1;
        $grep_result_44_1 = join "\n", @grep_filtered_44_1;
        if (!($grep_result_44_1 =~ m{\n\z}msx || $grep_result_44_1 eq q{})) {
        $grep_result_44_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_44_1 > 0 ? 0 : 1;
        $output_44 = $grep_result_44_1;
        if ( !$pipeline_success_44 ) { $main_exit_code = 1; }
        }
    return;
}

sub is_unicast_macaddr {
    my $x;
        is_macaddr("$_[0]");
    if ($CHILD_ERROR != 0) {
        return q{1};    }
    $x = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_45 = q{};
        my $output_printed_45;
        my $pipeline_success_45 = 1;
        $output_45 .= $1 . "\n";
        if ( !($output_45 =~ m{\n\z}msx) ) { $output_45 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_45 = 0; }
        my @lines_46 = split /\n/msx, $output_45;
        my @result_46;
        foreach my $line (@lines_46) {
        chomp $line;
        my @fields = split /:/msx, $line;
        if (@fields > 0) {
            push @result_46, $fields[0];
        }
        }
        $output_45 = join "\n", @result_46;
        if ($output_45 ne q{} && !($output_45  =~ m{\n\z}msx)) { $output_45 .= "\n"; }

        if ( !$pipeline_success_45 ) { $main_exit_code = 1; }
        $output_45 =~ s/\n+\z//msx;
        $output_45;
}; $_pipeline_result; };
    $x = sprintf('%d', "0x" . ${x});
;
(qx'expr $x % 2' == 0)
    return;
}

sub get_macaddr {
        is_interface("$_[0]");
    if ($CHILD_ERROR != 0) {
        return;    }
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "/sys/class/net/" . $_[0] . "/address" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "/sys/class/net/" . $_[0] . "/address" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    return;
}

sub get_mtu {
        is_interface("$_[0]");
    if ($CHILD_ERROR != 0) {
        return;    }
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "/sys/class/net/" . $_[0] . "/mtu" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "/sys/class/net/" . $_[0] . "/mtu" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    return;
}

sub alloc_new_iface {
    my $prefix = $_[0];
    my $i = "0";
    mutex_lock();
while (     $main_exit_code = system('bash', ':') >> 8 ) {
if (!(!(if (do {
is_interface($prefix, $i);
            $CHILD_ERROR == 0
        }) {
            (!-f $COMMON_CONFDIR/ifaces/$prefix$i)        }))) {
            use File::Path qw(make_path);
            my $err;
            if ( !-d $COMMON_CONFDIR ) {
                make_path( $COMMON_CONFDIR, { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . $COMMON_CONFDIR . ": $err->[0]\n";
                }
            }
            if ( !-d '/ifaces' ) {
                make_path( '/ifaces', { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . '/ifaces' . ": $err->[0]\n";
                }
            }
            if ( -e "$COMMON_CONFDIR" ) {
                my $current_time = time;
                utime $current_time, $current_time, "$COMMON_CONFDIR";
            }
            else {
                if ( open my $fh, '>', "$COMMON_CONFDIR" ) {
                    close $fh or croak "Close failed: $ERRNO";
                }
                else {
                    croak "touch: cannot create ", "$COMMON_CONFDIR",
                      ": $ERRNO\n";
                }
            }
            if ( -e "/ifaces/" ) {
                my $current_time = time;
                utime $current_time, $current_time, "/ifaces/";
            }
            else {
                if ( open my $fh, '>', "/ifaces/" ) {
                    close $fh or croak "Close failed: $ERRNO";
                }
                else {
                    croak "touch: cannot create ", "/ifaces/",
                      ": $ERRNO\n";
                }
            }
            if ( -e "$prefix" ) {
                my $current_time = time;
                utime $current_time, $current_time, "$prefix";
            }
            else {
                if ( open my $fh, '>', "$prefix" ) {
                    close $fh or croak "Close failed: $ERRNO";
                }
                else {
                    croak "touch: cannot create ", "$prefix",
                      ": $ERRNO\n";
                }
            }
            if ( -e "$i" ) {
                my $current_time = time;
                utime $current_time, $current_time, "$i";
            }
            else {
                if ( open my $fh, '>', "$i" ) {
                    close $fh or croak "Close failed: $ERRNO";
                }
                else {
                    croak "touch: cannot create ", "$i",
                      ": $ERRNO\n";
                }
            }
            do {
    my $__echo_line = $prefix . q{ } . $i;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            mutex_unlock();
return;
        }
        $i = eval { int($i + 1) } // "";
    }
    mutex_unlock();
    return;
}

sub dealloc_iface {
if ( -e "$COMMON_CONFDIR" ) {
        if ( -d "$COMMON_CONFDIR" ) {
            carp "rm: carping: ", $COMMON_CONFDIR,
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$COMMON_CONFDIR" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $COMMON_CONFDIR,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/ifaces/" ) {
        if ( -d "/ifaces/" ) {
            carp "rm: carping: ", "/ifaces/",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/ifaces/" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/ifaces/",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "$1" ) {
        if ( -d "$1" ) {
            carp "rm: carping: ", $1,
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$1" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $1,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}

sub get_all_macaddrs {
print do { my $cat_chunk = q{}; if ( open my $fh, '<', '/sys/class/net/*/address' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/sys/class/net/*/address' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    return;
}

sub get_new_macaddr {
    my $OLDMAC;
    my $NEWMAC;
    my $LAST_BYTE;
    my $i;
    $OLDMAC = do {
    my ($in_52, $out_52);
    my $pid_52 = open3($in_52, $out_52, '>&STDERR', 'get_macaddr', "$_[0]");
    close $in_52 or croak 'Close failed: $OS_ERROR';
    my $result_52 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_52> };
    close $out_52 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_52, 0;
    $result_52
};
    $LAST_BYTE = do {
    my $result = join('', map { sprintf '%d', $_ } ('0x', ${OLDMAC} =~ s/^.*://sr));
    $result;
}
;
    mutex_lock();
    for my $i ( 1 .. $MAX_LOOP_255 ) {
        $NEWMAC = (scalar reverse( (scalar reverse ${OLDMAC}) =~ s/^.*?://r ) =~ s/:.*?$//r) . ":" . (do { my $_chomp_temp = sprintf('%02x', eval { int( ($LAST_BYTE + $i) % 256 ) } // "");
; chomp $_chomp_temp; $_chomp_temp; });
                do {
            local %ENV = %ENV;
            my $i = $i;
            my $LAST_BYTE = $LAST_BYTE;
            my $COUNTER_LOCK_FILE = $COUNTER_LOCK_FILE;
            my $PROGNAME = $PROGNAME;
            my $VERSION = $VERSION;
            my $SCRIPT_UMASK = $SCRIPT_UMASK;
            my $OLDMAC = $OLDMAC;
            my $NEWMAC = $NEWMAC;
            # Original bash: get_all_macaddrs | grep "$NEWMAC" > /dev/null 2>&1)
{
                my $output_53 = q{};
                my $output_printed_53;
                my $pipeline_success_53 = 1;
                                my ($in_54, $out_54);
                my $pid_54 = open3($in_54, $out_54, '>&STDERR', 'get_all_macaddrs', );
                close $in_54 or croak 'Close failed: $OS_ERROR';
                $output_53 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_54> };
                close $out_54 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_54, 0;

                                my $grep_result_53_1;
                my @grep_lines_53_1 = split /\n/msx, $output_53;
                my @grep_filtered_53_1 = grep { /$NEWMAC/msx } @grep_lines_53_1;
                $grep_result_53_1 = join "\n", @grep_filtered_53_1;
                if (!($grep_result_53_1 =~ m{\n\z}msx || $grep_result_53_1 eq q{})) {
                $grep_result_53_1 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_53_1 > 0 ? 0 : 1;
                $output_53 = $grep_result_53_1;
                if ( !$pipeline_success_53 ) { $main_exit_code = 1; }
                }
            q{};
        };
        if ($CHILD_ERROR != 0) {
            last;        }
    }
    mutex_unlock();
    print $NEWMAC;
if ( !( ($NEWMAC) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}

sub haveged_watchdog {
    my $show_warn = "1";
while (     $main_exit_code = system('bash', ':') >> 8 ) {
        mutex_lock();
if ((qx'cat /proc/sys/kernel/random/entropy_avail' < $MAGIC_1000)) {
if (!(!(do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'haveged';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };))) {
if (($show_warn == 1)) {
                    print "WARN: Low entropy detected. We recommend you to install \\" . chr(96) . "haveged'\n";
                    $show_warn = q{0};
                }
}
            else {
                if (!(!(do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                    my $tmp = do {
                    $main_exit_code = system('pidof', 'haveged') >> 8;
                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };))) {
                    print "Low entropy detected, starting haveged\n";
                    $main_exit_code = system('haveged', '-w', '1024', '-p', $COMMON_CONFDIR, '/haveged.pid') >> 8;
                }
            }
        }
        mutex_unlock();
require Time::HiRes; Time::HiRes::sleep(q{2});
    }
    return;
}
my $NETWORKMANAGER_CONF;
my @NETWORKMANAGER_CONF;
my %NETWORKMANAGER_CONF;
$NETWORKMANAGER_CONF = '/etc/NetworkManager/NetworkManager.conf';
$NM_OLDER_VERSION = q{1};

sub networkmanager_exists {
    my $NM_VER;
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'nmcli';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        return q{1};    }
    $NM_VER = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_58 = q{};
        my $output_printed_58;
        my $pipeline_success_58 = 1;

        my ($in_59, $out_59);
        my $pid_59 = open3($in_59, $out_59, '>&STDERR', 'nmcli', '-v');
        close $in_59 or croak 'Close failed: $OS_ERROR';
        $output_58 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_59> };
        close $out_59 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_59, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_58 = 0; }
        my $grep_result_58_1;
        my @grep_lines_58_1 = split /\n/msx, $output_58;
        my @grep_filtered_58_1 = grep { /[0-9]+([.][0-9]+)*[.][0-9]+/msx } @grep_lines_58_1;
        my @grep_matches_58_1;
        foreach my $line (@grep_filtered_58_1) {
            if ($line =~ /([0-9]+([.][0-9]+)*[.][0-9]+)/msx) {
                push @grep_matches_58_1, $1;
            }
        }
        $grep_result_58_1 = join "\n", @grep_matches_58_1;
        $CHILD_ERROR = scalar @grep_filtered_58_1 > 0 ? 0 : 1;
        $output_58 = $grep_result_58_1;
        if ((scalar @grep_filtered_58_1) == 0) {
            $pipeline_success_58 = 0;
        }
        if ( !$pipeline_success_58 ) { $main_exit_code = 1; }
        $output_58 =~ s/\n+\z//msx;
        $output_58;
}; $_pipeline_result; };
    version_cmp($NM_VER, '0.9.9');
if (($? == 1)) {
        $NM_OLDER_VERSION = q{1};
}
    else {
        $NM_OLDER_VERSION = q{0};
    }
return q{0};
    return;
}

sub networkmanager_is_running {
    my $NMCLI_OUT;
        networkmanager_exists();
    if ($CHILD_ERROR != 0) {
        return q{1};    }
if (($NM_OLDER_VERSION == 1)) {
        $NMCLI_OUT = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_60 = q{};
            my $output_printed_60;
            my $pipeline_success_60 = 1;
            my ($in_61, $out_61);
            my $pid_61 = open3($in_61, $out_61, '>&STDERR', 'nmcli', '-t', '-f', 'RUNNING', 'nm');
            close $in_61 or croak 'Close failed: $OS_ERROR';
            $output_60 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_61> };
            close $out_61 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_61, 0;
            my $grep_result_60_1;
            my @grep_lines_60_1 = split /\n/msx, $output_60;
            my @grep_filtered_60_1 = grep { /^running$/msx } @grep_lines_60_1;
            $grep_result_60_1 = join "\n", @grep_filtered_60_1;
            if (!($grep_result_60_1 =~ m{\n\z}msx || $grep_result_60_1 eq q{})) {
            $grep_result_60_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_60_1 > 0 ? 0 : 1;
            $output_60 = $grep_result_60_1;
            $output_60 = $grep_result_60_1;
            if ((scalar @grep_filtered_60_1) == 0) {
                $pipeline_success_60 = 0;
            }
            if ( !$pipeline_success_60 ) { $main_exit_code = 1; }
            $output_60 =~ s/\n+\z//msx;
            $output_60;
}; $_pipeline_result; };
}
    else {
        $NMCLI_OUT = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_62 = q{};
            my $output_printed_62;
            my $pipeline_success_62 = 1;
            my ($in_63, $out_63);
            my $pid_63 = open3($in_63, $out_63, '>&STDERR', 'nmcli', '-t', '-f', 'RUNNING', q{g});
            close $in_63 or croak 'Close failed: $OS_ERROR';
            $output_62 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_63> };
            close $out_63 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_63, 0;
            my $grep_result_62_1;
            my @grep_lines_62_1 = split /\n/msx, $output_62;
            my @grep_filtered_62_1 = grep { /^running$/msx } @grep_lines_62_1;
            $grep_result_62_1 = join "\n", @grep_filtered_62_1;
            if (!($grep_result_62_1 =~ m{\n\z}msx || $grep_result_62_1 eq q{})) {
            $grep_result_62_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_62_1 > 0 ? 0 : 1;
            $output_62 = $grep_result_62_1;
            $output_62 = $grep_result_62_1;
            if ((scalar @grep_filtered_62_1) == 0) {
                $pipeline_success_62 = 0;
            }
            if ( !$pipeline_success_62 ) { $main_exit_code = 1; }
            $output_62 =~ s/\n+\z//msx;
            $output_62;
}; $_pipeline_result; };
    }
"$NMCLI_OUT" ne q{}
    return;
}

sub networkmanager_knows_iface {
    my ($file) = @_;
    # Original bash: nmcli -t -f DEVICE d 2>&1 | grep -Fxq "$1"
{
        my $output_64 = q{};
        my $output_printed_64;
        my $pipeline_success_64 = 1;
                $output = q{};
                do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_65 = q{};

my $cmd_68 = 'nmcli';
my ($in_67, $out_67);
my $pid_67 = open3($in_67, $out_67, '>&STDERR', $cmd_68, '-t', '-f', 'DEVICE', q{d});
print {$in_67} $output_64;
close $in_67 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_65 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_67> };
close $out_67 or croak 'Close failed: $OS_ERROR';
waitpid $pid_67, 0;
$tmp_redirect_65;
        };
        $output_64 = $output;

                my $grep_result_64_1;
        my @grep_lines_64_1 = split /\n/msx, $output_64;
        my @grep_filtered_64_1 = grep { /$_[0]/msx } @grep_lines_64_1;
        $grep_result_64_1 = join "\n", @grep_filtered_64_1;
        if (!($grep_result_64_1 =~ m{\n\z}msx || $grep_result_64_1 eq q{})) {
        $grep_result_64_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_64_1 > 0 ? 0 : 1;
        $grep_result_64_1 = q{};
        $output_64 = q{};
        if ((scalar @grep_filtered_64_1) == 0) {
            $pipeline_success_64 = 0;
        }
        if ($output_64 ne q{} && !defined $output_printed_64) {
            print $output_64;
            if (!($output_64 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_64 ) { $main_exit_code = 1; }
        }
    return;
}

sub networkmanager_iface_is_unmanaged {
        is_interface("$_[0]");
    if ($CHILD_ERROR != 0) {
        return q{2};    }
        networkmanager_knows_iface("$_[0]");
    if ($CHILD_ERROR != 0) {
        return q{0};    }
        do {
        local %ENV = %ENV;
        my $VERSION = $VERSION;
        my $SCRIPT_UMASK = $SCRIPT_UMASK;
        my $COUNTER_LOCK_FILE = $COUNTER_LOCK_FILE;
        my $NETWORKMANAGER_CONF = $NETWORKMANAGER_CONF;
        my $PROGNAME = $PROGNAME;
        # Original bash: nmcli -t -f DEVICE,STATE d 2>&1 | grep -E "^$1:unmanaged$" > /dev/null 2>&1)
{
            my $output_69 = q{};
            my $output_printed_69;
            my $pipeline_success_69 = 1;
                        $output = q{};
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_70 = q{};

my $cmd_73 = 'nmcli';
my ($in_72, $out_72);
my $pid_72 = open3($in_72, $out_72, '>&STDERR', $cmd_73, '-t', '-f', 'DEVICE,STATE', q{d});
print {$in_72} $output_69;
close $in_72 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_70 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_72> };
close $out_72 or croak 'Close failed: $OS_ERROR';
waitpid $pid_72, 0;
$tmp_redirect_70;
            };
            $output_69 = $output;

                        my $grep_result_69_1;
            my @grep_lines_69_1 = split /\n/msx, $output_69;
            my @grep_filtered_69_1 = grep { /^$_[0]:unmanaged$/msx } @grep_lines_69_1;
            $grep_result_69_1 = join "\n", @grep_filtered_69_1;
            if (!($grep_result_69_1 =~ m{\n\z}msx || $grep_result_69_1 eq q{})) {
            $grep_result_69_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_69_1 > 0 ? 0 : 1;
            $output_69 = $grep_result_69_1;
            if ( !$pipeline_success_69 ) { $main_exit_code = 1; }
            }
        q{};
    };
    if ($CHILD_ERROR != 0) {
        return q{1};    }
    return;
}
my $ADDED_UNMANAGED;
my @ADDED_UNMANAGED;
my %ADDED_UNMANAGED;
$ADDED_UNMANAGED = q{};

sub networkmanager_add_unmanaged {
    my $MAC;
    my $UNMANAGED;
    my $WAS_EMPTY;
    my $x;
        networkmanager_exists();
    if ($CHILD_ERROR != 0) {
        return q{1};    }
    if (!((-d ${NETWORKMANAGER_CONF%/*}))) {
                use File::Path qw(make_path);
        my $err;
        if ( !-d dirname(${NETWORKMANAGER_CONF}) ) {
            make_path( dirname(${NETWORKMANAGER_CONF}), { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . dirname(${NETWORKMANAGER_CONF}) . ": $err->[0]\n";
            }
        }
    }
    if (!((-f ${NETWORKMANAGER_CONF}))) {
                if ( -e "$NETWORKMANAGER_CONF" ) {
            my $current_time = time;
            utime $current_time, $current_time, "$NETWORKMANAGER_CONF";
        }
        else {
            if ( open my $fh, '>', "$NETWORKMANAGER_CONF" ) {
                close $fh or croak "Close failed: $ERRNO";
            }
            else {
                croak "touch: cannot create ", "$NETWORKMANAGER_CONF",
                  ": $ERRNO\n";
            }
        }
    }
if (($NM_OLDER_VERSION == 1)) {
if ("$2" eq q{}) {
            $MAC = do {
    my ($in_76, $out_76);
    my $pid_76 = open3($in_76, $out_76, '>&STDERR', 'get_macaddr', "$_[0]");
    close $in_76 or croak 'Close failed: $OS_ERROR';
    my $result_76 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_76> };
    close $out_76 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_76, 0;
    $result_76
};
}
        else {
            $MAC = "$_[1]";
        }
        if ("$MAC" eq q{}) {
            return q{1};            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    }
    mutex_lock();
    $UNMANAGED = do { my $grep_result_77;
my @grep_lines_77 = ();
my @grep_filenames_77 = ();
if (-e "/etc/NetworkManager/NetworkManager.conf") {
    open my $fh, '<', "/etc/NetworkManager/NetworkManager.conf" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_77, $line;
        push @grep_filenames_77, "/etc/NetworkManager/NetworkManager.conf";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/NetworkManager/NetworkManager.conf: No such file or directory\n"; }
my @grep_filtered_77 = grep { /^unmanaged-devices=[[:alnum:]:;,-]*/msx } @grep_lines_77;
my @grep_matches_77;
foreach my $line (@grep_filtered_77) {
    if ($line =~ /(^unmanaged-devices=[[:alnum:]:;,-]*)/msx) {
        push @grep_matches_77, $1;
    }
}
$grep_result_77 = join "\n", @grep_matches_77;
$CHILD_ERROR = scalar @grep_filtered_77 > 0 ? 0 : 1;
 $grep_result_77; };
    $WAS_EMPTY = q{0};
    if ("$UNMANAGED" eq q{}) {
                $WAS_EMPTY = q{1};
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    $UNMANAGED = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_78 = q{};
        my $output_printed_78;
        my $pipeline_success_78 = 1;
        $output_78 .= $UNMANAGED . "\n";
        if ( !($output_78 =~ m{\n\z}msx) ) { $output_78 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_78 = 0; }
        my @sed_lines_78 = split /\n/msx, $output_78;
        my @sed_result_78;
        foreach my $line (@sed_lines_78) {
        chomp $line;
        $line =~ s/unmanaged-devices=//gmsx;
        push @sed_result_78, $line;
        }
        $output_78 = join "\n", @sed_result_78;

        my $set1_79 = ';,';
        my $set2_79 = q{ };
        my $input_79 = $output_78;
        # Expand character ranges for tr command
        my $expanded_set1_79 = $set1_79;
        my $expanded_set2_79 = $set2_79;
        # Handle a-z range in set1
        if ($expanded_set1_79 =~ /a-z/msx) {
            $expanded_set1_79 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_79 =~ /A-Z/msx) {
            $expanded_set1_79 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_79 =~ /\[:upper:\]/msx) {
            $expanded_set1_79 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_79 =~ /\[:lower:\]/msx) {
            $expanded_set1_79 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_79 =~ /a-z/msx) {
            $expanded_set2_79 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_79 =~ /A-Z/msx) {
            $expanded_set2_79 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_79 =~ /\[:upper:\]/msx) {
            $expanded_set2_79 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_79 =~ /\[:lower:\]/msx) {
            $expanded_set2_79 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_78_2 = q{};
        for my $char ( split //msx, $input_79 ) {
            my $pos_79 = index $expanded_set1_79, $char;
            if ( $pos_79 >= 0 && $pos_79 < length $expanded_set2_79 ) {
                $tr_result_78_2 .= substr $expanded_set2_79, $pos_79, 1;
            } else {
                $tr_result_78_2 .= $char;
            }
        }
                if (!($tr_result_78_2 =~ m{\n\z}msx || $tr_result_78_2 eq q{})) {
                    $tr_result_78_2 .= "\n";
                }
                $output_78 = $tr_result_78_2;
        if ( !$pipeline_success_78 ) { $main_exit_code = 1; }
        $output_78 =~ s/\n+\z//msx;
        $output_78;
}; $_pipeline_result; };
    for my $x ($UNMANAGED) {
if (($x =~ /^"mac:[$]{MAC}"$/msx || (($NM_OLDER_VERSION == 0) && $x =~ /^"interface-name:[$]{1}"$/msx))) {
            mutex_unlock();
return q{2};
        }
    }
if (($NM_OLDER_VERSION == 1)) {
        $UNMANAGED = ${UNMANAGED} . " mac:" . ${MAC};
}
    else {
        $UNMANAGED = ${UNMANAGED} . " interface-name:" . $_[0];
    }
    $UNMANAGED = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_80 = q{};
        my $output_printed_80;
        my $pipeline_success_80 = 1;
        $output_80 .= $UNMANAGED . "\n";
        if ( !($output_80 =~ m{\n\z}msx) ) { $output_80 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_80 = 0; }
        my @sed_lines_80 = split /\n/msx, $output_80;
        my @sed_result_80;
        foreach my $line (@sed_lines_80) {
        chomp $line;
        push @sed_result_80, $line;
        }
        $output_80 = join "\n", @sed_result_80;

        if ( !$pipeline_success_80 ) { $main_exit_code = 1; }
        $output_80 =~ s/\n+\z//msx;
        $output_80;
}; $_pipeline_result; };
    $UNMANAGED = $UNMANAGED =~ s/ /;/grs;
    $UNMANAGED = "unmanaged-devices=" . ${UNMANAGED};
if (!(!(do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $grep_result_81;
my @grep_lines_81 = ();
my @grep_filtered_81 = grep { /^[\[]keyfile[\]]/msx } @grep_lines_81;
$grep_result_81 = join "\n", @grep_filtered_81;
        if (!($grep_result_81 =~ m{\n\z}msx || $grep_result_81 eq q{})) {
            $grep_result_81 .= "\n";
        }
print $grep_result_81;
$CHILD_ERROR = scalar @grep_filtered_81 > 0 ? 0 : 1;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };))) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $NETWORKMANAGER_CONF
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "\n\n[keyfile]\n${UNMANAGED}";
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
    else {
        if (($WAS_EMPTY == 1)) {
my @sed_lines_82 = split /\n/msx, $;
my @sed_result_82;
foreach my $line (@sed_lines_82) {
chomp $line;
push @sed_result_82, $line;
}
$ = join "\n", @sed_result_82;

}
        else {
my @sed_lines_83 = split /\n/msx, $;
my @sed_result_83;
foreach my $line (@sed_lines_83) {
chomp $line;
push @sed_result_83, $line;
}
$ = join "\n", @sed_result_83;

        }
    }
    $ADDED_UNMANAGED = ${ADDED_UNMANAGED} . " " . $_[0] . " ";
    mutex_unlock();
    my $nm_pid = do {
    my ($in_84, $out_84);
    my $pid_84 = open3($in_84, $out_84, '>&STDERR', 'pidof', 'NetworkManager');
    close $in_84 or croak 'Close failed: $OS_ERROR';
    my $result_84 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_84> };
    close $out_84 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_84, 0;
    $result_84
};
    if ("$nm_pid" ne q{}) {
        my $signal = 'HUP';
my @pids = ($nm_pid);
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
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
return q{0};
    return;
}

sub networkmanager_rm_unmanaged {
    my $MAC;
    my $UNMANAGED;
        networkmanager_exists();
    if ($CHILD_ERROR != 0) {
        return q{1};    }
    if ((!-f ${NETWORKMANAGER_CONF})) {
        return q{1};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if (($NM_OLDER_VERSION == 1)) {
if ("$2" eq q{}) {
            $MAC = do {
    my ($in_86, $out_86);
    my $pid_86 = open3($in_86, $out_86, '>&STDERR', 'get_macaddr', "$_[0]");
    close $in_86 or croak 'Close failed: $OS_ERROR';
    my $result_86 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_86> };
    close $out_86 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_86, 0;
    $result_86
};
}
        else {
            $MAC = "$_[1]";
        }
        if ("$MAC" eq q{}) {
            return q{1};            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    }
    mutex_lock();
    $UNMANAGED = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_87 = q{};
        my $output_printed_87;
        my $pipeline_success_87 = 1;
        my $grep_result_87_0;
        my @grep_lines_87_0 = ();
        my @grep_filenames_87_0 = ();
        if (-e "/etc/NetworkManager/NetworkManager.conf") {
            open my $fh, '<', "/etc/NetworkManager/NetworkManager.conf" or croak "Cannot open file: $ERRNO";
            while (my $line = <$fh>) {
                chomp $line;
                push @grep_lines_87_0, $line;
                push @grep_filenames_87_0, "/etc/NetworkManager/NetworkManager.conf";
            }
            close $fh
                or croak "Close failed: $OS_ERROR";
        }
        else { print {*STDERR} "grep: /etc/NetworkManager/NetworkManager.conf: No such file or directory\n"; }
        my @grep_filtered_87_0 = grep { /^unmanaged-devices=[[:alnum:]:;,-]*/msx } @grep_lines_87_0;
        my @grep_matches_87_0;
        foreach my $line (@grep_filtered_87_0) {
            if ($line =~ /(^unmanaged-devices=[[:alnum:]:;,-]*)/msx) {
                push @grep_matches_87_0, $1;
            }
        }
        $grep_result_87_0 = join "\n", @grep_matches_87_0;
        $CHILD_ERROR = scalar @grep_filtered_87_0 > 0 ? 0 : 1;
        $output_87 = $grep_result_87_0;
        if ($CHILD_ERROR != 0) { $pipeline_success_87 = 0; }
        my @sed_lines_87 = split /\n/msx, $output_87;
        my @sed_result_87;
        foreach my $line (@sed_lines_87) {
        chomp $line;
        $line =~ s/unmanaged-devices=//gmsx;
        push @sed_result_87, $line;
        }
        $output_87 = join "\n", @sed_result_87;

        my $set1_88 = ';,';
        my $set2_88 = q{ };
        my $input_88 = $output_87;
        # Expand character ranges for tr command
        my $expanded_set1_88 = $set1_88;
        my $expanded_set2_88 = $set2_88;
        # Handle a-z range in set1
        if ($expanded_set1_88 =~ /a-z/msx) {
            $expanded_set1_88 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_88 =~ /A-Z/msx) {
            $expanded_set1_88 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_88 =~ /\[:upper:\]/msx) {
            $expanded_set1_88 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_88 =~ /\[:lower:\]/msx) {
            $expanded_set1_88 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_88 =~ /a-z/msx) {
            $expanded_set2_88 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_88 =~ /A-Z/msx) {
            $expanded_set2_88 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_88 =~ /\[:upper:\]/msx) {
            $expanded_set2_88 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_88 =~ /\[:lower:\]/msx) {
            $expanded_set2_88 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_87_2 = q{};
        for my $char ( split //msx, $input_88 ) {
            my $pos_88 = index $expanded_set1_88, $char;
            if ( $pos_88 >= 0 && $pos_88 < length $expanded_set2_88 ) {
                $tr_result_87_2 .= substr $expanded_set2_88, $pos_88, 1;
            } else {
                $tr_result_87_2 .= $char;
            }
        }
                if (!($tr_result_87_2 =~ m{\n\z}msx || $tr_result_87_2 eq q{})) {
                    $tr_result_87_2 .= "\n";
                }
                $output_87 = $tr_result_87_2;
        if ( !$pipeline_success_87 ) { $main_exit_code = 1; }
        $output_87 =~ s/\n+\z//msx;
        $output_87;
}; $_pipeline_result; };
if ("$UNMANAGED" eq q{}) {
        mutex_unlock();
return q{1};
    }
    if ("$MAC" ne q{}) {
                $UNMANAGED = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_89 = q{};
            my $output_printed_89;
            my $pipeline_success_89 = 1;
            $output_89 .= $UNMANAGED . "\n";
            if ( !($output_89 =~ m{\n\z}msx) ) { $output_89 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_89 = 0; }
            my @sed_lines_89 = split /\n/msx, $output_89;
            my @sed_result_89;
            foreach my $line (@sed_lines_89) {
            chomp $line;
            push @sed_result_89, $line;
            }
            $output_89 = join "\n", @sed_result_89;

            if ( !$pipeline_success_89 ) { $main_exit_code = 1; }
            $output_89 =~ s/\n+\z//msx;
            $output_89;
}; $_pipeline_result; };
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    $UNMANAGED = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_90 = q{};
        my $output_printed_90;
        my $pipeline_success_90 = 1;
        $output_90 .= $UNMANAGED . "\n";
        if ( !($output_90 =~ m{\n\z}msx) ) { $output_90 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_90 = 0; }
        my @sed_lines_90 = split /\n/msx, $output_90;
        my @sed_result_90;
        foreach my $line (@sed_lines_90) {
        chomp $line;
        push @sed_result_90, $line;
        }
        $output_90 = join "\n", @sed_result_90;

        if ( !$pipeline_success_90 ) { $main_exit_code = 1; }
        $output_90 =~ s/\n+\z//msx;
        $output_90;
}; $_pipeline_result; };
    $UNMANAGED = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_91 = q{};
        my $output_printed_91;
        my $pipeline_success_91 = 1;
        $output_91 .= $UNMANAGED . "\n";
        if ( !($output_91 =~ m{\n\z}msx) ) { $output_91 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_91 = 0; }
        my @sed_lines_91 = split /\n/msx, $output_91;
        my @sed_result_91;
        foreach my $line (@sed_lines_91) {
        chomp $line;
        push @sed_result_91, $line;
        }
        $output_91 = join "\n", @sed_result_91;

        if ( !$pipeline_success_91 ) { $main_exit_code = 1; }
        $output_91 =~ s/\n+\z//msx;
        $output_91;
}; $_pipeline_result; };
if ("$UNMANAGED" eq q{}) {
my @sed_lines_92 = split /\n/msx, $;
my @sed_result_92;
foreach my $line (@sed_lines_92) {
chomp $line;
push @sed_result_92, $line;
}
$ = join "\n", @sed_result_92;

}
    else {
        $UNMANAGED = $UNMANAGED =~ s/ /;/grs;
        $UNMANAGED = "unmanaged-devices=" . ${UNMANAGED};
my @sed_lines_93 = split /\n/msx, $;
my @sed_result_93;
foreach my $line (@sed_lines_93) {
chomp $line;
push @sed_result_93, $line;
}
$ = join "\n", @sed_result_93;

    }
    $ADDED_UNMANAGED = $ENV{'ADDED_UNMANAGED/ ${1} /'};
    mutex_unlock();
    my $nm_pid = do {
    my ($in_94, $out_94);
    my $pid_94 = open3($in_94, $out_94, '>&STDERR', 'pidof', 'NetworkManager');
    close $in_94 or croak 'Close failed: $OS_ERROR';
    my $result_94 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_94> };
    close $out_94 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_94, 0;
    $result_94
};
    if ("$nm_pid" ne q{}) {
        my $signal = 'HUP';
my @pids = ($nm_pid);
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
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
return q{0};
    return;
}

sub networkmanager_fix_unmanaged {
    if (!((-f ${NETWORKMANAGER_CONF}))) {
        return;    }
    mutex_lock();
my @sed_lines_96 = split /\n/msx, $;
my @sed_result_96;
foreach my $line (@sed_lines_96) {
chomp $line;
push @sed_result_96, $line;
}
$ = join "\n", @sed_result_96;

    mutex_unlock();
    my $nm_pid = do {
    my ($in_97, $out_97);
    my $pid_97 = open3($in_97, $out_97, '>&STDERR', 'pidof', 'NetworkManager');
    close $in_97 or croak 'Close failed: $OS_ERROR';
    my $result_97 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_97> };
    close $out_97 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_97, 0;
    $result_97
};
    if ("$nm_pid" ne q{}) {
        my $signal = 'HUP';
my @pids = ($nm_pid);
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
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    return;
}

sub networkmanager_rm_unmanaged_if_needed {
    if ($ADDED_UNMANAGED =~ /.*[$]{1}[.]*/msx) {
                networkmanager_rm_unmanaged($1, $2);
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    return;
}

sub networkmanager_wait_until_unmanaged {
    my $RES;
        networkmanager_is_running();
    if ($CHILD_ERROR != 0) {
        return q{1};    }
while (     $main_exit_code = system('bash', ':') >> 8 ) {
        networkmanager_iface_is_unmanaged("$_[0]");
        $RES = $?;
        if (($RES == 0)) {
            last;            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if (($RES == 2)) {
                        $main_exit_code = system('die', "Interface '" . $_[0] . "' does not exist.
       It's probably renamed by a udev rule.") >> 8;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
require Time::HiRes; Time::HiRes::sleep(q{1});
    }
require Time::HiRes; Time::HiRes::sleep(q{2});
return q{0};
    return;
}
$CHANNEL = 'default';
my $GATEWAY;
my @GATEWAY;
my %GATEWAY;
$GATEWAY = '192.168.12.1';
$WPA_VERSION = '1+2';
$ETC_HOSTS = q{0};
$ADDN_HOSTS = q{};
$DHCP_DNS = 'gateway';
$NO_DNS = q{0};
$NO_DNSMASQ = q{0};
my $DNS_PORT;
my @DNS_PORT;
my %DNS_PORT;
$DNS_PORT = q{};
$HIDDEN = q{0};
$MAC_FILTER = q{0};
my $MAC_FILTER_ACCEPT;
my @MAC_FILTER_ACCEPT;
my %MAC_FILTER_ACCEPT;
$MAC_FILTER_ACCEPT = '/etc/hostapd/hostapd.accept';
$ISOLATE_CLIENTS = q{0};
$SHARE_METHOD = 'nat';
$IEEE80211N = q{0};
$IEEE80211AC = q{0};
my $HT_CAPAB;
my @HT_CAPAB;
my %HT_CAPAB;
$HT_CAPAB = '[HT40+]';
$VHT_CAPAB = q{};
$DRIVER = 'nl80211';
$NO_VIRT = q{0};
$COUNTRY = q{};
$FREQ_BAND = '2.4';
$NEW_MACADDR = q{};
$DAEMONIZE = q{0};
$DAEMON_PIDFILE = q{};
my $DAEMON_LOGFILE;
my @DAEMON_LOGFILE;
my %DAEMON_LOGFILE;
$DAEMON_LOGFILE = '/dev/null';
$NO_HAVEGED = q{0};
$USE_PSK = q{0};
my $HOSTAPD_DEBUG_ARGS;
my @HOSTAPD_DEBUG_ARGS;
my %HOSTAPD_DEBUG_ARGS;
$HOSTAPD_DEBUG_ARGS = q{};
$REDIRECT_TO_LOCALHOST = q{0};
my $CONFIG_OPTS;
my @CONFIG_OPTS = ('CHANNEL', 'GATEWAY', 'WPA_VERSION', 'ETC_HOSTS', 'DHCP_DNS', 'NO_DNS', 'NO_DNSMASQ', 'HIDDEN', 'MAC_FILTER', 'MAC_FILTER_ACCEPT', 'ISOLATE_CLIENTS', 'SHARE_METHOD', 'IEEE80211N', 'IEEE80211AC', 'HT_CAPAB', 'VHT_CAPAB', 'DRIVER', 'NO_VIRT', 'COUNTRY', 'FREQ_BAND', 'NEW_MACADDR', 'DAEMONIZE', 'DAEMON_PIDFILE', 'DAEMON_LOGFILE', 'NO_HAVEGED', 'WIFI_IFACE', 'INTERNET_IFACE', 'SSID', 'PASSPHRASE', 'USE_PSK');
my %CONFIG_OPTS;
$FIX_UNMANAGED = q{0};
$LIST_RUNNING = q{0};
$STOP_ID = q{};
$LIST_CLIENTS_ID = q{};
$STORE_CONFIG = q{};
$LOAD_CONFIG = q{};
my $CONFDIR;
my @CONFDIR;
my %CONFDIR;
$CONFDIR = q{};
$WIFI_IFACE = q{};
my $VWIFI_IFACE;
my @VWIFI_IFACE;
my %VWIFI_IFACE;
$VWIFI_IFACE = q{};
$INTERNET_IFACE = q{};
my $BRIDGE_IFACE;
my @BRIDGE_IFACE;
my %BRIDGE_IFACE;
$BRIDGE_IFACE = q{};
$OLD_MACADDR = q{};
my $IP_ADDRS;
my @IP_ADDRS;
my %IP_ADDRS;
$IP_ADDRS = q{};
my $ROUTE_ADDRS;
my @ROUTE_ADDRS;
my %ROUTE_ADDRS;
$ROUTE_ADDRS = q{};
my $HAVEGED_WATCHDOG_PID;
my @HAVEGED_WATCHDOG_PID;
my %HAVEGED_WATCHDOG_PID;
$HAVEGED_WATCHDOG_PID = q{};

sub _cleanup {
    my $PID;
    my $x;
$SIG{SIGINT} = sub { qx''; };
    mutex_lock();
    $main_exit_code = system('disown', '-a') >> 8;
    if ("$HAVEGED_WATCHDOG_PID" ne q{}) {
        my $signal = 'TERM';
my @pids = ($HAVEGED_WATCHDOG_PID);
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
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    for my $x ($CONFDIR, '/*.pid') {
        if ((-f $x)) {
            my $signal = '9';
my @pids = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $x ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $x . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
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
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    }
    $x = '/*.pid';
if ( -e "$CONFDIR" ) {
        if ( -d "$CONFDIR" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$CONFDIR", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", $CONFDIR, ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$CONFDIR" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $CONFDIR,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    my $found = "0";
    for my $x (do {
    my ($in_103, $out_103);
    my $pid_103 = open3($in_103, $out_103, '>&STDERR', 'list_running_conf');
    close $in_103 or croak 'Close failed: $OS_ERROR';
    my $result_103 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_103> };
    close $out_103 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_103, 0;
    $result_103
}) {
if (((-f $x/nat_internet_iface) && $(cat $x/nat_internet_iface) =~ /^[$]INTERNET_IFACE$/msx)) {
            $found = q{1};
last;
        }
    }
if (($found == 0)) {
        use File::Copy qw(copy);
        if ( -e $COMMON_CONFDIR ) {
            if ( -d '/forwarding' ) {
                require File::Copy; File::Copy::copy($COMMON_CONFDIR, '/forwarding' . '/' . ($COMMON_CONFDIR =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy($COMMON_CONFDIR, '/forwarding');
            }
        } else {
            croak "cp: cannot stat '-f': No such file or directory\n";
        }
        if ( -e q{/} ) {
            if ( -d '/forwarding' ) {
                require File::Copy; File::Copy::copy(q{/}, '/forwarding' . '/' . (q{/} =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy(q{/}, '/forwarding');
            }
        } else {
            croak "cp: cannot stat '-f': No such file or directory\n";
        }
        if ( -e $INTERNET_IFACE ) {
            if ( -d '/forwarding' ) {
                require File::Copy; File::Copy::copy($INTERNET_IFACE, '/forwarding' . '/' . ($INTERNET_IFACE =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy($INTERNET_IFACE, '/forwarding');
            }
        } else {
            croak "cp: cannot stat '-f': No such file or directory\n";
        }
        if ( -e '_forwarding' ) {
            if ( -d '/forwarding' ) {
                require File::Copy; File::Copy::copy('_forwarding', '/forwarding' . '/' . ('_forwarding' =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy('_forwarding', '/forwarding');
            }
        } else {
            croak "cp: cannot stat '-f': No such file or directory\n";
        }
        if ( -e '/proc/sys/net/ipv4/conf/' ) {
            if ( -d '/forwarding' ) {
                require File::Copy; File::Copy::copy('/proc/sys/net/ipv4/conf/', '/forwarding' . '/' . ('/proc/sys/net/ipv4/conf/' =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy('/proc/sys/net/ipv4/conf/', '/forwarding');
            }
        } else {
            croak "cp: cannot stat '-f': No such file or directory\n";
        }
        if ( -e $INTERNET_IFACE ) {
            if ( -d '/forwarding' ) {
                require File::Copy; File::Copy::copy($INTERNET_IFACE, '/forwarding' . '/' . ($INTERNET_IFACE =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy($INTERNET_IFACE, '/forwarding');
            }
        } else {
            croak "cp: cannot stat '-f': No such file or directory\n";
        }
if ( -e "$COMMON_CONFDIR" ) {
            if ( -d "$COMMON_CONFDIR" ) {
                carp "rm: carping: ", $COMMON_CONFDIR,
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$COMMON_CONFDIR" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", $COMMON_CONFDIR,
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "/" ) {
            if ( -d "/" ) {
                carp "rm: carping: ", "/",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "/" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "$INTERNET_IFACE" ) {
            if ( -d "$INTERNET_IFACE" ) {
                carp "rm: carping: ", $INTERNET_IFACE,
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$INTERNET_IFACE" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", $INTERNET_IFACE,
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "_forwarding" ) {
            if ( -d "_forwarding" ) {
                carp "rm: carping: ", "_forwarding",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "_forwarding" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "_forwarding",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
if (!(!($main_exit_code = system('bash', 'has_running_instance') >> 8;))) {
        for my $x ($COMMON_CONFDIR, '/*.pid') {
            if ((-f $x)) {
                my $signal = '9';
my @pids = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $x ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $x . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
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
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
        }
        $x = '/*.pid';
if ((-f $COMMON_CONFDIR/ip_forward)) {
            use File::Copy qw(copy);
            if ( -e $COMMON_CONFDIR ) {
                if ( -d '/proc/sys/net/ipv4' ) {
                    require File::Copy; File::Copy::copy($COMMON_CONFDIR, '/proc/sys/net/ipv4' . '/' . ($COMMON_CONFDIR =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy($COMMON_CONFDIR, '/proc/sys/net/ipv4');
                }
            } else {
                croak "cp: cannot stat '-f': No such file or directory\n";
            }
            if ( -e '/ip_forward' ) {
                if ( -d '/proc/sys/net/ipv4' ) {
                    require File::Copy; File::Copy::copy('/ip_forward', '/proc/sys/net/ipv4' . '/' . ('/ip_forward' =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy('/ip_forward', '/proc/sys/net/ipv4');
                }
            } else {
                croak "cp: cannot stat '-f': No such file or directory\n";
            }
if ( -e "$COMMON_CONFDIR" ) {
                if ( -d "$COMMON_CONFDIR" ) {
                    carp "rm: carping: ", $COMMON_CONFDIR,
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$COMMON_CONFDIR" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", $COMMON_CONFDIR,
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
if ( -e "/ip_forward" ) {
                if ( -d "/ip_forward" ) {
                    carp "rm: carping: ", "/ip_forward",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "/ip_forward" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "/ip_forward",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
if ((-f $COMMON_CONFDIR/bridge-nf-call-iptables)) {
if ((-e '/proc/sys/net/bridge/bridge-nf-call-iptables')) {
                use File::Copy qw(copy);
                if ( -e $COMMON_CONFDIR ) {
                    if ( -d '/proc/sys/net/bridge' ) {
                        require File::Copy; File::Copy::copy($COMMON_CONFDIR, '/proc/sys/net/bridge' . '/' . ($COMMON_CONFDIR =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy($COMMON_CONFDIR, '/proc/sys/net/bridge');
                    }
                } else {
                    croak "cp: cannot stat '-f': No such file or directory\n";
                }
                if ( -e '/bridge-nf-call-iptables' ) {
                    if ( -d '/proc/sys/net/bridge' ) {
                        require File::Copy; File::Copy::copy('/bridge-nf-call-iptables', '/proc/sys/net/bridge' . '/' . ('/bridge-nf-call-iptables' =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy('/bridge-nf-call-iptables', '/proc/sys/net/bridge');
                    }
                } else {
                    croak "cp: cannot stat '-f': No such file or directory\n";
                }
            }
if ( -e "$COMMON_CONFDIR" ) {
                if ( -d "$COMMON_CONFDIR" ) {
                    carp "rm: carping: ", $COMMON_CONFDIR,
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$COMMON_CONFDIR" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", $COMMON_CONFDIR,
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
if ( -e "/bridge-nf-call-iptables" ) {
                if ( -d "/bridge-nf-call-iptables" ) {
                    carp "rm: carping: ", "/bridge-nf-call-iptables",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "/bridge-nf-call-iptables" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "/bridge-nf-call-iptables",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
if ( -e "$COMMON_CONFDIR" ) {
            if ( -d "$COMMON_CONFDIR" ) {
                my $err;
                require File::Path;
                File::Path::remove_tree("$COMMON_CONFDIR", {error => \$err});
                if (@{$err}) {
                    carp "rm: carping: could not remove ", $COMMON_CONFDIR, ": $err->[0]\n";
                }
                else {
                                    }
            }
            else {
                if ( unlink "$COMMON_CONFDIR" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", $COMMON_CONFDIR,
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
if ("$SHARE_METHOD" ne "none") {
if ("$SHARE_METHOD" =~ /^"nat"$/msx) {
            $main_exit_code = system('iptables', '-w', '-t', 'nat', '-D', 'POSTROUTING', '-s', scalar reverse( (scalar reverse ${GATEWAY}) =~ s/^.*?\.//r ), '.0/24', q{!}, '-o', $WIFI_IFACE, '-j', 'MASQUERADE') >> 8;
            $main_exit_code = system('iptables', '-w', '-D', 'FORWARD', '-i', $WIFI_IFACE, '-s', scalar reverse( (scalar reverse ${GATEWAY}) =~ s/^.*?\.//r ), '.0/24', '-j', 'ACCEPT') >> 8;
            $main_exit_code = system('iptables', '-w', '-D', 'FORWARD', '-i', $INTERNET_IFACE, '-d', scalar reverse( (scalar reverse ${GATEWAY}) =~ s/^.*?\.//r ), '.0/24', '-j', 'ACCEPT') >> 8;
}
        else {
            if ("$SHARE_METHOD" =~ /^"bridge"$/msx) {
if (!(!(is_bridge_interface($INTERNET_IFACE);))) {
                    $main_exit_code = system('ip', 'link', 'set', 'dev', $BRIDGE_IFACE, 'down') >> 8;
                    $main_exit_code = system('ip', 'link', 'set', 'dev', $INTERNET_IFACE, 'down') >> 8;
                    $main_exit_code = system('ip', 'link', 'set', 'dev', $INTERNET_IFACE, 'promisc', 'off') >> 8;
                    $main_exit_code = system('ip', 'link', 'set', 'dev', $INTERNET_IFACE, 'nomaster') >> 8;
                    $main_exit_code = system('ip', 'link', 'delete', $BRIDGE_IFACE, 'type', 'bridge') >> 8;
                    $main_exit_code = system('ip', 'addr', 'flush', $INTERNET_IFACE) >> 8;
                    $main_exit_code = system('ip', 'link', 'set', 'dev', $INTERNET_IFACE, 'up') >> 8;
                    dealloc_iface($BRIDGE_IFACE);
                    for my $x (@IP_ADDRS) {
                        $x = ($ENV{x/inet/} // q{});
                        $x = ($ENV{x/secondary/} // q{});
                        $x = ($ENV{x/dynamic/} // q{});
                        $x = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                            my $output_108 = q{};
                            my $output_printed_108;
                            my $pipeline_success_108 = 1;
                            $output_108 .= $x . "\n";
                            if ( !($output_108 =~ m{\n\z}msx) ) { $output_108 .= "\n"; }
                            $CHILD_ERROR = 0;
                            if ($CHILD_ERROR != 0) { $pipeline_success_108 = 0; }
                            my @sed_lines_108 = split /\n/msx, $output_108;
                            my @sed_result_108;
                            foreach my $line (@sed_lines_108) {
                            chomp $line;
                            $line =~ s/\([0-9]\)sec/\1/gmsx;
                            push @sed_result_108, $line;
                            }
                            $output_108 = join "\n", @sed_result_108;

                            if ( !$pipeline_success_108 ) { $main_exit_code = 1; }
                            $output_108 =~ s/\n+\z//msx;
                            $output_108;
}; $_pipeline_result; };
                        $x = $ENV{'x/${INTERNET_IFACE}/'};
                        $main_exit_code = system('ip', 'addr', 'add', $x, 'dev', $INTERNET_IFACE) >> 8;
                    }
                    $main_exit_code = system('ip', 'route', 'flush', 'dev', $INTERNET_IFACE) >> 8;
                    for my $x (@ROUTE_ADDRS) {
                        if ("$x" eq q{}) {
                            next;                            $CHILD_ERROR = 0;
                        } else {
                            $CHILD_ERROR = 1;
                        }
                        if ("$x" =~ /^default.*$/msx) {
                            next;                            $CHILD_ERROR = 0;
                        } else {
                            $CHILD_ERROR = 1;
                        }
                        $main_exit_code = system('ip', 'route', 'add', $x, 'dev', $INTERNET_IFACE) >> 8;
                    }
                    for my $x (@ROUTE_ADDRS) {
                        if ("$x" eq q{}) {
                            next;                            $CHILD_ERROR = 0;
                        } else {
                            $CHILD_ERROR = 1;
                        }
                        if ("$x" ne default*) {
                            next;                            $CHILD_ERROR = 0;
                        } else {
                            $CHILD_ERROR = 1;
                        }
                        $main_exit_code = system('ip', 'route', 'add', $x, 'dev', $INTERNET_IFACE) >> 8;
                    }
                    networkmanager_rm_unmanaged_if_needed($INTERNET_IFACE);
                }
            }
        }
    }
if ("$SHARE_METHOD" ne "bridge") {
if (($NO_DNS == 0)) {
            $main_exit_code = system('iptables', '-w', '-D', 'INPUT', '-p', 'tcp', '-m', 'tcp', '--dport', $DNS_PORT, '-j', 'ACCEPT') >> 8;
            $main_exit_code = system('iptables', '-w', '-D', 'INPUT', '-p', 'udp', '-m', 'udp', '--dport', $DNS_PORT, '-j', 'ACCEPT') >> 8;
            $main_exit_code = system('iptables', '-w', '-t', 'nat', '-D', 'PREROUTING', '-s', scalar reverse( (scalar reverse ${GATEWAY}) =~ s/^.*?\.//r ), '.0/24', '-d', $GATEWAY, '-p', 'tcp', '-m', 'tcp', '--dport', '53', '-j', 'REDIRECT', '--to-ports', $DNS_PORT) >> 8;
            $main_exit_code = system('iptables', '-w', '-t', 'nat', '-D', 'PREROUTING', '-s', scalar reverse( (scalar reverse ${GATEWAY}) =~ s/^.*?\.//r ), '.0/24', '-d', $GATEWAY, '-p', 'udp', '-m', 'udp', '--dport', '53', '-j', 'REDIRECT', '--to-ports', $DNS_PORT) >> 8;
        }
        $main_exit_code = system('iptables', '-w', '-D', 'INPUT', '-p', 'udp', '-m', 'udp', '--dport', '67', '-j', 'ACCEPT') >> 8;
    }
if (($NO_VIRT == 0)) {
if ("$VWIFI_IFACE" ne q{}) {
            $main_exit_code = system('ip', 'link', 'set', 'down', 'dev', $VWIFI_IFACE) >> 8;
            $main_exit_code = system('ip', 'addr', 'flush', $VWIFI_IFACE) >> 8;
            networkmanager_rm_unmanaged_if_needed($VWIFI_IFACE, $OLD_MACADDR);
            $main_exit_code = system('iw', 'dev', $VWIFI_IFACE, 'del') >> 8;
            dealloc_iface($VWIFI_IFACE);
        }
}
    else {
        $main_exit_code = system('ip', 'link', 'set', 'down', 'dev', $WIFI_IFACE) >> 8;
        $main_exit_code = system('ip', 'addr', 'flush', $WIFI_IFACE) >> 8;
if ("$NEW_MACADDR" ne q{}) {
            $main_exit_code = system('ip', 'link', 'set', 'dev', $WIFI_IFACE, 'address', $OLD_MACADDR) >> 8;
        }
        networkmanager_rm_unmanaged_if_needed($WIFI_IFACE, $OLD_MACADDR);
    }
    mutex_unlock();
    cleanup_lock();
if (0) {
if ( -e "$DAEMON_PIDFILE" ) {
            if ( -d "$DAEMON_PIDFILE" ) {
                croak "rm: ", $DAEMON_PIDFILE,
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$DAEMON_PIDFILE" ) {
                                    }
                else {
                    croak "rm: cannot remove ", $DAEMON_PIDFILE,
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 1;
            croak "rm: ", $DAEMON_PIDFILE, ": No such file or directory\n";
        }
    }
    return;
}

sub cleanup {
    print "\n";
    $CHILD_ERROR = 0;
    print "Doing cleanup.. ";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        _cleanup();
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    print "done\n";
    return;
}

sub die {
    if ("$1" ne q{}) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "\nERROR: $1\n";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if (($BASHPID != $$)) {
        my $signal = 'USR2';
my @pids = ($$);
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
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
exit 1;
    return;
}

sub clean_exit {
    if (($BASHPID != $$)) {
        my $signal = 'USR1';
my @pids = ($$);
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
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
exit 0;
    return;
}

sub list_running_conf {
    my $x;
    mutex_lock();
    for my $x ('/tmp/create_ap.*') {
if (0) {
            print $x;
if ( !( ($x) =~ m{\n\z}msx ) ) { print "\n"; }
        }
    }
    mutex_unlock();
    return;
}

sub list_running {
    my $IFACE;
    my $wifi_iface;
    my $x;
    mutex_lock();
    for my $x (do {
    my ($in_111, $out_111);
    my $pid_111 = open3($in_111, $out_111, '>&STDERR', 'list_running_conf');
    close $in_111 or croak 'Close failed: $OS_ERROR';
    my $result_111 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_111> };
    close $out_111 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_111, 0;
    $result_111
}) {
        $IFACE = ${x} =~ s/^.*?\.//r;
        $IFACE = ${IFACE} =~ s/\..*$//sr;
        $wifi_iface = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $x ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $x . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/wifi_iface' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/wifi_iface' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
if ($IFACE =~ /^[$]wifi_iface$/msx) {
            do {
    my $__echo_line = join(" ", grep { length } split /\s+/msx, (do { my $cat_chunk = q{}; if ( open my $fh, '<', $x ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $x . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/pid' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/pid' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; })) . q{ } . $IFACE;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
}
        else {
            do {
    my $__echo_line = join(" ", grep { length } split /\s+/msx, (do { my $cat_chunk = q{}; if ( open my $fh, '<', $x ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $x . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/pid' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/pid' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; })) . q{ } . $IFACE . q{ } . q{(} . q{ } . join(" ", grep { length } split /\s+/msx, (do { my $cat_chunk = q{}; if ( open my $fh, '<', $x ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $x . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/wifi_iface' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/wifi_iface' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; })) . q{ } . q{)};
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
    }
    mutex_unlock();
    return;
}

sub get_wifi_iface_from_pid {
    my ($file) = @_;
    # Original bash: list_running | awk '{print $1 " " $NF}' | tr -d '\(\)' | grep -E "^${1} " | cut -d' ' -f2
{
        my $output_112 = q{};
        my $output_printed_112;
        my $pipeline_success_112 = 1;
                my ($in_113, $out_113);
        my $pid_113 = open3($in_113, $out_113, '>&STDERR', 'list_running', );
        close $in_113 or croak 'Close failed: $OS_ERROR';
        $output_112 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_113> };
        close $out_113 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_113, 0;

                my @lines = split /\n/msx, $output_112;
        my @result;
        foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($fields[0] . " " . $scalar(@fields) . "\n");
        }
        $output_112 = join "", @result;

                my $set1_114 = "\\(\\)";
        my $input_114 = $output_112;
        my $tr_result_112_2 = q{};
        for my $char ( split //msx, $input_114 ) {
        if ( (index $set1_114, $char) == -1 ) {
        $tr_result_112_2 .= $char;
        }
        }
        if (!($tr_result_112_2 =~ m{\n\z}msx || $tr_result_112_2 eq q{})) {
        $tr_result_112_2 .= "\n";
        }
        $output_112 = $tr_result_112_2;
        $output_112 = $tr_result_112_2;

                my $grep_result_112_3;
        my @grep_lines_112_3 = split /\n/msx, $output_112;
        my @grep_filtered_112_3 = grep { /^"\ .\ $_[0]\ .\ "\ /msx } @grep_lines_112_3;
        $grep_result_112_3 = join "\n", @grep_filtered_112_3;
        if (!($grep_result_112_3 =~ m{\n\z}msx || $grep_result_112_3 eq q{})) {
        $grep_result_112_3 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_112_3 > 0 ? 0 : 1;
        $output_112 = $grep_result_112_3;
        $output_112 = $grep_result_112_3;

                my @lines_115 = split /\n/msx, $output_112;
        my @result_115;
        foreach my $line (@lines_115) {
        chomp $line;
        my @fields = split /\ /msx, $line;
        if (@fields > 1) {
        push @result_115, $fields[1];
        }
        }
        $output_112 = join "\n", @result_115;
        if ($output_112 ne q{} && !($output_112  =~ m{\n\z}msx)) { $output_112 .= "\n"; }
        if ($output_112 ne q{} && !defined $output_printed_112) {
            print $output_112;
            if (!($output_112 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_112 ) { $main_exit_code = 1; }
        }
    return;
}

sub get_pid_from_wifi_iface {
    my ($file) = @_;
    # Original bash: list_running | awk '{print $1 " " $NF}' | tr -d '\(\)' | grep -E " ${1}$" | cut -d' ' -f1
{
        my $output_116 = q{};
        my $output_printed_116;
        my $pipeline_success_116 = 1;
                my ($in_117, $out_117);
        my $pid_117 = open3($in_117, $out_117, '>&STDERR', 'list_running', );
        close $in_117 or croak 'Close failed: $OS_ERROR';
        $output_116 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_117> };
        close $out_117 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_117, 0;

                my @lines = split /\n/msx, $output_116;
        my @result;
        foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($fields[0] . " " . $scalar(@fields) . "\n");
        }
        $output_116 = join "", @result;

                my $set1_118 = "\\(\\)";
        my $input_118 = $output_116;
        my $tr_result_116_2 = q{};
        for my $char ( split //msx, $input_118 ) {
        if ( (index $set1_118, $char) == -1 ) {
        $tr_result_116_2 .= $char;
        }
        }
        if (!($tr_result_116_2 =~ m{\n\z}msx || $tr_result_116_2 eq q{})) {
        $tr_result_116_2 .= "\n";
        }
        $output_116 = $tr_result_116_2;
        $output_116 = $tr_result_116_2;

                my $grep_result_116_3;
        my @grep_lines_116_3 = split /\n/msx, $output_116;
        my @grep_filtered_116_3 = grep { /\ "\ .\ $_[0]\ .\ "$/msx } @grep_lines_116_3;
        $grep_result_116_3 = join "\n", @grep_filtered_116_3;
        if (!($grep_result_116_3 =~ m{\n\z}msx || $grep_result_116_3 eq q{})) {
        $grep_result_116_3 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_116_3 > 0 ? 0 : 1;
        $output_116 = $grep_result_116_3;
        $output_116 = $grep_result_116_3;

                my @lines_119 = split /\n/msx, $output_116;
        my @result_119;
        foreach my $line (@lines_119) {
        chomp $line;
        my @fields = split /\ /msx, $line;
        if (@fields > 0) {
        push @result_119, $fields[0];
        }
        }
        $output_116 = join "\n", @result_119;
        if ($output_116 ne q{} && !($output_116  =~ m{\n\z}msx)) { $output_116 .= "\n"; }
        if ($output_116 ne q{} && !defined $output_printed_116) {
            print $output_116;
            if (!($output_116 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_116 ) { $main_exit_code = 1; }
        }
    return;
}

sub get_confdir_from_pid {
    my $IFACE;
    my $x;
    mutex_lock();
    for my $x (do {
    my ($in_120, $out_120);
    my $pid_120 = open3($in_120, $out_120, '>&STDERR', 'list_running_conf');
    close $in_120 or croak 'Close failed: $OS_ERROR';
    my $result_120 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_120> };
    close $out_120 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_120, 0;
    $result_120
}) {
if ($(cat $x/pid) =~ /^"[$]1"$/msx) {
            print $x;
if ( !( ($x) =~ m{\n\z}msx ) ) { print "\n"; }
last;
        }
    }
    mutex_unlock();
    return;
}

sub print_client {
    my $line;
    my $ipaddr;
    my $hostname;
    my $mac = "$_[0]";
if ((-f $CONFDIR/dnsmasq.leases)) {
        $line = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_121 = q{};
            my $output_printed_121;
            my $pipeline_success_121 = 1;
            my $grep_result_121_0;
            my @grep_lines_121_0 = ();
            my @grep_filenames_121_0 = ();
            if (-e "/dnsmasq.leases") {
                open my $fh, '<', "/dnsmasq.leases" or croak "Cannot open file: $ERRNO";
                while (my $line = <$fh>) {
                    chomp $line;
                    push @grep_lines_121_0, $line;
                    push @grep_filenames_121_0, "/dnsmasq.leases";
                }
                close $fh
                    or croak "Close failed: $OS_ERROR";
            }
            else { print {*STDERR} "grep: /dnsmasq.leases: No such file or directory\n"; }
            my @grep_filtered_121_0 = grep { /\ $mac\ /msx } @grep_lines_121_0;
            $grep_result_121_0 = join "\n", @grep_filtered_121_0;
                        if (!($grep_result_121_0 =~ m{\n\z}msx || $grep_result_121_0 eq q{})) {
                            $grep_result_121_0 .= "\n";
                        }
            $CHILD_ERROR = scalar @grep_filtered_121_0 > 0 ? 0 : 1;
            $output_121 = $grep_result_121_0;
            if ($CHILD_ERROR != 0) { $pipeline_success_121 = 0; }
            my @lines = split /\n/msx, $output_121;
            my $num_lines = 1;
            if ($num_lines > scalar @lines) {
            $num_lines = scalar @lines;
            }
            my $start_index = scalar @lines - $num_lines;
            if ($start_index < 0) { $start_index = 0; }
            my @result = @lines[$start_index..$#lines];
            $output_121 = join "\n", @result;
            if ($output_121 ne q{} && !($output_121  =~ m{\n\z}msx)) { $output_121 .= "\n"; }

            if ( !$pipeline_success_121 ) { $main_exit_code = 1; }
            $output_121 =~ s/\n+\z//msx;
            $output_121;
}; $_pipeline_result; };
        $ipaddr = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_122 = q{};
            my $output_printed_122;
            my $pipeline_success_122 = 1;
            $output_122 .= $line . "\n";
            if ( !($output_122 =~ m{\n\z}msx) ) { $output_122 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_122 = 0; }
            my @lines_123 = split /\n/msx, $output_122;
            my @result_123;
            foreach my $line (@lines_123) {
            chomp $line;
            my @fields = split /\ /msx, $line;
            if (@fields > 2) {
                push @result_123, $fields[2];
            }
            }
            $output_122 = join "\n", @result_123;
            if ($output_122 ne q{} && !($output_122  =~ m{\n\z}msx)) { $output_122 .= "\n"; }

            if ( !$pipeline_success_122 ) { $main_exit_code = 1; }
            $output_122 =~ s/\n+\z//msx;
            $output_122;
}; $_pipeline_result; };
        $hostname = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_124 = q{};
            my $output_printed_124;
            my $pipeline_success_124 = 1;
            $output_124 .= $line . "\n";
            if ( !($output_124 =~ m{\n\z}msx) ) { $output_124 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_124 = 0; }
            my @lines_125 = split /\n/msx, $output_124;
            my @result_125;
            foreach my $line (@lines_125) {
            chomp $line;
            my @fields = split /\ /msx, $line;
            if (@fields > 3) {
                push @result_125, $fields[3];
            }
            }
            $output_124 = join "\n", @result_125;
            if ($output_124 ne q{} && !($output_124  =~ m{\n\z}msx)) { $output_124 .= "\n"; }

            if ( !$pipeline_success_124 ) { $main_exit_code = 1; }
            $output_124 =~ s/\n+\z//msx;
            $output_124;
}; $_pipeline_result; };
    }
    if ("$ipaddr" eq q{}) {
                $ipaddr = "*";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ("$hostname" eq q{}) {
                $hostname = "*";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
printf("%-20s %-18s %s\n", "$mac", "$ipaddr", "$hostname");
    return;
}

sub list_clients {
    my $wifi_iface;
    my $pid;
if ("$1" =~ /^[1-9][0-9]*$/msx) {
        $pid = "$_[0]";
        $wifi_iface = do {
    my ($in_127, $out_127);
    my $pid_127 = open3($in_127, $out_127, '>&STDERR', 'get_wifi_iface_from_pid', "$pid");
    close $in_127 or croak 'Close failed: $OS_ERROR';
    my $result_127 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_127> };
    close $out_127 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_127, 0;
    $result_127
};
        if ("$wifi_iface" eq q{}) {
                        die("'$pid' is not the pid of a running $PROGNAME instance.");
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    }
    if ("$wifi_iface" eq q{}) {
                $wifi_iface = "$_[0]";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
        is_wifi_interface("$wifi_iface");
    if ($CHILD_ERROR != 0) {
                die("'$wifi_iface' is not a WiFi interface.");
    }
    if ("$pid" eq q{}) {
                $pid = do {
    my ($in_128, $out_128);
    my $pid_128 = open3($in_128, $out_128, '>&STDERR', 'get_pid_from_wifi_iface', "$wifi_iface");
    close $in_128 or croak 'Close failed: $OS_ERROR';
    my $result_128 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_128> };
    close $out_128 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_128, 0;
    $result_128
};
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ("$pid" eq q{}) {
                die("'$wifi_iface' is not used from $PROGNAME instance.\n\
       Maybe you need to pass the virtual interface instead.\n\
       Use --list-running to find it out.");
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ("$CONFDIR" eq q{}) {
                $CONFDIR = do {
    my ($in_129, $out_129);
    my $pid_129 = open3($in_129, $out_129, '>&STDERR', 'get_confdir_from_pid', "$pid");
    close $in_129 or croak 'Close failed: $OS_ERROR';
    my $result_129 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_129> };
    close $out_129 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_129, 0;
    $result_129
};
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if (($USE_IWCONFIG == 0)) {
        my $awk_cmd = "($1 ~ /Station$/) {print $2}";
        my $client_list = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_130 = q{};
            my $output_printed_130;
            my $pipeline_success_130 = 1;

            my ($in_131, $out_131);
            my $pid_131 = open3($in_131, $out_131, '>&STDERR', 'iw', 'dev', 'station', 'dump');
            close $in_131 or croak 'Close failed: $OS_ERROR';
            $output_130 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_131> };
            close $out_131 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_131, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_130 = 0; }
            my @lines = split /\n/msx, $output_130;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                push @result, ($line . "\n");
            }
            $output_130 = join "", @result;

            if ( !$pipeline_success_130 ) { $main_exit_code = 1; }
            $output_130 =~ s/\n+\z//msx;
            $output_130;
}; $_pipeline_result; };
if ("$client_list" eq q{}) {
            print "No clients connected\n";
return;
        }
printf("%-20s %-18s %s\n", "MAC", "IP", "Hostname");
        my $mac;
        for my $mac ($client_list) {
            print_client($mac);
        }
}
    else {
        die("This option is not supported for the current driver.");
    }
    return;
}

sub has_running_instance {
    my $PID;
    my $x;
    mutex_lock();
    for my $x ('/tmp/create_ap.*') {
if ((-f $x/pid)) {
            $PID = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $x ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $x . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/pid' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/pid' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
if ((-d '/proc/$PID')) {
                mutex_unlock();
return q{0};
            }
        }
    }
    mutex_lock();
return q{1};
    return;
}

sub is_running_pid {
    # Original bash: list_running | grep -E "^${1} " > /dev/null 2>&1
{
        my $output_133 = q{};
        my $output_printed_133;
        my $pipeline_success_133 = 1;
                my ($in_134, $out_134);
        my $pid_134 = open3($in_134, $out_134, '>&STDERR', 'list_running', );
        close $in_134 or croak 'Close failed: $OS_ERROR';
        $output_133 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_134> };
        close $out_134 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_134, 0;

                my $grep_result_133_1;
        my @grep_lines_133_1 = split /\n/msx, $output_133;
        my @grep_filtered_133_1 = grep { /^"\ .\ $_[0]\ .\ "\ /msx } @grep_lines_133_1;
        $grep_result_133_1 = join "\n", @grep_filtered_133_1;
        if (!($grep_result_133_1 =~ m{\n\z}msx || $grep_result_133_1 eq q{})) {
        $grep_result_133_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_133_1 > 0 ? 0 : 1;
        $output_133 = $grep_result_133_1;
        if ( !$pipeline_success_133 ) { $main_exit_code = 1; }
        }
    return;
}

sub send_stop {
    my $x;
    mutex_lock();
if (!(    is_running_pid($1))) {
my $signal = 'USR1';
my @pids = ($1);
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
        mutex_unlock();
return;
    }
    for my $x (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_136 = q{};
        my $output_printed_136;
        my $pipeline_success_136 = 1;

        my ($in_137, $out_137);
        my $pid_137 = open3($in_137, $out_137, '>&STDERR', 'list_running', );
        close $in_137 or croak 'Close failed: $OS_ERROR';
        $output_136 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_137> };
        close $out_137 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_137, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_136 = 0; }
        my $grep_result_136_1;
        my @grep_lines_136_1 = split /\n/msx, $output_136;
        my @grep_filtered_136_1 = grep { /\ (?"\ .\ $_[0]\ .\ "(\ |)?$)/msx } @grep_lines_136_1;
        $grep_result_136_1 = join "\n", @grep_filtered_136_1;
                if (!($grep_result_136_1 =~ m{\n\z}msx || $grep_result_136_1 eq q{})) {
                    $grep_result_136_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_136_1 > 0 ? 0 : 1;
        $output_136 = $grep_result_136_1;
        my @lines_138 = split /\n/msx, $output_136;
        my @result_138;
        foreach my $line (@lines_138) {
        chomp $line;
        my @fields = split /\ /msx, $line;
        if (@fields > 0) {
            push @result_138, $fields[0];
        }
        }
        $output_136 = join "\n", @result_138;
        if ($output_136 ne q{} && !($output_136  =~ m{\n\z}msx)) { $output_136 .= "\n"; }

        if ( !$pipeline_success_136 ) { $main_exit_code = 1; }
        $output_136 =~ s/\n+\z//msx;
        $output_136;
}; $_pipeline_result; }) {
my $signal = 'USR1';
my @pids = ($x);
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
    mutex_unlock();
    return;
}

sub write_config {
    my $i = "1";
if (!(!(do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$STORE_CONFIG"
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
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "ERROR: Unable to create config file $STORE_CONFIG";
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
    $WIFI_IFACE = $1;
if ("$SHARE_METHOD" =~ /^"none"$/msx) {
        my $SSID;
        my @SSID;
        my %SSID;
        $SSID = "$_[1]";
        $PASSPHRASE = "$_[2]";
}
    else {
        $INTERNET_IFACE = "$_[1]";
        $SSID = "$_[2]";
        $PASSPHRASE = "$_[3]";
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$STORE_CONFIG"
      or die "Cannot open file: $OS_ERROR\n";
        my $config_opt;
        for my $config_opt (@CONFIG_OPTS) {
do { my $eval_input = "echo" . $config_opt . "=" . "\\$$config_opt"; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
        }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
    my $__echo_line = "Config options written to '$STORE_CONFIG'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
exit 0;
    return;
}

sub is_config_opt {
    my $elem;
    my $opt = "$_[0]";
    for my $elem (@CONFIG_OPTS) {
if ("$elem" =~ /^"[$]opt"$/msx) {
return q{0};
        }
    }
return q{1};
    return;
}

sub read_config {
    my $opt_name;
    my $opt_val;
    my $line;
open STDIN, '<', "$LOAD_CONFIG" or croak "Cannot open file: $OS_ERROR\n";
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $line = $_fields[0] // q{};
        $opt_name = (${line} =~ s/=.*$//sr =~ s/=.*$//sr);
        $opt_val = (${line} =~ s/^.*?=//r =~ s/^.*?=//r);
if (!(        is_config_opt("$opt_name"))) {
do { my $eval_input = $opt_name . "=" . "$opt_val"; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
}
        else {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "WARN: Unrecognized configuration entry $opt_name";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
        }
    }
    return;
}
@ARGS = ('$@');
for (eval { int($ENV{i}=0) } // ""; eval { int($ENV{i}<$#) } // ""; eval { int($ENV{i}++) } // "") {
if ("${ARGS[i]}" eq "--config") {
if ((-f "${ARGS[i+1]}")) {
                $LOAD_CONFIG = $ARGS[eval { int($ENV{i}+1) } // ""];
                read_config();
}
            else {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    print "ERROR: No config file found at given location\n";
                };
exit 1;
            }
last;
        }
}
my $GETOPT_ARGS;
my @GETOPT_ARGS;
my %GETOPT_ARGS;
$GETOPT_ARGS = do {
    my ($in_140, $out_140);
    my $pid_140 = open3($in_140, $out_140, '>&STDERR', 'getopt', '-o', 'hc:w:g:de:nm:', '-l', "help", q{,}, "hidden", q{,}, "hostapd-debug:", q{,}, "redirect-to-localhost", q{,}, "mac-filter", q{,}, "mac-filter-accept:", q{,}, "isolate-clients", q{,}, "ieee80211n", q{,}, "ieee80211ac", q{,}, "ht_capab:", q{,}, "vht_capab:", q{,}, "driver:", q{,}, "no-virt", q{,}, "fix-unmanaged", q{,}, "country:", q{,}, "freq-band:", q{,}, "mac:", q{,}, "dhcp-dns:", q{,}, "daemon", q{,}, "pidfile:", q{,}, "logfile:", q{,}, "stop:", q{,}, "list", q{,}, "list-running", q{,}, "list-clients:", q{,}, "version", q{,}, "psk", q{,}, "no-haveged", q{,}, "no-dns", q{,}, "no-dnsmasq", q{,}, "mkconfig:", q{,}, "config:", '-n', "$PROGNAME", '--', "@ARGV");
    close $in_140 or croak 'Close failed: $OS_ERROR';
    my $result_140 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_140> };
    close $out_140 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_140, 0;
    $result_140
};
if (($? != 0)) {
    exit 1;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
do { my $eval_input = "set" . "--" . $GETOPT_ARGS; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
while ( $main_exit_code = system('bash', ':') >> 8 ) {
if ("$_[0]" =~ /^-h$/msx or "$_[0]" =~ /^--help$/msx) {
                usage();
        exit 0;
    } elsif ("$_[0]" =~ /^--version$/msx) {
                print $VERSION;
if ( !( ($VERSION) =~ m{\n\z}msx ) ) { print "\n"; }
        exit 0;
    } elsif ("$_[0]" =~ /^--hidden$/msx) {
        # Builtin command 'shift' not implemented
                $HIDDEN = q{1};
    } elsif ("$_[0]" =~ /^--mac-filter$/msx) {
        # Builtin command 'shift' not implemented
                $MAC_FILTER = q{1};
    } elsif ("$_[0]" =~ /^--mac-filter-accept$/msx) {
        # Builtin command 'shift' not implemented
                $MAC_FILTER_ACCEPT = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--isolate-clients$/msx) {
        # Builtin command 'shift' not implemented
                $ISOLATE_CLIENTS = q{1};
    } elsif ("$_[0]" =~ /^-c$/msx) {
        # Builtin command 'shift' not implemented
                $CHANNEL = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-w$/msx) {
        # Builtin command 'shift' not implemented
                $WPA_VERSION = "$_[0]";
                if ("$WPA_VERSION" =~ /^"2[+]1"$/msx) {
                        $WPA_VERSION = '1+2';
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-g$/msx) {
        # Builtin command 'shift' not implemented
                $GATEWAY = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-d$/msx) {
        # Builtin command 'shift' not implemented
                $ETC_HOSTS = q{1};
    } elsif ("$_[0]" =~ /^-e$/msx) {
        # Builtin command 'shift' not implemented
                $ADDN_HOSTS = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-n$/msx) {
        # Builtin command 'shift' not implemented
                $SHARE_METHOD = 'none';
    } elsif ("$_[0]" =~ /^-m$/msx) {
        # Builtin command 'shift' not implemented
                $SHARE_METHOD = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--ieee80211n$/msx) {
        # Builtin command 'shift' not implemented
                $IEEE80211N = q{1};
    } elsif ("$_[0]" =~ /^--ieee80211ac$/msx) {
        # Builtin command 'shift' not implemented
                $IEEE80211AC = q{1};
    } elsif ("$_[0]" =~ /^--ht_capab$/msx) {
        # Builtin command 'shift' not implemented
                $HT_CAPAB = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--vht_capab$/msx) {
        # Builtin command 'shift' not implemented
                $VHT_CAPAB = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--driver$/msx) {
        # Builtin command 'shift' not implemented
                $DRIVER = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--no-virt$/msx) {
        # Builtin command 'shift' not implemented
                $NO_VIRT = q{1};
    } elsif ("$_[0]" =~ /^--fix-unmanaged$/msx) {
        # Builtin command 'shift' not implemented
                $FIX_UNMANAGED = q{1};
    } elsif ("$_[0]" =~ /^--country$/msx) {
        # Builtin command 'shift' not implemented
                $COUNTRY = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--freq-band$/msx) {
        # Builtin command 'shift' not implemented
                $FREQ_BAND = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--mac$/msx) {
        # Builtin command 'shift' not implemented
                $NEW_MACADDR = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--dhcp-dns$/msx) {
        # Builtin command 'shift' not implemented
                $DHCP_DNS = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--daemon$/msx) {
        # Builtin command 'shift' not implemented
                $DAEMONIZE = q{1};
    } elsif ("$_[0]" =~ /^--pidfile$/msx) {
        # Builtin command 'shift' not implemented
                $DAEMON_PIDFILE = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--logfile$/msx) {
        # Builtin command 'shift' not implemented
                $DAEMON_LOGFILE = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--stop$/msx) {
        # Builtin command 'shift' not implemented
                $STOP_ID = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--list$/msx) {
        # Builtin command 'shift' not implemented
                $LIST_RUNNING = q{1};
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "WARN: --list is deprecated, use --list-running instead.\n" . "\n";
            $CHILD_ERROR = 0;
        };
    } elsif ("$_[0]" =~ /^--list-running$/msx) {
        # Builtin command 'shift' not implemented
                $LIST_RUNNING = q{1};
    } elsif ("$_[0]" =~ /^--list-clients$/msx) {
        # Builtin command 'shift' not implemented
                $LIST_CLIENTS_ID = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--no-haveged$/msx) {
        # Builtin command 'shift' not implemented
                $NO_HAVEGED = q{1};
    } elsif ("$_[0]" =~ /^--psk$/msx) {
        # Builtin command 'shift' not implemented
                $USE_PSK = q{1};
    } elsif ("$_[0]" =~ /^--no-dns$/msx) {
        # Builtin command 'shift' not implemented
                $NO_DNS = q{1};
    } elsif ("$_[0]" =~ /^--no-dnsmasq$/msx) {
        # Builtin command 'shift' not implemented
                $NO_DNSMASQ = q{1};
    } elsif ("$_[0]" =~ /^--redirect-to-localhost$/msx) {
        # Builtin command 'shift' not implemented
                $REDIRECT_TO_LOCALHOST = q{1};
    } elsif ("$_[0]" =~ /^--hostapd-debug$/msx) {
        # Builtin command 'shift' not implemented
        if ("x$1" eq "x1") {
            $HOSTAPD_DEBUG_ARGS = "-d";
}
        else {
            if ("x$1" eq "x2") {
                $HOSTAPD_DEBUG_ARGS = "-dd";
}
            else {
printf("Error: argument for --hostapd-debug expected 1 or 2, got %s\n", "$_[0]");
exit 1;
            }
        }
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--mkconfig$/msx) {
        # Builtin command 'shift' not implemented
                $STORE_CONFIG = "$_[0]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--config$/msx) {
        # Builtin command 'shift' not implemented
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--$/msx) {
        # Builtin command 'shift' not implemented
        last;    }
}
if (("$LOAD_CONFIG" ne q{} && (scalar(@ARGV) == 0))) {
    my $i;
    my @i;
    my %i;
    $i = q{0};
    for my $x ('WIFI_IFACE', 'INTERNET_IFACE', 'SSID', 'PASSPHRASE') {
if (!(do { my $eval_input = "[[ -n \"$" . ${x} . "\" ]]"; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; })) {
do { my $eval_input = "set -- \"${@:1:" . $i . "}\" \"$" . ${x} . "\""; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
            $CHILD_ERROR = ($main_exit_code = eval { int($i++) } // "") ? 0 : 1;
        }
do { my $eval_input = "unset " . $x; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    }
    $x = 'PASSPHRASE';
}
if (0) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        usage();
    };
exit 1;
}
if (($NO_DNSMASQ == 1)) {
    $NO_DNS = q{1};
}
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'cleanup_lock 2>&1'; print $end_out if $end_out ne q{}; }
if (!(!(init_lock();))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "ERROR: Failed to initialize lock\n";
    };
exit 1;
}
$SIG{SIGINT} = sub { qx'clean_exit'; };
$SIG{SIGUSR2} = sub { qx'die'; };
if ("$STORE_CONFIG" ne q{}) {
        write_config("@ARGV");
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if (($LIST_RUNNING == 1)) {
    do {
    my $__echo_line = "List of running $PROGNAME instances:\n";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    list_running();
exit 0;
}
if ("$LIST_CLIENTS_ID" ne q{}) {
    list_clients("$LIST_CLIENTS_ID");
exit 0;
}
if ((qx'id -u' != 0)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "You must run it as root.\n";
    };
exit 1;
}
if ("$STOP_ID" ne q{}) {
    do {
    my $__echo_line = "Trying to kill $PROGNAME instance associated with $STOP_ID...";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    send_stop("$STOP_ID");
exit 0;
}
if (($FIX_UNMANAGED == 1)) {
    print "Trying to fix unmanaged status in NetworkManager...\n";
    networkmanager_fix_unmanaged();
exit 0;
}
if ((($DAEMONIZE == 1) && ($RUNNING_AS_DAEMON == 0))) {
if ("$DAEMON_PIDFILE" eq q{}) {
        print "Running as Daemon...\n";
    }
        my $RUNNING_AS_DAEMON = q{1};
        if (my $pid = fork()) {
            # Parent process continues
        } elsif (defined $pid) {
            # Child process executes the background command
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $DAEMON_LOGFILE
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('setsid', "$PROGRAM_NAME", (join(" ", @ARGS))) >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            exit(0);
        } else {
            die "Cannot fork: $ERRNO\n";
        }
exit 0;
}
else {
    if ((($RUNNING_AS_DAEMON == 1) && "$DAEMON_PIDFILE" ne q{})) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $DAEMON_PIDFILE
      or die "Cannot open file: $OS_ERROR\n";
            print $$;
if ( !( ($$) =~ m{\n\z}msx ) ) { print "\n"; }
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
}
if (($FREQ_BAND ne 2.4 && $FREQ_BAND ne 5)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "ERROR: Invalid frequency band\n";
    };
exit 1;
}
if ($CHANNEL =~ /^default$/msx) {
if ($FREQ_BAND =~ /^2[.]4$/msx) {
        $CHANNEL = q{1};
}
    else {
        $CHANNEL = '36';
    }
}
if (($FREQ_BAND ne 5 && ($CHANNEL > 1$MAGIC_4))) {
    print "Channel number is greater than 14, assuming 5GHz frequency band\n";
    $FREQ_BAND = q{5};
}
$WIFI_IFACE = $1;
if (!(!(is_wifi_interface($WIFI_IFACE);))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "ERROR: '" . ${WIFI_IFACE} . "' is not a WiFi interface";
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
if (!(!(can_be_ap($WIFI_IFACE);))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "ERROR: Your adapter does not support AP (master) mode\n";
    };
exit 1;
}
if (!(!(can_be_sta_and_ap($WIFI_IFACE);))) {
if (!(    is_wifi_connected($WIFI_IFACE))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "ERROR: Your adapter can not be a station (i.e. be connected) and an AP at the same time\n";
        };
exit 1;
}
    else {
        if (($NO_VIRT == 0)) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "WARN: Your adapter does not fully support AP virtual interface, enabling --no-virt\n";
            };
            $NO_VIRT = q{1};
        }
    }
}
$HOSTAPD = do { my $which_cmd = 'which hostapd'; my $which_output = qx{$which_cmd}; $CHILD_ERROR = $? >> 8; $which_output; };
if ((!-x "$HOSTAPD")) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "ERROR: hostapd not found.\n";
    };
exit 1;
}
if ($ENV{(get_adapter_kernel_module ${WIFI_IFACE})} =~ /^(8192[cd][ue]|8723a[sue])$/msx) {
if (!(!(# Original bash: strings "$HOSTAPD" | grep -m1 rtl871xdrv > /dev/null 2>&1;
{
        my $output_142 = q{};
        my $output_printed_142;
        my $pipeline_success_142 = 1;
                my $input_data = $;
        my @result;
        while ($input_data =~ /([\x20-\x7E]{4,})/g) {
        push @result, $1;
        }
        my $line = join "\n", @result;
        if ($line ne q{} && !($line =~ m{\n\z}msx)) { $line .= "\n"; }
        $output_142 = $line;

                my $grep_result_142_1;
        my @grep_lines_142_1 = split /\n/msx, $output_142;
        my @grep_filtered_142_1 = grep { /rtl871xdrv/msx } @grep_lines_142_1;
        $grep_result_142_1 = join "\n", @grep_filtered_142_1;
        if (!($grep_result_142_1 =~ m{\n\z}msx || $grep_result_142_1 eq q{})) {
        $grep_result_142_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_142_1 > 0 ? 0 : 1;
        $output_142 = $grep_result_142_1;
        if ( !$pipeline_success_142 ) { $main_exit_code = 1; }
        }))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "ERROR: You need to patch your hostapd with rtl871xdrv patches.\n";
        };
exit 1;
    }
if ($DRIVER ne "rtl871xdrv") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "WARN: Your adapter needs rtl871xdrv, enabling --driver=rtl871xdrv\n";
        };
        $DRIVER = 'rtl871xdrv';
    }
}
if (0) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "ERROR: Wrong Internet sharing method\n";
    };
    print "\n";
    $CHILD_ERROR = 0;
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        usage();
    };
exit 1;
}
if ("$NEW_MACADDR" ne q{}) {
if (!(!(is_macaddr("$NEW_MACADDR");))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "ERROR: '" . ${NEW_MACADDR} . "' is not a valid MAC address";
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
if (!(!(is_unicast_macaddr("$NEW_MACADDR");))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "ERROR: The first byte of MAC address (" . ${NEW_MACADDR} . ") must be even";
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
if ((qx'get_all_macaddrs | grep -c ${NEW_MACADDR}' != 0)) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "WARN: MAC address '" . ${NEW_MACADDR} . "' already exists. Because of this, you may encounter some problems";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
    }
}
if ("$SHARE_METHOD" ne "none") {
    $MIN_REQUIRED_ARGS = q{2};
}
else {
    $MIN_REQUIRED_ARGS = q{1};
}
if ((scalar(@ARGV) > $MIN_REQUIRED_ARGS)) {
if ("$SHARE_METHOD" ne "none") {
if (((scalar(@ARGV) != $MAGIC_3) && (scalar(@ARGV) != $MAGIC_4))) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                usage();
            };
exit 1;
        }
        $INTERNET_IFACE = "$_[1]";
        my $SSID;
        my @SSID;
        my %SSID;
        $SSID = "$_[2]";
        $PASSPHRASE = "$_[3]";
}
    else {
if (((scalar(@ARGV) != 2) && (scalar(@ARGV) != $MAGIC_3))) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                usage();
            };
exit 1;
        }
        $SSID = "$_[1]";
        $PASSPHRASE = "$_[2]";
    }
}
else {
if ("$SHARE_METHOD" ne "none") {
if ((scalar(@ARGV) != 2)) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                usage();
            };
exit 1;
        }
        $INTERNET_IFACE = "$_[1]";
    }
if (!(    $main_exit_code = system('tty', '-s') >> 8)) {
while (         $main_exit_code = system('bash', ':') >> 8 ) {
$SSID = <>;
chomp $SSID;
$CHILD_ERROR = defined($SSID) ? 0 : 1;
if (((${#SSID} < 1) || (${#SSID} > $MAGIC_$MAGIC_32))) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "ERROR: Invalid SSID length " . length($SSID) . " (expected 1..32)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                };
next;
            }
last;
        }
while (         $main_exit_code = system('bash', ':') >> 8 ) {
if (($USE_PSK == 0)) {
$PASSPHRASE = <>;
chomp $PASSPHRASE;
$CHILD_ERROR = defined($PASSPHRASE) ? 0 : 1;
                print "\n";
                $CHILD_ERROR = 0;
if ((((${#PASSPHRASE} > 0) && (${#PASSPHRASE} < 8)) || (${#PASSPHRASE} > 6$MAGIC_3))) {
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                        do {
    my $__echo_line = "ERROR: Invalid passphrase length " . length($PASSPHRASE) . " (expected 8..63)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                    };
next;
                }
$PASSPHRASE2 = <>;
chomp $PASSPHRASE2;
$CHILD_ERROR = defined($PASSPHRASE2) ? 0 : 1;
                print "\n";
                $CHILD_ERROR = 0;
if ("$PASSPHRASE" ne "$PASSPHRASE2") {
                    print "Passphrases do not match.\n";
}
                else {
last;
                }
}
            else {
$PASSPHRASE = <>;
chomp $PASSPHRASE;
$CHILD_ERROR = defined($PASSPHRASE) ? 0 : 1;
                print "\n";
                $CHILD_ERROR = 0;
if (((${#PASSPHRASE} > 0) && (${#PASSPHRASE} != 6$MAGIC_4))) {
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                        do {
    my $__echo_line = "ERROR: Invalid pre-shared-key length " . length($PASSPHRASE) . " (expected 64)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                    };
next;
                }
            }
        }
}
    else {
$SSID = <>;
chomp $SSID;
$CHILD_ERROR = defined($SSID) ? 0 : 1;
$PASSPHRASE = <>;
chomp $PASSPHRASE;
$CHILD_ERROR = defined($PASSPHRASE) ? 0 : 1;
    }
}
if (("$SHARE_METHOD" ne "none" && !(!(is_interface($INTERNET_IFACE);)))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "ERROR: '" . ${INTERNET_IFACE} . "' is not an interface";
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
if (((${#SSID} < 1) || (${#SSID} > $MAGIC_$MAGIC_32))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "ERROR: Invalid SSID length " . length($SSID) . " (expected 1..32)";
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
if (($USE_PSK == 0)) {
if ((((${#PASSPHRASE} > 0) && (${#PASSPHRASE} < 8)) || (${#PASSPHRASE} > 6$MAGIC_3))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "ERROR: Invalid passphrase length " . length($PASSPHRASE) . " (expected 8..63)";
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
}
else {
    if (((${#PASSPHRASE} > 0) && (${#PASSPHRASE} != 6$MAGIC_4))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "ERROR: Invalid pre-shared-key length " . length($PASSPHRASE) . " (expected 64)";
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
}
if ($ENV{(get_adapter_kernel_module ${WIFI_IFACE})} =~ /^rtl[0-9].*$/msx) {
if ("$PASSPHRASE" ne q{}) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "WARN: Realtek drivers usually have problems with WPA1, enabling -w 2\n";
        };
        $WPA_VERSION = q{2};
    }
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "WARN: If AP doesn't work, please read: howto/realtek.md\n";
    };
}
if ((($NO_VIRT == 1) && "$WIFI_IFACE" =~ /^"[$]INTERNET_IFACE"$/msx)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "ERROR: You can not share your connection from the same";
    };
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print " interface if you are using --no-virt option.\n";
    };
exit 1;
}
mutex_lock();
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'cleanup 2>&1'; print $end_out if $end_out ne q{}; }
$CONFDIR = do {
    my ($in_149, $out_149);
    my $pid_149 = open3($in_149, $out_149, '>&STDERR', 'mktemp', '-d', '/tmp/create_ap.', $WIFI_IFACE, '.conf.XXXXXXXX');
    close $in_149 or croak 'Close failed: $OS_ERROR';
    my $result_149 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_149> };
    close $out_149 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_149, 0;
    $result_149
};
do {
    my $__echo_line = "Config dir: $CONFDIR";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    my $__echo_line = "PID: $ENV{$}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', $CONFDIR
      or die "Cannot open file: $OS_ERROR\n";
    print $$;
if ( !( ($$) =~ m{\n\z}msx ) ) { print "\n"; }
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
$main_exit_code = system('bash', '/pid') >> 8;
chmod(oct('755'), ($CONFDIR)) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
chmod(oct('444'), ($CONFDIR, '/pid')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
my $COMMON_CONFDIR;
my @COMMON_CONFDIR;
my %COMMON_CONFDIR;
$COMMON_CONFDIR = '/tmp/create_ap.common.conf';
use File::Path qw(make_path);
my $err;
if ( !-d $COMMON_CONFDIR ) {
    make_path( $COMMON_CONFDIR, { error => \$err } );
    if ( @{$err} ) {
        croak "mkdir: cannot create directory " . $COMMON_CONFDIR . ": $err->[0]\n";
    }
}
if ("$SHARE_METHOD" =~ /^"nat"$/msx) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', $CONFDIR
      or die "Cannot open file: $OS_ERROR\n";
        print $INTERNET_IFACE;
if ( !( ($INTERNET_IFACE) =~ m{\n\z}msx ) ) { print "\n"; }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('bash', '/nat_internet_iface') >> 8;
    cp_n('/proc/sys/net/ipv4/conf/', $INTERNET_IFACE, '/forwarding', $COMMON_CONFDIR, q{/}, $INTERNET_IFACE, '_forwarding');
}
cp_n('/proc/sys/net/ipv4/ip_forward', $COMMON_CONFDIR);
if ((-e '/proc/sys/net/bridge/bridge-nf-call-iptables')) {
    cp_n('/proc/sys/net/bridge/bridge-nf-call-iptables', $COMMON_CONFDIR);
}
mutex_unlock();
if ("$SHARE_METHOD" =~ /^"bridge"$/msx) {
if (!(    is_bridge_interface($INTERNET_IFACE))) {
        $BRIDGE_IFACE = $INTERNET_IFACE;
}
    else {
        $BRIDGE_IFACE = do {
    my ($in_153, $out_153);
    my $pid_153 = open3($in_153, $out_153, '>&STDERR', 'alloc_new_iface', 'br');
    close $in_153 or croak 'Close failed: $OS_ERROR';
    my $result_153 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_153> };
    close $out_153 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_153, 0;
    $result_153
};
    }
}
if (($USE_IWCONFIG == 0)) {
    $main_exit_code = system('iw', 'dev', $WIFI_IFACE, 'set', 'power_save', 'off') >> 8;
}
if (($NO_VIRT == 0)) {
    $VWIFI_IFACE = do {
    my ($in_154, $out_154);
    my $pid_154 = open3($in_154, $out_154, '>&STDERR', 'alloc_new_iface', 'ap');
    close $in_154 or croak 'Close failed: $OS_ERROR';
    my $result_154 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_154> };
    close $out_154 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_154, 0;
    $result_154
};
if ((!(    networkmanager_is_running()) && ($NM_OLDER_VERSION == 0))) {
        print "Network Manager found, set " . ${VWIFI_IFACE} . " as unmanaged device... ";
        networkmanager_add_unmanaged($VWIFI_IFACE);
        print "DONE\n";
    }
if (!(    is_wifi_connected($WIFI_IFACE))) {
        my $WIFI_IFACE_FREQ;
        my @WIFI_IFACE_FREQ;
        my %WIFI_IFACE_FREQ;
        $WIFI_IFACE_FREQ = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_155 = q{};
            my $output_printed_155;
            my $pipeline_success_155 = 1;

            my ($in_156, $out_156);
            my $pid_156 = open3($in_156, $out_156, '>&STDERR', 'iw', 'dev', 'link');
            close $in_156 or croak 'Close failed: $OS_ERROR';
            $output_155 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_156> };
            close $out_156 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_156, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_155 = 0; }
            my $grep_result_155_1;
            my @grep_lines_155_1 = split /\n/msx, $output_155;
            my @grep_filtered_155_1 = grep { /freq/msxi } @grep_lines_155_1;
            $grep_result_155_1 = join "\n", @grep_filtered_155_1;
                        if (!($grep_result_155_1 =~ m{\n\z}msx || $grep_result_155_1 eq q{})) {
                            $grep_result_155_1 .= "\n";
                        }
            $CHILD_ERROR = scalar @grep_filtered_155_1 > 0 ? 0 : 1;
            $output_155 = $grep_result_155_1;
            my @lines = split /\n/msx, $output_155;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                push @result, ($fields[1] . "\n");
            }
            $output_155 = join "", @result;

            if ( !$pipeline_success_155 ) { $main_exit_code = 1; }
            $output_155 =~ s/\n+\z//msx;
            $output_155;
}; $_pipeline_result; };
        $WIFI_IFACE_CHANNEL = do {
    my ($in_157, $out_157);
    my $pid_157 = open3($in_157, $out_157, '>&STDERR', 'ieee80211_frequency_to_channel', $WIFI_IFACE_FREQ);
    close $in_157 or croak 'Close failed: $OS_ERROR';
    my $result_157 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_157> };
    close $out_157 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_157, 0;
    $result_157
};
        print ${WIFI_IFACE} . " is already associated with channel " . ${WIFI_IFACE_CHANNEL} . " (" . ${WIFI_IFACE_FREQ} . " MHz)";
if (!(        is_5ghz_frequency($WIFI_IFACE_FREQ))) {
            $FREQ_BAND = q{5};
}
        else {
            $FREQ_BAND = '2.4';
        }
if (($WIFI_IFACE_CHANNEL != $CHANNEL)) {
            do {
    my $__echo_line = ", fallback to channel " . ${WIFI_IFACE_CHANNEL};
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            $CHANNEL = $WIFI_IFACE_CHANNEL;
}
        else {
            print "\n";
            $CHILD_ERROR = 0;
        }
    }
    my $VIRTDIEMSG;
    my @VIRTDIEMSG;
    my %VIRTDIEMSG;
    $VIRTDIEMSG = "Maybe your WiFi adapter does not fully support virtual interfaces.
       Try again with --no-virt.";
    print "Creating a virtual WiFi interface... ";
if (!(    $main_exit_code = system('iw', 'dev', $WIFI_IFACE, 'interface', 'add', $VWIFI_IFACE, 'type', '__ap') >> 8)) {
        if (do {
if (do {
networkmanager_is_running();
    $CHILD_ERROR == 0
}) {
    ($NM_OLDER_VERSION == 0)}
            $CHILD_ERROR == 0
        }) {
                        networkmanager_wait_until_unmanaged($VWIFI_IFACE);
        }
        print ${VWIFI_IFACE} . " created.";
if ( !( (${VWIFI_IFACE} . " created.") =~ m{\n\z}msx ) ) { print "\n"; }
}
    else {
        $VWIFI_IFACE = q{};
        die("$VIRTDIEMSG");
    }
    $OLD_MACADDR = do {
    my ($in_158, $out_158);
    my $pid_158 = open3($in_158, $out_158, '>&STDERR', 'get_macaddr', $VWIFI_IFACE);
    close $in_158 or croak 'Close failed: $OS_ERROR';
    my $result_158 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_158> };
    close $out_158 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_158, 0;
    $result_158
};
if (("$NEW_MACADDR" eq q{} && (qx'get_all_macaddrs | grep -c ${OLD_MACADDR}' != 1))) {
        $NEW_MACADDR = do {
    my ($in_159, $out_159);
    my $pid_159 = open3($in_159, $out_159, '>&STDERR', 'get_new_macaddr', $VWIFI_IFACE);
    close $in_159 or croak 'Close failed: $OS_ERROR';
    my $result_159 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_159> };
    close $out_159 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_159, 0;
    $result_159
};
    }
    $WIFI_IFACE = $VWIFI_IFACE;
}
else {
    $OLD_MACADDR = do {
    my ($in_160, $out_160);
    my $pid_160 = open3($in_160, $out_160, '>&STDERR', 'get_macaddr', $WIFI_IFACE);
    close $in_160 or croak 'Close failed: $OS_ERROR';
    my $result_160 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_160> };
    close $out_160 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_160, 0;
    $result_160
};
}
mutex_lock();
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', $CONFDIR
      or die "Cannot open file: $OS_ERROR\n";
    print $WIFI_IFACE;
if ( !( ($WIFI_IFACE) =~ m{\n\z}msx ) ) { print "\n"; }
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
$main_exit_code = system('bash', '/wifi_iface') >> 8;
chmod(oct('444'), ($CONFDIR, '/wifi_iface')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
mutex_unlock();
if (("$COUNTRY" ne q{} && ($USE_IWCONFIG == 0))) {
    $main_exit_code = system('iw', 'reg', 'set', "$COUNTRY") >> 8;
}
can_transmit_to_channel($WIFI_IFACE, $CHANNEL);
if ($CHILD_ERROR != 0) {
        die("Your adapter can not transmit to channel " . ${CHANNEL} . ", frequency band " . ${FREQ_BAND} . "GHz.");
}
if ((!(networkmanager_exists()) && !(!(networkmanager_iface_is_unmanaged($WIFI_IFACE);)))) {
    print "Network Manager found, set " . ${WIFI_IFACE} . " as unmanaged device... ";
    networkmanager_add_unmanaged($WIFI_IFACE);
if (!(    networkmanager_is_running())) {
        networkmanager_wait_until_unmanaged($WIFI_IFACE);
    }
    print "DONE\n";
}
if (($HIDDEN == 1)) {
        print "Access Point's SSID is hidden!\n";
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if (($MAC_FILTER == 1)) {
        print "MAC address filtering is enabled!\n";
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if (($ISOLATE_CLIENTS == 1)) {
        print "Access Point's clients will be isolated!\n";
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
open my $fh_cat, '>', '$CONFDIR' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "beacon_int=100
ssid=${SSID}
interface=${WIFI_IFACE}
driver=${DRIVER}
channel=${CHANNEL}
ctrl_interface=$CONFDIR/hostapd_ctrl
ctrl_interface_group=0
ignore_broadcast_ssid=$HIDDEN
ap_isolate=$ISOLATE_CLIENTS
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
$main_exit_code = system('bash', '/hostapd.conf') >> 8;
if ("$COUNTRY" ne q{}) {
open my $fh_cat, '>', '$CONFDIR' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "country_code=${COUNTRY}
ieee80211d=1
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    $main_exit_code = system('bash', '/hostapd.conf') >> 8;
}
if ($FREQ_BAND =~ /^2[.]4$/msx) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $CONFDIR
      or die "Cannot open file: $OS_ERROR\n";
        print "hw_mode=g\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('bash', '/hostapd.conf') >> 8;
}
else {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $CONFDIR
      or die "Cannot open file: $OS_ERROR\n";
        print "hw_mode=a\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('bash', '/hostapd.conf') >> 8;
}
if (($MAC_FILTER == 1)) {
open my $fh_cat, '>', '$CONFDIR' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "macaddr_acl=${MAC_FILTER}
accept_mac_file=${MAC_FILTER_ACCEPT}
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    $main_exit_code = system('bash', '/hostapd.conf') >> 8;
}
if (($IEEE80211N == 1)) {
open my $fh_cat, '>', '$CONFDIR' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "ieee80211n=1
ht_capab=${HT_CAPAB}
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    $main_exit_code = system('bash', '/hostapd.conf') >> 8;
}
if (($IEEE80211AC == 1)) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $CONFDIR
      or die "Cannot open file: $OS_ERROR\n";
        print "ieee80211ac=1\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('bash', '/hostapd.conf') >> 8;
}
if ("$VHT_CAPAB" ne q{}) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $CONFDIR
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "vht_capab=" . ${VHT_CAPAB};
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
    $main_exit_code = system('bash', '/hostapd.conf') >> 8;
}
if ((($IEEE80211N == 1) || ($IEEE80211AC == 1))) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $CONFDIR
      or die "Cannot open file: $OS_ERROR\n";
        print "wmm_enabled=1\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('bash', '/hostapd.conf') >> 8;
}
if ("$PASSPHRASE" ne q{}) {
    if ("$WPA_VERSION" =~ /^"1[+]2"$/msx) {
                $WPA_VERSION = q{3};
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if (($USE_PSK == 0)) {
        my $WPA_KEY_TYPE;
        my @WPA_KEY_TYPE;
        my %WPA_KEY_TYPE;
        $WPA_KEY_TYPE = 'passphrase';
}
    else {
        $WPA_KEY_TYPE = 'psk';
    }
open my $fh_cat, '>', '$CONFDIR' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "wpa=${WPA_VERSION}
wpa_${WPA_KEY_TYPE}=${PASSPHRASE}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP CCMP
rsn_pairwise=CCMP
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    $main_exit_code = system('bash', '/hostapd.conf') >> 8;
}
if ("$SHARE_METHOD" =~ /^"bridge"$/msx) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $CONFDIR
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "bridge=" . ${BRIDGE_IFACE};
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
    $main_exit_code = system('bash', '/hostapd.conf') >> 8;
}
else {
    if (($NO_DNSMASQ == 0)) {
        my $DNSMASQ_VER;
        my @DNSMASQ_VER;
        my %DNSMASQ_VER;
        $DNSMASQ_VER = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_162 = q{};
            my $output_printed_162;
            my $pipeline_success_162 = 1;

            my ($in_163, $out_163);
            my $pid_163 = open3($in_163, $out_163, '>&STDERR', 'dnsmasq', '-v');
            close $in_163 or croak 'Close failed: $OS_ERROR';
            $output_162 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_163> };
            close $out_163 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_163, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_162 = 0; }
            my $grep_result_162_1;
            my @grep_lines_162_1 = split /\n/msx, $output_162;
            my @grep_filtered_162_1 = grep { /[0-9]+([.][0-9]+)*[.][0-9]+/msx } @grep_lines_162_1;
            my @grep_matches_162_1;
            foreach my $line (@grep_filtered_162_1) {
                if ($line =~ /([0-9]+([.][0-9]+)*[.][0-9]+)/msx) {
                    push @grep_matches_162_1, $1;
                }
            }
            $grep_result_162_1 = join "\n", @grep_matches_162_1;
            $CHILD_ERROR = scalar @grep_filtered_162_1 > 0 ? 0 : 1;
            $output_162 = $grep_result_162_1;
            if ((scalar @grep_filtered_162_1) == 0) {
                $pipeline_success_162 = 0;
            }
            if ( !$pipeline_success_162 ) { $main_exit_code = 1; }
            $output_162 =~ s/\n+\z//msx;
            $output_162;
}; $_pipeline_result; };
        version_cmp($DNSMASQ_VER, '2.63');
if (($? == 1)) {
            my $DNSMASQ_BIND;
            my @DNSMASQ_BIND;
            my %DNSMASQ_BIND;
            $DNSMASQ_BIND = 'bind-interfaces';
}
        else {
            $DNSMASQ_BIND = 'bind-dynamic';
        }
if ("$DHCP_DNS" =~ /^"gateway"$/msx) {
            $DHCP_DNS = "$GATEWAY";
        }
open my $fh_cat, '>', '$CONFDIR' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "listen-address=${GATEWAY}
${DNSMASQ_BIND}
dhcp-range=${GATEWAY%.*}.1,${GATEWAY%.*}.254,255.255.255.0,24h
dhcp-option-force=option:router,${GATEWAY}
dhcp-option-force=option:dns-server,${DHCP_DNS}
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
        $main_exit_code = system('bash', '/dnsmasq.conf') >> 8;
        $MTU = do {
    my ($in_164, $out_164);
    my $pid_164 = open3($in_164, $out_164, '>&STDERR', 'get_mtu', $INTERNET_IFACE);
    close $in_164 or croak 'Close failed: $OS_ERROR';
    my $result_164 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_164> };
    close $out_164 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_164, 0;
    $result_164
};
        if ("$MTU" ne q{}) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $CONFDIR
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "dhcp-option-force=option:mtu," . ${MTU};
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
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        $main_exit_code = system('bash', '/dnsmasq.conf') >> 8;
        if (($ETC_HOSTS == 0)) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $CONFDIR
      or die "Cannot open file: $OS_ERROR\n";
                print 'no-hosts' . "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        $main_exit_code = system('bash', '/dnsmasq.conf') >> 8;
        if ("$ADDN_HOSTS" ne q{}) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $CONFDIR
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "addn-hosts=" . ${ADDN_HOSTS};
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
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        $main_exit_code = system('bash', '/dnsmasq.conf') >> 8;
if (("$SHARE_METHOD" =~ /^"none"$/msx && "$REDIRECT_TO_LOCALHOST" =~ /^"1"$/msx)) {
open my $fh_cat, '>', '$CONFDIR' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "address=/#/$GATEWAY
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
            $main_exit_code = system('bash', '/dnsmasq.conf') >> 8;
        }
    }
}
if ((($NO_VIRT == 0) && "$NEW_MACADDR" ne q{})) {
        $main_exit_code = system('ip', 'link', 'set', 'dev', $WIFI_IFACE, 'address', $NEW_MACADDR) >> 8;
    if ($CHILD_ERROR != 0) {
                die("$VIRTDIEMSG");
    }
}
$main_exit_code = system('ip', 'link', 'set', 'down', 'dev', $WIFI_IFACE) >> 8;
if ($CHILD_ERROR != 0) {
        die("$VIRTDIEMSG");
}
$main_exit_code = system('ip', 'addr', 'flush', $WIFI_IFACE) >> 8;
if ($CHILD_ERROR != 0) {
        die("$VIRTDIEMSG");
}
if ((($NO_VIRT == 1) && "$NEW_MACADDR" ne q{})) {
        $main_exit_code = system('ip', 'link', 'set', 'dev', $WIFI_IFACE, 'address', $NEW_MACADDR) >> 8;
    if ($CHILD_ERROR != 0) {
                die();
    }
}
if ("$SHARE_METHOD" ne "bridge") {
        $main_exit_code = system('ip', 'link', 'set', 'up', 'dev', $WIFI_IFACE) >> 8;
    if ($CHILD_ERROR != 0) {
                die("$VIRTDIEMSG");
    }
        $main_exit_code = system('ip', 'addr', 'add', $GATEWAY, '/24', 'broadcast', scalar reverse( (scalar reverse ${GATEWAY}) =~ s/^.*?\.//r ), '.255', 'dev', $WIFI_IFACE) >> 8;
    if ($CHILD_ERROR != 0) {
                die("$VIRTDIEMSG");
    }
}
if ("$SHARE_METHOD" ne "none") {
    do {
    my $__echo_line = "Sharing Internet using method: $SHARE_METHOD";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if ("$SHARE_METHOD" =~ /^"nat"$/msx) {
                $main_exit_code = system('iptables', '-w', '-t', 'nat', '-I', 'POSTROUTING', '-s', scalar reverse( (scalar reverse ${GATEWAY}) =~ s/^.*?\.//r ), '.0/24', q{!}, '-o', $WIFI_IFACE, '-j', 'MASQUERADE') >> 8;
        if ($CHILD_ERROR != 0) {
                        die();
        }
                $main_exit_code = system('iptables', '-w', '-I', 'FORWARD', '-i', $WIFI_IFACE, '-s', scalar reverse( (scalar reverse ${GATEWAY}) =~ s/^.*?\.//r ), '.0/24', '-j', 'ACCEPT') >> 8;
        if ($CHILD_ERROR != 0) {
                        die();
        }
                $main_exit_code = system('iptables', '-w', '-I', 'FORWARD', '-i', $INTERNET_IFACE, '-d', scalar reverse( (scalar reverse ${GATEWAY}) =~ s/^.*?\.//r ), '.0/24', '-j', 'ACCEPT') >> 8;
        if ($CHILD_ERROR != 0) {
                        die();
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/proc/sys/net/ipv4/conf/'
      or die "Cannot open file: $OS_ERROR\n";
            print q{1} . "\n";
            $CHILD_ERROR = 0;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
                $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) {
                        die();
        }
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/proc/sys/net/ipv4/ip_forward'
      or die "Cannot open file: $OS_ERROR\n";
            print q{1} . "\n";
            $CHILD_ERROR = 0;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ($CHILD_ERROR != 0) {
                        die();
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('modprobe', 'nf_nat_pptp') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
}
    else {
        if ("$SHARE_METHOD" =~ /^"bridge"$/msx) {
if ((-e '/proc/sys/net/bridge/bridge-nf-call-iptables')) {
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/proc/sys/net/bridge/bridge-nf-call-iptables'
      or die "Cannot open file: $OS_ERROR\n";
                    print q{0} . "\n";
                    $CHILD_ERROR = 0;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
            }
if (!(!(is_bridge_interface($INTERNET_IFACE);))) {
                print "Create a bridge interface... ";
                my $OLD_IFS;
                my @OLD_IFS;
                my %OLD_IFS;
                $OLD_IFS = "$ENV{IFS}";
                my $IFS;
                my @IFS;
                my %IFS;
                $IFS = "\n";
                @IP_ADDRS = (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_165 = q{};
                    my $output_printed_165;
                    my $pipeline_success_165 = 1;

                    my ($in_166, $out_166);
                    my $pid_166 = open3($in_166, $out_166, '>&STDERR', 'ip', 'addr', 'show');
                    close $in_166 or croak 'Close failed: $OS_ERROR';
                    $output_165 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_166> };
                    close $out_166 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_166, 0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_165 = 0; }
                    my $grep_result_165_1;
                    my @grep_lines_165_1 = split /\n/msx, $output_165;
                    my @grep_filtered_165_1 = grep { /inet[[:blank:]]/msx } @grep_lines_165_1;
                    my @grep_with_context_165_1;
                    for my $i (0..@grep_lines_165_1-1) {
                        if (scalar grep { $_ eq $grep_lines_165_1[$i] } @grep_filtered_165_1) {
                            push @grep_with_context_165_1, $grep_lines_165_1[$i];
                            for my $j (($i + 1)..($i + 1)) {
                                push @grep_with_context_165_1, $grep_lines_165_1[$j];
                            }
                        }
                    }
                    $grep_result_165_1 = join "\n", @grep_with_context_165_1;
                    $CHILD_ERROR = scalar @grep_filtered_165_1 > 0 ? 0 : 1;
                    $output_165 = $grep_result_165_1;
                    $output_165 = do {
                                        my @paste_stdin_lines_fh_1 = split /\n/msx, $output_165;
                                        my $paste_output = q{};
                                        my $stdin_pos_fh_1 = 0;
                                        for (my $i = 0; ; $i++) {
                                            my @parts = ();
                                            my $row_has_data = 0;
                                            my $val_0_fh_1 = $stdin_pos_fh_1 < scalar @paste_stdin_lines_fh_1 ? $paste_stdin_lines_fh_1[$stdin_pos_fh_1] : q{};
                                            if ($val_0_fh_1 ne q{}) { $row_has_data = 1; $stdin_pos_fh_1++; }
                                            push @parts, $val_0_fh_1;
                                            my $val_1_fh_1 = $stdin_pos_fh_1 < scalar @paste_stdin_lines_fh_1 ? $paste_stdin_lines_fh_1[$stdin_pos_fh_1] : q{};
                                            if ($val_1_fh_1 ne q{}) { $row_has_data = 1; $stdin_pos_fh_1++; }
                                            push @parts, $val_1_fh_1;
                                            last unless $row_has_data;
                                            $paste_output .= join("\t", @parts) . "\n";
                                        }
                    $paste_output
                                        }
                    ;
                    if ( !$pipeline_success_165 ) { $main_exit_code = 1; }
                    $output_165 =~ s/\n+\z//msx;
                    $output_165;
}; $_pipeline_result; });
                @ROUTE_ADDRS = (do {
    my ($in_167, $out_167);
    my $pid_167 = open3($in_167, $out_167, '>&STDERR', 'ip', 'route', 'show', 'dev', $INTERNET_IFACE);
    close $in_167 or croak 'Close failed: $OS_ERROR';
    my $result_167 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_167> };
    close $out_167 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_167, 0;
    $result_167
});
                $IFS = "$OLD_IFS";
if (!(                networkmanager_is_running())) {
                    networkmanager_add_unmanaged($INTERNET_IFACE);
                    networkmanager_wait_until_unmanaged($INTERNET_IFACE);
                }
                                $main_exit_code = system('ip', 'link', 'add', 'name', $BRIDGE_IFACE, 'type', 'bridge') >> 8;
                if ($CHILD_ERROR != 0) {
                                        die();
                }
                                $main_exit_code = system('ip', 'link', 'set', 'dev', $BRIDGE_IFACE, 'up') >> 8;
                if ($CHILD_ERROR != 0) {
                                        die();
                }
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/sys/class/net/'
      or die "Cannot open file: $OS_ERROR\n";
                    print q{0};
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
                $CHILD_ERROR = 0;
                                $main_exit_code = system('ip', 'link', 'set', 'dev', $INTERNET_IFACE, 'promisc', 'on') >> 8;
                if ($CHILD_ERROR != 0) {
                                        die();
                }
                                $main_exit_code = system('ip', 'link', 'set', 'dev', $INTERNET_IFACE, 'up') >> 8;
                if ($CHILD_ERROR != 0) {
                                        die();
                }
                                $main_exit_code = system('ip', 'link', 'set', 'dev', $INTERNET_IFACE, 'master', $BRIDGE_IFACE) >> 8;
                if ($CHILD_ERROR != 0) {
                                        die();
                }
                $main_exit_code = system('ip', 'addr', 'flush', $INTERNET_IFACE) >> 8;
                for my $x (@IP_ADDRS) {
                    $x = ($ENV{x/inet/} // q{});
                    $x = ($ENV{x/secondary/} // q{});
                    $x = ($ENV{x/dynamic/} // q{});
                    $x = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                        my $output_168 = q{};
                        my $output_printed_168;
                        my $pipeline_success_168 = 1;
                        $output_168 .= $x . "\n";
                        if ( !($output_168 =~ m{\n\z}msx) ) { $output_168 .= "\n"; }
                        $CHILD_ERROR = 0;
                        if ($CHILD_ERROR != 0) { $pipeline_success_168 = 0; }
                        my @sed_lines_168 = split /\n/msx, $output_168;
                        my @sed_result_168;
                        foreach my $line (@sed_lines_168) {
                        chomp $line;
                        $line =~ s/\([0-9]\)sec/\1/gmsx;
                        push @sed_result_168, $line;
                        }
                        $output_168 = join "\n", @sed_result_168;

                        if ( !$pipeline_success_168 ) { $main_exit_code = 1; }
                        $output_168 =~ s/\n+\z//msx;
                        $output_168;
}; $_pipeline_result; };
                    $x = $ENV{'x/${INTERNET_IFACE}/'};
                                        $main_exit_code = system('ip', 'addr', 'add', $x, 'dev', $BRIDGE_IFACE) >> 8;
                    if ($CHILD_ERROR != 0) {
                                                die();
                    }
                }
                $main_exit_code = system('ip', 'route', 'flush', 'dev', $INTERNET_IFACE) >> 8;
                $main_exit_code = system('ip', 'route', 'flush', 'dev', $BRIDGE_IFACE) >> 8;
                for my $x (@ROUTE_ADDRS) {
                    if ("$x" =~ /^default.*$/msx) {
                        next;                        $CHILD_ERROR = 0;
                    } else {
                        $CHILD_ERROR = 1;
                    }
                                        $main_exit_code = system('ip', 'route', 'add', $x, 'dev', $BRIDGE_IFACE) >> 8;
                    if ($CHILD_ERROR != 0) {
                                                die();
                    }
                }
                for my $x (@ROUTE_ADDRS) {
                    if ("$x" ne default*) {
                        next;                        $CHILD_ERROR = 0;
                    } else {
                        $CHILD_ERROR = 1;
                    }
                                        $main_exit_code = system('ip', 'route', 'add', $x, 'dev', $BRIDGE_IFACE) >> 8;
                    if ($CHILD_ERROR != 0) {
                                                die();
                    }
                }
                do {
    my $__echo_line = "$BRIDGE_IFACE created.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            }
        }
    }
}
else {
    print "No Internet sharing\n";
}
if ("$SHARE_METHOD" ne "bridge") {
if (($NO_DNS == 0)) {
        $DNS_PORT = '5353';
                $main_exit_code = system('iptables', '-w', '-I', 'INPUT', '-p', 'tcp', '-m', 'tcp', '--dport', $DNS_PORT, '-j', 'ACCEPT') >> 8;
        if ($CHILD_ERROR != 0) {
                        die();
        }
                $main_exit_code = system('iptables', '-w', '-I', 'INPUT', '-p', 'udp', '-m', 'udp', '--dport', $DNS_PORT, '-j', 'ACCEPT') >> 8;
        if ($CHILD_ERROR != 0) {
                        die();
        }
                $main_exit_code = system('iptables', '-w', '-t', 'nat', '-I', 'PREROUTING', '-s', scalar reverse( (scalar reverse ${GATEWAY}) =~ s/^.*?\.//r ), '.0/24', '-d', $GATEWAY, '-p', 'tcp', '-m', 'tcp', '--dport', '53', '-j', 'REDIRECT', '--to-ports', $DNS_PORT) >> 8;
        if ($CHILD_ERROR != 0) {
                        die();
        }
                $main_exit_code = system('iptables', '-w', '-t', 'nat', '-I', 'PREROUTING', '-s', scalar reverse( (scalar reverse ${GATEWAY}) =~ s/^.*?\.//r ), '.0/24', '-d', $GATEWAY, '-p', 'udp', '-m', 'udp', '--dport', '53', '-j', 'REDIRECT', '--to-ports', $DNS_PORT) >> 8;
        if ($CHILD_ERROR != 0) {
                        die();
        }
}
    else {
        $DNS_PORT = q{0};
    }
if (($NO_DNSMASQ == 0)) {
                $main_exit_code = system('iptables', '-w', '-I', 'INPUT', '-p', 'udp', '-m', 'udp', '--dport', '67', '-j', 'ACCEPT') >> 8;
        if ($CHILD_ERROR != 0) {
                        die();
        }
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'complain';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $main_exit_code = system('complain', 'dnsmasq') >> 8;
        }
        $main_exit_code = system('umask', '0033') >> 8;
                $main_exit_code = system('dnsmasq', '-C', $CONFDIR, '/dnsmasq.conf', '-x', $CONFDIR, '/dnsmasq.pid', '-l', $CONFDIR, '/dnsmasq.leases', '-p', $DNS_PORT) >> 8;
        if ($CHILD_ERROR != 0) {
                        die();
        }
        $main_exit_code = system('umask', $SCRIPT_UMASK) >> 8;
    }
}
do {
    my $__echo_line = "hostapd command-line interface: hostapd_cli -p $CONFDIR/hostapd_ctrl";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
if (($NO_HAVEGED == 0)) {
    if (my $pid = fork()) {
        # Parent process continues
    } elsif (defined $pid) {
        # Child process executes the background command
        haveged_watchdog();
        exit(0);
    } else {
        die "Cannot fork: $ERRNO\n";
    }
    $HAVEGED_WATCHDOG_PID = $!;
}
my $STDBUF_PATH;
my @STDBUF_PATH;
my %STDBUF_PATH;
$STDBUF_PATH = do { my $which_cmd = 'which stdbuf'; my $which_output = qx{$which_cmd}; $CHILD_ERROR = $? >> 8; $which_output; };
if (($? == 0)) {
    $STDBUF_PATH = $STDBUF_PATH;
}
if (my $pid = fork()) {
    # Parent process continues
} elsif (defined $pid) {
    # Child process executes the background command
    $CHILD_ERROR = 0;
    exit(0);
} else {
    die "Cannot fork: $ERRNO\n";
}
my $HOSTAPD_PID;
my @HOSTAPD_PID;
my %HOSTAPD_PID;
$HOSTAPD_PID = $!;
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', $CONFDIR
      or die "Cannot open file: $OS_ERROR\n";
    print $HOSTAPD_PID;
if ( !( ($HOSTAPD_PID) =~ m{\n\z}msx ) ) { print "\n"; }
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
$main_exit_code = system('bash', '/hostapd.pid') >> 8;
if (!(!(1 while wait() > -1;
$CHILD_ERROR = $? == -1 ? 0 : $? >> 8;))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\nError: Failed to run hostapd, maybe a program is interfering." . "\n";
        $CHILD_ERROR = 0;
    };
if (!(    networkmanager_is_running())) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "If an error like 'n80211: Could not configure driver mode' was thrown\n";
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "try running the following before starting create_ap:\n";
        };
if (($NM_OLDER_VERSION == 1)) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "    nmcli nm wifi off\n";
            };
}
        else {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "    nmcli r wifi off\n";
            };
        }
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "    rfkill unblock wlan\n";
        };
    }
    die();
}
clean_exit();

exit $main_exit_code;
