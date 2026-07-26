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

my $CONFIGFILE;
my @CONFIGFILE;
my %CONFIGFILE;
my $DISPLAY;
my @DISPLAY;
my %DISPLAY;

$__set_e = 1;
$main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;

sub which {
    my $IFS;
    $IFS = q{:};
    my $i;
    for my $i ($PATH) {
if ((-x "$i/$1")) {
            do {
    my $__echo_line = "$i/$_[0]";
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
return q{1};
    return;
}
if ((-f '/usr/share/console-setup/keyboard-configuration.config')) {
        $main_exit_code = system('bash', '/usr/share/console-setup/keyboard-configuration.config') >> 8;
    if ($CHILD_ERROR != 0) {
            }
}

sub keyboard_present {
    my $kern;
    my $kbdpattern;
    my $class;
    my $subclass;
    my $protocol;
    $kern = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; };
if ("$kern" =~ /^2.0.*$/msx or "$kern" =~ /^2.1.*$/msx or "$kern" =~ /^2.2.*$/msx or "$kern" =~ /^2.3.*$/msx or "$kern" =~ /^2.4.*$/msx or "$kern" =~ /^2.5.*$/msx) {
        return q{0};    }
    if (!((-d '/sys/bus/usb/devices'))) {
        return q{0};    }
    my $d;
    for my $d ('/sys/bus/usb/devices/*:*') {
        if (!((-d "$d"))) {
            next;        }
        $class = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$d/bInterfaceClass" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$d/bInterfaceClass" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        $subclass = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$d/bInterfaceSubClass" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$d/bInterfaceSubClass" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        $protocol = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$d/bInterfaceProtocol" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$d/bInterfaceProtocol" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
if ("$class:$subclass:$protocol" =~ /^03:01:01$/msx) {
            return q{0};        }
    }
    if (!((-f '/proc/bus/input/devices'))) {
        return q{0};    }
    $kbdpattern = "AT Set \|AT Translated Set\|AT Raw Set";
    $kbdpattern = "$kbdpattern\|Atari Keyboard";
    $kbdpattern = "$kbdpattern\|Amiga Keyboard";
    $kbdpattern = "$kbdpattern\|HIL keyboard";
    $kbdpattern = "$kbdpattern\|ADB keyboard";
    $kbdpattern = "$kbdpattern\|Sun Type";
    $kbdpattern = "$kbdpattern\|bluetooth.*keyboard";
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_0;
my @grep_lines_0 = ();
my @grep_filenames_0 = ();
if (-e "/proc/bus/input/devices") {
    open my $fh, '<', "/proc/bus/input/devices" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_0, $line;
        push @grep_filenames_0, "/proc/bus/input/devices";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/bus/input/devices: No such file or directory\n"; }
my @grep_filtered_0 = grep { /$kbdpattern/msxi } @grep_lines_0;
$grep_result_0 = join "\n", @grep_filtered_0;
        if (!($grep_result_0 =~ m{\n\z}msx || $grep_result_0 eq q{})) {
            $grep_result_0 .= "\n";
        }
print $grep_result_0;
$CHILD_ERROR = scalar @grep_filtered_0 > 0 ? 0 : 1;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
return q{0};
    }
return q{1};
    return;
}
$CONFIGFILE = '/etc/default/keyboard';
if (("$1" eq "configure" && (!-L "$CONFIGFILE"))) {
    $main_exit_code = system('db_get', 'keyboard-configuration/modelcode') >> 8;
    my $model;
    my @model;
    my %model;
    $model = "$ENV{RET}";
    $main_exit_code = system('db_get', 'keyboard-configuration/layoutcode') >> 8;
    my $layout;
    my @layout;
    my %layout;
    $layout = "$ENV{RET}";
    $main_exit_code = system('db_get', 'keyboard-configuration/variantcode') >> 8;
    my $variant;
    my @variant;
    my %variant;
    $variant = "$ENV{RET}";
    $main_exit_code = system('db_get', 'keyboard-configuration/optionscode') >> 8;
    my $options;
    my @options;
    my %options;
    $options = "$ENV{RET}";
if ((!-e $CONFIGFILE)) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $CONFIGFILE
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', '/usr/share/console-setup/keyboard' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/usr/share/console-setup/keyboard' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
    use File::Copy qw(copy);
    if ( -e $CONFIGFILE ) {
        if ( -d '.tmp' ) {
            require File::Copy; File::Copy::copy($CONFIGFILE, '.tmp' . '/' . ($CONFIGFILE =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy($CONFIGFILE, '.tmp');
        }
    } else {
        croak "cp: cannot stat '-a': No such file or directory\n";
    }
    if ( -e $CONFIGFILE ) {
        if ( -d '.tmp' ) {
            require File::Copy; File::Copy::copy($CONFIGFILE, '.tmp' . '/' . ($CONFIGFILE =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy($CONFIGFILE, '.tmp');
        }
    } else {
        croak "cp: cannot stat '-a': No such file or directory\n";
    }
    my $var;
    for my $var ('XKBMODEL', 'XKBLAYOUT', 'XKBVARIANT', 'XKBOPTIONS', 'BACKSPACE') {
if (!(!(do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_4;
my @grep_lines_4 = ();
my @grep_filtered_4 = grep { /^\ *"\ .\ ${var}\ .\ "=/msx } @grep_lines_4;
$grep_result_4 = join "\n", @grep_filtered_4;
            if (!($grep_result_4 =~ m{\n\z}msx || $grep_result_4 eq q{})) {
                $grep_result_4 .= "\n";
            }
print $grep_result_4;
$CHILD_ERROR = scalar @grep_filtered_4 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };))) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $CONFIGFILE
      or die "Cannot open file: $OS_ERROR\n";
                print ${var} . "=";
if ( !( (${var} . "=") =~ m{\n\z}msx ) ) { print "\n"; }
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
    }
open STDIN, '<', $CONFIGFILE or croak "Cannot open file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', $CONFIGFILE
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
my @sed_lines_5 = split /\n/msx, $;
my @sed_result_5;
foreach my $line (@sed_lines_5) {
chomp $line;
push @sed_result_5, $line;
}
$ = join "\n", @sed_result_5;

        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('bash', '.tmp') >> 8;
    my $err;
    my $force = 1;
    if ( -e "$CONFIGFILE" ) {
        my $dest = $CONFIGFILE;
        if ( -e $dest && -d $dest ) {
            my $source_name = "$CONFIGFILE";
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
        if ( File::Copy::move( "$CONFIGFILE", $dest ) ) {
        } else {
            croak
  "mv: cannot move "$CONFIGFILE" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "$CONFIGFILE": No such file or directory\n";
    }
    if ( -e '.tmp' ) {
        my $dest = $CONFIGFILE;
        if ( -e $dest && -d $dest ) {
            my $source_name = '.tmp';
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
        if ( File::Copy::move( '.tmp', $dest ) ) {
        } else {
            croak
  "mv: cannot move '.tmp' to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: '.tmp': No such file or directory\n";
    }
    $main_exit_code = system('db_set', 'keyboard-configuration/store_defaults_in_debconf_db', 'true') >> 8;
}
if ((-d '/lib/debian-installer')) {
if ((("$DISPLAY") && !(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'setxkbmap';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }))) {
                $main_exit_code = system('setxkbmap', '-option', q{}, '-model', "$model", "$layout", "$variant", "$options") >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('type', 'setupcon') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('setupcon', '--save-only') >> 8;
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
print "Your console font configuration will be updated the next time your system
boots. If you want to update it now, run 'setupcon' from a virtual console.
";
        }
}
    else {
if ((do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^GNU$/msx) {
                        if (!((!-f /var/run/hurd-console.pid))) {
                my $signal = 'TERM';
my @pids = (do { my $cat_chunk = q{}; if ( open my $fh, '<', '/var/run/hurd-console.pid' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/var/run/hurd-console.pid' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
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
        } elsif (1) {
            if (!(            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('type', 'setupcon') >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            })) {
                                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
                    $main_exit_code = system('setupcon', '--force', '--save') >> 8;
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
}
else {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('setupcon', '--save-only') >> 8;
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
print "Your console font configuration will be updated the next time your system
boots. If you want to update it now, run 'setupcon' from a virtual console.
";
}
if (!(!((-d '/lib/debian-installer.d')))) {
    $main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/init.d/keyboard-setup', '1.138', q{~}, '--', "@ARGV") >> 8;
    $main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/init.d/console-setup', '1.138', q{~}, '--', "@ARGV") >> 8;
}
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('type', 'update-initramfs') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
    $main_exit_code = system('update-initramfs', '-u') >> 8;
}
exit 0;

exit $main_exit_code;
