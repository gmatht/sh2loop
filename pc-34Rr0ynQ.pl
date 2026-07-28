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

my $MINIDLNA_STATUS;
my @MINIDLNA_STATUS;
my %MINIDLNA_STATUS;
my $DOCKER_STATUS;
my @DOCKER_STATUS;
my %DOCKER_STATUS;
my $EUID;
my @EUID;
my %EUID;
my $selection;
my @selection;
my %selection;
my $HASS_STATUS;
my @HASS_STATUS;
my %HASS_STATUS;
my $TVHEADEND_STATUS;
my @TVHEADEND_STATUS;
my %TVHEADEND_STATUS;
my $ISPCONFIG_STATUS;
my @ISPCONFIG_STATUS;
my %ISPCONFIG_STATUS;
my $MYSQL_PASS;
my @MYSQL_PASS;
my %MYSQL_PASS;
my $PLEX_STATUS;
my @PLEX_STATUS;
my %PLEX_STATUS;
my $SONARR_STATUS;
my @SONARR_STATUS;
my %SONARR_STATUS;
my $VPN_CLIENT_STATUS;
my @VPN_CLIENT_STATUS;
my %VPN_CLIENT_STATUS;
my $VPN_SERVER_STATUS;
my @VPN_SERVER_STATUS;
my %VPN_SERVER_STATUS;
my $SYNCTHING_STATUS;
my @SYNCTHING_STATUS;
my %SYNCTHING_STATUS;
my $HOSTNAMEFQDN;
my @HOSTNAMEFQDN;
my %HOSTNAMEFQDN;
my $OMV_STATUS;
my @OMV_STATUS;
my %OMV_STATUS;
my $i;
my @i;
my %i;
my $NCP_STATUS;
my @NCP_STATUS;
my %NCP_STATUS;
my $EMBY_STATUS;
my @EMBY_STATUS;
my %EMBY_STATUS;
my $PI_HOLE_STATUS;
my @PI_HOLE_STATUS;
my %PI_HOLE_STATUS;
my $TRANSMISSION_STATUS;
my @TRANSMISSION_STATUS;
my %TRANSMISSION_STATUS;
my $URBACKUP_STATUS;
my @URBACKUP_STATUS;
my %URBACKUP_STATUS;
my $MAYAN_STATUS;
my @MAYAN_STATUS;
my %MAYAN_STATUS;
my $CUPS_STATUS;
my @CUPS_STATUS;
my %CUPS_STATUS;
my $SAMBA_STATUS;
my @SAMBA_STATUS;
my %SAMBA_STATUS;
my $LISTLENGTH;
my @LISTLENGTH;
my %LISTLENGTH;
my $OPENHAB_STATUS;
my @OPENHAB_STATUS;
my %OPENHAB_STATUS;
my $RADARR_STATUS;
my @RADARR_STATUS;
my %RADARR_STATUS;

my $MAGIC_38    = 38;
my $MAGIC_700   = 700;
my $MAGIC_33    = 33;
my $MAGIC_70    = 70;
my $MAGIC_75    = 75;
my $MAGIC_8989  = 8_989;
my $MAGIC_8096  = 8_096;
my $MAGIC_8200  = 8_200;
my $MAGIC_9981  = 9_981;
my $MAGIC_631   = 631;
my $MAGIC_443   = 443;
my $MAGIC_445   = 445;
my $MAGIC_600   = 600;
my $MAGIC_9091  = 9_091;
my $MAGIC_5     = 5;
my $MAGIC_8123  = 8_123;
my $MAGIC_28    = 28;
my $MAGIC_755   = 755;
my $MAGIC_68    = 68;
my $MAGIC_80    = 80;
my $MAGIC_11    = 11;
my $MAGIC_3     = 3;
my $MAGIC_7878  = 7_878;
my $MAGIC_41    = 41;
my $MAGIC_8080  = 8_080;
my $MAGIC_55414 = 55_414;
my $MAGIC_8     = 8;
my $MAGIC_52    = 52;
my $MAGIC_8384  = 8_384;
my $MAGIC_44    = 44;
my $MAGIC_7     = 7;
my $MAGIC_32400 = 32_400;

if ((-f 'debian-config-jobs')) {
# Builtin command 'source' not implemented
}
else {
    if ((-f '/usr/lib/orangepi-config/jobs.sh')) {
# Builtin command 'source' not implemented
}
    else {
exit 1;
    }
}
if ((-f 'debian-config-submenu')) {
# Builtin command 'source' not implemented
}
else {
    if ((-f '/usr/lib/orangepi-config/submenu.sh')) {
# Builtin command 'source' not implemented
}
    else {
exit 1;
    }
}
if ((-f 'debian-config-functions')) {
# Builtin command 'source' not implemented
}
else {
    if ((-f '/usr/lib/orangepi-config/functions.sh')) {
# Builtin command 'source' not implemented
}
    else {
exit 1;
    }
}
if ((-f 'debian-config-functions-network')) {
# Builtin command 'source' not implemented
}
else {
    if ((-f '/usr/lib/orangepi-config/functions-network.sh')) {
# Builtin command 'source' not implemented
}
    else {
exit 1;
    }
}

sub check_status {
    $main_exit_code = system('dialog', '--backtitle', "$ENV{BACKTITLE}", '--title', "Please wait", '--infobox', "\nLoading install info ... ", q{5}, '28') >> 8;
    my $LIST;
    my @LIST = ();
    my %LIST;
    my $LIST_CONST;
    my @LIST_CONST;
    my %LIST_CONST;
    $LIST_CONST = '26';
    $SAMBA_STATUS = (do { my $_chomp_temp = do {
    my $command = 'check_if_installed samba && echo on || echo off';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_port', "Windows compatible file sharing", "445", "boolean") >> 8;
    push @LIST, 'Samba', $DESCRIPTION, $SAMBA_STATUS;
    $CUPS_STATUS = (do { my $_chomp_temp = do {
    my $command = 'check_if_installed cups && echo on || echo off';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_port', "Common UNIX Printing System (CUPS)", "631", "boolean") >> 8;
    push @LIST, 'CUPS', $DESCRIPTION, $CUPS_STATUS;
    $TVHEADEND_STATUS = (do { my $_chomp_temp = do {
    my $command = 'check_if_installed tvheadend && echo on || echo off';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_port', "TV streaming server", "9981") >> 8;
    push @LIST, 'TV headend', $DESCRIPTION, $TVHEADEND_STATUS;
    $SYNCTHING_STATUS = (do { my $_chomp_temp = do {
    my $command = q{: 'Complex command not supported in bash string generation' && echo on || echo off};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_port', "Personal cloud @syncthing.net", "8384") >> 8;
    push @LIST, 'Syncthing', $DESCRIPTION, $SYNCTHING_STATUS;
    $HASS_STATUS = (do { my $_chomp_temp = do {
    my $command = q{: 'Complex command not supported in bash string generation' && echo on || echo off};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_port', "Home assistant smarthome suite", "8123") >> 8;
    $OPENHAB_STATUS = (do { my $_chomp_temp = do {
    my $command = q{: 'Complex command not supported in bash string generation' && echo on || echo off};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_port', "Openhab2 smarthome suite", "8080") >> 8;
    push @LIST, 'OpenHAB', $DESCRIPTION, $OPENHAB_STATUS;
if (("$(dpkg --print-architecture)" =~ /^"armhf"$/msx || "$(dpkg --print-architecture)" =~ /^"amd64"$/msx)) {
        $VPN_SERVER_STATUS = (do { my $_chomp_temp = do {
    my $command = q{: 'Complex command not supported in bash string generation' && echo on || echo off};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
        push @LIST, 'VPN server', 'Softether VPN server', $VPN_SERVER_STATUS;
        $VPN_CLIENT_STATUS = (do { my $_chomp_temp = do {
    my $command = q{: 'Complex command not supported in bash string generation' && echo on || echo off};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
        push @LIST, 'VPN client', 'Softether VPN client', $VPN_CLIENT_STATUS;
        $LIST_CONST = eval { int($LIST_CONST + 1) } // "";
    }
    $NCP_STATUS = (do { my $_chomp_temp = do {
    my $command = q{: 'Complex command not supported in bash string generation' && echo on || echo off};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_port', "Nextcloud personal cloud", "443") >> 8;
    if (do {
if ("$family" ne "Ubuntu") {
        @LIST = ('NCP', $DESCRIPTION, $NCP_STATUS);
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
        $CHILD_ERROR == 0
    }) {
                $LIST_CONST = eval { int($LIST_CONST + 1) } // "";
    }
    $OMV_STATUS = (do { my $_chomp_temp = do {
    my $command = 'check_if_installed openmediavault && echo on || echo off';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    if (do {
if ("$family" ne "Ubuntu") {
        @LIST = ('OMV', 'OpenMediaVault NAS solution', $OMV_STATUS);
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
        $CHILD_ERROR == 0
    }) {
                $LIST_CONST = eval { int($LIST_CONST + 1) } // "";
    }
    $PLEX_STATUS = (do { my $_chomp_temp = do {
    my $command = 'check_if_installed plexmediaserver || check_if_installed plexmediaserver-installer && echo on || echo off';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_port', "Plex media server", "32400") >> 8;
    push @LIST, 'Plex', $DESCRIPTION, $PLEX_STATUS;
    my $AMBY_STATUS;
    my @AMBY_STATUS;
    my %AMBY_STATUS;
    $AMBY_STATUS = (do { my $_chomp_temp = do {
    my $command = 'check_if_installed emby-server && echo on || echo off';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_port', "Emby server", "8096") >> 8;
    push @LIST, 'Emby', $DESCRIPTION, $AMBY_STATUS;
    $RADARR_STATUS = (do { my $_chomp_temp = do {
    my $command = q{: 'Complex command not supported in bash string generation' && echo on || echo off};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_port', "Movies downloading server", "7878") >> 8;
    push @LIST, 'Radarr', $DESCRIPTION, $RADARR_STATUS;
    $SONARR_STATUS = (do { my $_chomp_temp = do {
    my $command = q{: 'Complex command not supported in bash string generation' && echo on || echo off};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_port', "TV shows downloading server", "8989") >> 8;
    push @LIST, 'Sonarr', $DESCRIPTION, $SONARR_STATUS;
    $MINIDLNA_STATUS = (do { my $_chomp_temp = do {
    my $command = 'check_if_installed minidlna && echo on || echo off';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_port', "Lightweight DLNA/UPnP-AV server", "8200", "boolean") >> 8;
    push @LIST, 'Minidlna', $DESCRIPTION, $MINIDLNA_STATUS;
    $PI_HOLE_STATUS = (do { my $_chomp_temp = do {
    my $command = q{: 'Complex command not supported in bash string generation' && echo on || echo off};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_process', "Ad blocker", "pihole-FTL") >> 8;
    push @LIST, 'Pi hole', $DESCRIPTION, $PI_HOLE_STATUS;
    $TRANSMISSION_STATUS = (do { my $_chomp_temp = do {
    my $command = 'check_if_installed transmission-daemon && echo on || echo off';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_port', "Torrent download server", "9091") >> 8;
    $URBACKUP_STATUS = (do { my $_chomp_temp = do {
    my $command = 'check_if_installed urbackup-server || check_if_installed urbackup-server-dbg && echo on || echo off';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('alive_port', "Client/server backup " . "sys" . "tem", "55414") >> 8;
    push @LIST, 'UrBackup', $DESCRIPTION, $URBACKUP_STATUS;
    $DOCKER_STATUS = (do { my $_chomp_temp = do {
    my $command = 'check_if_installed docker-ce && echo on || echo off';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    push @LIST, 'Docker', 'Run applications by using containers', $DOCKER_STATUS;
if ("$DOCKER_STATUS" =~ /^"on"$/msx) {
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Headers;
my $ua = LWP::UserAgent->new;
my $request = HTTP::Request->new('GET', 'http://localhost/authentication/login/?next');
my $response = $ua->request($request);
if ($response->is_success) {
if (open my $fh, '>', '/dev/null') {
print $fh $response->content;
close $fh or croak "Close failed: $ERRNO";
print "Content saved to '/dev/null'\n";
} else {
die "curl: Cannot write to '/dev/null': $OS_ERROR\n";
}
} else {
die "curl: HTTP error: $response->code $response->message\n";
}
        $MAYAN_STATUS = do {
    my $command = q{: 'Complex command not supported in bash string generation' && echo on || echo off};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
}
    else {
        $MAYAN_STATUS = "off";
    }
    $main_exit_code = system('alive_port', "SMTP mail, IMAP, POP3 & LAMP/LEMP web server", "8080", "ssl") >> 8;
    $ISPCONFIG_STATUS = (do { my $_chomp_temp = do {
    my $command = q{: 'Complex command not supported in bash string generation' && echo on || echo off};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
    push @LIST, 'ISPConfig', $DESCRIPTION, $ISPCONFIG_STATUS;
    return;
}

sub choose_webserver {
    $main_exit_code = system('check_if_installed', 'openmediavault') >> 8;
if ($? =~ /^0$/msx) {
                my $server;
        my @server;
        my %server;
        $server = "nginx";
    } elsif (1) {
                $main_exit_code = system('dialog', '--title', "Choose a webserver", '--backtitle', "$ENV{BACKTITLE}", '--yes-label', "Apache", '--no-label', "Nginx", '--yesno', "\nChoose a web server which you are familiar with. They both work almost the same.", q{8}, '70') >> 8;
                my $response;
        my @response;
        my %response;
        $response = $?;
        if ($response =~ /^0$/msx) {
                        $server = "apache";
        } elsif ($response =~ /^1$/msx) {
                        $server = "nginx";
        } elsif ($response =~ /^255$/msx) {
            exit $main_exit_code;
        }
    }
    return;
}

sub server_conf {
if ("$(curl -s ipinfo.io/ip)" ne "$serverIP") {
        my $table;
        my @table;
        my %table;
        $table = "\Z2Application     Protocol      Port\n
\Z0----------------------------------\n
FTP                  TCP        20\n
FTP                  TCP        21\n
SSH/SFTP             TCP        22\n
Mail (SMTP)          TCP        25\n
DNS                  TCP        53\n
Web (HTTP)           TCP        80\n
Mail (POP3)          TCP       110\n
Mail (IMAP)          TCP       143\n
Web (HTTPS)          TCP       443\n
Mail (SMTPS)         TCP       465\n
Mail (SMTP)          TCP       587\n
Mail (IMAPS)         TCP       993\n
Mail (POP3S)         TCP       995\n
Database             TCP      3306\n
Chat (XMPP)          TCP      5222\n
ISPConfig            TCP      8080\n
ISPConfig            TCP      8081\n
ISPConfig            TCP     10000\n
DNS                  UDP        53\n
Database             UDP      3306\n
";
        $main_exit_code = system('dialog', '--colors', '--title', "Warning", '--msgbox', "\nYour internal and external IP addresses are different which seems that you are behind a router. \n\nMake sure \Z1$ENV{serverIP}\Z0 is a static IP address. Then forward external ports to those services which you plan to use.\n\n\n$table", '38', '38') >> 8;
    }
    $HOSTNAMEFQDN = do { my @_qx_cmd = ("dialog --title 'Server configuration' --ok-label Install --backtitle \"$BACKTITLE\" --inputbox \"\\\\nSet FQDN for $serverIP:\" 10 50 \"$var.example.com\" 2>&1 2>&2 2>&3 2> -"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    $MYSQL_PASS = do { my @_qx_cmd = (" < /dev/urandom"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    return;
}

sub install_packet {
    my ($file) = @_;
    $i = q{0};
    my $j;
    my @j;
    my %j;
    $j = q{1};
    my $IFS;
    my @IFS;
    my %IFS;
    $IFS = " ";
    my @PACKETS = ('$1');
    my $skupaj;
    my @skupaj;
    my %skupaj;
    $skupaj = scalar(@PACKETS);
while ( $i < $skupaj ) {
        my $procent;
        my @procent;
        my %procent;
        $procent = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_1 = q{};
            my $output_printed_1;
            my $pipeline_success_1 = 1;
            $output_1 .= "scale=2;($j/$skupaj)*100\n";
            if ( !($output_1 =~ m{\n\z}msx) ) { $output_1 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }

            my $cmd_3 = 'bc';
            my ($in_2, $out_2);
            my $pid_2 = open3($in_2, $out_2, '>&STDERR', $cmd_3, );
            print {$in_2} $output_1;
            close $in_2 or croak 'Close failed: $OS_ERROR';
            $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
            close $out_2 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_2, 0;
            if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
            $output_1 =~ s/\n+\z//msx;
            $output_1;
}; $_pipeline_result; };
        my $x;
        my @x;
        my %x;
        $x = $PACKETS[eval { int($i) } // ""];
if ($(dpkg-query -W -f eq '${Status}' $x 2>/dev/null | grep -c "ok installed") -eq 0) {
            # Original bash: printf '%.0f\n' $procent | dialog \
{
                my $output_4 = q{};
                my $output_printed_4;
                my $pipeline_success_4 = 1;
                                my $output_4;
                {
                local *STDOUT;
                open STDOUT, '>', \$output_4 or die "Cannot redirect STDOUT";
                printf("%.0f\n", $procent);
                }

                                my $cmd_6 = 'dialog';
                my ($in_5, $out_5);
                my $pid_5 = open3($in_5, $out_5, '>&STDERR', $cmd_6, '--backtitle', '--title', '--gauge', '10', '70');
                print {$in_5} $output_4;
                close $in_5 or croak 'Close failed: $OS_ERROR';
                $output_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
                close $out_5 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_5, 0;
                if ($output_4 ne q{} && !defined $output_printed_4) {
                    print $output_4;
                    if (!($output_4 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
                }
if ("$(DEBIAN_FRONTEND=noninteractive apt-get -qq -y install $x >${TEMP_DIR}/install.log 2>&1 || echo 'Installation failed' \
		| grep 'Installation failed')" ne "") {
                print "[\\e[0;31m error \\x1B[0m] Installation failed\n";
do { my @_qx_cmd = ('tail $TEMP_DIR /install.log'); qx{$_qx_cmd[0]}; };
exit $main_exit_code;
            }
        }
        if (defined $i) {
            $i = eval { int($i+1) } // "";
        }
        $j = eval { int($j+1) } // "";
    }
    print "\n";
    return;
}

sub alive_port {
if (-n $(netstat -lnt | awk '$6 =~ /^"LISTEN"\ &&\ [$]4\ ~\ "[.]'[$]2'"'[)]$/msx) {
if ($3 =~ /^boolean$/msx) {
            my $DESCRIPTION;
            my @DESCRIPTION;
            my %DESCRIPTION;
            $DESCRIPTION = "$_[0] is \Z1active\Z0";
}
        else {
            if ($3 =~ /^ssl$/msx) {
                $DESCRIPTION = "Active on https://" . ($ENV{serverIP} // q{}) . ":\Z1$_[1]\Z0$_[3]";
}
            else {
                $DESCRIPTION = "Active on http://" . ($ENV{serverIP} // q{}) . ":\Z1$_[1]\Z0$_[3]";
            }
        }
}
    else {
        $DESCRIPTION = "$_[0]";
    }
    return;
}

sub alive_process {
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('pgrep', '-x', "$_[1]") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        my $DESCRIPTION;
        my @DESCRIPTION;
        my %DESCRIPTION;
        $DESCRIPTION = "$_[0] is \Z1active\Z0";
}
    else {
        $DESCRIPTION = "$_[0]";
    }
    return;
}

sub install_basic {
    my $IFS;
    my @IFS;
    my %IFS;
    $IFS = " ";
    my $HOSTNAMESHORT;
    my @HOSTNAMESHORT;
    my %HOSTNAMESHORT;
    $HOSTNAMESHORT = "$_[0]";
    use File::Copy qw(copy);
    if ( -e '/etc/hosts' ) {
        if ( -d '/etc/hosts.backup' ) {
            require File::Copy; File::Copy::copy('/etc/hosts', '/etc/hosts.backup' . '/' . ('/etc/hosts' =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy('/etc/hosts', '/etc/hosts.backup');
        }
    } else {
        croak "cp: cannot stat '/etc/hosts': No such file or directory\n";
    }
    use File::Copy qw(copy);
    if ( -e '/etc/hostname' ) {
        if ( -d '/etc/hostname.backup' ) {
            require File::Copy; File::Copy::copy('/etc/hostname', '/etc/hostname.backup' . '/' . ('/etc/hostname' =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy('/etc/hostname', '/etc/hostname.backup');
        }
    } else {
        croak "cp: cannot stat '/etc/hostname': No such file or directory\n";
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/etc/hosts'
      or die "Cannot open file: $OS_ERROR\n";
        print "127.0.0.1   localhost.localdomain   localhost\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', '/etc/hosts'
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = ($ENV{serverIP} // q{}) . " " . ${HOSTNAMEFQDN} . " " . ${HOSTNAMESHORT} . " #ispconfig ";
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
        open STDOUT, '>', '/etc/hostname'
      or die "Cannot open file: $OS_ERROR\n";
        print $HOSTNAMESHORT;
if ( !( ($HOSTNAMESHORT) =~ m{\n\z}msx ) ) { print "\n"; }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('/etc/init.d/hostname.sh', 'start') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('hostnamectl', 'set-hostname', $HOSTNAMESHORT) >> 8;
if ($family =~ /^"Ubuntu"$/msx) {
        $main_exit_code = system('hostnamectl', 'set-hostname', $HOSTNAMESHORT) >> 8;
if ($(service apparmor status  2> /dev/null | grep -w active | grep -w running) ne q{}) {
            $main_exit_code = system('service', 'apparmor', 'stop') >> 8;
            $main_exit_code = system('update-rc.d', '-f', 'apparmor', 'remove') >> 8;
            $main_exit_code = system('apt-get', '-y', '-qq', 'remove', 'apparmor', 'apparmor-utils') >> 8;
        }
}
    else {
        my $grep_result_10;
my @grep_lines_10 = ();
my @grep_filenames_10 = ();
if (-e "/etc/apt/sources.list") {
    open my $fh, '<', "/etc/apt/sources.list" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_10, $line;
        push @grep_filenames_10, "/etc/apt/sources.list";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/apt/sources.list: No such file or directory\n"; }
my @grep_filtered_10 = grep { /contrib/msx } @grep_lines_10;
$grep_result_10 = join "\n", @grep_filtered_10;
        if (!($grep_result_10 =~ m{\n\z}msx || $grep_result_10 eq q{})) {
            $grep_result_10 .= "\n";
        }
$CHILD_ERROR = scalar @grep_filtered_10 > 0 ? 0 : 1;
$grep_result_10 = q{};
        if ($CHILD_ERROR != 0) {
            my @sed_lines_11 = split /\n/msx, $;
my @sed_result_11;
foreach my $line (@sed_lines_11) {
chomp $line;
push @sed_result_11, $line;
}
$ = join "\n", @sed_result_11;

        }
        my $grep_result_12;
my @grep_lines_12 = ();
my @grep_filenames_12 = ();
if (-e "/etc/apt/sources.list") {
    open my $fh, '<', "/etc/apt/sources.list" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_12, $line;
        push @grep_filenames_12, "/etc/apt/sources.list";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/apt/sources.list: No such file or directory\n"; }
my @grep_filtered_12 = grep { /non-free/msx } @grep_lines_12;
$grep_result_12 = join "\n", @grep_filtered_12;
        if (!($grep_result_12 =~ m{\n\z}msx || $grep_result_12 eq q{})) {
            $grep_result_12 .= "\n";
        }
$CHILD_ERROR = scalar @grep_filtered_12 > 0 ? 0 : 1;
$grep_result_12 = q{};
        if ($CHILD_ERROR != 0) {
            my @sed_lines_13 = split /\n/msx, $;
my @sed_result_13;
foreach my $line (@sed_lines_13) {
chomp $line;
push @sed_result_13, $line;
}
$ = join "\n", @sed_result_13;

        }
        my $grep_result_14;
my @grep_lines_14 = ();
my @grep_filenames_14 = ();
if (-e "/etc/apt/sources.list") {
    open my $fh, '<', "/etc/apt/sources.list" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_14, $line;
        push @grep_filenames_14, "/etc/apt/sources.list";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/apt/sources.list: No such file or directory\n"; }
my @grep_filtered_14 = grep { /deb\ http:\/\/ftp.debian.org\/debian\ jessie-backports\ main/msx } @grep_lines_14;
$grep_result_14 = join "\n", @grep_filtered_14;
        if (!($grep_result_14 =~ m{\n\z}msx || $grep_result_14 eq q{})) {
            $grep_result_14 .= "\n";
        }
$CHILD_ERROR = scalar @grep_filtered_14 > 0 ? 0 : 1;
$grep_result_14 = q{};
        if ($CHILD_ERROR != 0) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', '/etc/apt/sources.list'
      or die "Cannot open file: $OS_ERROR\n";
                print "deb http://ftp.debian.org/debian jessie-backports main\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
    }
    return;
}

sub create_ispconfig_configuration {
open my $fh_cat, '>', '$TEMP_DIR' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "<?php
\\$autoinstall['language'] = 'en'; // de, en (default)
\\$autoinstall['install_mode'] = 'standard'; // standard (default), expert
\\$autoinstall['hostname'] = '$HOSTNAMEFQDN'; // default
\\$autoinstall['mysql_hostname'] = 'localhost'; // default: localhost
\\$autoinstall['mysql_root_user'] = 'root'; // default: root
\\$autoinstall['mysql_root_password'] = '$MYSQL_PASS';
\\$autoinstall['mysql_database'] = 'dbispconfig'; // default: dbispcongig
\\$autoinstall['mysql_charset'] = 'utf8'; // default: utf8
\\$autoinstall['mysql_port'] = '3306'; // default: 3306
\\$autoinstall['configure_jailkit'] = 'y'; // y (default), n
\\$autoinstall['configure_firewall'] = 'y'; // y (default), n
\\$autoinstall['configure_$server'] = 'y'; // y (default), n
\\$autoinstall['configure_dns'] = 'y'; // y (default), n
\\$autoinstall['http_server'] = '$server'; // y (default), n
\\$autoinstall['ispconfig_port'] = '8080'; // default: 8080
\\$autoinstall['ispconfig_admin_password'] = '1234'; // default: 1234
\\$autoinstall['ispconfig_use_ssl'] = 'y'; // y (default), n

/* SSL Settings */
\\$autoinstall['ssl_cert_country'] = 'AU';
\\$autoinstall['ssl_cert_state'] = 'Some-State';
\\$autoinstall['ssl_cert_locality'] = 'Chicago';
\\$autoinstall['ssl_cert_organisation'] = 'Internet Widgits Pty Ltd';
\\$autoinstall['ssl_cert_organisation_unit'] = 'IT department';
\\$autoinstall['ssl_cert_common_name'] = \\$autoinstall['hostname'];
\\$autoinstall['ssl_cert_email'] = 'joe@lamer.com';
?>
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub install_cups {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('apt-get', 'update') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('apt-get', '-y', 'install', 'cups', 'lpr', 'cups-filters') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
my @sed_lines_15 = split /\n/msx, $;
my @sed_result_15;
foreach my $line (@sed_lines_15) {
chomp $line;
push @sed_result_15, $line;
}
$ = join "\n", @sed_result_15;

my @sed_lines_16 = split /\n/msx, $;
my @sed_result_16;
foreach my $line (@sed_lines_16) {
chomp $line;
push @sed_result_16, $line;
}
$ = join "\n", @sed_result_16;

my @sed_lines_17 = split /\n/msx, $;
my @sed_result_17;
foreach my $line (@sed_lines_17) {
chomp $line;
push @sed_result_17, $line;
}
$ = join "\n", @sed_result_17;

my @sed_lines_18 = split /\n/msx, $;
my @sed_result_18;
foreach my $line (@sed_lines_18) {
chomp $line;
push @sed_result_18, $line;
}
$ = join "\n", @sed_result_18;

    $main_exit_code = system('service', 'cups', 'restart') >> 8;
    # Original bash: service samba restart | service smbd restart >/dev/null 2>&1
{
        my $output_19 = q{};
        my $output_printed_19;
        my $pipeline_success_19 = 1;
                my ($in_20, $out_20);
        my $pid_20 = open3($in_20, $out_20, '>&STDERR', 'service', 'samba', 'restart');
        close $in_20 or croak 'Close failed: $OS_ERROR';
        $output_19 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
        close $out_20 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_20, 0;

                my $cmd_22 = 'service';
        my ($in_21, $out_21);
        my $pid_21 = open3($in_21, $out_21, '>&STDERR', $cmd_22, 'smbd', 'restart');
        print {$in_21} $output_19;
        close $in_21 or croak 'Close failed: $OS_ERROR';
        $output_19 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_21> };
        close $out_21 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_21, 0;
        if ( !$pipeline_success_19 ) { $main_exit_code = 1; }
        }
    return;
}

sub install_samba {
    my $SECTION = "Samba";
    my $SMBUSER;
    my @SMBUSER;
    my %SMBUSER;
    $SMBUSER = do { my @_qx_cmd = ("whiptail --inputbox 'What is your samba username?' 8 78 Variable(\"SMBUSER\", false, None) --title \"$SECTION\" 2>&1 2>&2 2>&3"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    my $exitstatus;
    my @exitstatus;
    my %exitstatus;
    $exitstatus = $?;
if ($exitstatus eq 1) {
exit 1;
    }
    my $SMBPASS;
    my @SMBPASS;
    my %SMBPASS;
    $SMBPASS = do { my @_qx_cmd = ("whiptail --inputbox 'What is your samba password?' 8 78 Variable(\"SMBPASS\", false, None) --title \"$SECTION\" 2>&1 2>&2 2>&3"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    $exitstatus = $?;
if ($exitstatus eq 1) {
exit 1;
    }
    my $SMBGROUP;
    my @SMBGROUP;
    my %SMBGROUP;
    $SMBGROUP = do { my @_qx_cmd = ("whiptail --inputbox 'What is your samba group?' 8 78 Variable(\"SMBGROUP\", false, None) --title \"$SECTION\" 2>&1 2>&2 2>&3"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    $exitstatus = $?;
if ($exitstatus eq 1) {
exit 1;
    }
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', '-y', 'install', 'samba', 'samba-common-bin', 'samba-vfs-modules') >> 8;
    $main_exit_code = system('useradd', $SMBUSER) >> 8;
    # Original bash: echo -ne "$SMBPASS\n$SMBPASS\n" | passwd $SMBUSER >/dev/null 2>&1
{
        my $output_23 = q{};
        my $output_printed_23;
        my $pipeline_success_23 = 1;
        $output_23 .= '-ne' . q{ } . "$SMBPASS\n$SMBPASS\n" . "\n";
if ( !($output_23 =~ m{\n\z}msx) ) { $output_23 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_25 = 'passwd';
        my ($in_24, $out_24);
        my $pid_24 = open3($in_24, $out_24, '>&STDERR', $cmd_25, );
        print {$in_24} $output_23;
        close $in_24 or croak 'Close failed: $OS_ERROR';
        $output_23 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_24> };
        close $out_24 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_24, 0;
        if ( !$pipeline_success_23 ) { $main_exit_code = 1; }
        }
    # Original bash: echo -ne "$SMBPASS\n$SMBPASS\n" | smbpasswd -a -s $SMBUSER >/dev/null 2>&1
{
        my $output_26 = q{};
        my $output_printed_26;
        my $pipeline_success_26 = 1;
        $output_26 .= '-ne' . q{ } . "$SMBPASS\n$SMBPASS\n" . "\n";
if ( !($output_26 =~ m{\n\z}msx) ) { $output_26 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_28 = 'smbpasswd';
        my ($in_27, $out_27);
        my $pid_27 = open3($in_27, $out_27, '>&STDERR', $cmd_28, '-a', '-s');
        print {$in_27} $output_26;
        close $in_27 or croak 'Close failed: $OS_ERROR';
        $output_26 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_27> };
        close $out_27 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_27, 0;
        if ( !$pipeline_success_26 ) { $main_exit_code = 1; }
        }
    # Original bash: service samba stop | service smbd stop >/dev/null 2>&1
{
        my $output_29 = q{};
        my $output_printed_29;
        my $pipeline_success_29 = 1;
                my ($in_30, $out_30);
        my $pid_30 = open3($in_30, $out_30, '>&STDERR', 'service', 'samba', 'stop');
        close $in_30 or croak 'Close failed: $OS_ERROR';
        $output_29 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
        close $out_30 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_30, 0;

                my $cmd_32 = 'service';
        my ($in_31, $out_31);
        my $pid_31 = open3($in_31, $out_31, '>&STDERR', $cmd_32, 'smbd', 'stop');
        print {$in_31} $output_29;
        close $in_31 or croak 'Close failed: $OS_ERROR';
        $output_29 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
        close $out_31 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_31, 0;
        if ( !$pipeline_success_29 ) { $main_exit_code = 1; }
        }
    use File::Copy qw(copy);
    if ( -e '/etc/samba/smb.conf' ) {
        if ( -d '/etc/samba/smb.conf.stock' ) {
            require File::Copy; File::Copy::copy('/etc/samba/smb.conf', '/etc/samba/smb.conf.stock' . '/' . ('/etc/samba/smb.conf' =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy('/etc/samba/smb.conf', '/etc/samba/smb.conf.stock');
        }
    } else {
        croak "cp: cannot stat '/etc/samba/smb.conf': No such file or directory\n";
    }
open my $fh_cat, '>', '/etc/samba/smb.conf.tmp' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "[global]
\tworkgroup = SMBGROUP
\tserver string = %h server
\thosts allow = SUBNET
\tlog file = /var/log/samba/log.%m
\tmax log size = 1000
\tsyslog = 0
\tpanic action = /usr/share/samba/panic-action %d
\tload printers = yes
\tprinting = cups
\tprintcap name = cups
\tmin receivefile size = 16384
\twrite cache size = 524288
\tgetwd cache = yes
\tsocket options = TCP_NODELAY IPTOS_LOWDELAY

[printers]
\tcomment = All Printers
\tpath = /var/spool/samba
\tbrowseable = no
\tpublic = yes
\tguest ok = yes
\twritable = no
\tprintable = yes
\tprinter admin = SMBUSER

[print$]
\tcomment = Printer Drivers
\tpath = /etc/samba/drivers
\tbrowseable = yes
\tguest ok = no
\tread only = yes
\twrite list = SMBUSER

[ext]
\tcomment = Storage
\tpath = /ext
\tbrowseable = yes
\twritable = yes
\tpublic = no
\tvalid users = SMBUSER
\tforce create mode = 0644
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
my @sed_lines_34 = split /\n/msx, $;
my @sed_result_34;
foreach my $line (@sed_lines_34) {
chomp $line;
push @sed_result_34, $line;
}
$ = join "\n", @sed_result_34;

my @sed_lines_35 = split /\n/msx, $;
my @sed_result_35;
foreach my $line (@sed_lines_35) {
chomp $line;
push @sed_result_35, $line;
}
$ = join "\n", @sed_result_35;

my @sed_lines_36 = split /\n/msx, $;
my @sed_result_36;
foreach my $line (@sed_lines_36) {
chomp $line;
push @sed_result_36, $line;
}
$ = join "\n", @sed_result_36;

    do {
local *STDERR;
open STDERR, '>', '/etc/samba/smb.conf.tmp.out' or croak "Cannot open file: $OS_ERROR\n";
        $main_exit_code = system('dialog', '--backtitle', "$ENV{BACKTITLE}", '--title', "Review samba configuration", '--no-collapse', '--editbox', '/etc/samba/smb.conf.tmp', '30', q{0}) >> 8;
    };
if ($? eq 0) {
        my $err;
        my $force = 0;
        if ( -e '/etc/samba/smb.conf.tmp.out' ) {
            my $dest = '/etc/samba/smb.conf';
            if ( -e $dest && -d $dest ) {
                my $source_name = '/etc/samba/smb.conf.tmp.out';
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
            if ( File::Copy::move( '/etc/samba/smb.conf.tmp.out', $dest ) ) {
            } else {
                croak
  "mv: cannot move '/etc/samba/smb.conf.tmp.out' to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: '/etc/samba/smb.conf.tmp.out': No such file or directory\n";
        }
        $main_exit_code = system('install', '-m', '755', '-g', $SMBUSER, '-o', $SMBUSER, '-d', '/ext') >> 8;
        # Original bash: echo -ne "$SMBPASS\n$SMBPASS\n" | smbpasswd -a -s $SMBUSER >/dev/null 2>&1
{
            my $output_38 = q{};
            my $output_printed_38;
            my $pipeline_success_38 = 1;
            $output_38 .= '-ne' . q{ } . "$SMBPASS\n$SMBPASS\n" . "\n";
if ( !($output_38 =~ m{\n\z}msx) ) { $output_38 .= "\n"; }
$CHILD_ERROR = 0;

                        my $cmd_40 = 'smbpasswd';
            my ($in_39, $out_39);
            my $pid_39 = open3($in_39, $out_39, '>&STDERR', $cmd_40, '-a', '-s');
            print {$in_39} $output_38;
            close $in_39 or croak 'Close failed: $OS_ERROR';
            $output_38 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_39> };
            close $out_39 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_39, 0;
            if ( !$pipeline_success_38 ) { $main_exit_code = 1; }
            }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('service', 'smbd', 'stop') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
require Time::HiRes; Time::HiRes::sleep(q{3});
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('service', 'smbd', 'start') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    return;
}

sub install_ncp {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', $TEMP_DIR
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Headers;
my $ua = LWP::UserAgent->new;
my $request = HTTP::Request->new('GET', 'SL');
my $response = $ua->request($request);
if ($response->is_success) {
} else {
die "curl: HTTP error: $response->code $response->message\n";
}
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
        open STDOUT, '>', $TEMP_DIR
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Headers;
my $ua = LWP::UserAgent->new;
my $request = HTTP::Request->new('GET', 'SL');
my $response = $ua->request($request);
if ($response->is_success) {
} else {
die "curl: HTTP error: $response->code $response->message\n";
}
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    my $DEBIAN_RELEASE = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_44 = q{};
    my $output_printed_44;
    my $output_45 = q{};
    while (my $line = <>) {
        chomp $line;
        # awk doesn't support line-by-line processing
        $line =~ "s/[\", ]//g";
    }
    $output_45; };
}; $_pipeline_result; };
my @sed_lines_46 = split /\n/msx, $;
my @sed_result_46;
foreach my $line (@sed_lines_46) {
chomp $line;
push @sed_result_46, $line;
}
$ = join "\n", @sed_result_46;

    $main_exit_code = system('bash', $TEMP_DIR, '/install.sh') >> 8;
    return;
}

sub install_omv {
    my ($file) = @_;
if ((-f '/etc/orangepi-release')) {
        $main_exit_code = system('.', '/etc/orangepi-release') >> 8;
    }
if ("$family" =~ /^"Ubuntu"$/msx) {
        $main_exit_code = system('dialog', '--backtitle', "$ENV{BACKTITLE}", '--title', "Dependencies not met", '--msgbox', "\nOpenMediaVault can only be installed on Debian.", q{7}, '52') >> 8;
require Time::HiRes; Time::HiRes::sleep(q{5});
exit 1;
    }
if ($distribution =~ /^wheezy$/msx or $distribution =~ /^jessie$/msx) {
                $main_exit_code = system('dialog', '--backtitle', "$ENV{BACKTITLE}", '--title', "OMV3 is End of Life", '--msgbox', "\nUpgrade to a supported OS : Debian Stretch or Buster.", q{7}, '52') >> 8;
        require Time::HiRes; Time::HiRes::sleep(q{5});
        exit 1;
    }
    my $wgeturl;
    my @wgeturl;
    my %wgeturl;
    $wgeturl = "https://github.com/OpenMediaVault-Plugin-Developers/installScript/raw/master/install";
    $main_exit_code = system('fancy_wget', "$wgeturl", "-O " . ($ENV{TEMP_DIR} // q{}) . "/omv_install.sh") >> 8;
if ("$distribution" =~ /^"stretch"$/msx) {
        $main_exit_code = system('apt-get', '-y', '-qq', 'remove', 'chrony') >> 8;
    }
    print "Now installing OpenMediaVault. Be patient, it will take several minutes...\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', '/var/log/omv_install.log'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('bash', $TEMP_DIR, '/omv_install.sh') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    print "Now applying board tweak if required...\n";
    if (do {
{
    my $output_49 = q{};
    my $output_printed_49;
    my $pipeline_success_49 = 1;
        my ($in_50, $out_50);
    my $pid_50 = open3($in_50, $out_50, '>&STDERR', 'lsusb', );
    close $in_50 or croak 'Close failed: $OS_ERROR';
    $output_49 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_50> };
    close $out_50 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_50, 0;

        my $grep_result_49_1;
    my @grep_lines_49_1 = split /\n/msx, $output_49;
    my @grep_filtered_49_1 = grep { /05e3:0735/msxi } @grep_lines_49_1;
    $grep_result_49_1 = join "\n", @grep_filtered_49_1;
    if (!($grep_result_49_1 =~ m{\n\z}msx || $grep_result_49_1 eq q{})) {
    $grep_result_49_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_49_1 > 0 ? 0 : 1;
    $grep_result_49_1 = q{};
    $output_49 = q{};
    if ((scalar @grep_filtered_49_1) == 0) {
        $pipeline_success_49 = 0;
    }
    if ($output_49 ne q{} && !defined $output_printed_49) {
        print $output_49;
        if (!($output_49 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_49 ) { $main_exit_code = 1; }
    }
        $CHILD_ERROR == 0
    }) {
        my @sed_lines_51 = split /\n/msx, $;
my @sed_result_51;
foreach my $line (@sed_lines_51) {
chomp $line;
push @sed_result_51, $line;
}
$ = join "\n", @sed_result_51;

    }
if ($BOARD =~ /^odroidxu4$/msx) {
                my $HMP_Fix;
        my @HMP_Fix;
        my %HMP_Fix;
        $HMP_Fix = '; taskset -c -p 4-7 $i ';
                $main_exit_code = system('apt', 'install', '-y', 'i2c-tools') >> 8;
                # Original bash: /usr/sbin/i2cdetect -y 1 | grep -q "60: 60"
{
            my $output_52 = q{};
            my $output_printed_52;
            my $pipeline_success_52 = 1;
                        my ($in_53, $out_53);
            my $pid_53 = open3($in_53, $out_53, '>&STDERR', '/usr/sbin/i2cdetect', '-y', q{1});
            close $in_53 or croak 'Close failed: $OS_ERROR';
            $output_52 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_53> };
            close $out_53 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_53, 0;

                        my $grep_result_52_1;
            my @grep_lines_52_1 = split /\n/msx, $output_52;
            my @grep_filtered_52_1 = grep { /60:\ 60/msx } @grep_lines_52_1;
            $grep_result_52_1 = join "\n", @grep_filtered_52_1;
            if (!($grep_result_52_1 =~ m{\n\z}msx || $grep_result_52_1 eq q{})) {
            $grep_result_52_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_52_1 > 0 ? 0 : 1;
            $grep_result_52_1 = q{};
            $output_52 = q{};
            if ((scalar @grep_filtered_52_1) == 0) {
                $pipeline_success_52 = 0;
            }
            if ($output_52 ne q{} && !defined $output_printed_52) {
                print $output_52;
                if (!($output_52 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_52 ) { $main_exit_code = 1; }
            }
        if (($? == 0)) {
            $main_exit_code = system('add-apt-repository', '-y', 'ppa:kyle1117/ppa') >> 8;
my @sed_lines_54 = split /\n/msx, $;
my @sed_result_54;
foreach my $line (@sed_lines_54) {
chomp $line;
push @sed_result_54, $line;
}
$ = join "\n", @sed_result_54;

            if (my $pid = fork()) {
                # Parent process continues
            } elsif (defined $pid) {
                # Child process executes the background command
                $main_exit_code = system('apt', 'install', '-y', '-q', 'cloudshell-lcd', 'odroid-cloudshell', 'cloudshell2-fan') >> 8;
                exit(0);
            } else {
                die "Cannot fork: $ERRNO\n";
            }
            # Original bash: lsusb -v | awk -F"__" '/RANDOM_/ {print $2}' | head -n1 | while read ; do
{
                my $output_55 = q{};
                my $output_printed_55;
                my $pipeline_success_55 = 1;
                                my ($in_56, $out_56);
                my $pid_56 = open3($in_56, $out_56, '>&STDERR', 'lsusb', '-v');
                close $in_56 or croak 'Close failed: $OS_ERROR';
                $output_55 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_56> };
                close $out_56 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_56, 0;

                                my @lines = split /\n/msx, $output_55;
                my @result;
                foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /__/msx, $line;
                if (!(/RANDOM_/)) { next; }
                push @result, ($fields[1] . "\n");
                }
                $output_55 = join "", @result;

                                my $num_lines       = 1;
                my $head_line_count = 0;
                my $result          = q{};
                my $input           = $output_55;
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
                $output_55 = $result;

                                my @lines = split /\n/msx, $output_55;
                my $result_55_3 = q{};
                for my $line (@lines) {
                chomp $line;
                my $L = $line;
                do {
                open my $original_stdout, '>&', STDOUT
                or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', '/etc/udev/rules.d/99'
                or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                my $tmp_redirect_57 = q{};
                $tmp_redirect_57 .= "ATTRS{idVendor}==\"152d\", ATTRS{idProduct}==\"0561\", KERNEL==\"sd*\", ENV{DEVTYPE}==\"disk\", SYMLINK=\"disk/by-id/$env{ID_BUS}-CloudShell2-" . ($ENV{REPLY} // q{}) . "-$env{ID_MODEL}\"" . q{ } . '-c' . q{ } . 'loudshell2.rules' . "\n";
                if ( !($tmp_redirect_57 =~ m{\n\z}msx) ) { $tmp_redirect_57 .= "\n"; }
                $CHILD_ERROR = 0;
                $tmp_redirect_57;
                };
                print $tmp;
                if ($tmp eq q{}) { print $output_55; }
                $output_printed_55 = 1;
                open STDOUT, '>&', $original_stdout
                or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
                or die "Close failed: $OS_ERROR\n";
                };
                do {
                open my $original_stdout, '>&', STDOUT
                or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', '/etc/udev/rules.d/99'
                or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                my $tmp_redirect_59 = q{};
                $tmp_redirect_59 .= "ATTRS{idVendor}==\"152d\", ATTRS{idProduct}==\"0561\", KERNEL==\"sd*\", ENV{DEVTYPE}==\"partition\", SYMLINK=\"disk/by-id/$env{ID_BUS}-CloudShell2-" . ($ENV{REPLY} // q{}) . "-$env{ID_MODEL}-part%n\"" . q{ } . '-c' . q{ } . 'loudshell2.rules' . "\n";
                if ( !($tmp_redirect_59 =~ m{\n\z}msx) ) { $tmp_redirect_59 .= "\n"; }
                $CHILD_ERROR = 0;
                $tmp_redirect_59;
                };
                print $tmp;
                if ($tmp eq q{}) { print $output_55; }
                $output_printed_55 = 1;
                open STDOUT, '>&', $original_stdout
                or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
                or die "Close failed: $OS_ERROR\n";
                };
                }
                $output_55 = $result_55_3;
                if ($output_55 ne q{} && !defined $output_printed_55) {
                    print $output_55;
                    if (!($output_55 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_55 ) { $main_exit_code = 1; }
                }
        }
    } elsif ($BOARD =~ /^helios4$/msx) {
        if ((-f '/usr/sbin/mdadm-fault-led.sh')) {
if ("$distribution" =~ /^"stretch"$/msx) {
my @sed_lines_61 = split /\n/msx, $;
my @sed_result_61;
foreach my $line (@sed_lines_61) {
chomp $line;
push @sed_result_61, $line;
}
$ = join "\n", @sed_result_61;

                $main_exit_code = system('/usr/sbin/omv-mkconf', 'mdadm') >> 8;
}
            else {
                if ("$distribution" =~ /^"buster"$/msx) {
open my $fh_cat, '>', '/srv/salt/omv/deploy/mdadm/25faultled.sls' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "mdadm_add_program_config:
  cmd.run:
    - name: \"echo -e '\\n# Trigger Fault Led script when an event is detected\\nPROGRAM /usr/sbin/mdadm-fault-led.sh' >> /etc/mdadm/mdadm.conf\"
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
                    $main_exit_code = system('/usr/sbin/omv-salt', 'deploy', 'run', 'mdadm') >> 8;
                }
            }
        }
    }
    return;
}

sub install_tvheadend {
if ("$family" =~ /^"Ubuntu"$/msx) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('apt-key', 'adv', '--keyserver', 'hkp://keyserver.ubuntu.com:80', '--recv-keys', '26F4EF8440618B66') >> 8;
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
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('add-apt-repository', '-y', 'ppa:mamarley/tvheadend-git-stable') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', '-y', 'install', 'libssl-doc', 'libssl1.0.0', 'zlib1g-dev', 'tvheadend', 'xmltv-util') >> 8;
}
    else {
if ((!-f /etc/apt/sources.list.d/tvheadend.list)) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', '/etc/apt/sources.list.d/tvheadend.list'
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "deb https://www.deb-multimedia.org " . ($ENV{distribution} // q{}) . " main non-free";
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
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('apt-key', 'adv', '--keyserver', 'hkp://keyserver.ubuntu.com:80', '--recv-keys', '5C808C2B65558117') >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
        my $URL;
        my @URL;
        my %URL;
        $URL = "https://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl1.0.0_1.0.1t-1+deb8u9_";
        $CHILD_ERROR = 0;
        $main_exit_code = system('fancy_wget', "$URL", "-O " . ($ENV{TEMP_DIR} // q{}) . "/package.deb") >> 8;
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('dpkg', '-i', $TEMP_DIR, '/package.deb') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', '-y', 'install', 'libssl-doc', 'zlib1g-dev', 'tvheadend', 'xmltv-util') >> 8;
    }
    return;
}

sub install_docker {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/etc/apt/sources.list.d/docker.list'
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "deb [arch=" . (do { my $_chomp_temp = do {
    my ($in_62, $out_62);
    my $pid_62 = open3($in_62, $out_62, '>&STDERR', 'dpkg', '--print-architecture');
    close $in_62 or croak 'Close failed: $OS_ERROR';
    my $result_62 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_62> };
    close $out_62 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_62, 0;
    $result_62
}; chomp $_chomp_temp; $_chomp_temp; }) . "] https://mirrors.aliyun.com/docker-ce/linux/" . lc(lc(($ENV{family} // q{}))) . " $ENV{distribution} edge";
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
    # Original bash: curl -fsSL "https://mirrors.aliyun.com/docker-ce/linux/${family,,}/gpg" | apt-key add -qq - > /dev/null 2>&1
{
        my $output_63 = q{};
        my $output_printed_63;
        my $pipeline_success_63 = 1;
                use LWP::UserAgent;
        use HTTP::Request;
        use HTTP::Headers;
        my $ua = LWP::UserAgent->new;
        my $request = HTTP::Request->new('GET', 'sSL');
        my $response = $ua->request($request);
        if ($response->is_success) {
        print $response->content;
        } else {
        die "curl: HTTP error: $response->code $response->message\n";
        }

                my $cmd_65 = 'apt-key';
        my ($in_64, $out_64);
        my $pid_64 = open3($in_64, $out_64, '>&STDERR', $cmd_65, 'add', '-qq', q{-});
        print {$in_64} $output_63;
        close $in_64 or croak 'Close failed: $OS_ERROR';
        $output_63 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_64> };
        close $out_64 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_64, 0;
        if ( !$pipeline_success_63 ) { $main_exit_code = 1; }
        }
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'install', '-y', '-qq', '--no-install-recommends', 'docker-ce') >> 8;
    return;
}

sub install_urbackup {
    my ($file) = @_;
if ("$(dpkg --print-architecture | grep arm64)" =~ /^"arm64"$/msx) {
        my $arch = "armhf";
}
    else {
        my $arch = do {
    my ($in_66, $out_66);
    my $pid_66 = open3($in_66, $out_66, '>&STDERR', 'dpkg', '--print-architecture');
    close $in_66 or croak 'Close failed: $OS_ERROR';
    my $result_66 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_66> };
    close $out_66 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_66, 0;
    $result_66
};
    }
    my $PREFIX;
    my @PREFIX;
    my %PREFIX;
    $PREFIX = "https://hndl.urbackup.org/Server/latest/";
    my $URL;
    my @URL;
    my %URL;
    $URL = "https://hndl.urbackup.org/Server/latest/";
    $CHILD_ERROR = 0;
    $main_exit_code = system('fancy_wget', "$URL", "-O " . ($ENV{TEMP_DIR} // q{}) . "/package.deb") >> 8;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('dpkg', '-i', $TEMP_DIR, '/package.deb') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('apt-get', '-yy', '-f', 'install') >> 8;
    return;
}

sub install_transmission {
    install_packet("debconf-utils unzip build-essential html2text apt-transport-https", "Downloading dependencies");
    install_packet("transmission-cli transmission-common transmission-daemon", "Install torrent server");
    $main_exit_code = system('service', 'transmission-daemon', 'stop') >> 8;
    my @A = ('${serverIP//./', '}');
    my $servernetwork = $A[0] . "." . $A[1] . ".*.*";
my @sed_lines_67 = split /\n/msx, $;
my @sed_result_67;
foreach my $line (@sed_lines_67) {
chomp $line;
push @sed_result_67, $line;
}
$ = join "\n", @sed_result_67;

    $main_exit_code = system('service', 'transmission-daemon', 'start') >> 8;
my @sed_lines_68 = split /\n/msx, $;
my @sed_result_68;
foreach my $line (@sed_lines_68) {
chomp $line;
push @sed_result_68, $line;
}
$ = join "\n", @sed_result_68;

open my $fh_cat, '>', '/etc/rc.local' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} q{service transmission-daemon restart
exit 0
};
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub install_transmission_seed_orangepi_torrents {
    my $rmem_recommended;
    my @rmem_recommended;
    my %rmem_recommended;
    $rmem_recommended = '4194304';
    my $wmem_recommended;
    my @wmem_recommended;
    my %wmem_recommended;
    $wmem_recommended = '1048576';
    my $rmem_actual;
    my @rmem_actual;
    my %rmem_actual;
    $rmem_actual = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_69 = q{};
        my $output_printed_69;
        my $pipeline_success_69 = 1;

        my ($in_70, $out_70);
        my $pid_70 = open3($in_70, $out_70, '>&STDERR', 'sysctl', 'net.core.rmem_max');
        close $in_70 or croak 'Close failed: $OS_ERROR';
        $output_69 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_70> };
        close $out_70 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_70, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_69 = 0; }
        my @lines = split /\n/msx, $output_69;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\ /msx, $line;
            push @result, ($fields[2] . "\n");
        }
        $output_69 = join "", @result;

        if ( !$pipeline_success_69 ) { $main_exit_code = 1; }
        $output_69 =~ s/\n+\z//msx;
        $output_69;
}; $_pipeline_result; };
if ((${rmem_actual} < ${rmem_recommended})) {
                if (do {
                        my $grep_result_71;
            my @grep_lines_71 = ();
            my @grep_filenames_71 = ();
            if (-e "/etc/sysctl.conf") {
                open my $fh, '<', "/etc/sysctl.conf" or croak "Cannot open file: $ERRNO";
                while (my $line = <$fh>) {
                    chomp $line;
                    push @grep_lines_71, $line;
                    push @grep_filenames_71, "/etc/sysctl.conf";
                }
                close $fh
                    or croak "Close failed: $OS_ERROR";
            }
            else { print {*STDERR} "grep: /etc/sysctl.conf: No such file or directory\n"; }
            my @grep_filtered_71 = grep { /net.core.rmem_max/msx } @grep_lines_71;
            $grep_result_71 = join "\n", @grep_filtered_71;
                        if (!($grep_result_71 =~ m{\n\z}msx || $grep_result_71 eq q{})) {
                            $grep_result_71 .= "\n";
                        }
            $CHILD_ERROR = scalar @grep_filtered_71 > 0 ? 0 : 1;
            $grep_result_71 = q{};
            $CHILD_ERROR == 0
        }) {
            my @sed_lines_72 = split /\n/msx, $;
my @sed_result_72;
foreach my $line (@sed_lines_72) {
chomp $line;
push @sed_result_72, $line;
}
$ = join "\n", @sed_result_72;

        }
        if ($CHILD_ERROR != 0) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', '/etc/sysctl.conf'
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "net.core.rmem_max = " . ${rmem_recommended};
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
    }
    my $wmem_actual;
    my @wmem_actual;
    my %wmem_actual;
    $wmem_actual = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_73 = q{};
        my $output_printed_73;
        my $pipeline_success_73 = 1;

        my ($in_74, $out_74);
        my $pid_74 = open3($in_74, $out_74, '>&STDERR', 'sysctl', 'net.core.wmem_max');
        close $in_74 or croak 'Close failed: $OS_ERROR';
        $output_73 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_74> };
        close $out_74 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_74, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_73 = 0; }
        my @lines = split /\n/msx, $output_73;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\ /msx, $line;
            push @result, ($fields[2] . "\n");
        }
        $output_73 = join "", @result;

        if ( !$pipeline_success_73 ) { $main_exit_code = 1; }
        $output_73 =~ s/\n+\z//msx;
        $output_73;
}; $_pipeline_result; };
if ((${wmem_actual} < ${wmem_recommended})) {
                if (do {
                        my $grep_result_75;
            my @grep_lines_75 = ();
            my @grep_filenames_75 = ();
            if (-e "/etc/sysctl.conf") {
                open my $fh, '<', "/etc/sysctl.conf" or croak "Cannot open file: $ERRNO";
                while (my $line = <$fh>) {
                    chomp $line;
                    push @grep_lines_75, $line;
                    push @grep_filenames_75, "/etc/sysctl.conf";
                }
                close $fh
                    or croak "Close failed: $OS_ERROR";
            }
            else { print {*STDERR} "grep: /etc/sysctl.conf: No such file or directory\n"; }
            my @grep_filtered_75 = grep { /net.core.wmem_max/msx } @grep_lines_75;
            $grep_result_75 = join "\n", @grep_filtered_75;
                        if (!($grep_result_75 =~ m{\n\z}msx || $grep_result_75 eq q{})) {
                            $grep_result_75 .= "\n";
                        }
            $CHILD_ERROR = scalar @grep_filtered_75 > 0 ? 0 : 1;
            $grep_result_75 = q{};
            $CHILD_ERROR == 0
        }) {
            my @sed_lines_76 = split /\n/msx, $;
my @sed_result_76;
foreach my $line (@sed_lines_76) {
chomp $line;
push @sed_result_76, $line;
}
$ = join "\n", @sed_result_76;

        }
        if ($CHILD_ERROR != 0) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', '/etc/sysctl.conf'
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "net.core.wmem_max = " . ${wmem_recommended};
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
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('/sbin/sysctl', '-p') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
open my $fh_cat, '>', '/etc/cron.daily/seed-armbian-torrent' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} q%#!/bin/bash
#
# armbian torrents auto update
#
# download latest torrent pack
TEMP_DIR=$(mktemp -d || exit 1)
chmod 700 ${TEMP_DIR}
trap "rm -rf \"${TEMP_DIR}\" ; exit 0" 0 1 2 3 15
wget -qO- -O ${TEMP_DIR}/armbian-torrents.zip https://dl.armbian.com/torrent/all-torrents.zip
# test zip for corruption
unzip -t ${TEMP_DIR}/armbian-torrents.zip >/dev/null 2>&1
[[ $? -ne 0 ]] && echo "Error in zip" && exit
# extract zip
unzip -o ${TEMP_DIR}/armbian-torrents.zip -d ${TEMP_DIR}/torrent-tmp >/dev/null 2>&1
# create list of current active torrents
transmission-remote -n 'transmission:transmission' -l | sed '1d; $d' > ${TEMP_DIR}/torrent-tmp/active.torrents
# loop and add/update torrent files
for f in ${TEMP_DIR}/torrent-tmp/*.torrent; do
        transmission-remote -n 'transmission:transmission' -a $f > /dev/null 2>&1
        # remove added from the list
        pattern="${f//.torrent}"; pattern="${pattern##*/}";
        sed -i "/$pattern/d" ${TEMP_DIR}/torrent-tmp/active.torrents
done
# remove old armbian torrents
while read i; do
        [[ $i == *Armbian_* || $i == *gcc-linaro-* || $i == *tar.lz4 ]] && transmission-remote -n 'transmission:transmission' -t $(echo "$i" | awk '{print $1}';) --remove-and-delete
done < ${TEMP_DIR}/torrent-tmp/active.torrents
# remove temporally files and direcotories
%;
close $fh_cat or croak "Close failed: $OS_ERROR\n";
chmod(oct('+x'), ('/etc/cron.daily/seed-armbian-torrent')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    if (my $pid = fork()) {
        # Parent process continues
    } elsif (defined $pid) {
        # Child process executes the background command
        $main_exit_code = system('bash', '/etc/cron.daily/seed-armbian-torrent') >> 8;
        exit(0);
    } else {
        die "Cannot fork: $ERRNO\n";
    }
    return;
}

sub install_hassio {
    my $arch = do {
    my ($in_78, $out_78);
    my $pid_78 = open3($in_78, $out_78, '>&STDERR', 'dpkg', '--print-architecture');
    close $in_78 or croak 'Close failed: $OS_ERROR';
    my $result_78 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_78> };
    close $out_78 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_78, 0;
    $result_78
};
if ($arch =~ /^armhf$/msx) {
                my $machine = "raspberrypi2";
    } elsif ($arch =~ /^arm64$/msx) {
                my $machine = "raspberrypi4-64";
    } elsif ($arch =~ /^amd64$/msx) {
                my $machine = "intel-nuc";
    } elsif (1) {
        exit 1;
    }
if ($? =~ /^0$/msx) {
        install_docker();
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'install', '-y', 'apparmor-utils', 'apt-transport-https', 'avahi-daemon', 'ca-certificates', 'dbus', 'jq', 'network-manager', 'socat', 'software-properties-common') >> 8;
        # Original bash: curl -sL "https://gitee.com/leeboby/supervised-installer/raw/master/installer.sh" | \
{
            my $output_79 = q{};
            my $output_printed_79;
            my $pipeline_success_79 = 1;
                        use LWP::UserAgent;
            use HTTP::Request;
            use HTTP::Headers;
            my $ua = LWP::UserAgent->new;
            my $request = HTTP::Request->new('GET', q{L});
            my $response = $ua->request($request);
            if ($response->is_success) {
            } else {
            die "curl: HTTP error: $response->code $response->message\n";
            }

                        my $cmd_81 = 'bash';
            my ($in_80, $out_80);
            my $pid_80 = open3($in_80, $out_80, '>&STDERR', $cmd_81, '-s', '--', '-m');
            print {$in_80} $output_79;
            close $in_80 or croak 'Close failed: $OS_ERROR';
            $output_79 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_80> };
            close $out_80 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_80, 0;
            if ($output_79 ne q{} && !defined $output_printed_79) {
                print $output_79;
                if (!($output_79 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_79 ) { $main_exit_code = 1; }
            }
        $main_exit_code = system('dialog', '--backtitle', "$ENV{BACKTITLE}", '--title', "Please wait", '--msgbox', "\nIt can take several minutes before Home Assistant UI becomes available! ", q{7}, '75') >> 8;
    }
    return;
}

sub install_openhab {
    my $jdkArch = do {
    my ($in_82, $out_82);
    my $pid_82 = open3($in_82, $out_82, '>&STDERR', 'dpkg', '--print-architecture');
    close $in_82 or croak 'Close failed: $OS_ERROR';
    my $result_82 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_82> };
    close $out_82 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_82, 0;
    $result_82
};
if ($jdkArch =~ /^armhf$/msx) {
                my $URL;
        my @URL;
        my %URL;
        $URL = "https://cdn.azul.com/zulu-embedded/bin/zulu8.40.0.178-ca-jdk1.8.0_222-linux_aarch32hf.tar.gz";
    } elsif ($jdkArch =~ /^arm64$/msx) {
                $URL = "https://cdn.azul.com/zulu-embedded/bin/zulu8.40.0.178-ca-jdk1.8.0_222-linux_aarch64.tar.gz";
    } elsif ($jdkArch =~ /^amd64$/msx) {
                $URL = "https://cdn.azul.com/zulu/bin/zulu8.42.0.21-ca-jdk8.0.232-linux_x64.tar.gz";
    } elsif (1) {
                $URL = "https://cdn.azul.com/zulu/bin/zulu8.42.0.21-ca-jdk8.0.232-linux_i686.tar.gz";
    }
    $main_exit_code = system('fancy_wget', "$URL", "-O " . ($ENV{TEMP_DIR} // q{}) . "/zulu8.tar.gz") >> 8;
    use File::Path qw(make_path);
    my $err;
    if ( !-d '/opt/jdk' ) {
        make_path( '/opt/jdk', { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . '/opt/jdk' . ": $err->[0]\n";
        }
    }
    $main_exit_code = system('tar', '-x', 'pzf', $TEMP_DIR, '/zulu8.tar.gz', '-C', '/opt/jdk') >> 8;
    my $jdkBin;
    my @jdkBin;
    my %jdkBin;
    $jdkBin = do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { if (1) { push @find_results, $File::Find::name; } }, '/opt/jdk/*/bin');
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
};
    my $jdkLib;
    my @jdkLib;
    my %jdkLib;
    $jdkLib = do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { if (1) { push @find_results, $File::Find::name; } }, '/opt/jdk/*/lib');
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
};
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('update-alternatives', '--remove-all', 'java') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('update-alternatives', '--remove-all', 'javac') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('update-alternatives', '--install', '/usr/bin/java', 'java', "$jdkBin", '/java', '1083000') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('update-alternatives', '--install', '/usr/bin/javac', 'javac', "$jdkBin", '/javac', '1083000') >> 8;
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
        open STDOUT, '>', '/etc/ld.so.conf.d/java.conf'
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = $jdkLib . q{ } . q{/} . q{ } . $jdkArch;
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', '/etc/ld.so.conf.d/java.conf'
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = $jdkLib . q{ } . q{/} . q{ } . $jdkArch . q{ } . '/jli';
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('bash', 'ldconfig') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    # Original bash: wget -qO - 'https://bintray.com/user/downloadSubjectPublicKey?username=openhab' | apt-key add - >/dev/null 2>&1
{
        my $output_84 = q{};
        my $output_printed_84;
        my $pipeline_success_84 = 1;
                use LWP::Simple;
        my $url = 'https://bintray.com/user/downloadSubjectPublicKey?username=openhab';
        my $content = get($url);
        if (defined $content) {
        print $content;
        } else {
        die "Failed to download $url\n";
        }

                my $cmd_86 = 'apt-key';
        my ($in_85, $out_85);
        my $pid_85 = open3($in_85, $out_85, '>&STDERR', $cmd_86, 'add', q{-});
        print {$in_85} $output_84;
        close $in_85 or croak 'Close failed: $OS_ERROR';
        $output_84 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_85> };
        close $out_85 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_85, 0;
        if ( !$pipeline_success_84 ) { $main_exit_code = 1; }
        }
    # Original bash: echo 'deb https://dl.bintray.com/openhab/apt-repo2 stable main' | tee /etc/apt/sources.list.d/openhab2.list >/dev/null 2>&1
{
        my $output_87 = q{};
        my $output_printed_87;
        my $pipeline_success_87 = 1;
        $output_87 .= 'deb https://dl.bintray.com/openhab/apt-repo2 stable main' . "\n";
if ( !($output_87 =~ m{\n\z}msx) ) { $output_87 .= "\n"; }
$CHILD_ERROR = 0;

                use Carp qw(carp croak);
        if ( open my $fh, '>', '/etc/apt/sources.list.d/openhab2.list' ) {
        print {$fh} $output_87;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open '/etc/apt/sources.list.d/openhab2.list': $ERRNO";
        }
        $output_87 = $output_87;
        if ( !$pipeline_success_87 ) { $main_exit_code = 1; }
        }
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'install', '-y', 'openhab2') >> 8;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', 'daemon-reload') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', 'enable', 'openhab2.service') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', 'start', 'openhab2.service') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
my @sed_lines_88 = split /\n/msx, $;
my @sed_result_88;
foreach my $line (@sed_lines_88) {
chomp $line;
push @sed_result_88, $line;
}
$ = join "\n", @sed_result_88;

    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('service', 'openhab2', 'restart') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('dialog', '--backtitle', "$ENV{BACKTITLE}", '--title', "Please wait", '--msgbox', "\nIt can take several minutes before OpenHAB UI becomes available! ", q{7}, '68') >> 8;
    return;
}

sub install_syncthing {
    # Original bash: curl -s https://syncthing.net/release-key.txt | apt-key add - >/dev/null 2>&1
{
        my $output_89 = q{};
        my $output_printed_89;
        my $pipeline_success_89 = 1;
                use LWP::UserAgent;
        use HTTP::Request;
        use HTTP::Headers;
        my $ua = LWP::UserAgent->new;
        my $request = HTTP::Request->new('GET', 'https://syncthing.net/release-key.txt');
        my $response = $ua->request($request);
        if ($response->is_success) {
        } else {
        die "curl: HTTP error: $response->code $response->message\n";
        }

                my $cmd_91 = 'apt-key';
        my ($in_90, $out_90);
        my $pid_90 = open3($in_90, $out_90, '>&STDERR', $cmd_91, 'add', q{-});
        print {$in_90} $output_89;
        close $in_90 or croak 'Close failed: $OS_ERROR';
        $output_89 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_90> };
        close $out_90 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_90, 0;
        if ( !$pipeline_success_89 ) { $main_exit_code = 1; }
        }
    # Original bash: echo "deb https://apt.syncthing.net/ syncthing stable" | tee /etc/apt/sources.list.d/syncthing.list >/dev/null 2>&1
{
        my $output_92 = q{};
        my $output_printed_92;
        my $pipeline_success_92 = 1;
        $output_92 .= 'deb https://apt.syncthing.net/ syncthing stable' . "\n";
if ( !($output_92 =~ m{\n\z}msx) ) { $output_92 .= "\n"; }
$CHILD_ERROR = 0;

                use Carp qw(carp croak);
        if ( open my $fh, '>', '/etc/apt/sources.list.d/syncthing.list' ) {
        print {$fh} $output_92;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open '/etc/apt/sources.list.d/syncthing.list': $ERRNO";
        }
        $output_92 = $output_92;
        if ( !$pipeline_success_92 ) { $main_exit_code = 1; }
        }
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', '-y', 'install', 'syncthing') >> 8;
if (!(!($main_exit_code = system('bash', 'grep -qs "fs.inotify.max_user_watches=204800" "/etc/sysctl.conf"') >> 8;))) {
        # Original bash: echo -e "fs.inotify.max_user_watches=204800" | tee -a /etc/sysctl.conf
{
            my $output_93 = q{};
            my $output_printed_93;
            my $pipeline_success_93 = 1;
            $output_93 .= "fs.inotify.max_user_watches=204800\n";
if ( !($output_93 =~ m{\n\z}msx) ) { $output_93 .= "\n"; }
$CHILD_ERROR = 0;

                        use Carp qw(carp croak);
            if ( open my $fh, '>>', '/etc/sysctl.conf' ) {
            print {$fh} $output_93;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/etc/sysctl.conf': $ERRNO";
            }
            $output_93 = $output_93;
            if ($output_93 ne q{} && !defined $output_printed_93) {
                print $output_93;
                if (!($output_93 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_93 ) { $main_exit_code = 1; }
            }
    }
    $main_exit_code = system('bash', 'add_choose_user') >> 8;
    my $err;
    my $force = 0;
    if ( -e "/lib/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/syncthing" ) {
        my $dest = '.service';
        if ( -e $dest && -d $dest ) {
            my $source_name = "/lib/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/syncthing";
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
        if ( File::Copy::move( "/lib/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/syncthing", $dest ) ) {
        } else {
            croak
  "mv: cannot move "/lib/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/syncthing" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "/lib/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/syncthing": No such file or directory\n";
    }
    if ( -e "q{@}" ) {
        my $dest = '.service';
        if ( -e $dest && -d $dest ) {
            my $source_name = "q{@}";
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
        if ( File::Copy::move( "q{@}", $dest ) ) {
        } else {
            croak
  "mv: cannot move "q{@}" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "q{@}": No such file or directory\n";
    }
    if ( -e '.service' ) {
        my $dest = '.service';
        if ( -e $dest && -d $dest ) {
            my $source_name = '.service';
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
        if ( File::Copy::move( '.service', $dest ) ) {
        } else {
            croak
  "mv: cannot move '.service' to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: '.service': No such file or directory\n";
    }
    if ( -e "/lib/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/syncthing" ) {
        my $dest = '.service';
        if ( -e $dest && -d $dest ) {
            my $source_name = "/lib/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/syncthing";
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
        if ( File::Copy::move( "/lib/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/syncthing", $dest ) ) {
        } else {
            croak
  "mv: cannot move "/lib/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/syncthing" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "/lib/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/syncthing": No such file or directory\n";
    }
    if ( -e "q{@}" ) {
        my $dest = '.service';
        if ( -e $dest && -d $dest ) {
            my $source_name = "q{@}";
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
        if ( File::Copy::move( "q{@}", $dest ) ) {
        } else {
            croak
  "mv: cannot move "q{@}" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "q{@}": No such file or directory\n";
    }
    if ( -e "$CHOSEN_USER" ) {
        my $dest = '.service';
        if ( -e $dest && -d $dest ) {
            my $source_name = "$CHOSEN_USER";
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
        if ( File::Copy::move( "$CHOSEN_USER", $dest ) ) {
        } else {
            croak
  "mv: cannot move "$CHOSEN_USER" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "$CHOSEN_USER": No such file or directory\n";
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', 'enable', 'syncthing', q{@}, $CHOSEN_USER, '.service') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', 'start', 'syncthing', q{@}, $CHOSEN_USER, '.service') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', 'stop', 'syncthing', q{@}, $CHOSEN_USER, '.service') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', 'start', 'syncthing', q{@}, $CHOSEN_USER, '.service') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
while (     $main_exit_code = system('bash', ':') >> 8 ) {
if ((-f '/home/${CHOSEN_USER}/.config/syncthing/config.xml')) {
last;
        }
require Time::HiRes; Time::HiRes::sleep(q{1});
    }
my @sed_lines_96 = split /\n/msx, $;
my @sed_result_96;
foreach my $line (@sed_lines_96) {
chomp $line;
push @sed_result_96, $line;
}
$ = join "\n", @sed_result_96;

    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', 'restart', 'syncthing', q{@}, $CHOSEN_USER, '.service') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('dialog', '--backtitle', "$ENV{BACKTITLE}", '--title', "Please wait", '--msgbox', "\nIt can take several minutes before Syncthing UI becomes available! ", q{7}, '70') >> 8;
    return;
}

sub install_plex_media_server {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/etc/apt/sources.list.d/plex.list'
      or die "Cannot open file: $OS_ERROR\n";
        print "deb https://downloads.plex.tv/repo/deb public main\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    # Original bash: wget -q -O - https://downloads.plex.tv/plex-keys/PlexSign.key | apt-key add - >/dev/null 2>&1
{
        my $output_97 = q{};
        my $output_printed_97;
        my $pipeline_success_97 = 1;
                use LWP::Simple;
        my $url = 'https://downloads.plex.tv/plex-keys/PlexSign.key';
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

                my $cmd_99 = 'apt-key';
        my ($in_98, $out_98);
        my $pid_98 = open3($in_98, $out_98, '>&STDERR', $cmd_99, 'add', q{-});
        print {$in_98} $output_97;
        close $in_98 or croak 'Close failed: $OS_ERROR';
        $output_97 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_98> };
        close $out_98 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_98, 0;
        if ( !$pipeline_success_97 ) { $main_exit_code = 1; }
        }
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', '-y', 'install', 'plexmediaserver') >> 8;
    return;
}

sub install_emby_server {
    my $ARCH;
    my @ARCH;
    my %ARCH;
    $ARCH = do {
    my ($in_100, $out_100);
    my $pid_100 = open3($in_100, $out_100, '>&STDERR', 'dpkg', '--print-architecture');
    close $in_100 or croak 'Close failed: $OS_ERROR';
    my $result_100 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_100> };
    close $out_100 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_100, 0;
    $result_100
};
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('git', 'clone', 'https://gitee.com/leeboby/embyreleases.git', '/tmp/emby') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('dpkg', '-i', '/tmp/emby/emby-server-deb_4.5.2.0_', $ARCH, '.deb') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('apt-get', '-yy', '-f', 'install') >> 8;
if ( -e "/tmp/emby" ) {
        if ( -d "/tmp/emby" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("/tmp/emby", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "/tmp/emby", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "/tmp/emby" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/tmp/emby",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}

sub install_radarr {
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', '-y', 'install', 'mono-devel', 'mediainfo', 'libmono-cil-dev') >> 8;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('git', 'clone', '-b', 'radarr', 'https://gitee.com/leeboby/software.git', '/tmp/radarr') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    use File::Copy qw(copy);
    if ( -e '/tmp/radarr/Radarr*linux.tar.gz' ) {
        if ( -d '/tmp/radarr/radarr.tgz' ) {
            require File::Copy; File::Copy::copy('/tmp/radarr/Radarr*linux.tar.gz', '/tmp/radarr/radarr.tgz' . '/' . ('/tmp/radarr/Radarr*linux.tar.gz' =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy('/tmp/radarr/Radarr*linux.tar.gz', '/tmp/radarr/radarr.tgz');
        }
    } else {
        croak "cp: cannot stat '/tmp/radarr/Radarr*linux.tar.gz': No such file or directory\n";
    }
    $main_exit_code = system('tar', 'xf', '/tmp/radarr/radarr.tgz', '-C', '/opt') >> 8;
open my $fh_cat, '>', "/etc/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/radarr.service" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "[Unit]
Description=Radarr Daemon
After=network.target
[Service]
User=root
Type=simple
ExecStart=/usr/bin/mono --debug /opt/Radarr/Radarr.exe -nobrowser
[Install]
WantedBy=multi-user.target
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', 'enable', 'radarr') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('systemctl', 'start', 'radarr') >> 8;
    return;
}

sub install_sonarr {
if ("$(dpkg --print-architecture | grep arm64)" =~ /^"arm64"$/msx) {
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', '-y', 'install', 'mono-complete', 'mediainfo') >> 8;
        $main_exit_code = system('fancy_wget', "https://update.sonarr.tv/v2/develop/mono/NzbDrone.develop.tar.gz", "-O " . ($ENV{TEMP_DIR} // q{}) . "/sonarr.tgz") >> 8;
        $main_exit_code = system('tar', 'xf', $TEMP_DIR, '/sonarr.tgz', '-C', '/opt') >> 8;
}
    else {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('apt-key', 'adv', '--keyserver', 'keyserver.ubuntu.com', '--recv-keys', '0xA236C58F409091A18ACA53CBEBFF6B99D9B78493') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        # Original bash: echo -e "deb http://apt.sonarr.tv/ master main" | sudo tee /etc/apt/sources.list.d/sonarr.list
{
            my $output_102 = q{};
            my $output_printed_102;
            my $pipeline_success_102 = 1;
            $output_102 .= "deb http://apt.sonarr.tv/ master main\n";
if ( !($output_102 =~ m{\n\z}msx) ) { $output_102 .= "\n"; }
$CHILD_ERROR = 0;

                        my $cmd_104 = 'sudo';
            my ($in_103, $out_103);
            my $pid_103 = open3($in_103, $out_103, '>&STDERR', $cmd_104, 'tee', '/etc/apt/sources.list.d/sonarr.list');
            print {$in_103} $output_102;
            close $in_103 or croak 'Close failed: $OS_ERROR';
            $output_102 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_103> };
            close $out_103 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_103, 0;
            if ($output_102 ne q{} && !defined $output_printed_102) {
                print $output_102;
                if (!($output_102 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_102 ) { $main_exit_code = 1; }
            }
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', '-y', 'install', 'nzbdrone') >> 8;
    }
open my $fh_cat, '>', "/etc/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/sonarr.service" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "[Unit]
Description=Sonarr (NzbDrone) Daemon
After=network.target
[Service]
User=root
Type=simple
ExecStart=/usr/bin/mono --debug /opt/NzbDrone/NzbDrone.exe -nobrowser
[Install]
WantedBy=multi-user.target
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', 'enable', 'sonarr') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('systemctl', 'start', 'sonarr') >> 8;
    return;
}

sub install_vpn_server {
    chdir($TEMP_DIR);
    $CHILD_ERROR = 0;
    install_packet("debconf-utils unzip build-essential html2text apt-transport-https", "Downloading basic packages");
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('git', 'clone', '-b', 'vpnserver', '--depth=1', 'https://gitee.com/leeboby/software.git', '/tmp/vpnserver') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    chdir('/tmp/vpnserver');
    $CHILD_ERROR = 0;
    $main_exit_code = system('tar', '-z', 'xf', '*.tar.gz') >> 8;
    chdir('vpnserver');
    $CHILD_ERROR = 0;
    # Original bash: make i_read_and_agree_the_license_agreement | dialog --backtitle "$BACKTITLE" --title "Compiling SoftEther VPN" --progressbox $TTY_Y $TTY_X
{
        my $output_105 = q{};
        my $output_printed_105;
        my $pipeline_success_105 = 1;
                my ($in_106, $out_106);
        my $pid_106 = open3($in_106, $out_106, '>&STDERR', 'make', 'i_read_and_agree_the_license_agreement');
        close $in_106 or croak 'Close failed: $OS_ERROR';
        $output_105 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_106> };
        close $out_106 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_106, 0;

                my $cmd_108 = 'dialog';
        my ($in_107, $out_107);
        my $pid_107 = open3($in_107, $out_107, '>&STDERR', $cmd_108, '--backtitle', '--title', '--progressbox');
        print {$in_107} $output_105;
        close $in_107 or croak 'Close failed: $OS_ERROR';
        $output_105 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_107> };
        close $out_107 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_107, 0;
        if ($output_105 ne q{} && !defined $output_printed_105) {
            print $output_105;
            if (!($output_105 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_105 ) { $main_exit_code = 1; }
        }
    chdir('..');
    $CHILD_ERROR = 0;
    use File::Copy qw(copy);
    if (-d '/usr/local') {
        require File::Path; File::Path::make_path('/usr/local' . '/' . ('vpnserver' =~ m|([^/]+)$|)[0]);
        require File::Copy; File::Copy::copy('vpnserver', '/usr/local' . '/' . ('vpnserver' =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy('vpnserver', '/usr/local');
    }
    chdir('/usr/local/vpnserver/');
    $CHILD_ERROR = 0;
chmod(oct('600'), (q{*})) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
chmod(oct('700'), ('vpncmd')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
chmod(oct('700'), ('vpnserver')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
if ((-d '/run/systemd/system/')) {
open my $fh_cat, '>', "/lib/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/ethervpn.service" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "[Unit]
Description=VPN service

[Service]
Type=oneshot
ExecStart=/usr/local/vpnserver/vpnserver start
ExecStop=/usr/local/vpnserver/vpnserver stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
        $main_exit_code = system('systemctl', 'enable', 'ethervpn.service') >> 8;
        $main_exit_code = system('service', 'ethervpn', 'start') >> 8;
}
    else {
open my $fh_cat, '>', '/etc/init.d/vpnserver' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "#!/bin/sh
### BEGIN INIT INFO
# Provides:          vpnserver
# Required-Start:    \\$remote_fs \\$syslog
# Required-Stop:     \\$remote_fs \\$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable Softether by daemon.
### END INIT INFO
DAEMON=/usr/local/vpnserver/vpnserver
LOCK=/var/lock/vpnserver
test -x $DAEMON || exit 0
case \"\\$1\" in
start)
\\$DAEMON start
touch \\$LOCK
;;
stop)
\\$DAEMON stop
rm \\$LOCK
;;
restart)
\\$DAEMON stop
sleep 3
\\$DAEMON start
;;
*)
echo \"Usage: \\$0 {start|stop|restart}\"
exit 1
esac
exit 0
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
chmod(oct('755'), ('/etc/init.d/vpnserver')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        use File::Path qw(make_path);
        my $err;
        if ( mkdir '/var/lock/subsys' ) {
            }
        else {
            croak "mkdir: cannot create directory " . '/var/lock/subsys' . ": File exists\n";
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('update-rc.d', 'vpnserver', 'defaults') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $main_exit_code = system('/etc/init.d/vpnserver', 'start') >> 8;
    }
    return;
}

sub install_vpn_client {
    install_packet("debconf-utils unzip build-essential html2text apt-transport-https", "Downloading basic packages");
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('git', 'clone', '-b', 'vpnclient', '--depth=1', 'https://gitee.com/leeboby/software.git', '/tmp/vpnclient') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    chdir('/tmp/vpnclient');
    $CHILD_ERROR = 0;
    $main_exit_code = system('tar', '-z', 'xf', '*.tar.gz') >> 8;
    chdir('vpnclient');
    $CHILD_ERROR = 0;
    # Original bash: make i_read_and_agree_the_license_agreement | dialog --backtitle "$BACKTITLE" --title "Compiling SoftEther VPN vpnclient" --progressbox $TTY_Y $TTY_X
{
        my $output_115 = q{};
        my $output_printed_115;
        my $pipeline_success_115 = 1;
                my ($in_116, $out_116);
        my $pid_116 = open3($in_116, $out_116, '>&STDERR', 'make', 'i_read_and_agree_the_license_agreement');
        close $in_116 or croak 'Close failed: $OS_ERROR';
        $output_115 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_116> };
        close $out_116 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_116, 0;

                my $cmd_118 = 'dialog';
        my ($in_117, $out_117);
        my $pid_117 = open3($in_117, $out_117, '>&STDERR', $cmd_118, '--backtitle', '--title', '--progressbox');
        print {$in_117} $output_115;
        close $in_117 or croak 'Close failed: $OS_ERROR';
        $output_115 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_117> };
        close $out_117 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_117, 0;
        if ($output_115 ne q{} && !defined $output_printed_115) {
            print $output_115;
            if (!($output_115 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_115 ) { $main_exit_code = 1; }
        }
    chdir('..');
    $CHILD_ERROR = 0;
    use File::Copy qw(copy);
    if (-d '/usr/local') {
        require File::Path; File::Path::make_path('/usr/local' . '/' . ('vpnclient' =~ m|([^/]+)$|)[0]);
        require File::Copy; File::Copy::copy('vpnclient', '/usr/local' . '/' . ('vpnclient' =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy('vpnclient', '/usr/local');
    }
    chdir('/usr/local/vpnclient/');
    $CHILD_ERROR = 0;
chmod(oct('600'), (q{*})) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
chmod(oct('700'), ('vpncmd')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
chmod(oct('700'), ('vpnclient')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    return;
}

sub install_DashNTP {
    # Original bash: echo "dash dash/sh boolean false" | debconf-set-selections
{
        my $output_123 = q{};
        my $output_printed_123;
        my $pipeline_success_123 = 1;
        $output_123 .= 'dash dash/sh boolean false' . "\n";
if ( !($output_123 =~ m{\n\z}msx) ) { $output_123 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_125 = 'debconf-set-selections';
        my ($in_124, $out_124);
        my $pid_124 = open3($in_124, $out_124, '>&STDERR', $cmd_125, );
        print {$in_124} $output_123;
        close $in_124 or croak 'Close failed: $OS_ERROR';
        $output_123 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_124> };
        close $out_124 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_124, 0;
        if ($output_123 ne q{} && !defined $output_printed_123) {
            print $output_123;
            if (!($output_123 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_123 ) { $main_exit_code = 1; }
        }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('dpkg-reconfigure', '-f', 'noninteractive', 'dash') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    install_packet("ntp ntpdate", "Install DASH and NTP service");
    return;
}

sub install_MySQL {
    install_packet("mariadb-client mariadb-server", "SQL client and server");
    use File::Copy qw(copy);
    if ( -e '/etc/mysql/my.cnf' ) {
        if ( -d '/etc/mysql/my.cnf.backup' ) {
            require File::Copy; File::Copy::copy('/etc/mysql/my.cnf', '/etc/mysql/my.cnf.backup' . '/' . ('/etc/mysql/my.cnf' =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy('/etc/mysql/my.cnf', '/etc/mysql/my.cnf.backup');
        }
    } else {
        croak "cp: cannot stat '/etc/mysql/my.cnf': No such file or directory\n";
    }
    if ((-f '/etc/mysql/my.cnf')) {
        my @sed_lines_127 = split /\n/msx, $;
my @sed_result_127;
foreach my $line (@sed_lines_127) {
chomp $line;
push @sed_result_127, $line;
}
$ = join "\n", @sed_result_127;

        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ((-f '/etc/mysql/mariadb.conf.d/50-s erver.cnf')) {
        my @sed_lines_128 = split /\n/msx, $;
my @sed_result_128;
foreach my $line (@sed_lines_128) {
chomp $line;
push @sed_result_128, $line;
}
$ = join "\n", @sed_result_128;

        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $SECURE_MYSQL;
    my @SECURE_MYSQL;
    my %SECURE_MYSQL;
    $SECURE_MYSQL = do {
    my ($in_129, $out_129);
    my $pid_129 = open3($in_129, $out_129, '>&STDERR', 'expect', '-c', "
set timeout 3
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"root password?\"
send \"y\r\"
expect \"New password:\"
send \"$MYSQL_PASS\r\"
expect \"Re-enter new password:\"
send \"$MYSQL_PASS\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
");
    close $in_129 or croak 'Close failed: $OS_ERROR';
    my $result_129 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_129> };
    close $out_129 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_129, 0;
    $result_129
};
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        print ${SECURE_MYSQL};
if ( !( (${SECURE_MYSQL}) =~ m{\n\z}msx ) ) { print "\n"; }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    use File::Path qw(make_path);
    my $err;
    if ( !-d '/etc/mysql/mariadb.conf.d/' ) {
        make_path( '/etc/mysql/mariadb.conf.d/', { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . '/etc/mysql/mariadb.conf.d/' . ": $err->[0]\n";
        }
    }
open my $fh_cat, '>', '/etc/mysql/mariadb.conf.d/99-ispconfig.cnf' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} q{[mysqld]
sql-mode="NO_ENGINE_SUBSTITUTION"
};
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('service', 'mysql', 'restart') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub install_MySQLDovecot {
    # Original bash: echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
{
        my $output_131 = q{};
        my $output_printed_131;
        my $pipeline_success_131 = 1;
        $output_131 .= 'postfix postfix/main_mailer_type select Internet Site' . "\n";
if ( !($output_131 =~ m{\n\z}msx) ) { $output_131 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_133 = 'debconf-set-selections';
        my ($in_132, $out_132);
        my $pid_132 = open3($in_132, $out_132, '>&STDERR', $cmd_133, );
        print {$in_132} $output_131;
        close $in_132 or croak 'Close failed: $OS_ERROR';
        $output_131 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_132> };
        close $out_132 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_132, 0;
        if ($output_131 ne q{} && !defined $output_printed_131) {
            print $output_131;
            if (!($output_131 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_131 ) { $main_exit_code = 1; }
        }
    # Original bash: echo "postfix postfix/mailname string $HOSTNAMEFQDN" | debconf-set-selections
{
        my $output_134 = q{};
        my $output_printed_134;
        my $pipeline_success_134 = 1;
        $output_134 .= "postfix postfix/mailname string $HOSTNAMEFQDN\n";
if ( !($output_134 =~ m{\n\z}msx) ) { $output_134 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_136 = 'debconf-set-selections';
        my ($in_135, $out_135);
        my $pid_135 = open3($in_135, $out_135, '>&STDERR', $cmd_136, );
        print {$in_135} $output_134;
        close $in_135 or croak 'Close failed: $OS_ERROR';
        $output_134 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_135> };
        close $out_135 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_135, 0;
        if ($output_134 ne q{} && !defined $output_printed_134) {
            print $output_134;
            if (!($output_134 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_134 ) { $main_exit_code = 1; }
        }
    install_packet("postfix postfix-mysql postfix-doc openssl getmail4 rkhunter binutils dovecot-imapd dovecot-pop3d dovecot-mysql \
dovecot-sieve sudo libsasl2-modules dovecot-lmtpd", "postfix, dovecot, saslauthd, rkhunter, binutils");
    use File::Copy qw(copy);
    if ( -e '/etc/postfix/master.cf' ) {
        if ( -d '/etc/postfix/master.cf.backup' ) {
            require File::Copy; File::Copy::copy('/etc/postfix/master.cf', '/etc/postfix/master.cf.backup' . '/' . ('/etc/postfix/master.cf' =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy('/etc/postfix/master.cf', '/etc/postfix/master.cf.backup');
        }
    } else {
        croak "cp: cannot stat '/etc/postfix/master.cf': No such file or directory\n";
    }
my @sed_lines_138 = split /\n/msx, $;
my @sed_result_138;
foreach my $line (@sed_lines_138) {
chomp $line;
push @sed_result_138, $line;
}
$ = join "\n", @sed_result_138;

my @sed_lines_139 = split /\n/msx, $;
my @sed_result_139;
foreach my $line (@sed_lines_139) {
chomp $line;
push @sed_result_139, $line;
}
$ = join "\n", @sed_result_139;

my @sed_lines_140 = split /\n/msx, $;
my @sed_result_140;
foreach my $line (@sed_lines_140) {
chomp $line;
push @sed_result_140, $line;
}
$ = join "\n", @sed_result_140;

my @sed_lines_141 = split /\n/msx, $;
my @sed_result_141;
foreach my $line (@sed_lines_141) {
chomp $line;
push @sed_result_141, $line;
}
$ = join "\n", @sed_result_141;

my @sed_lines_142 = split /\n/msx, $;
my @sed_result_142;
foreach my $line (@sed_lines_142) {
chomp $line;
push @sed_result_142, $line;
}
$ = join "\n", @sed_result_142;

my @sed_lines_143 = split /\n/msx, $;
my @sed_result_143;
foreach my $line (@sed_lines_143) {
chomp $line;
push @sed_result_143, $line;
}
$ = join "\n", @sed_result_143;

my @sed_lines_144 = split /\n/msx, $;
my @sed_result_144;
foreach my $line (@sed_lines_144) {
chomp $line;
push @sed_result_144, $line;
}
$ = join "\n", @sed_result_144;

my @sed_lines_145 = split /\n/msx, $;
my @sed_result_145;
foreach my $line (@sed_lines_145) {
chomp $line;
push @sed_result_145, $line;
}
$ = join "\n", @sed_result_145;

my @sed_lines_146 = split /\n/msx, $;
my @sed_result_146;
foreach my $line (@sed_lines_146) {
chomp $line;
push @sed_result_146, $line;
}
$ = join "\n", @sed_result_146;

my @sed_lines_147 = split /\n/msx, $;
my @sed_result_147;
foreach my $line (@sed_lines_147) {
chomp $line;
push @sed_result_147, $line;
}
$ = join "\n", @sed_result_147;

my @sed_lines_148 = split /\n/msx, $;
my @sed_result_148;
foreach my $line (@sed_lines_148) {
chomp $line;
push @sed_result_148, $line;
}
$ = join "\n", @sed_result_148;

    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('service', 'postfix', 'restart') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub install_Virus {
    my $packets;
    my @packets;
    my %packets;
    $packets = "amavisd-new spamassassin clamav clamav-daemon unzip bzip2 arj p7zip unrar-free rpm nomarch lzop \
cabextract apt-listchanges libnet-ldap-perl libauthen-sasl-perl clamav-docs daemon libio-string-perl libio-socket-ssl-perl \
libnet-ident-perl zip libnet-dns-perl postgrey";
if (($distribution ne "bionic" && $distribution ne "buster")) {
        $packets = "$packets zoo";
    }
if ($distribution ne "buster") {
        $packets = "$packets ripole";
    }
    install_packet("$packets", "amavisd, spamassassin, clamav");
my @sed_lines_149 = split /\n/msx, $;
my @sed_result_149;
foreach my $line (@sed_lines_149) {
chomp $line;
push @sed_result_149, $line;
}
$ = join "\n", @sed_result_149;

    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('service', 'spamassassin', 'stop') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', 'disable', 'spamassassin') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
if ($distribution =~ /^bionic$/msx) {
        chdir($TEMP_DIR);
        $CHILD_ERROR = 0;
use LWP::Simple;
my $url = 'https://git.ispconfig.org/ispconfig/ispconfig3/raw/stable-3.1/helper_scripts/ubuntu-amavisd-new-2.11.patch';
my $content = get($url);
if (defined $content) {
print $content;
} else {
die "Failed to download $url\n";
}
        chdir('/usr/sbin');
        $CHILD_ERROR = 0;
        use File::Copy qw(copy);
        if ( -e q{f} ) {
            if ( -d 'amavisd-new_bak' ) {
                require File::Copy; File::Copy::copy(q{f}, 'amavisd-new_bak' . '/' . (q{f} =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy(q{f}, 'amavisd-new_bak');
            }
        } else {
            croak "cp: cannot stat '-p': No such file or directory\n";
        }
        if ( -e 'amavisd-new' ) {
            if ( -d 'amavisd-new_bak' ) {
                require File::Copy; File::Copy::copy('amavisd-new', 'amavisd-new_bak' . '/' . ('amavisd-new' =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy('amavisd-new', 'amavisd-new_bak');
            }
        } else {
            croak "cp: cannot stat '-p': No such file or directory\n";
        }
open STDIN, '<', $TEMP_DIR or croak "Cannot open file: $OS_ERROR\n";
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('patch', '--silent', '/ubuntu-amavisd-new-2.11.patch') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', '/var/log/ispconfig_config.log'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('bash', 'freshclam') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('service', 'clamav-daemon', 'start') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub install_hhvm {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('apt-key', 'adv', '--recv-keys', '--keyserver', 'hkp://keyserver.ubuntu.com:80', '0xB4112585D386EB94') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('add-apt-repository', 'https://dl.hhvm.com/', lc(lc(($ENV{family} // q{})))) >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
    install_packet("hhvm", "HipHop Virtual Machine");
    return;
}

sub install_phpmyadmin {
if ("$family" ne "Ubuntu") {
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
        my $DEBIAN_FRONTEND = 'noninteractive';
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', '-y', 'install', 'phpmyadmin') >> 8;
}
    else {
        $main_exit_code = system('bash', 'debconf-set-selections') >> 8;
        $main_exit_code = system('bash', 'debconf-set-selections') >> 8;
        $main_exit_code = system('bash', 'debconf-set-selections') >> 8;
        # Original bash: echo "phpmyadmin phpmyadmin/internal/skip-preseed boolean true" | debconf-set-selections
{
            my $output_152 = q{};
            my $output_printed_152;
            my $pipeline_success_152 = 1;
            $output_152 .= 'phpmyadmin phpmyadmin/internal/skip-preseed boolean true' . "\n";
if ( !($output_152 =~ m{\n\z}msx) ) { $output_152 .= "\n"; }
$CHILD_ERROR = 0;

                        my $cmd_154 = 'debconf-set-selections';
            my ($in_153, $out_153);
            my $pid_153 = open3($in_153, $out_153, '>&STDERR', $cmd_154, );
            print {$in_153} $output_152;
            close $in_153 or croak 'Close failed: $OS_ERROR';
            $output_152 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_153> };
            close $out_153 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_153, 0;
            if ($output_152 ne q{} && !defined $output_printed_152) {
                print $output_152;
                if (!($output_152 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_152 ) { $main_exit_code = 1; }
            }
        # Original bash: echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect" | debconf-set-selections
{
            my $output_155 = q{};
            my $output_printed_155;
            my $pipeline_success_155 = 1;
            $output_155 .= 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect' . "\n";
if ( !($output_155 =~ m{\n\z}msx) ) { $output_155 .= "\n"; }
$CHILD_ERROR = 0;

                        my $cmd_157 = 'debconf-set-selections';
            my ($in_156, $out_156);
            my $pid_156 = open3($in_156, $out_156, '>&STDERR', $cmd_157, );
            print {$in_156} $output_155;
            close $in_156 or croak 'Close failed: $OS_ERROR';
            $output_155 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_156> };
            close $out_156 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_156, 0;
            if ($output_155 ne q{} && !defined $output_printed_155) {
                print $output_155;
                if (!($output_155 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_155 ) { $main_exit_code = 1; }
            }
        # Original bash: echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | debconf-set-selections
{
            my $output_158 = q{};
            my $output_printed_158;
            my $pipeline_success_158 = 1;
            $output_158 .= 'phpmyadmin phpmyadmin/dbconfig-install boolean false' . "\n";
if ( !($output_158 =~ m{\n\z}msx) ) { $output_158 .= "\n"; }
$CHILD_ERROR = 0;

                        my $cmd_160 = 'debconf-set-selections';
            my ($in_159, $out_159);
            my $pid_159 = open3($in_159, $out_159, '>&STDERR', $cmd_160, );
            print {$in_159} $output_158;
            close $in_159 or croak 'Close failed: $OS_ERROR';
            $output_158 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_159> };
            close $out_159 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_159, 0;
            if ($output_158 ne q{} && !defined $output_printed_158) {
                print $output_158;
                if (!($output_158 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_158 ) { $main_exit_code = 1; }
            }
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
        $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'install', '-y', 'phpmyadmin') >> 8;
    }
    my $WWW_RECONFIG;
    my @WWW_RECONFIG;
    my %WWW_RECONFIG;
    $WWW_RECONFIG = do {
    my ($in_161, $out_161);
    my $pid_161 = open3($in_161, $out_161, '>&STDERR', 'expect', '-c', "
set timeout 3
spawn dpkg-reconfigure -f readline phpmyadmin
expect \"Reinstall database for phpmyadmin?\"
send \"No\r\"
expect \"Web server to reconfigure automatically:\"
send \"1\r\"
expect eof
");
    close $in_161 or croak 'Close failed: $OS_ERROR';
    my $result_161 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_161> };
    close $out_161 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_161, 0;
    $result_161
};
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        print ${WWW_RECONFIG};
if ( !( (${WWW_RECONFIG}) =~ m{\n\z}msx ) ) { print "\n"; }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub install_apache {
    my $pkg = "apache2 apache2-doc apache2-utils libapache2-mod-fcgid php-pear mcrypt imagemagick libruby libapache2-mod-python memcached";
    my $pkg_xenial = "libapache2-mod-php php7.0 php7.0-common php7.0-gd php7.0-mysql php7.0-imap php7.0-cli php7.0-cgi \
apache2-suexec-pristine php-auth php7.0-mcrypt php7.0-curl php7.0-intl php7.0-pspell php7.0-recode php7.0-sqlite3 php7.0-tidy \
php7.0-xmlrpc php7.0-xsl php-memcache php-imagick php-gettext php7.0-zip php7.0-mbstring php7.0-opcache php-apcu \
libapache2-mod-fastcgi php7.0-fpm";
    my $pkg_bionic = "apache2 apache2-doc apache2-utils libapache2-mod-php php7.2 php7.2-common php7.2-gd php7.2-mysql php7.2-imap \
phpmyadmin php7.2-cli php7.2-cgi libapache2-mod-fcgid apache2-suexec-pristine php-pear mcrypt  imagemagick libruby libapache2-mod-python \
php7.2-curl php7.2-intl php7.2-pspell php7.2-recode php7.2-sqlite3 php7.2-tidy php7.2-xmlrpc php7.2-xsl memcached php-memcache \
php-imagick php-gettext php7.2-zip php7.2-mbstring php-soap php7.2-soap php7.2-fpm php-apcu certbot";
    my $pkg_stretch = "libapache2-mod-php php7.0 php7.0-common php7.0-gd php7.0-mysql php7.0-imap php7.0-cli php7.0-cgi libapache2-mod-fcgid \
apache2-suexec-pristine php7.0-mcrypt libapache2-mod-python php7.0-curl php7.0-intl php7.0-pspell php7.0-recode php7.0-sqlite3 \
php7.0-tidy php7.0-xmlrpc php7.0-xsl php-memcache php-imagick php-gettext php7.0-zip php7.0-mbstring libapache2-mod-passenger \
php7.0-soap php7.0-fpm php7.0-opcache php-apcu certbot";
    my $pkg_jessie = "apache2.2-common apache2-mpm-prefork libexpat1 ssl-cert libapache2-mod-php5 php5 php5-common php5-gd php5-mysql \
php5-imap php5-cli php5-cgi libapache2-mod-fcgid apache2-suexec php-pear php-auth php5-mcrypt mcrypt php5-imagick libapache2-mod-python \
php5-curl php5-intl php5-memcache php5-memcached php5-pspell php5-recode php5-sqlite php5-tidy php5-xmlrpc php5-xsl \
libapache2-mod-passenger php5-xcache libapache2-mod-fastcgi php5-fpm";
    my $pkg_buster = "apache2 apache2-doc apache2-utils libapache2-mod-php php7.3 php7.3-common php7.3-gd php7.3-mysql php7.3-imap \
php7.3-cli php7.3-cgi libapache2-mod-fcgid apache2-suexec-pristine php-pear mcrypt  imagemagick libruby libapache2-mod-python \
php7.3-curl php7.3-intl php7.3-pspell php7.3-recode php7.3-sqlite3 php7.3-tidy php7.3-xmlrpc php7.3-xsl memcached php-memcache \
php-imagick php-gettext php7.3-zip php7.3-mbstring php-soap php7.3-soap php7.3-fpm php-apcu certbot";
    my $temp = "pkg_" . ($ENV{distribution} // q{});
    install_packet(${pkg} . " " . ($ENV{!temp} // q{}), "Apache for $ENV{family} $ENV{distribution}");
open my $fh_cat, '>', '/etc/apache2/conf-available/httpoxy.conf' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "<IfModule mod_headers.c>
    RequestHeader unset Proxy early
</IfModule>

";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('a2enmod', 'actions', 'proxy_fcgi', 'setenvif', 'fastcgi', 'alias', 'httpoxy', 'suexec', 'rewrite', 'ssl', 'actions', 'include', 'dav_fs', 'dav', 'auth_digest', 'cgi', 'headers') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
if ($distribution =~ /^jessie$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('a2enconf', 'php5-fpm') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } elsif ($distribution =~ /^xenial$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('a2enconf', 'php7.0', '-f', 'pm') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } elsif ($distribution =~ /^stretch$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('a2enconf', 'php7.0', '-f', 'pm') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } elsif ($distribution =~ /^bionic$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('a2enconf', 'php7.2', '-f', 'pm') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } elsif ($distribution =~ /^buster$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('a2enconf', 'php7.3', '-f', 'pm') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('service', 'apache2', 'restart') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub install_nginx {
    my $pkg = "nginx php-pear memcached fcgiwrap";
    my $pkg_xenial = "php7.0-fpm php7.0-opcache php7.0-fpm php7.0 php7.0-common php7.0-gd php7.0-mysql php7.0-imap php7.0-cli php7.0-cgi \
php7.0-mcrypt mcrypt imagemagick libruby php7.0-curl php7.0-intl php7.0-pspell php7.0-recode php7.0-sqlite3 php7.0-tidy \
php7.0-xmlrpc php7.0-xsl php-memcache php-imagick php-gettext php7.0-zip php7.0-mbstring php-apcu letsencrypt";
    my $pkg_stretch = "php7.0-fpm php7.0-opcache php7.0-fpm php7.0 php7.0-common php7.0-gd php7.0-mysql php7.0-imap php7.0-cli php7.0-cgi \
php7.0-mcrypt mcrypt imagemagick libruby php7.0-curl php7.0-intl php7.0-pspell php7.0-recode php7.0-sqlite3 php7.0-tidy \
php7.0-xmlrpc php7.0-xsl php-memcache php-imagick php-gettext php7.0-zip php7.0-mbstring php-apcu letsencrypt";
    my $pkg_jessie = "php5-fpm php5-mysql php5-curl php5-gd php5-intl php5-imagick php5-imap php5-mcrypt php5-memcache \
php5-memcached php5-pspell php5-recode php5-snmp php5-sqlite php5-tidy php5-xmlrpc php5-xsl php-apc";
    my $pkg_bionic = "php7.2-fpm php7.2-opcache php7.2-fpm php7.2 php7.2-common php7.2-gd php7.2-mysql php7.2-imap php7.2-cli php7.2-cgi \
imagemagick libruby php7.2-curl php7.2-intl php7.2-pspell php7.2-recode php7.2-sqlite3 php7.2-tidy \
php7.2-xmlrpc php7.2-xsl php-memcache php-imagick php-gettext php7.2-zip php7.2-mbstring php-apcu letsencrypt";
    my $pkg_buster = "php7.3-fpm php7.3-opcache php7.3-fpm php7.3 php7.3-common php7.3-gd php7.3-mysql php7.3-imap php7.3-cli php7.3-cgi \
imagemagick libruby php7.3-curl php7.3-intl php7.3-pspell php7.3-recode php7.3-sqlite3 php7.3-tidy \
php7.3-xmlrpc php7.3-xsl php-memcache php-imagick php-gettext php7.3-zip php7.3-mbstring php-apcu letsencrypt";
    my $temp = "pkg_" . ($ENV{distribution} // q{});
    install_packet(${pkg} . " " . ($ENV{!temp} // q{}), "Nginx for $ENV{family} $ENV{distribution}");
if ($distribution =~ /^jessie$/msx) {
                $main_exit_code = system('phpenmod', 'mcrypt', 'mbstring') >> 8;
                $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
                $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'install', '-y', 'python-certbot', '-t', 'jessie-backports') >> 8;
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('service', 'php5-fpm', 'reload') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } elsif ($distribution =~ /^xenial$/msx) {
                $main_exit_code = system('phpenmod', 'mcrypt', 'mbstring') >> 8;
                my $tz;
        my @tz;
        my %tz;
        $tz = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_162 = q{};
            my $output_printed_162;
            my $pipeline_success_162 = 1;
            $output_162 = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/timezone' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/timezone' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            if ($CHILD_ERROR != 0) { $pipeline_success_162 = 0; }
            my @sed_lines_162 = split /\n/msx, $output_162;
            my @sed_result_162;
            foreach my $line (@sed_lines_162) {
            chomp $line;
            $line =~ s/\//gmsx;
            push @sed_result_162, $line;
            }
            $output_162 = join "\n", @sed_result_162;

            if ( !$pipeline_success_162 ) { $main_exit_code = 1; }
            $output_162 =~ s/\n+\z//msx;
            $output_162;
}; $_pipeline_result; };
        my @sed_lines_163 = split /\n/msx, $;
my @sed_result_163;
foreach my $line (@sed_lines_163) {
chomp $line;
push @sed_result_163, $line;
}
$ = join "\n", @sed_result_163;

        my @sed_lines_164 = split /\n/msx, $;
my @sed_result_164;
foreach my $line (@sed_lines_164) {
chomp $line;
push @sed_result_164, $line;
}
$ = join "\n", @sed_result_164;

                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('service', 'php7.0', '-f', 'pm', 'reload') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } elsif ($distribution =~ /^stretch$/msx) {
                $tz = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_165 = q{};
            my $output_printed_165;
            my $pipeline_success_165 = 1;
            $output_165 = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/timezone' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/timezone' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            if ($CHILD_ERROR != 0) { $pipeline_success_165 = 0; }
            my @sed_lines_165 = split /\n/msx, $output_165;
            my @sed_result_165;
            foreach my $line (@sed_lines_165) {
            chomp $line;
            $line =~ s/\//gmsx;
            push @sed_result_165, $line;
            }
            $output_165 = join "\n", @sed_result_165;

            if ( !$pipeline_success_165 ) { $main_exit_code = 1; }
            $output_165 =~ s/\n+\z//msx;
            $output_165;
}; $_pipeline_result; };
        my @sed_lines_166 = split /\n/msx, $;
my @sed_result_166;
foreach my $line (@sed_lines_166) {
chomp $line;
push @sed_result_166, $line;
}
$ = join "\n", @sed_result_166;

        my @sed_lines_167 = split /\n/msx, $;
my @sed_result_167;
foreach my $line (@sed_lines_167) {
chomp $line;
push @sed_result_167, $line;
}
$ = join "\n", @sed_result_167;

                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('service', 'php7.0', '-f', 'pm', 'reload') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
                $main_exit_code = system('phpenmod', 'mcrypt', 'mbstring') >> 8;
    } elsif ($distribution =~ /^bionic$/msx) {
                $tz = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_168 = q{};
            my $output_printed_168;
            my $pipeline_success_168 = 1;
            $output_168 = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/timezone' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/timezone' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            if ($CHILD_ERROR != 0) { $pipeline_success_168 = 0; }
            my @sed_lines_168 = split /\n/msx, $output_168;
            my @sed_result_168;
            foreach my $line (@sed_lines_168) {
            chomp $line;
            $line =~ s/\//gmsx;
            push @sed_result_168, $line;
            }
            $output_168 = join "\n", @sed_result_168;

            if ( !$pipeline_success_168 ) { $main_exit_code = 1; }
            $output_168 =~ s/\n+\z//msx;
            $output_168;
}; $_pipeline_result; };
        my @sed_lines_169 = split /\n/msx, $;
my @sed_result_169;
foreach my $line (@sed_lines_169) {
chomp $line;
push @sed_result_169, $line;
}
$ = join "\n", @sed_result_169;

        my @sed_lines_170 = split /\n/msx, $;
my @sed_result_170;
foreach my $line (@sed_lines_170) {
chomp $line;
push @sed_result_170, $line;
}
$ = join "\n", @sed_result_170;

                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('service', 'php7.2', '-f', 'pm', 'reload') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
                $main_exit_code = system('phpenmod', 'mbstring') >> 8;
    } elsif ($distribution =~ /^buster$/msx) {
                $tz = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_171 = q{};
            my $output_printed_171;
            my $pipeline_success_171 = 1;
            $output_171 = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/timezone' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/timezone' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            if ($CHILD_ERROR != 0) { $pipeline_success_171 = 0; }
            my @sed_lines_171 = split /\n/msx, $output_171;
            my @sed_result_171;
            foreach my $line (@sed_lines_171) {
            chomp $line;
            $line =~ s/\//gmsx;
            push @sed_result_171, $line;
            }
            $output_171 = join "\n", @sed_result_171;

            if ( !$pipeline_success_171 ) { $main_exit_code = 1; }
            $output_171 =~ s/\n+\z//msx;
            $output_171;
}; $_pipeline_result; };
        my @sed_lines_172 = split /\n/msx, $;
my @sed_result_172;
foreach my $line (@sed_lines_172) {
chomp $line;
push @sed_result_172, $line;
}
$ = join "\n", @sed_result_172;

        my @sed_lines_173 = split /\n/msx, $;
my @sed_result_173;
foreach my $line (@sed_lines_173) {
chomp $line;
push @sed_result_173, $line;
}
$ = join "\n", @sed_result_173;

                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('service', 'php7.3', '-f', 'pm', 'reload') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
                $main_exit_code = system('phpenmod', 'mbstring') >> 8;
    }
    return;
}

sub install_PureFTPD {
    install_packet("pure-ftpd-common pure-ftpd-mysql quota quotatool", "pureFTPd and Quota");
my @sed_lines_174 = split /\n/msx, $;
my @sed_result_174;
foreach my $line (@sed_lines_174) {
chomp $line;
push @sed_result_174, $line;
}
$ = join "\n", @sed_result_174;

    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/etc/pure-ftpd/conf/TLS'
      or die "Cannot open file: $OS_ERROR\n";
        print q{1} . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    use File::Path qw(make_path);
    my $err;
    if ( !-d '/etc/ssl/private/' ) {
        make_path( '/etc/ssl/private/', { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . '/etc/ssl/private/' . ": $err->[0]\n";
        }
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('openssl', 'req', '-x', '509', '-n', 'odes', '-d', 'ays', '7300', '-ne', 'wkey', 'rsa:2048', '-s', 'ubj', "/C=GB/ST=GB/L=GB/O=GB/OU=GB/CN=" . (do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); $__node . "\n"; }; chomp $_chomp_temp; $_chomp_temp; }) . "/emailAddress=joe@joe.com", '-k', 'eyout', '/etc/ssl/private/pure-ftpd.pem', '-out', '/etc/ssl/private/pure-ftpd.pem') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
chmod(oct('600'), ('/etc/ssl/private/pure-ftpd.pem')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('/etc/init.d/pure-ftpd-mysql', 'restart') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    my $temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_177 = q{};
        my $output_printed_177;
        my $pipeline_success_177 = 1;
        $output_177 = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/fstab' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/fstab' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        if ($CHILD_ERROR != 0) { $pipeline_success_177 = 0; }
        my $grep_result_177_1;
        my @grep_lines_177_1 = split /\n/msx, $output_177;
        my @grep_filtered_177_1 = grep { /\/\ /msx } @grep_lines_177_1;
        $grep_result_177_1 = join "\n", @grep_filtered_177_1;
                if (!($grep_result_177_1 =~ m{\n\z}msx || $grep_result_177_1 eq q{})) {
                    $grep_result_177_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_177_1 > 0 ? 0 : 1;
        $output_177 = $grep_result_177_1;
        my @lines = split /\n/msx, $output_177;
        my $num_lines = 1;
        if ($num_lines > scalar @lines) {
        $num_lines = scalar @lines;
        }
        my $start_index = scalar @lines - $num_lines;
        if ($start_index < 0) { $start_index = 0; }
        my @result = @lines[$start_index..$#lines];
        $output_177 = join "\n", @result;
        if ($output_177 ne q{} && !($output_177  =~ m{\n\z}msx)) { $output_177 .= "\n"; }

        my @lines = split /\n/msx, $output_177;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\s+/msx, $line;
            push @result, ($fields[3] . "\n");
        }
        $output_177 = join "", @result;

        if ( !$pipeline_success_177 ) { $main_exit_code = 1; }
        $output_177 =~ s/\n+\z//msx;
        $output_177;
}; $_pipeline_result; };
my @sed_lines_178 = split /\n/msx, $;
my @sed_result_178;
foreach my $line (@sed_lines_178) {
chomp $line;
push @sed_result_178, $line;
}
$ = join "\n", @sed_result_178;

    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('mount', '-o', 'remount', q{/}) >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('quotacheck', '-avugm') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('quotaon', '-avug') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub install_Bind {
    install_packet("bind9 dnsutils haveged", "Install BIND DNS Server");
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', 'enable', 'haveged') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', 'start', 'haveged') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub install_Stats {
    install_packet("vlogger webalizer awstats geoip-database libclass-dbi-mysql-perl", "vlogger, webalizer, awstats");
my @sed_lines_179 = split /\n/msx, $;
my @sed_result_179;
foreach my $line (@sed_lines_179) {
chomp $line;
push @sed_result_179, $line;
}
$ = join "\n", @sed_result_179;

my @sed_lines_180 = split /\n/msx, $;
my @sed_result_180;
foreach my $line (@sed_lines_180) {
chomp $line;
push @sed_result_180, $line;
}
$ = join "\n", @sed_result_180;

my @sed_lines_181 = split /\n/msx, $;
my @sed_result_181;
foreach my $line (@sed_lines_181) {
chomp $line;
push @sed_result_181, $line;
}
$ = join "\n", @sed_result_181;

    return;
}

sub install_Jailkit {
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
    $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'install', '-y', 'build-essential', 'autoconf', 'automake', 'libtool', 'flex', 'bison', 'debhelper', 'binutils') >> 8;
    chdir($TEMP_DIR);
    $CHILD_ERROR = 0;
    if (do {
{
    my $output_182 = q{};
    my $output_printed_182;
    my $pipeline_success_182 = 1;
        use LWP::Simple;
    my $url = q{-};
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

        my $cmd_184 = 'tar';
    my ($in_183, $out_183);
    my $pid_183 = open3($in_183, $out_183, '>&STDERR', $cmd_184, '-x', q{z});
    print {$in_183} $output_182;
    close $in_183 or croak 'Close failed: $OS_ERROR';
    $output_182 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_183> };
    close $out_183 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_183, 0;
    if ($output_182 ne q{} && !defined $output_printed_182) {
        print $output_182;
        if (!($output_182 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_182 ) { $main_exit_code = 1; }
    }
        $CHILD_ERROR == 0
    }) {
                chdir('jailkit-2.19');
        $CHILD_ERROR = 0;
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', 'debian/compat'
      or die "Cannot open file: $OS_ERROR\n";
        print q{5} . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('./debian/rules', 'binary') >> 8;
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('dpkg', '-i', '../jailkit_2.19-1_*.deb') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub install_Fail2BanDovecot {
    install_packet("fail2ban ufw", "Install fail2ban and UFW Firewall");
if ($distribution =~ /^"stretch"$/msx) {
open my $fh_cat, '>', '/etc/fail2ban/jail.local' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} q{[pure-ftpd]
enabled = true
port = ftp
filter = pure-ftpd
logpath = /var/log/syslog
maxretry = 3

[dovecot]
enabled = true
filter = dovecot
logpath = /var/log/mail.log
maxretry = 5

[postfix-sasl]
enabled = true
port = smtp
filter = postfix-sasl
logpath = /var/log/mail.log
maxretry = 3
};
close $fh_cat or croak "Close failed: $OS_ERROR\n";
}
    else {
open my $fh_cat, '>', '/etc/fail2ban/jail.local' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} q{[pureftpd]
enabled  = true
port     = ftp
filter   = pureftpd
logpath  = /var/log/syslog
maxretry = 3

[dovecot-pop3imap]
enabled = true
filter = dovecot-pop3imap
action = iptables-multiport[name=dovecot-pop3imap, port="pop3,pop3s,imap,imaps", protocol=tcp]
logpath = /var/log/mail.log
maxretry = 5

[sasl]
enabled  = true
port     = smtp
filter   = postfix-sasl
logpath  = /var/log/mail.log
maxretry = 3
};
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    }
    return;
}

sub install_Fail2BanRulesDovecot {
open my $fh_cat, '>', '/etc/fail2ban/filter.d/pureftpd.conf' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} q{[Definition]
failregex = .*pure-ftpd: \(.*@<HOST>\) \[WARNING\] Authentication failed for user.*
ignoreregex =
};
close $fh_cat or croak "Close failed: $OS_ERROR\n";
open my $fh_cat, '>', '/etc/fail2ban/filter.d/dovecot-pop3imap.conf' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} q{[Definition]
failregex = (?: pop3-login|imap-login): .*(?:Authentication failure|Aborted login \(auth failed|Aborted login \(tried to use disabled|Disconnected \(auth failed|Aborted login \(\d+ authentication attempts).*rip=(?P<host>\S*),.*
ignoreregex =
};
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', '/etc/fail2ban/filter.d/postfix-sasl.conf'
      or die "Cannot open file: $OS_ERROR\n";
        print "ignoreregex =\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('service', 'fail2ban', 'restart') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub install_ISPConfig {
    chdir($TEMP_DIR);
    $CHILD_ERROR = 0;
    # Original bash: wget -q https://www.ispconfig.org/downloads/ISPConfig-3-stable.tar.gz -O - | tar -xz
{
        my $output_185 = q{};
        my $output_printed_185;
        my $pipeline_success_185 = 1;
                use LWP::Simple;
        my $url = q{-};
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

                my $cmd_187 = 'tar';
        my ($in_186, $out_186);
        my $pid_186 = open3($in_186, $out_186, '>&STDERR', $cmd_187, '-x', q{z});
        print {$in_186} $output_185;
        close $in_186 or croak 'Close failed: $OS_ERROR';
        $output_185 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_186> };
        close $out_186 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_186, 0;
        if ($output_185 ne q{} && !defined $output_printed_185) {
            print $output_185;
            if (!($output_185 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_185 ) { $main_exit_code = 1; }
        }
    chdir($TEMP_DIR);
    $CHILD_ERROR = 0;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', '/var/log/ispconfig_config.log'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('php', '-q', 'install.php', '--autoinstall=', $TEMP_DIR, '/isp.conf.php') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('dialog', '--colors', '--backtitle', "$ENV{BACKTITLE}", '--no-collapse', '--title', " Auto updating SSL certificate ", '--clear', '--yesno', "\nDo you want to secure ISPConfig control panel and all services with free Let's Encrypt SSL certificate?", q{8}, '80') >> 8;
if ($? =~ /^0$/msx) {
        $main_exit_code = system('dialog', '--colors', '--backtitle', "$ENV{BACKTITLE}", '--no-collapse', '--title', " Instructions ", '--clear', '--msgbox', "\n1. Access admin panel with your browser: \Z1https://$ENV{serverIP}:8080\Z0\n\nUsername: \Z1admin\Z0\nPassword: \Z11234\Z0 \n\n\n2. Go to Sites > Website > \Z1Add new website\Z0\n\nDomain: \Z1" . (do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); $__node . "\n"; }; chomp $_chomp_temp; $_chomp_temp; }) . "\Z0\nAuto-Subdomain: \Z1None\Z0\nSSL: \Z1enable\Z0\nLet's Encrypt SSL: \Z1enable\Z0\n\n\n3. Go to Tools > \Z1Password and language\Z0\n\nChange ISPConfig control panel password.\n\nSave and Logout. \n\n\n4. Wait until SSL is not working here: \Z1https://" . (do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); $__node . "\n"; }; chomp $_chomp_temp; $_chomp_temp; }) . "\Z0 \n\nIt can take up to a few minutes.\n\n\n5. Proceed with install (\Z1Press ENTER\Z0):", '33', '80') >> 8;
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', 'master.zip'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Headers;
my $ua = LWP::UserAgent->new;
my $request = HTTP::Request->new('GET', 'SL');
my $response = $ua->request($request);
if ($response->is_success) {
} else {
die "curl: HTTP error: $response->code $response->message\n";
}
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $main_exit_code = system('unzip', '-qq', 'master.zip') >> 8;
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            $main_exit_code = system('bash', 'LE4ISPC-master/', $server, '/le4ispc.sh') >> 8;
        };
    }
    return;
}
if ($EUID ne 0) {
    $main_exit_code = system('dialog', '--title', "Warning", '--infobox', "\nThis script requires root privileges.\n\nExiting ...", q{7}, '41') >> 8;
require Time::HiRes; Time::HiRes::sleep(q{3});
exit $main_exit_code;
}
if ((-d '/etc/resolvconf/resolv.conf.d')) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/etc/resolvconf/resolv.conf.d/head'
      or die "Cannot open file: $OS_ERROR\n";
        print 'nameserver 8.8.8.8' . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('resolvconf', '-u') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
my $TEMP_DIR;
my @TEMP_DIR;
my %TEMP_DIR;
$TEMP_DIR = do {
    my $command = q{mktemp -d || : 'Complex command not supported in bash string generation'};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
chmod(oct('700'), ($TEMP_DIR)) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
# Builtin command 'trap' with dynamic handler not supported
$i = q{0};
$main_exit_code = system('tput', 'sc') >> 8;
while ( do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('fuser', '/var/lib/dpkg/lock') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
} ) {
if (eval { int($i % 4) } // "" =~ /^0$/msx) {
                my $j;
        my @j;
        my %j;
        $j = "-";
    } elsif (eval { int($i % 4) } // "" =~ /^1$/msx) {
                $j = "\";
    } elsif (eval { int($i % 4) } // "" =~ /^2$/msx) {
                $j = "|";
    } elsif (eval { int($i % 4) } // "" =~ /^3$/msx) {
                $j = "/";
    }
    $main_exit_code = system('tput', 'rc') >> 8;
    do {
    my $__echo_line = "n" . q{ } . "\r[$j] Waiting for other software managers to finish...";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
require Time::HiRes; Time::HiRes::sleep('0.5');
    $i = eval { int($i+1) } // "";
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('apt-get', '-qq', '-y', '--no-install-recommends', 'install', 'curl', 'debconf-utils', 'html2text', 'apt-transport-https', 'dialog', 'whiptail', 'lsb-release', 'bc', 'expect') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
my $TTY_X;
my @TTY_X;
my %TTY_X;
my $stty;
my $size;
my $awk;
my $print;
$TTY_X = eval { int(do { chomp(my $_r = qx'stty size | awk '\''{print $2}'\'''); $_r; }-6) } // "";
my $TTY_Y;
my @TTY_Y;
my %TTY_Y;
$TTY_Y = eval { int(do { chomp(my $_r = qx'stty size | awk '\''{print $1}'\'''); $_r; }-6) } // "";
my $distribution;
my @distribution;
my %distribution;
$distribution = do {
    my ($in_192, $out_192);
    my $pid_192 = open3($in_192, $out_192, '>&STDERR', 'lsb_release', '-c', q{s});
    close $in_192 or croak 'Close failed: $OS_ERROR';
    my $result_192 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_192> };
    close $out_192 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_192, 0;
    $result_192
};
my $family;
my @family;
my %family;
$family = do {
    my ($in_193, $out_193);
    my $pid_193 = open3($in_193, $out_193, '>&STDERR', 'lsb_release', '-is');
    close $in_193 or croak 'Close failed: $OS_ERROR';
    my $result_193 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_193> };
    close $out_193 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_193, 0;
    $result_193
};
my $DEFAULT_ADAPTER;
my @DEFAULT_ADAPTER;
my %DEFAULT_ADAPTER;
$DEFAULT_ADAPTER = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_194 = q{};
    my $output_printed_194;
    my $pipeline_success_194 = 1;

    my ($in_195, $out_195);
    my $pid_195 = open3($in_195, $out_195, '>&STDERR', 'ip', '-4', 'route', 'ls');
    close $in_195 or croak 'Close failed: $OS_ERROR';
    $output_194 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_195> };
    close $out_195 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_195, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_194 = 0; }
    my $grep_result_194_1;
    my @grep_lines_194_1 = split /\n/msx, $output_194;
    my @grep_filtered_194_1 = grep { /default/msx } @grep_lines_194_1;
    $grep_result_194_1 = join "\n", @grep_filtered_194_1;
        if (!($grep_result_194_1 =~ m{\n\z}msx || $grep_result_194_1 eq q{})) {
            $grep_result_194_1 .= "\n";
        }
    $CHILD_ERROR = scalar @grep_filtered_194_1 > 0 ? 0 : 1;
    $output_194 = $grep_result_194_1;
    my @lines = split /\n/msx, $output_194;
    my $num_lines = 1;
    if ($num_lines > scalar @lines) {
    $num_lines = scalar @lines;
    }
    my $start_index = scalar @lines - $num_lines;
    if ($start_index < 0) { $start_index = 0; }
    my @result = @lines[$start_index..$#lines];
    $output_194 = join "\n", @result;
    if ($output_194 ne q{} && !($output_194  =~ m{\n\z}msx)) { $output_194 .= "\n"; }

    my $grep_result_194_3;
    my @grep_lines_194_3 = split /\n/msx, $output_194;
    my @grep_filtered_194_3 = grep { /(?<=dev\ )(\S+)/msx } @grep_lines_194_3;
    my @grep_matches_194_3;
    foreach my $line (@grep_filtered_194_3) {
        if ($line =~ /((?<=dev\ )(\S+))/msx) {
            push @grep_matches_194_3, $1;
        }
    }
    $grep_result_194_3 = join "\n", @grep_matches_194_3;
    $CHILD_ERROR = scalar @grep_filtered_194_3 > 0 ? 0 : 1;
    $output_194 = $grep_result_194_3;
    if ((scalar @grep_filtered_194_3) == 0) {
        $pipeline_success_194 = 0;
    }
    if ( !$pipeline_success_194 ) { $main_exit_code = 1; }
    $output_194 =~ s/\n+\z//msx;
    $output_194;
}; $_pipeline_result; };
my $serverIP;
my @serverIP;
my %serverIP;
$serverIP = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_196 = q{};
    my $output_printed_196;
    my $pipeline_success_196 = 1;

    my ($in_197, $out_197);
    my $pid_197 = open3($in_197, $out_197, '>&STDERR', 'ip', '-4', 'addr', 'show', 'dev');
    close $in_197 or croak 'Close failed: $OS_ERROR';
    $output_196 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_197> };
    close $out_197 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_197, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_196 = 0; }
    my @lines = split /\n/msx, $output_196;
    my @result;
    foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        if (!(/inet/)) { next; }
        push @result, ($fields[1] . "\n");
    }
    $output_196 = join "", @result;

    my @lines_198 = split /\n/msx, $output_196;
    my @result_198;
    foreach my $line (@lines_198) {
    chomp $line;
    my @fields = split /\//msx, $line;
    if (@fields > 0) {
        push @result_198, $fields[0];
    }
    }
    $output_196 = join "\n", @result_198;
    if ($output_196 ne q{} && !($output_196  =~ m{\n\z}msx)) { $output_196 .= "\n"; }

    if ( !$pipeline_success_196 ) { $main_exit_code = 1; }
    $output_196 =~ s/\n+\z//msx;
    $output_196;
}; $_pipeline_result; };

my $SUBNET;
my @SUBNET;
my %SUBNET;
$SUBNET = "$_[0].$_[1].$_[2].";
my $hostnamefqdn;
my @hostnamefqdn;
my %hostnamefqdn;
$hostnamefqdn = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); $__node . "\n"; };
my $mysql_pass;
my @mysql_pass;
my %mysql_pass;
$mysql_pass = "";
my $BACKTITLE;
my @BACKTITLE;
my %BACKTITLE;
$BACKTITLE = "Softy - Orange Pi post deployment scripts, http://www.orangepi.org";
my $SCRIPTDIR;
my @SCRIPTDIR;
my %SCRIPTDIR;
$SCRIPTDIR = (do { my $_chomp_temp = do {
    my $left_result_199 = do { chdir((do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname($BASH_SOURCE[0]); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; })); q{} };
;
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_199 = do { use Cwd; getcwd(); };
        $left_result_199 . $right_result_199;
    } else {
        q{};
    }
}; chomp $_chomp_temp; $_chomp_temp; });
my $DIALOG_CANCEL;
my @DIALOG_CANCEL;
my %DIALOG_CANCEL;
$DIALOG_CANCEL = q{1};
my $DIALOG_ESC;
my @DIALOG_ESC;
my %DIALOG_ESC;
$DIALOG_ESC = '255';
while ( 1 ) {
    check_status();
    $LISTLENGTH = (do { my $_chomp_temp = do {
    my ($in_201, $out_201);
    my $pid_201 = open3($in_201, $out_201, '>&STDERR', '${#LIST[@]}/2');
    close $in_201 or croak 'Close failed: $OS_ERROR';
    my $result_201 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_201> };
    close $out_201 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_201, 0;
    $result_201
}; chomp $_chomp_temp; $_chomp_temp; });
    do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
    };
    $selection = do { my @_qx_cmd = ("dialog --backtitle \"$BACKTITLE\" --title \"Installing to $family $distribution\" --colors --clear --cancel-label Cancel --ok-label Install --checklist \"\\\\nChoose what you want to install:\\\\n \" Variable(\"LIST_CONST\", false, None) 71 18 \"${LIST}\" 2>&1 2>&3"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    my $exit_status;
    my @exit_status;
    my %exit_status;
    $exit_status = $?;
    do {
local *STDERR;
open STDERR, '>', q{-} or croak "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
    };
if ($exit_status =~ /^$DIALOG_ESC$/msx or $exit_status =~ /^$DIALOG_CANCEL$/msx) {
                $main_exit_code = system('bash', 'clear') >> 8;
        exit 1;
    }
    $i = q{0};
if (!(!($main_exit_code = system('bash', 'is_package_manager_running') >> 8;))) {
while ( $i < $LISTLENGTH ) {
if (("$selection" =~ /^.*Samba.*$/msx && "$SAMBA_STATUS" ne "on")) {
                install_samba();
                $selection = $selection//Samba/;
            }
if (("$selection" =~ /^.*CUPS.*$/msx && "$CUPS_STATUS" ne "on")) {
                install_cups();
                $selection = $selection//CUPS/;
            }
if (("$selection" =~ /^.*headend.*$/msx && "$TVHEADEND_STATUS" ne "on")) {
                install_tvheadend();
                $selection = $selection//\"TV headend\"/;
            }
if (("$selection" =~ /^.*Minidlna.*$/msx && "$MINIDLNA_STATUS" ne "on")) {
                install_packet("minidlna", "Install lightweight DLNA/UPnP-AV server");
                $selection = $selection//Minidlna/;
            }
if (("$selection" =~ /^.*ISPConfig.*$/msx && "$ISPCONFIG_STATUS" ne "on")) {
                $main_exit_code = system('debconf-apt-progress', '--', 'apt-get', 'update') >> 8;
                server_conf();
if ("$MYSQL_PASS" =~ /^""$/msx) {
                    $main_exit_code = system('dialog', '--msgbox', "Mysql password can't be blank. Exiting...", q{7}, '70') >> 8;
exit $main_exit_code;
                }
if ("$(echo $HOSTNAMEFQDN | grep -P '(?=^.{1,254}$)(^(?>(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+(?:[a-zA-Z]{2,})$)')" =~ /^""$/msx) {
                    $main_exit_code = system('dialog', '--msgbox', "Invalid FQDN. Exiting...", q{7}, '70') >> 8;
exit $main_exit_code;
                }
                choose_webserver();
                install_basic();
                install_DashNTP();
                install_MySQL();
                install_MySQLDovecot();
                install_Virus();
                $main_exit_code = system('install_', $server) >> 8;
                install_phpmyadmin();
                if ("$(dpkg --print-architecture | grep arm)" eq q{}) {
                                        install_hhvm();
                    $CHILD_ERROR = 0;
                } else {
                    $CHILD_ERROR = 1;
                }
                create_ispconfig_configuration();
                install_PureFTPD();
                install_Stats();
                install_Bind();
                install_Jailkit();
                install_Fail2BanDovecot();
                install_Fail2BanRulesDovecot();
                install_ISPConfig();
                $selection = $selection//ISPConfig/;
            }
if (("$selection" =~ /^.*Syncthing.*$/msx && "$SYNCTHING_STATUS" ne "on")) {
                install_syncthing();
                $selection = $selection//Syncthing/;
            }
if (("$selection" =~ /^.*Hassio.*$/msx && "$HASS_STATUS" ne "on")) {
                install_hassio();
                $selection = $selection//Hassio/;
            }
if (("$selection" =~ /^.*OpenHAB.*$/msx && "$OPENHAB_STATUS" ne "on")) {
                install_openhab();
                $selection = $selection//OpenHAB/;
            }
if (("$selection" =~ /^.*server.*$/msx && "$VPN_SERVER_STATUS" ne "on")) {
                install_vpn_server();
                $selection = $selection//\"VPN server\"/;
            }
if (("$selection" =~ /^.*client.*$/msx && "$VPN_CLIENT_STATUS" ne "on")) {
                install_vpn_client();
                $selection = $selection//\"VPN client\"/;
            }
if (("$selection" =~ /^.*NCP.*$/msx && "$NCP_STATUS" ne "on")) {
                install_ncp();
                $selection = $selection//NCP/;
            }
if (("$selection" =~ /^.*OMV.*$/msx && "$OMV_STATUS" ne "on")) {
                install_omv();
                $selection = $selection//OMV/;
            }
if (("$selection" =~ /^.*Plex.*$/msx && "$PLEX_STATUS" ne "on")) {
                install_plex_media_server();
                $selection = $selection//Plex/;
            }
if (("$selection" =~ /^.*Emby.*$/msx && "$EMBY_STATUS" ne "on")) {
                install_emby_server();
                $selection = $selection//Emby/;
            }
if (("$selection" =~ /^.*Radarr.*$/msx && "$RADARR_STATUS" ne "on")) {
                install_radarr();
                $selection = $selection//Radarr/;
            }
if (("$selection" =~ /^.*Sonarr.*$/msx && "$SONARR_STATUS" ne "on")) {
                install_sonarr();
                $selection = $selection//Sonarr/;
            }
if (("$selection" =~ /^.*hole.*$/msx && "$PI_HOLE_STATUS" ne "on")) {
$ENV{PIHOLE_SKIP_OS_CHECK} = 'true';
                # Original bash: curl -L "https://gitee.com/leeboby/pi-hole/raw/master/automated%20install/basic-install.sh" | bash
{
                    my $output_202 = q{};
                    my $output_printed_202;
                    my $pipeline_success_202 = 1;
                                        use LWP::UserAgent;
                    use HTTP::Request;
                    use HTTP::Headers;
                    my $ua = LWP::UserAgent->new;
                    $ua->max_redirect(5);
                    my $request = HTTP::Request->new('GET', "https://gitee.com/leeboby/pi-hole/raw/master/automated%20install/basic-install.sh");
                    my $response = $ua->request($request);
                    if ($response->is_success) {
                    print $response->content;
                    } else {
                    die "curl: HTTP error: $response->code $response->message\n";
                    }

                                        my $cmd_204 = 'bash';
                    my ($in_203, $out_203);
                    my $pid_203 = open3($in_203, $out_203, '>&STDERR', $cmd_204, );
                    print {$in_203} $output_202;
                    close $in_203 or croak 'Close failed: $OS_ERROR';
                    $output_202 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_203> };
                    close $out_203 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_203, 0;
                    if ($output_202 ne q{} && !defined $output_printed_202) {
                        print $output_202;
                        if (!($output_202 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_202 ) { $main_exit_code = 1; }
                    }
                $selection = $selection//\"Pi hole\"/;
            }
if (("$selection" =~ /^.*Docker.*$/msx && "$DOCKER_STATUS" ne "on")) {
                install_docker();
                $selection = $selection//Docker/;
            }
if (("$selection" =~ /^.*Transmission.*$/msx && "$TRANSMISSION_STATUS" ne "on")) {
                install_transmission();
                $selection = $selection//Transmission/;
                $main_exit_code = system('dialog', '--title', "Seed Armbian torrents", '--backtitle', "$BACKTITLE", '--yes-label', "Yes", '--no-label', "No", '--yesno', "\
			\nDo you want to help the community and seed armbian torrent files? It will ensure faster downloads for everyone.\
			\n\nApproximately 400GB disk space is required.", '11', '44') >> 8;
if ($? eq 0) {
                    install_transmission_seed_orangepi_torrents();
                }
            }
if (("$selection" =~ /^.*UrBackup.*$/msx && "$URBACKUP_STATUS" ne "on")) {
                install_urbackup();
                $selection = $selection//UrBackup/;
            }
if (("$selection" =~ /^.*Mayan.*$/msx && "$MAYAN_STATUS" ne "on")) {
if ("$DOCKER_STATUS" =~ /^"off"$/msx) {
                    install_docker();
                }
                # Original bash: curl -fsSL https://get.mayan-edms.com | bash
{
                    my $output_205 = q{};
                    my $output_printed_205;
                    my $pipeline_success_205 = 1;
                                        use LWP::UserAgent;
                    use HTTP::Request;
                    use HTTP::Headers;
                    my $ua = LWP::UserAgent->new;
                    my $request = HTTP::Request->new('GET', 'sSL');
                    my $response = $ua->request($request);
                    if ($response->is_success) {
                    print $response->content;
                    } else {
                    die "curl: HTTP error: $response->code $response->message\n";
                    }

                                        my $cmd_207 = 'bash';
                    my ($in_206, $out_206);
                    my $pid_206 = open3($in_206, $out_206, '>&STDERR', $cmd_207, );
                    print {$in_206} $output_205;
                    close $in_206 or croak 'Close failed: $OS_ERROR';
                    $output_205 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_206> };
                    close $out_206 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_206, 0;
                    if ($output_205 ne q{} && !defined $output_printed_205) {
                        print $output_205;
                        if (!($output_205 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_205 ) { $main_exit_code = 1; }
                    }
                $selection = $selection//Mayan/;
            }
            if (defined $i) {
                $i = eval { int($i+1) } // "";
            }
        }
    }
    check_status();
}

exit $main_exit_code;
