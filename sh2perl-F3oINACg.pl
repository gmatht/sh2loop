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

my $main;
my @main;
my %main;
my $EUID;
my @EUID;
my %EUID;
my $DIALOG_ESC;
my @DIALOG_ESC;
my %DIALOG_ESC;
my $exit_status;
my @exit_status;
my %exit_status;
my $BASH_SOURCE;
my @BASH_SOURCE;
my %BASH_SOURCE;
my $num;
my @num;
my %num;
my $BOARD_NAME;
my @BOARD_NAME;
my %BOARD_NAME;
my $TITLELENGTH;
my @TITLELENGTH;
my %TITLELENGTH;
my $DIALOG_CANCEL;
my @DIALOG_CANCEL;
my %DIALOG_CANCEL;

my $MAGIC_18 = 18;
my $MAGIC_5  = 5;

if ($EUID ne 0) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "This tool requires root privileges. Try again with \"sudo \" please ...\n";
    };
require Time::HiRes; Time::HiRes::sleep(q{2});
exit 1;
}
use LWP::Simple;
my $url = 'www.baidu.com';
my $content = get($url);
if (defined $content) {
print $content;
} else {
die "Failed to download $url\n";
}
if (($? != 0)) {
$1 = <>;
chomp $1;
$CHILD_ERROR = defined($1) ? 0 : 1;
}
if ((-f ${BASH_SOURCE}-jobs)) {
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
if ((-f ${BASH_SOURCE}-s ubmenu)) {
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
if ((-f ${BASH_SOURCE}-f unctions)) {
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
if ((-f ${BASH_SOURCE}-f unctions-network)) {
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
while ( $1 =~ /^.*=.*$/msx ) {
    my $parameter;
    my @parameter;
    my %parameter;
    $parameter = $_[0] =~ s/=.*$//sr;
    my $value;
    my @value;
    my %value;
    $value = $_[0] =~ s/^.*=//sr;
# Builtin command 'shift' not implemented
    do {
    my $__echo_line = "Command line: setting $parameter to " . (defined (defined ${value} && ${value} ne q{} ? ${value} : '(empty)') && (defined ${value} && ${value} ne q{} ? ${value} : '(empty)') ne q{} ? (defined ${value} && ${value} ne q{} ? ${value} : '(empty)') : '(empty)');
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
do { my $eval_input = $parameter . "=\"" . $value . "\""; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    my $scripted;
    my @scripted;
    my %scripted;
    $scripted = 'true';
}
if ($1 =~ /^"--help"$/msx) {
    print "Orange Pi config options:\n";
    print "\n";
    print "Examples:\n";
    print "\n";
    do {
    my $__echo_line = "Install headers:					" . $BASH_SOURCE[0] . " main=Sytem selection=Headers";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Update, upgrade and reboot:			" . $BASH_SOURCE[0] . " main=System selection=Firmware";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Switch to nightly builds:				" . $BASH_SOURCE[0] . " main=System selection=Nightly";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Switch to stable builds: 				" . $BASH_SOURCE[0] . " main=System selection=Stable";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Install default desktop:                          " . $BASH_SOURCE[0] . " main=System selection=Default";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Change to ZSH:					" . $BASH_SOURCE[0] . " main=System selection=ZSH";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Change to BASH: 					" . $BASH_SOURCE[0] . " main=System selection=BASH";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Change to stable repository [branch=dev]:		" . $BASH_SOURCE[0] . " main=System selection=Stable";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Change to nightly repository [branch=dev]:	" . $BASH_SOURCE[0] . " main=System selection=Nightly";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Install headers:					" . $BASH_SOURCE[0] . " main=Software selection=Headers_install";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Remove headers:					" . $BASH_SOURCE[0] . " main=Software selection=Headers_remove";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Install kernel source:				" . $BASH_SOURCE[0] . " main=Software selection=Source_install";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Remove kernel source:				" . $BASH_SOURCE[0] . " main=Software selection=Source_remove";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Install Avahi mDNS/DNS-SD daemon:			" . $BASH_SOURCE[0] . " main=Software selection=Avahi";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
exit $main_exit_code;
}
$main_exit_code = system('main', "@ARGV") >> 8;
while ( 1 ) {
    my $LIST;
    my @LIST = ();
    my %LIST;
    push @LIST, 'System', 'System and security settings';
    push @LIST, 'Network', 'Wired, wireless, Bluetooth, access point';
    push @LIST, 'Personal', 'Timezone, language, hostname';
    push @LIST, 'Software', 'System and 3rd party software install';
    push @LIST, 'Help', 'Documentation, support, sources';
    my $LISTLENGTH;
    my @LISTLENGTH;
    my %LISTLENGTH;
    $LISTLENGTH = (do { my $_chomp_temp = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', '11+${#LIST[@]}/2');
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
}; chomp $_chomp_temp; $_chomp_temp; });
    my $BOXLENGTH;
    my @BOXLENGTH;
    my %BOXLENGTH;
    $BOXLENGTH = scalar(@LIST);
    my $MENUTITLE;
    my @MENUTITLE;
    my %MENUTITLE;
    $MENUTITLE = "Configure \Z1$ENV{DISTRO} $ENV{DISTROID}\Z0";
    my $POLICY;
    my @POLICY;
    my %POLICY;
    $POLICY = "policy0";
    if ((qx'grep -c '^processor' /proc/cpuinfo' > 4)) {
                $POLICY = "policy4";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ((!-d /sys/devices/system/cpu/cpufreq/policy4)) {
                $POLICY = "policy0";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    $num = do { my @_qx_cmd = ("cat /sys/devices/system/cpu/cpufreq/ Variable(\"POLICY\", false, None) /scaling_min_freq 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if (((-f '/etc/default/cpufrequtils') && ! "${num##*[!0-9]*}" eq q{})) {
        $LISTLENGTH = eval { int($LISTLENGTH + 2) } // "";
        my $MIN_CPU;
        my @MIN_CPU;
        my %MIN_CPU;
        my $cat;
        my $sys;
        my $devices;
        my $system;
        my $cpu;
        my $cpufreq;
        my $scaling_min_freq;
        $MIN_CPU = eval { int(do { chomp(my $_r = qx'cat /sys/devices/system/cpu/cpufreq/$POLICY/scaling_min_freq'); $_r; } / 1000) } // "";
        my $MAX_CPU;
        my @MAX_CPU;
        my %MAX_CPU;
        my $scaling_max_freq;
        $MAX_CPU = eval { int(do { chomp(my $_r = qx'cat /sys/devices/system/cpu/cpufreq/$POLICY/scaling_max_freq'); $_r; } / 1000) } // "";
        my $GOVERNOR_CPU;
        my @GOVERNOR_CPU;
        my %GOVERNOR_CPU;
        $GOVERNOR_CPU = (do { my $cat_chunk = q{}; if ( open my $fh, '<', "/sys/devices/" . "sys" . "tem" . "/cpu/cpufreq/" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "/sys/devices/" . "sys" . "tem" . "/cpu/cpufreq/" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', $POLICY ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $POLICY . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/scaling_governor' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/scaling_governor' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
        my $FREQENCIES;
        my @FREQENCIES;
        my %FREQENCIES;
        $FREQENCIES = "\nSoC runs between \Z1" . ${MIN_CPU} . "\Z0 and \Z1" . ${MAX_CPU} . " MHz\Z0 using \Z1" . ${GOVERNOR_CPU} . "\Z0 governor.\n";
    }
    if ("${BOARD_NAME/ /}" ne q{}) {
                $MENUTITLE = $MENUTITLE;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    $DIALOG_CANCEL = q{1};
    $DIALOG_ESC = '255';
    $TITLELENGTH = length($MENUTITLE);
    if (($TITLELENGTH < 60)) {
                $TITLELENGTH = "60";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if ($main eq q{}) {
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
        };
        $main = do { my @_qx_cmd = ("dialog --colors --backtitle \"$BACKTITLE\" --title ' orangepi-config ' --clear --cancel-label Exit --menu \"\\\\n$MENUTITLE \\\\n$FREQENCIES\\\\nSupport: \\\\Z1http://www.orangepi.org\\\\Z0\\\\n \" Variable(\"LISTLENGTH\", false, None) Variable(\"TITLELENGTH\", true, None) Variable(\"BOXLENGTH\", false, None) \"${LIST}\" 2>&1 2>&3"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        $exit_status = $?;
        do {
local *STDERR;
open STDERR, '>', q{-} or croak "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
        };
        if (do {
if (($exit_status =~ /^[$]DIALOG_CANCEL$/msx || $exit_status =~ /^[$]DIALOG_ESC$/msx)) {
        $main_exit_code = system('bash', 'clear') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
            $CHILD_ERROR == 0
        }) {
            exit $main_exit_code;
        }
        $main_exit_code = system('dialog', '--backtitle', "$ENV{BACKTITLE}", '--title', "Please wait", '--infobox', "\nLoading " . lc(lc(${main})) . " submodule ... ", q{5}, eval { int(26+length($main)) } // "") >> 8;
    }
if ($main =~ /^System$/msx) {
                $main_exit_code = system('bash', 'submenu_settings') >> 8;
    } elsif ($main =~ /^Network$/msx) {
                $main_exit_code = system('bash', 'submenu_networking') >> 8;
    } elsif ($main =~ /^Personal$/msx) {
                $main_exit_code = system('bash', 'submenu_personal') >> 8;
    } elsif ($main =~ /^Software$/msx) {
                $main_exit_code = system('bash', 'submenu_software') >> 8;
    } elsif ($main =~ /^Help$/msx) {
        delete $ENV{main};
                my $t;
        my @t;
        my %t;
        $t = "This tool provides a straightforward way of configuring.";
                $t = $t;
                $t = $t;
                $t = $t;
                $t = $t;
                $t = $t;
                $main_exit_code = system('show_box', "Info", "$t", "18") >> 8;
    }
}

exit $main_exit_code;
