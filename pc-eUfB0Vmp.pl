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

my $SETTERM;
my @SETTERM;
my %SETTERM;
my $b;
my @b;
my %b;
my $do_saveonly;
my @do_saveonly;
my %do_saveonly;
my $FONT_MAP;
my @FONT_MAP;
my %FONT_MAP;
my $FONTSIZE;
my @FONTSIZE;
my %FONTSIZE;
my $FONTFILES;
my @FONTFILES;
my %FONTFILES;
my $CONSOLE_MAP;
my @CONSOLE_MAP;
my %CONSOLE_MAP;
my $installdir;
my @installdir;
my %installdir;
my $MAIN_CONFIG2;
my @MAIN_CONFIG2;
my %MAIN_CONFIG2;
my $FONTMAPFILE;
my @FONTMAPFILE;
my %FONTMAPFILE;
my $unicode;
my @unicode;
my %unicode;
my $VIDEOMODE;
my @VIDEOMODE;
my %VIDEOMODE;
my $a;
my @a;
my %a;
my $do_term;
my @do_term;
my %do_term;
my $CHARMAP;
my @CHARMAP;
my %CHARMAP;
my $XKBRULES;
my @XKBRULES;
my %XKBRULES;
my $font;
my @font;
my %font;
my $CONFIG2;
my @CONFIG2;
my %CONFIG2;
my $do_save;
my @do_save;
my %do_save;
my $ACTIVE_CONSOLES;
my @ACTIVE_CONSOLES;
my %ACTIVE_CONSOLES;
my $VERBOSE_OUTPUT;
my @VERBOSE_OUTPUT;
my %VERBOSE_OUTPUT;
my $i;
my @i;
my %i;
my $MAIN_CONFIG;
my @MAIN_CONFIG;
my %MAIN_CONFIG;
my $console_map_dec;
my @console_map_dec;
my %console_map_dec;
my $FONT;
my @FONT;
my %FONT;
my $do_font;
my @do_font;
my %do_font;
my $CODESET;
my @CODESET;
my %CODESET;
my $cached;
my @cached;
my %cached;
my $SCREEN_HEIGHT;
my @SCREEN_HEIGHT;
my %SCREEN_HEIGHT;
my $tty;
my @tty;
my %tty;
my $setupdir;
my @setupdir;
my %setupdir;
my $do_printonly;
my @do_printonly;
my %do_printonly;
my $SCREEN_WIDTH;
my @SCREEN_WIDTH;
my %SCREEN_WIDTH;
my $STTY;
my @STTY;
my %STTY;
my $BEEP;
my @BEEP;
my %BEEP;
my $do_check;
my @do_check;
my %do_check;
my $USER_CONFIG;
my @USER_CONFIG;
my %USER_CONFIG;
my $CONFIG;
my @CONFIG;
my %CONFIG;
my $RES;
my @RES;
my %RES;
my $kernel;
my @kernel;
my %kernel;
my $FONTFACE;
my @FONTFACE;
my %FONTFACE;
my $savekbdfile;
my @savekbdfile;
my %savekbdfile;
my $KMAP;
my @KMAP;
my %KMAP;
my $USER_CONFIG2;
my @USER_CONFIG2;
my %USER_CONFIG2;
my $XKBMODEL;
my @XKBMODEL;
my %XKBMODEL;
my $do_kbd;
my @do_kbd;
my %do_kbd;
my $VARIANT;
my @VARIANT;
my %VARIANT;

my $MAGIC_70 = 70;

$do_font = q{};
$do_kbd = q{};
$do_term = q{};
$do_check = 'yes';
my $do_verbose;
my @do_verbose;
my %do_verbose;
$do_verbose = q{};
$do_save = q{};
$do_saveonly = q{};
my $do_currenttty;
my @do_currenttty;
my %do_currenttty;
$do_currenttty = q{};
$savekbdfile = q{};
$do_printonly = q{};
$setupdir = q{};
my $SETUP;
my @SETUP;
my %SETUP;
$SETUP = q{};

sub which {
    my $IFS;
    $IFS = q{:};
    for my $i ($PATH) {
if (((-f "$i/$1") && (-x "$i/$1"))) {
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
my $tempfiles;
my @tempfiles;
my %tempfiles;
$tempfiles = q{};
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'rm -f $tempfiles >/dev/null 2>&1 2>&1'; print $end_out if $end_out ne q{}; }
$SIG{1} = sub { qx'exit 2'; };

sub tempfile {
if ((!(    my $TMPFILE;
    my @TMPFILE;
    my %TMPFILE;
    $TMPFILE = do { my @_qx_cmd = ("mktemp /run/tmpkbd.XXXXXX 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }) || !(    $TMPFILE = do { my @_qx_cmd = ("mktemp /tmp/tmpkbd.XXXXXX 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }))) {
        $tempfiles = "$tempfiles $TMPFILE";
return q{0};
}
    else {
        $TMPFILE = q{};
return q{1};
    }
    return;
}

sub report {
    my $nl;
if ("$_[0]" =~ /^-n$/msx) {
        # Builtin command 'shift' not implemented
                $nl = q{};
    } elsif (1) {
                $nl = "\n";
    }
if (("$do_verbose")) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print @ARGV . q{ } . $nl;
            $CHILD_ERROR = 0;
        };
    }
    return;
}

sub run {
    my $ttyarg;
    my $cmd;
    my $verbose;
    my $tty;
    my $x;
    $ttyarg = "$_[0]";
    $verbose = "$_[1]";
    $cmd = "$_[2]";
# Builtin command 'shift' not implemented
# Builtin command 'shift' not implemented
# Builtin command 'shift' not implemented
if (("$ACTIVE_CONSOLES" eq q{} || "$do_currenttty" ne q{})) {
        $ttyarg = 'plain';
    }
if ("$ttyarg" =~ /^plain$/msx) {
        if (("$setupdir$do_printonly")) {
if ("$verbose" eq NONE) {
                $SETUP = "$SETUP$cmd @ARGV > /dev/null
";
}
            else {
                $SETUP = "$SETUP$cmd @ARGV
";
            }
}
        else {
            if (("$do_verbose")) {
if ("$verbose" =~ /^NONE$/msx) {
                                        report('executing', $cmd, "@ARGV", q{.});
                                        $CHILD_ERROR = 0;
                } elsif ("$verbose" =~ /^FORK$/msx) {
                                        report('executing', "$cmd.");
                                        if (my $pid = fork()) {
                        # Parent process continues
                    } elsif (defined $pid) {
                        # Child process executes the background command
                        $CHILD_ERROR = 0;
                        exit(0);
                    } else {
                        die "Cannot fork: $ERRNO\n";
                    }
                } elsif (1) {
                                        report('executing', $cmd, "@ARGV", q{.});
                                        $CHILD_ERROR = 0;
                }
}
            else {
if ("$verbose" =~ /^NONE$/msx) {
                                        report('executing', $cmd, "@ARGV", q{.});
                                        do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                        my $tmp = do {
                        $CHILD_ERROR = 0;
                        };
                        print $tmp;
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                } elsif ("$verbose" =~ /^FORK$/msx) {
                                        report('executing', "$cmd.");
                                        if (my $pid = fork()) {
                        # Parent process continues
                    } elsif (defined $pid) {
                        # Child process executes the background command
                        $CHILD_ERROR = 0;
                        exit(0);
                    } else {
                        die "Cannot fork: $ERRNO\n";
                    }
                } elsif (1) {
                                        report('executing', $cmd, "@ARGV", q{.});
                                        $CHILD_ERROR = 0;
                }
            }
        }
    } elsif ("$ttyarg" =~ /^in$/msx) {
                for my $tty ($ACTIVE_CONSOLES) {
if (("$setupdir$do_printonly")) {
if ("$verbose" eq NONE) {
                    $SETUP = "$SETUP$cmd @ARGV < $tty > /dev/null
";
}
                else {
                    $SETUP = "$SETUP$cmd @ARGV < $tty
";
                }
}
            else {
                if ((-r $tty)) {
                    report('-n', 'on', $tty, q{});
open STDIN, '<', $tty or croak "Cannot open file: $OS_ERROR\n";
                    $main_exit_code = system('run', 'plain', "$verbose", "$cmd", "@ARGV") >> 8;
}
                else {
                    report('No', 'read', 'access', 'from', "$tty.", 'Can', 'not', 'execute', "$cmd.");
                }
            }
        }
    } elsif ("$ttyarg" =~ /^out$/msx) {
                for my $tty ($ACTIVE_CONSOLES) {
if (("$setupdir$do_printonly")) {
                $SETUP = "$SETUP$cmd @ARGV > $tty
";
}
            else {
                if ((-w $tty)) {
                    report('-n', 'on', $tty, q{});
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', $tty
      or die "Cannot open file: $OS_ERROR\n";
                        my $tmp = do {
                        $main_exit_code = system('run', 'plain', "$verbose", "$cmd", "@ARGV") >> 8;
                        };
                        print $tmp;
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
}
                else {
                    report('No', 'write', 'access', 'to', "$tty.", 'Can', 'not', 'execute', "$cmd.");
                }
            }
        }
    } elsif (1) {
                for my $tty ($ACTIVE_CONSOLES) {
            $x = ${ttyarg} . "$tty";
            $main_exit_code = system('run', 'plain', "$verbose", "$cmd", $x, "@ARGV") >> 8;
        }
    }
    return;
}

sub findfile {
    my $f;
if ("$_[1]" =~ /^/.*$/msx) {
        if ((-f "$2")) {
            print $2;
if ( !( ($2) =~ m{\n\z}msx ) ) { print "\n"; }
return q{0};
        }
    }
    for my $f ("$installdir", q{/}, $1, q{/}, $2, '/usr/local/', $1, q{/}, $2, '/usr/', $1, q{/}, $2, '/etc/console-setup/cached_', $2, '/etc/console-setup/', $2, "$installdir", '/etc/console-setup/cached_', $2, "$installdir", '/etc/console-setup/', $2) {
if ((-f "$f")) {
            print $f;
if ( !( ($f) =~ m{\n\z}msx ) ) { print "\n"; }
return q{0};
        }
    }
    report('Unable', 'to', 'find', "$_[1]", q{.});
    return;
}

sub test_console {
    my $ok;
    $ok = q{0};
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'tty';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
if ((do { my $_chomp_temp = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'tty');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
}; chomp $_chomp_temp; $_chomp_temp; }) =~ /^/dev/tty\[1-9\].*$/msx or (do { my $_chomp_temp = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'tty');
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
}; chomp $_chomp_temp; $_chomp_temp; }) =~ /^/dev/vc/\[0-9\].*$/msx or (do { my $_chomp_temp = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'tty');
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
}; chomp $_chomp_temp; $_chomp_temp; }) =~ /^/dev/console$/msx or (do { my $_chomp_temp = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'tty');
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
}; chomp $_chomp_temp; $_chomp_temp; }) =~ /^/dev/ttyv\[0-9\].*$/msx) {
            return q{0};        }
        $ok = q{1};
    }
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'kbd_mode';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        my $mode;
        my @mode;
        my %mode;
        $mode = (do { my $_chomp_temp = do { my @_qx_cmd = ("(LC_ALL=C; : 'Complex command not supported in bash string generation'; kbd_mode) 2>&1"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; });
        $mode = ${mode} =~ s/^The keyboard is in //r;
if ("$mode" =~ /^Unicode.*$/msx or "$mode" =~ /^default.*$/msx or "$mode" =~ /^xlate.*$/msx) {
            return q{0};        }
        $ok = q{1};
    }
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'vidcontrol';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
if (!(        do {
local *STDERR;
open STDERR, '>', q{-} or croak "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', q{-} or croak "Cannot open file: $OS_ERROR\n";
            $main_exit_code = system('vidcontrol', '-i', 'adapter') >> 8;
        })) {
return q{0};
        }
        $ok = q{1};
    }
return $ok;
    return;
}
while ( "$1" ) {
if ("$_[0]" =~ /^-k$/msx or "$_[0]" =~ /^--keyboard-only$/msx) {
                $do_kbd = 'yes';
    } elsif ("$_[0]" =~ /^-f$/msx or "$_[0]" =~ /^--font-only$/msx) {
                $do_font = 'yes';
    } elsif ("$_[0]" =~ /^-t$/msx or "$_[0]" =~ /^--terminal-only$/msx) {
                $do_term = 'yes';
    } elsif ("$_[0]" =~ /^--current-tty$/msx) {
                $do_currenttty = 'yes';
    } elsif ("$_[0]" =~ /^-v$/msx or "$_[0]" =~ /^--verbose$/msx) {
                $do_verbose = 'yes';
    } elsif ("$_[0]" =~ /^--force$/msx) {
                $do_check = q{};
    } elsif ("$_[0]" =~ /^--save$/msx) {
                $do_save = 'yes';
    } elsif ("$_[0]" =~ /^--save-only$/msx) {
                $do_save = 'yes';
                $do_saveonly = 'yes';
                $do_check = q{};
    } elsif ("$_[0]" =~ /^--save-keyboard$/msx) {
        # Builtin command 'shift' not implemented
                $savekbdfile = "$_[0]";
                $do_saveonly = 'yes';
                $do_check = q{};
    } elsif ("$_[0]" =~ /^--print-commands-only$/msx) {
                $do_printonly = 'yes';
                $do_check = q{};
    } elsif ("$_[0]" =~ /^--setup-dir$/msx) {
        # Builtin command 'shift' not implemented
                $do_kbd = 'yes';
                $do_currenttty = 'yes';
                $setupdir = "$_[0]";
                $do_check = q{};
    } elsif ("$_[0]" =~ /^-h$/msx or "$_[0]" =~ /^--help$/msx) {
        print "Usage: setupcon [OPTION] [VARIANT]
Sets up the font and the keyboard on Linux console.

  -k, --keyboard-only  setup the keyboard only, do not setup the font
  -f, --font-only      setup the font only, do not setup the keyboard
  -t, --terminal-only  setup the terminal only
      --current-tty    setup only the current virtual terminal
      --force          do not check whether we are on the console
  -v, --verbose        explain what is being doing, try it if s.t. goes wrong
      --save           copy the font and the console map in /etc/console-setup,
                         update /etc/console-setup/cached.*
      --save-only      only save; don't setup keyboard/font immediately
                         (implies --force)
      --print-commands-only
                       print the configuration commands, do not configure
      --save-keyboard FILE, --setup-dir DIR    options for initrd builders
  -h, --help           display this help and exit

If VARIANT is not specified setupcon looks for the configuration files
(in this order) ~/.console-setup and if this doesn't exist then the
combination /etc/default/keyboard + /etc/default/console-setup.  When
a VARIANT is specified then setupcon looks for the configuration files
~/.console-setup.VARIANT and /etc/default/console-setup.VARIANT.
";
        exit 0;
    } elsif ("$_[0]" =~ /^-.*$/msx) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "setupcon: Unrecognised option $_[0]";
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
    } elsif (1) {
        if ("$VARIANT" eq q{}) {
            $VARIANT = "$_[0]";
}
        else {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "setupcon: Two variants specified: $VARIANT and $_[0]";
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
# Builtin command 'shift' not implemented
}
if ("$do_saveonly$do_kbd$do_font$do_term" eq q{}) {
    $do_kbd = 'yes';
    $do_font = 'yes';
    $do_term = 'yes';
}
$installdir = dirname($_[0]);
if ("$installdir" =~ /^.*/bin$/msx) {
        $installdir = scalar reverse( (scalar reverse ${installdir}) =~ s/^nib///r );
} elsif (1) {
        $installdir = $installdir;
        $main_exit_code = system('bash', '/..') >> 8;
}
if (!(("$installdir" ne q{} && (-d "$installdir"/bin)))) {
        $installdir = '/usr';
}
if ("$installdir" =~ /^/.*$/msx) {
} elsif (1) {
        $installdir = (do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; }) . "$installdir";
}
if (("$VARIANT")) {
    $VARIANT = ".$VARIANT";
}
$USER_CONFIG = $HOME;
$main_exit_code = system('/.console-setup', "$VARIANT") >> 8;
$USER_CONFIG2 = $HOME;
$main_exit_code = system('/.keyboard', "$VARIANT") >> 8;
$MAIN_CONFIG = '/etc/default/keyboard';
if (!((-f "$MAIN_CONFIG"))) {
    (!-f "$installdir"/etc/default/keyboard"$VARIANT")}
if ($CHILD_ERROR != 0) {
        my $MAIN_CONFIG = "$installdir";
    $main_exit_code = system('/etc/default/keyboard', "$VARIANT") >> 8;
}
$MAIN_CONFIG2 = '/etc/default/console-setup';
if (!((-f "$MAIN_CONFIG2"))) {
    (!-f "$installdir"/etc/default/console-setup"$VARIANT")}
if ($CHILD_ERROR != 0) {
        my $MAIN_CONFIG2 = "$installdir";
    $main_exit_code = system('/etc/default/console-setup', "$VARIANT") >> 8;
}
if (((-f "$USER_CONFIG") || (-f "$USER_CONFIG2"))) {
    $CONFIG = "$USER_CONFIG";
    $CONFIG2 = "$USER_CONFIG2";
}
else {
    if (((-f "$MAIN_CONFIG") || (-f "$MAIN_CONFIG2"))) {
        $CONFIG = "$MAIN_CONFIG";
        $CONFIG2 = "$MAIN_CONFIG2";
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "setupcon: None of $MAIN_CONFIG, $MAIN_CONFIG2, $USER_CONFIG, $USER_CONFIG2 exists.";
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
if ((-f "$CONFIG2")) {
    $main_exit_code = system('.', "$CONFIG2") >> 8;
}
else {
    $CONFIG2 = "$CONFIG";
}
if ((-f "$CONFIG")) {
    $main_exit_code = system('.', "$CONFIG") >> 8;
}
if ("$VERBOSE_OUTPUT" eq yes) {
    $do_verbose = 'yes';
}
$kernel = 'unknown';
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'uname';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
if ((do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^.*Linux.*$/msx) {
                $kernel = 'linux';
    } elsif ((do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^.*FreeBSD.*$/msx) {
                $kernel = 'freebsd';
    } elsif (1) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print 'setupcon: Unknown kernel (only Linux and FreeBSD are supported).' . "\n";
            $CHILD_ERROR = 0;
        };
        exit 1;
    }
}
if ("$do_save" ne q{}) {
if ((!-d /usr/share)) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print 'setupcon:' . q{ } . 'It' . q{ } . 'seems' . q{ } . '/usr' . q{ } . 'is' . q{ } . 'not' . q{ } . 'mounted.' . q{ } . 'Will' . q{ } . 'not' . q{ } . 'save' . q{ } . 'files' . q{ } . 'in' . q{ } . '/etc.' . "\n";
            $CHILD_ERROR = 0;
        };
        $do_save = q{};
    }
}
$ACTIVE_CONSOLES = do {
    local $ENV{ACTIVE_CONSOLES} = $ACTIVE_CONSOLES;
    local $ENV{tty} = $tty;
    my $command = q{: 'Complex command not supported in bash string generation'};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
if ("$ACTIVE_CONSOLES" eq q{}) {
    for my $tty (do { my @_qx_cmd = ("sed -n Ee \"/^\\\\s*#/d;/getty/s/.*\\\\s(tty([1-9][0-9]*|v[0-9a-f]))(\\\\s|\\$).*/\\\\1/p\" /etc/inittab '/etc/init/*' /etc/ttys 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }) {
if ((-e '/dev/$tty')) {
            $ACTIVE_CONSOLES = "$ACTIVE_CONSOLES /dev/$tty";
        }
    }
}
if ("$ACTIVE_CONSOLES" eq q{}) {
if ("$kernel" =~ /^linux$/msx) {
                $ACTIVE_CONSOLES = do { my @_qx_cmd = ("ls '/dev/tty[1-6]' 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    } elsif ("$kernel" =~ /^freebsd$/msx) {
                $ACTIVE_CONSOLES = do { my @_qx_cmd = ("ls '/dev/ttyv[0-3]' 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    }
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        report('Can', 'not', 'find', 'the', 'active', 'virtual', 'consoles,', 'assuming', 'ACTIVE_CONSOLES', q{=}, "\\\"", $ACTIVE_CONSOLES, "\\\"");
    };
}
else {
    report('Configuring', $ACTIVE_CONSOLES);
}
if (("$CHARMAP" eq guess || "$CHARMAP" eq q{})) {
    $CHARMAP = q{};
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'locale';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        $CHARMAP = do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'locale', 'charmap');
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
};
    }
}
$CHARMAP = (defined ${CHARMAP} && ${CHARMAP} ne q{} ? ${CHARMAP} : 'UTF-8');
if ("$CHARMAP" =~ /^ISO8859-.*$/msx) {
        $CHARMAP = "ISO-8859-" . (${CHARMAP} =~ s/^ISO8859-//r =~ s/^ISO8859-//r);
} elsif ("$CHARMAP" =~ /^US-ASCII$/msx or "$CHARMAP" =~ /^ANSI.*$/msx) {
        $CHARMAP = 'ISO-8859-1';
}
report('The', 'charmap', 'is', $CHARMAP);
if ("$CHARMAP" eq UTF-8) {
    $unicode = 'yes';
}
else {
    $unicode = q{};
}
if (("$do_font")) {
if ("$kernel" =~ /^linux$/msx) {
        if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'consolechars';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $do_font = 'linuxct';
}
        else {
            if (!(            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'setfont';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            })) {
                $do_font = 'linuxkbd';
}
            else {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    print "setupcon: Neither setfont nor consolechars is accessible. No font will be configured.\n";
                };
                $do_font = q{};
            }
        }
    } elsif ("$kernel" =~ /^freebsd$/msx) {
        if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'vidcontrol';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $do_font = 'freebsd';
}
        else {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "setupcon: vidcontrol is not accessible. No font will be configured.\n";
            };
            $do_font = q{};
        }
    }
}
if (!("$CODESET" ne guess)) {
        $CODESET = q{};
}
if ("$CODESET" eq q{}) {
if ("$CHARMAP" =~ /^UTF-8$/msx) {
                $CODESET = 'Uni2';
    } elsif ("$CHARMAP" =~ /^ARMSCII-8$/msx) {
                $CODESET = 'Armenian';
    } elsif ("$CHARMAP" =~ /^CP1251$/msx) {
                $CODESET = 'CyrSlav';
    } elsif ("$CHARMAP" =~ /^CP1255$/msx) {
                $CODESET = 'Hebrew';
    } elsif ("$CHARMAP" =~ /^CP1256$/msx) {
                $CODESET = 'Arabic';
    } elsif ("$CHARMAP" =~ /^GEORGIAN-ACADEMY$/msx) {
                $CODESET = 'Georgian';
    } elsif ("$CHARMAP" =~ /^GEORGIAN-PS$/msx) {
                $CODESET = 'Georgian';
    } elsif ("$CHARMAP" =~ /^IBM1133$/msx) {
                $CODESET = 'Lao';
    } elsif ("$CHARMAP" =~ /^ISIRI-3342$/msx) {
                $CODESET = 'Arabic';
    } elsif ("$CHARMAP" =~ /^ISO-8859-1$/msx) {
                $CODESET = 'Lat15';
    } elsif ("$CHARMAP" =~ /^ISO-8859-2$/msx) {
                $CODESET = 'Lat2';
    } elsif ("$CHARMAP" =~ /^ISO-8859-3$/msx) {
                $CODESET = 'Lat38';
    } elsif ("$CHARMAP" =~ /^ISO-8859-4$/msx) {
                $CODESET = 'Lat7';
    } elsif ("$CHARMAP" =~ /^ISO-8859-5$/msx) {
                $CODESET = 'CyrSlav';
    } elsif ("$CHARMAP" =~ /^ISO-8859-6$/msx) {
                $CODESET = 'Arabic';
    } elsif ("$CHARMAP" =~ /^ISO-8859-7$/msx) {
                $CODESET = 'Greek';
    } elsif ("$CHARMAP" =~ /^ISO-8859-8$/msx) {
                $CODESET = 'Hebrew';
    } elsif ("$CHARMAP" =~ /^ISO-8859-9$/msx) {
                $CODESET = 'Lat15';
    } elsif ("$CHARMAP" =~ /^ISO-8859-10$/msx) {
                $CODESET = 'Lat15';
    } elsif ("$CHARMAP" =~ /^ISO-8859-11$/msx) {
                $CODESET = 'Thai';
    } elsif ("$CHARMAP" =~ /^ISO-8859-13$/msx) {
                $CODESET = 'Lat7';
    } elsif ("$CHARMAP" =~ /^ISO-8859-14$/msx) {
                $CODESET = 'Lat38';
    } elsif ("$CHARMAP" =~ /^ISO-8859-15$/msx) {
                $CODESET = 'Lat15';
    } elsif ("$CHARMAP" =~ /^ISO-8859-16$/msx) {
                $CODESET = 'Lat2';
    } elsif ("$CHARMAP" =~ /^KOI8-R$/msx) {
                $CODESET = 'CyrKoi';
    } elsif ("$CHARMAP" =~ /^KOI8-U$/msx) {
                $CODESET = 'CyrKoi';
    } elsif ("$CHARMAP" =~ /^TIS-620$/msx) {
                $CODESET = 'Thai';
    } elsif ("$CHARMAP" =~ /^VISCII$/msx) {
                $CODESET = 'Vietnamese';
    } elsif (1) {
        if (("$do_font")) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = 'Unsupported' . q{ } . 'charmap' . q{ } . $CHARMAP;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
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
if ("$kernel" eq freebsd) {
if ("$CODESET" =~ /^Uni.*$/msx or "$CODESET" =~ /^Vietnamese$/msx or "$CODESET" =~ /^Arabic$/msx or "$CODESET" =~ /^Ethiopian$/msx) {
                        $CODESET = 'Lat15';
        }
    }
}
if (("$CHARMAP" ne UTF-8 && "$kernel" eq freebsd)) {
if ("`findfile share/syscons/scrnmaps ${CHARMAP}_${CODESET}.scm`" eq q{}) {
        report("Ignoring the CODESET specification ($CODESET).");
        $CODESET = do {
    my ($in_13, $out_13);
    my $pid_13 = open3($in_13, $out_13, '>&STDERR', 'findfile', 'share/syscons/scrnmaps', $CHARMAP, '_*.scm');
    close $in_13 or croak 'Close failed: $OS_ERROR';
    my $result_13 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
    close $out_13 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_13, 0;
    $result_13
};
if (("$do_font" ne q{} && "$CODESET" eq q{})) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = 'setupcon:' . q{ } . 'Unsupported' . q{ } . 'charmap' . q{ } . $CHARMAP;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
exit 1;
        }
        $CODESET = ${CODESET} =~ s/.*/$//sr;
        $CODESET = ${CODESET} =~ s/^\.scm.*?//r;
        $CODESET = scalar reverse( (scalar reverse ${CODESET}) =~ s/^_.*?//r );
        report('Using', $CODESET, 'instead.');
    }
}
if (("$FONTSIZE" eq q{} || "$FONTSIZE" eq guess)) {
    $FONTSIZE = '16';
}
if ("$FONTSIZE" =~ /^8x.*$/msx) {
        $FONTSIZE = ${FONTSIZE} =~ s/^.*?x//r;
} elsif ("$FONTSIZE" =~ /^.*x8$/msx) {
        $FONTSIZE = scalar reverse( (scalar reverse ${FONTSIZE}) =~ s/^.*?x//r );
} elsif ("$FONTSIZE" =~ /^.*x.*$/msx) {
        $a = scalar reverse( (scalar reverse ${FONTSIZE}) =~ s/^.*?x//r );
        $b = ${FONTSIZE} =~ s/^.*?x//r;
    if (($a < $b)) {
        my $FONTSIZE = $b;
        $main_exit_code = system('x', $a) >> 8;
    }
}
if ("$kernel" =~ /^linux$/msx) {
        my $mapdir;
    my @mapdir;
    my %mapdir;
    $mapdir = 'share/consoletrans';
        my $stdmap;
    my @stdmap;
    my %stdmap;
    $stdmap = "$CHARMAP.acm";
        $main_exit_code = system('bash', '.gz') >> 8;
        my $fontdir;
    my @fontdir;
    my %fontdir;
    $fontdir = 'share/consolefonts';
        my $stdfont;
    my @stdfont;
    my %stdfont;
    $stdfont = $CODESET;
        $main_exit_code = system('-', $FONTFACE, "$FONTSIZE.psf", '.gz') >> 8;
        my $stdfontfallback;
    my @stdfontfallback;
    my %stdfontfallback;
    $stdfontfallback = $CODESET;
        $main_exit_code = system('-*[A-WXYZa-wyz]', "$FONTSIZE.psf", '.gz') >> 8;
} elsif ("$kernel" =~ /^freebsd$/msx) {
        $mapdir = 'share/syscons/scrnmaps';
        $stdmap = $CHARMAP;
    $main_exit_code = system('_', $CODESET, '.scm') >> 8;
        $fontdir = 'share/syscons/fonts';
        my $stdfont16;
    my @stdfont16;
    my %stdfont16;
    $stdfont16 = $CODESET;
        $main_exit_code = system('-', $FONTFACE, '16.fnt') >> 8;
        my $stdfont14;
    my @stdfont14;
    my %stdfont14;
    $stdfont14 = $CODESET;
        $main_exit_code = system('-', $FONTFACE, '14.fnt') >> 8;
        my $stdfont8;
    my @stdfont8;
    my %stdfont8;
    $stdfont8 = $CODESET;
        $main_exit_code = system('-', $FONTFACE, '8.fnt') >> 8;
        my $stdfontfallback16;
    my @stdfontfallback16;
    my %stdfontfallback16;
    $stdfontfallback16 = $CODESET;
        $main_exit_code = system('bash', '-*[A-WXYZa-wyz]16.fnt') >> 8;
        my $stdfontfallback14;
    my @stdfontfallback14;
    my %stdfontfallback14;
    $stdfontfallback14 = $CODESET;
        $main_exit_code = system('bash', '-*[A-WXYZa-wyz]14.fnt') >> 8;
        my $stdfontfallback8;
    my @stdfontfallback8;
    my %stdfontfallback8;
    $stdfontfallback8 = $CODESET;
        $main_exit_code = system('bash', '-*[A-WXYZa-wyz]8.fnt') >> 8;
}
$CONSOLE_MAP = (defined ${CONSOLE_MAP} && ${CONSOLE_MAP} ne q{} ? ${CONSOLE_MAP} : '$ACM');
if (!("$CONSOLE_MAP" eq q{})) {
        $CONSOLE_MAP = do {
    my ($in_14, $out_14);
    my $pid_14 = open3($in_14, $out_14, '>&STDERR', 'findfile', $mapdir, "$CONSOLE_MAP");
    close $in_14 or croak 'Close failed: $OS_ERROR';
    my $result_14 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_14> };
    close $out_14 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_14, 0;
    $result_14
};
}
if (!(("$CONSOLE_MAP" ne q{} || "$CHARMAP" eq UTF-8))) {
        $CONSOLE_MAP = do {
    my ($in_15, $out_15);
    my $pid_15 = open3($in_15, $out_15, '>&STDERR', 'findfile', $mapdir, $stdmap);
    close $in_15 or croak 'Close failed: $OS_ERROR';
    my $result_15 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_15> };
    close $out_15 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_15, 0;
    $result_15
};
}
if (!(("$CONSOLE_MAP" ne q{} || "$CHARMAP" eq UTF-8))) {
        $CONSOLE_MAP = do {
    my ($in_16, $out_16);
    my $pid_16 = open3($in_16, $out_16, '>&STDERR', 'findfile', $mapdir, scalar reverse( (scalar reverse ${stdmap}) =~ s/^zg\.//r ));
    close $in_16 or croak 'Close failed: $OS_ERROR';
    my $result_16 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_16> };
    close $out_16 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_16, 0;
    $result_16
};
}
$FONTFILES = q{};
if (("$FONT")) {
    my $f;
    for my $f ($FONT) {
        $FONTFILES = "$FONTFILES " . (do { my $_chomp_temp = do {
    my ($in_17, $out_17);
    my $pid_17 = open3($in_17, $out_17, '>&STDERR', 'findfile', $fontdir, $f);
    close $in_17 or croak 'Close failed: $OS_ERROR';
    my $result_17 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> };
    close $out_17 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_17, 0;
    $result_17
}; chomp $_chomp_temp; $_chomp_temp; });
        $RES = do {
    my ($in_18, $out_18);
    my $pid_18 = open3($in_18, $out_18, '>&STDERR', 'findfile', $fontdir, $f);
    close $in_18 or croak 'Close failed: $OS_ERROR';
    my $result_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_18> };
    close $out_18 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_18, 0;
    $result_18
};
if ("$RES" eq q{}) {
            my $fdec;
            my @fdec;
            my %fdec;
            $fdec = (scalar reverse( (scalar reverse ${f}) =~ s/^zg\.//r ) =~ s/\.gz$//r);
            $RES = do {
    my ($in_19, $out_19);
    my $pid_19 = open3($in_19, $out_19, '>&STDERR', 'findfile', $fontdir, $fdec);
    close $in_19 or croak 'Close failed: $OS_ERROR';
    my $result_19 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19> };
    close $out_19 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_19, 0;
    $result_19
};
        }
        $FONTFILES = "$FONTFILES $RES";
    }
}
$FONTFILES = ($FONTFILES);
if (("$FONTFACE" ne q{} && "$FONTFILES" eq q{})) {
if ("$kernel" =~ /^linux$/msx) {
                $FONTFILES = do {
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', 'findfile', $fontdir, $stdfont);
    close $in_20 or croak 'Close failed: $OS_ERROR';
    my $result_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    $result_20
};
                if (!(("$FONTFILES"))) {
                        $FONTFILES = do {
    my ($in_21, $out_21);
    my $pid_21 = open3($in_21, $out_21, '>&STDERR', 'findfile', $fontdir, $stdfontfallback);
    close $in_21 or croak 'Close failed: $OS_ERROR';
    my $result_21 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_21> };
    close $out_21 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_21, 0;
    $result_21
};
        }
        if ("$FONTFILES" =~ /^.*\[0-9\]x\[1-9\].*.psf.gz$/msx) {
            if (!(            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'consolechars';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            })) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    print "\
The consolechars utility from the \"console-tools\" package can load only fonts
with 8 pixel width matrix.  Please install the setfont utility from the package
\"kbd\" or reconfigure the font size.\n";
                };
            }
        }
    } elsif ("$kernel" =~ /^freebsd$/msx) {
                $FONTFILES = do {
    my ($in_23, $out_23);
    my $pid_23 = open3($in_23, $out_23, '>&STDERR', 'findfile', $fontdir, $stdfont16);
    close $in_23 or croak 'Close failed: $OS_ERROR';
    my $result_23 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
    close $out_23 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_23, 0;
    $result_23
};
                if (!(("$FONTFILES"))) {
                        $FONTFILES = do {
    my ($in_24, $out_24);
    my $pid_24 = open3($in_24, $out_24, '>&STDERR', 'findfile', $fontdir, $stdfontfallback16);
    close $in_24 or croak 'Close failed: $OS_ERROR';
    my $result_24 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_24> };
    close $out_24 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_24, 0;
    $result_24
};
        }
                $font = do {
    my ($in_25, $out_25);
    my $pid_25 = open3($in_25, $out_25, '>&STDERR', 'findfile', $fontdir, $stdfont14);
    close $in_25 or croak 'Close failed: $OS_ERROR';
    my $result_25 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_25> };
    close $out_25 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_25, 0;
    $result_25
};
                if (!(("$font"))) {
                        $font = do {
    my ($in_26, $out_26);
    my $pid_26 = open3($in_26, $out_26, '>&STDERR', 'findfile', $fontdir, $stdfontfallback14);
    close $in_26 or croak 'Close failed: $OS_ERROR';
    my $result_26 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_26> };
    close $out_26 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_26, 0;
    $result_26
};
        }
                if (!("$font" eq q{})) {
                        $FONTFILES = "$FONTFILES $font";
        }
                $font = do {
    my ($in_27, $out_27);
    my $pid_27 = open3($in_27, $out_27, '>&STDERR', 'findfile', $fontdir, $stdfont8);
    close $in_27 or croak 'Close failed: $OS_ERROR';
    my $result_27 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_27> };
    close $out_27 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_27, 0;
    $result_27
};
                if (!(("$font"))) {
                        $font = do {
    my ($in_28, $out_28);
    my $pid_28 = open3($in_28, $out_28, '>&STDERR', 'findfile', $fontdir, $stdfontfallback8);
    close $in_28 or croak 'Close failed: $OS_ERROR';
    my $result_28 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_28> };
    close $out_28 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_28, 0;
    $result_28
};
        }
                if (!("$font" eq q{})) {
                        $FONTFILES = "$FONTFILES $font";
        }
    }
if (("$do_font" ne q{} && "$FONTFILES" eq q{})) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print 'setupcon:' . q{ } . 'Unable' . q{ } . 'to' . q{ } . 'find' . q{ } . 'the' . q{ } . 'required' . q{ } . 'font.' . q{ } . 'No' . q{ } . 'font' . q{ } . 'will' . q{ } . 'be' . q{ } . 'configured.' . "\n";
            $CHILD_ERROR = 0;
        };
        $do_font = q{};
    }
}
$FONTMAPFILE = q{};
if (("$kernel" eq linux && "$FONT_MAP" ne q{})) {
    $FONTMAPFILE = do {
    my ($in_29, $out_29);
    my $pid_29 = open3($in_29, $out_29, '>&STDERR', 'findfile', 'share/consoletrans', "$FONT_MAP");
    close $in_29 or croak 'Close failed: $OS_ERROR';
    my $result_29 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_29> };
    close $out_29 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_29, 0;
    $result_29
};
}
if (("$do_kbd$do_save$savekbdfile$setupdir$do_printonly" ne q{} && "$XKBMODEL" eq q{})) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print 'setupcon:' . q{ } . 'The' . q{ } . 'keyboard' . q{ } . 'model' . q{ } . 'is' . q{ } . 'unknown,' . q{ } . 'assuming' . q{ } . "\\'pc105\\'." . q{ } . 'Keyboard' . q{ } . 'may' . q{ } . 'be' . q{ } . 'configured' . q{ } . 'incorrectly.' . "\n";
        $CHILD_ERROR = 0;
    };
    $XKBMODEL = 'pc105';
}
if (!(("$XKBMODEL" ne q{} || "$savekbdfile" eq q{}))) {
    exit 1;
}
if ("$XKBMODEL" eq SKIP) {
    $XKBMODEL = q{};
}
if (!(("$XKBMODEL$KMAP"))) {
        $do_kbd = q{};
}
if (("$do_kbd")) {
if ("$kernel" =~ /^linux$/msx) {
        if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'loadkeys';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $do_kbd = 'linux';
}
        else {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print 'setupcon:' . q{ } . 'loadkeys' . q{ } . 'is' . q{ } . 'not' . q{ } . 'accessible.' . q{ } . 'Keyboard' . q{ } . 'will' . q{ } . 'not' . q{ } . 'be' . q{ } . 'configured.' . "\n";
                $CHILD_ERROR = 0;
            };
            $do_kbd = q{};
        }
    } elsif ("$kernel" =~ /^freebsd$/msx) {
        if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'kbdcontrol';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $do_kbd = 'freebsd';
}
        else {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print 'setupcon:' . q{ } . 'kbdcontrol' . q{ } . 'is' . q{ } . 'not' . q{ } . 'accessible.' . q{ } . 'Keyboard' . q{ } . 'will' . q{ } . 'not' . q{ } . 'be' . q{ } . 'configured.' . "\n";
                $CHILD_ERROR = 0;
            };
            $do_kbd = q{};
        }
    }
}
if ("$CHARMAP" ne UTF-8) {
    my $acm_option;
    my @acm_option;
    my %acm_option;
    $acm_option = "-charmap $CHARMAP";
}
else {
    if ("$kernel" eq freebsd) {
        $acm_option = '-charmap ISO-8859-1';
}
    else {
        my $layout;
        my @layout;
        my %layout;
        $layout = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_32 = q{};
            my $output_printed_32;
            my $pipeline_success_32 = 1;
            $output_32 .= $XKBLAYOUT . "\n";
            if ( !($output_32 =~ m{\n\z}msx) ) { $output_32 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_32 = 0; }
            my @sed_lines_32 = split /\n/msx, $output_32;
            my @sed_result_32;
            foreach my $line (@sed_lines_32) {
            chomp $line;
            push @sed_result_32, $line;
            }
            $output_32 = join "\n", @sed_result_32;

            if ( !$pipeline_success_32 ) { $main_exit_code = 1; }
            $output_32 =~ s/\n+\z//msx;
            $output_32;
}; $_pipeline_result; };
        $layout = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_33 = q{};
            my $output_printed_33;
            my $pipeline_success_33 = 1;
            $output_33 .= $layout . "\n";
            if ( !($output_33 =~ m{\n\z}msx) ) { $output_33 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_33 = 0; }
            my @sed_lines_33 = split /\n/msx, $output_33;
            my @sed_result_33;
            foreach my $line (@sed_lines_33) {
            chomp $line;
            push @sed_result_33, $line;
            }
            $output_33 = join "\n", @sed_result_33;

            if ( !$pipeline_success_33 ) { $main_exit_code = 1; }
            $output_33 =~ s/\n+\z//msx;
            $output_33;
}; $_pipeline_result; };
if ("$layout" =~ /^ca$/msx or "$layout" =~ /^br$/msx or "$layout" =~ /^latam$/msx or "$layout" =~ /^us$/msx) {
                        $acm_option = '-ccharmap ISO-8859-1';
        } elsif ("$layout" =~ /^al$/msx or "$layout" =~ /^ba$/msx or "$layout" =~ /^cz$/msx or "$layout" =~ /^hr$/msx or "$layout" =~ /^hu$/msx or "$layout" =~ /^pl$/msx or "$layout" =~ /^rs$/msx or "$layout" =~ /^rs$/msx or "$layout" =~ /^sk$/msx or "$layout" =~ /^si$/msx or "$layout" =~ /^si$/msx) {
                        $acm_option = '-ccharmap ISO-8859-2';
        } elsif ("$layout" =~ /^epo$/msx or "$layout" =~ /^epo$/msx or "$layout" =~ /^mt$/msx or "$layout" =~ /^mt$/msx) {
                        $acm_option = '-ccharmap ISO-8859-3';
        } elsif ("$layout" =~ /^gr$/msx) {
                        $acm_option = '-ccharmap ISO-8859-7';
        } elsif ("$layout" =~ /^az$/msx or "$layout" =~ /^tr$/msx) {
                        $acm_option = '-ccharmap ISO-8859-9';
        } elsif ("$layout" =~ /^ee$/msx or "$layout" =~ /^lt$/msx or "$layout" =~ /^lv$/msx) {
                        $acm_option = '-ccharmap ISO-8859-13';
        } elsif ("$layout" =~ /^be$/msx or "$layout" =~ /^ch$/msx or "$layout" =~ /^de$/msx or "$layout" =~ /^dk$/msx or "$layout" =~ /^es$/msx or "$layout" =~ /^ie$/msx or "$layout" =~ /^is$/msx or "$layout" =~ /^fi$/msx or "$layout" =~ /^fr$/msx or "$layout" =~ /^gb$/msx or "$layout" =~ /^it$/msx or "$layout" =~ /^nl$/msx or "$layout" =~ /^pt$/msx or "$layout" =~ /^se$/msx) {
                        $acm_option = '-ccharmap ISO-8859-15';
        } elsif ("$layout" =~ /^ro$/msx or "$layout" =~ /^ro,.*$/msx) {
                        $acm_option = '-ccharmap ISO-8859-2';
        } elsif ("$layout" =~ /^kg$/msx or "$layout" =~ /^mk$/msx or "$layout" =~ /^ru$/msx or "$layout" =~ /^tj$/msx) {
                        $acm_option = '-ccharmap KOI8-R';
        } elsif ("$layout" =~ /^by$/msx or "$layout" =~ /^kz$/msx or "$layout" =~ /^ua$/msx) {
                        $acm_option = '-ccharmap KOI8-U';
        } elsif ("$layout" =~ /^vn$/msx) {
                        $acm_option = '-ccharmap VISCII';
        } elsif ("$layout" =~ /^bd$/msx or "$layout" =~ /^bt$/msx or "$layout" =~ /^cn$/msx or "$layout" =~ /^dz$/msx or "$layout" =~ /^in$/msx or "$layout" =~ /^jp$/msx or "$layout" =~ /^kh$/msx or "$layout" =~ /^kr$/msx or "$layout" =~ /^lk$/msx or "$layout" =~ /^mm$/msx or "$layout" =~ /^np$/msx or "$layout" =~ /^ph$/msx or "$layout" =~ /^pk$/msx or 1) {
                        $acm_option = q{};
        }
    }
}
report('The', 'ACM', 'is', $acm_option);
if (("$XKBRULES")) {
    my $rules_option;
    my @rules_option;
    my %rules_option;
    $rules_option = "-rules $XKBRULES";
}
else {
    $rules_option = q{};
}
if ("$kernel" =~ /^linux$/msx) {
        my $backspace;
    my @backspace;
    my %backspace;
    $backspace = 'del';
} elsif ("$kernel" =~ /^freebsd$/msx) {
        $backspace = 'bs';
}
if ((do { my $_chomp_temp = do { my @_qx_cmd = ("stty -a | sed -ne \"s/.*\\\\berase *= *\\\\([^; ]*\\\\).*/\\\\1/p\" 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^^\.$/msx) {
        $backspace = 'del';
} elsif ((do { my $_chomp_temp = do { my @_qx_cmd = ("stty -a | sed -ne \"s/.*\\\\berase *= *\\\\([^; ]*\\\\).*/\\\\1/p\" 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^^h|^H$/msx) {
        $backspace = 'bs';
}
if ("$ENV{BACKSPACE}" =~ /^del$/msx) {
        $backspace = 'del';
} elsif ("$ENV{BACKSPACE}" =~ /^bs$/msx) {
        $backspace = 'bs';
}
if ("$backspace" =~ /^del$/msx) {
        for my $file (glob('^?')) {
        report($file, 'BackSpace', 'is');
    }
} elsif ("$backspace" =~ /^bs$/msx) {
        report('BackSpace', 'is', '^h');
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print 'setupcon:' . q{ } . 'Wrong' . q{ } . 'BackSpace' . q{ } . 'option' . "\n";
        $CHILD_ERROR = 0;
    };
}
if (("$do_term")) {
if ("$kernel" =~ /^linux$/msx) {
                $do_term = 'linux';
    } elsif ("$kernel" =~ /^freebsd$/msx) {
                $do_term = 'freebsd';
    }
}
if ("$kernel" =~ /^linux$/msx) {
        $cached = '/etc/console-setup/cached_';
        $CHILD_ERROR = 0;
} elsif ("$kernel" =~ /^freebsd$/msx) {
        $cached = '/etc/console-setup/cached_';
        $CHILD_ERROR = 0;
}
if ((("$savekbdfile" eq q{} && "$do_save" ne q{}) && 0)) {
    $savekbdfile = "$cached";
}
if (!(("$XKBMODEL"))) {
        $savekbdfile = q{};
}
if (("$kernel" eq linux && !(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
!(my $_wa0 = 'gzip';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;)
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
}))) {
    $savekbdfile = q{};
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print 'setupcon:' . q{ } . 'gzip' . q{ } . 'is' . q{ } . 'not' . q{ } . 'accessible.' . q{ } . 'Will' . q{ } . 'not' . q{ } . 'save' . q{ } . 'cached' . q{ } . 'keyboard' . q{ } . 'map.' . "\n";
        $CHILD_ERROR = 0;
    };
}
if (("$KMAP" ne q{} && (!-f "$KMAP"))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = 'setupcon:' . q{ } . $KMAP . q{ } . 'does' . q{ } . 'not' . q{ } . 'exist.';
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    $KMAP = q{};
}
for my $i ('/etc/console-setup', $CONSOLE_MAP, $FONTFILES, $FONTMAPFILE, $savekbdfile) {
if (("$i" eq "${i#/etc/console-setup}" && "$do_save" ne q{})) {
if (!(!(do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            if ( -e "/etc/console-setup/cached_rwtest" ) {
                my $current_time = time;
                utime $current_time, $current_time, "/etc/console-setup/cached_rwtest";
            }
            else {
                if ( open my $fh, '>', "/etc/console-setup/cached_rwtest" ) {
                    close $fh or croak "Close failed: $ERRNO";
                }
                else {
                    croak "touch: cannot create ", "/etc/console-setup/cached_rwtest",
                      ": $ERRNO\n";
                }
            }
        };
        if ($CHILD_ERROR != 0) {
                        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
!(if ( -e "/etc/console-setup/cached_rwtest" ) {
                    if ( -d "/etc/console-setup/cached_rwtest" ) {
                        croak "rm: ", "/etc/console-setup/cached_rwtest",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "/etc/console-setup/cached_rwtest" ) {
                                                    }
                        else {
                            croak "rm: cannot remove ", "/etc/console-setup/cached_rwtest",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 1;
                    croak "rm: ", "/etc/console-setup/cached_rwtest", ": No such file or directory\n";
                })
            };
        }))) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print 'setupcon:' . q{ } . '/etc/console-setup' . q{ } . 'is' . q{ } . 'not' . q{ } . 'writable.' . q{ } . 'No' . q{ } . 'files' . q{ } . 'will' . q{ } . 'be' . q{ } . 'saved' . q{ } . 'there.' . "\n";
                $CHILD_ERROR = 0;
            };
            $do_save = q{};
        }
last;
    }
}
$i = $savekbdfile;
if ("$do_save" ne q{}) {
if ("$CONSOLE_MAP" =~ /^/etc/console-setup/.*$/msx) {
    } elsif ("$CONSOLE_MAP" =~ /^..*$/msx) {
                $console_map_dec = (scalar reverse( (scalar reverse ${CONSOLE_MAP}) =~ s/^zg\.//r ) =~ s/\.gz$//r);
        if ("$console_map_dec" eq "$CONSOLE_MAP") {
            use File::Copy qw(copy);
            if ( -e "$CONSOLE_MAP" ) {
                if ( -d '/etc/console-setup/' ) {
                    require File::Copy; File::Copy::copy("$CONSOLE_MAP", '/etc/console-setup/' . '/' . ("$CONSOLE_MAP" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$CONSOLE_MAP", '/etc/console-setup/');
                }
            } else {
                croak "cp: cannot stat '$CONSOLE_MAP': No such file or directory\n";
            }
}
        else {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "/etc/console-setup/" . ( ( basename(${console_map_dec}) ) =~ s|^.*/||sr )
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('gunzip', '-c', "$CONSOLE_MAP") >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
        my @files_to_remove = glob("/etc/console-setup/" . ( ( basename(${console_map_dec}) ) =~ s|^.*/||sr ) . ".gz");
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
    }
    for my $font ($FONTFILES) {
if ("$font" =~ /^/etc/console-setup/.*$/msx) {
        } elsif ("$font" =~ /^..*$/msx) {
                        use File::Copy qw(copy);
            if ( -e "$font" ) {
                if ( -d '/etc/console-setup/' ) {
                    require File::Copy; File::Copy::copy("$font", '/etc/console-setup/' . '/' . ("$font" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$font", '/etc/console-setup/');
                }
            } else {
                croak "cp: cannot stat '$font': No such file or directory\n";
            }
        }
    }
if ("$FONTMAPFILE" =~ /^/etc/console-setup/.*$/msx) {
    } elsif ("$FONTMAPFILE" =~ /^..*$/msx) {
                use File::Copy qw(copy);
        if ( -e "$FONTMAPFILE" ) {
            if ( -d '/etc/console-setup/' ) {
                require File::Copy; File::Copy::copy("$FONTMAPFILE", '/etc/console-setup/' . '/' . ("$FONTMAPFILE" =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy("$FONTMAPFILE", '/etc/console-setup/');
            }
        } else {
            croak "cp: cannot stat '$FONTMAPFILE': No such file or directory\n";
        }
    }
}
if (("$savekbdfile")) {
if ("$kernel" =~ /^linux$/msx) {
                        tempfile();
        if ($CHILD_ERROR != 0) {
                            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    print 'setupcon:' . q{ } . 'Can' . q{ } . 'not' . q{ } . 'create' . q{ } . 'temporary' . q{ } . 'file' . "\n";
                    $CHILD_ERROR = 0;
                };
exit 1;
        }
                            if (do {
                                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', $TMPFILE
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
            } == 0) {
                open STDIN, '<', $TMPFILE or croak "Cannot open file: $OS_ERROR\n";
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', "$savekbdfile"
      or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
my ($in_40);
my $pid_40 = open3($in_40, $out_40, $err_40, 'bash', '-c', 'echo "$" | gzip | base64');
close $in_40 or croak 'Close failed: $OS_ERROR';
my $compressed = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_40> };
close $out_40 or croak 'Close failed: $OS_ERROR';
waitpid $pid_40, 0;
chomp $compressed;
 = $compressed;

                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
            }
        if ($CHILD_ERROR != 0) {
            exit 1;
        }
    } elsif ("$kernel" =~ /^freebsd$/msx) {
                        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$savekbdfile"
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
            exit 1;
        }
    }
}
if ("$do_save" ne q{}) {
if ("$CONSOLE_MAP" =~ /^/etc/console-setup/.*$/msx) {
    } elsif ("$CONSOLE_MAP" =~ /^..*$/msx) {
                use File::Copy qw(copy);
        if ( -e "$CONSOLE_MAP" ) {
            if ( -d ( ( basename(${CONSOLE_MAP}) ) =~ s|^.*/||sr ) ) {
                require File::Copy; File::Copy::copy("$CONSOLE_MAP", ( ( basename(${CONSOLE_MAP}) ) =~ s|^.*/||sr ) . '/' . ("$CONSOLE_MAP" =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy("$CONSOLE_MAP", ( ( basename(${CONSOLE_MAP}) ) =~ s|^.*/||sr ));
            }
        } else {
            croak "cp: cannot stat '$CONSOLE_MAP': No such file or directory\n";
        }
        if ( -e '/etc/console-setup/cached_' ) {
            if ( -d ( ( basename(${CONSOLE_MAP}) ) =~ s|^.*/||sr ) ) {
                require File::Copy; File::Copy::copy('/etc/console-setup/cached_', ( ( basename(${CONSOLE_MAP}) ) =~ s|^.*/||sr ) . '/' . ('/etc/console-setup/cached_' =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy('/etc/console-setup/cached_', ( ( basename(${CONSOLE_MAP}) ) =~ s|^.*/||sr ));
            }
        } else {
            croak "cp: cannot stat '$CONSOLE_MAP': No such file or directory\n";
        }
    }
    for my $font ($FONTFILES) {
if ("$font" =~ /^/etc/console-setup/.*$/msx) {
        } elsif ("$font" =~ /^..*$/msx) {
                        use File::Copy qw(copy);
            if ( -e "$font" ) {
                if ( -d ( ( basename(${font}) ) =~ s|^.*/||sr ) ) {
                    require File::Copy; File::Copy::copy("$font", ( ( basename(${font}) ) =~ s|^.*/||sr ) . '/' . ("$font" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$font", ( ( basename(${font}) ) =~ s|^.*/||sr ));
                }
            } else {
                croak "cp: cannot stat '$font': No such file or directory\n";
            }
            if ( -e '/etc/console-setup/cached_' ) {
                if ( -d ( ( basename(${font}) ) =~ s|^.*/||sr ) ) {
                    require File::Copy; File::Copy::copy('/etc/console-setup/cached_', ( ( basename(${font}) ) =~ s|^.*/||sr ) . '/' . ('/etc/console-setup/cached_' =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy('/etc/console-setup/cached_', ( ( basename(${font}) ) =~ s|^.*/||sr ));
                }
            } else {
                croak "cp: cannot stat '$font': No such file or directory\n";
            }
        }
    }
if ("$FONTMAPFILE" =~ /^/etc/console-setup/.*$/msx) {
    } elsif ("$FONTMAPFILE" =~ /^..*$/msx) {
                use File::Copy qw(copy);
        if ( -e "$FONTMAPFILE" ) {
            if ( -d ( ( basename(${FONTMAPFILE}) ) =~ s|^.*/||sr ) ) {
                require File::Copy; File::Copy::copy("$FONTMAPFILE", ( ( basename(${FONTMAPFILE}) ) =~ s|^.*/||sr ) . '/' . ("$FONTMAPFILE" =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy("$FONTMAPFILE", ( ( basename(${FONTMAPFILE}) ) =~ s|^.*/||sr ));
            }
        } else {
            croak "cp: cannot stat '$FONTMAPFILE': No such file or directory\n";
        }
        if ( -e '/etc/console-setup/cached_' ) {
            if ( -d ( ( basename(${FONTMAPFILE}) ) =~ s|^.*/||sr ) ) {
                require File::Copy; File::Copy::copy('/etc/console-setup/cached_', ( ( basename(${FONTMAPFILE}) ) =~ s|^.*/||sr ) . '/' . ('/etc/console-setup/cached_' =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy('/etc/console-setup/cached_', ( ( basename(${FONTMAPFILE}) ) =~ s|^.*/||sr ));
            }
        } else {
            croak "cp: cannot stat '$FONTMAPFILE': No such file or directory\n";
        }
    }
if ("$kernel" eq linux) {
        my $commands_k;
        my @commands_k;
        my %commands_k;
        $commands_k = do {
    my ($in_44, $out_44);
    my $pid_44 = open3($in_44, $out_44, '>&STDERR', $PROGRAM_NAME, '-k', '--print-commands-only');
    close $in_44 or croak 'Close failed: $OS_ERROR';
    my $result_44 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_44> };
    close $out_44 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_44, 0;
    $result_44
};
        my $commands_f;
        my @commands_f;
        my %commands_f;
        $commands_f = do {
    my ($in_45, $out_45);
    my $pid_45 = open3($in_45, $out_45, '>&STDERR', $PROGRAM_NAME, '-f', '--current-tty', '--print-commands-only');
    close $in_45 or croak 'Close failed: $OS_ERROR';
    my $result_45 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_45> };
    close $out_45 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_45, 0;
    $result_45
};
        my $commands_t;
        my @commands_t;
        my %commands_t;
        $commands_t = do {
    my ($in_46, $out_46);
    my $pid_46 = open3($in_46, $out_46, '>&STDERR', $PROGRAM_NAME, '-t', '--current-tty', '--print-commands-only');
    close $in_46 or croak 'Close failed: $OS_ERROR';
    my $result_46 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_46> };
    close $out_46 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_46, 0;
    $result_46
};
open my $fh_cat, '>', '/etc/console-setup/cached_setup_keyboard.sh' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "#!/bin/sh

if [ -f /run/console-setup/keymap_loaded ]; then
    rm /run/console-setup/keymap_loaded
    exit 0
fi
$commands_k
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
open my $fh_cat, '>', '/etc/console-setup/cached_setup_font.sh' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "#!/bin/sh

$commands_f

if ls /dev/fb* >/dev/null 2>/dev/null; then
    for i in /dev/vcs[0-9]*; do
        { :
            $commands_f
        } < /dev/tty\\${i#/dev/vcs} > /dev/tty\\${i#/dev/vcs}
    done
fi

mkdir -p /run/console-setup
> /run/console-setup/font-loaded
for i in /dev/vcs[0-9]*; do
    { :
$commands_t
    } < /dev/tty\\${i#/dev/vcs} > /dev/tty\\${i#/dev/vcs}
done
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
open my $fh_cat, '>', '/etc/console-setup/cached_setup_terminal.sh' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "#!/bin/sh

{ :
$commands_t
} < /dev/tty\\${1#vcs} > /dev/tty\\${1#vcs}
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
chmod(oct('+x'), ('/etc/console-setup/cached_setup_keyboard.sh', '/etc/console-setup/cached_setup_font.sh', '/etc/console-setup/cached_setup_terminal.sh')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
}
if (("$do_check")) {
if (!(!(test_console();))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print 'setupcon:' . q{ } . 'We' . q{ } . 'are' . q{ } . 'not' . q{ } . 'on' . q{ } . 'the' . q{ } . 'console,' . q{ } . 'the' . q{ } . 'console' . q{ } . 'is' . q{ } . 'left' . q{ } . 'unconfigured.' . "\n";
            $CHILD_ERROR = 0;
        };
exit 0;
    }
}
if (("$VIDEOMODE")) {
if ("$do_font" =~ /^freebsd$/msx) {
                run('in', q{}, 'vidcontrol', "$VIDEOMODE");
    } elsif ("$do_font" =~ /^linux.*$/msx) {
        if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'fbset';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            run('plain', q{}, 'fbset', '-a', "$VIDEOMODE");
}
        else {
            report('fbset', 'is', 'not', 'installed');
        }
    }
}
if (("$FONTFILES")) {
if ("$do_font" =~ /^freebsd$/msx) {
        if ("$unicode" eq q{}) {
            for my $font ($FONTFILES) {
                run('plain', q{}, 'vidcontrol', '-f', $font);
            }
if (("$CONSOLE_MAP")) {
                run('plain', q{}, 'vidcontrol', '-l', "$CONSOLE_MAP");
            }
        }
    } elsif ("$do_font" =~ /^linuxkbd$/msx) {
        if (("$FONTMAPFILE")) {
if (("$CONSOLE_MAP")) {
                run('-C ', '-v', 'setfont', $FONTFILES, '-u', "$FONTMAPFILE", '-m', "$CONSOLE_MAP");
}
            else {
                run('-C ', '-v', 'setfont', $FONTFILES, '-u', "$FONTMAPFILE");
            }
}
        else {
if (("$CONSOLE_MAP")) {
                run('-C ', '-v', 'setfont', $FONTFILES, '-m', "$CONSOLE_MAP");
}
            else {
                run('-C ', '-v', 'setfont', $FONTFILES);
            }
        }
    } elsif ("$do_font" =~ /^linuxct$/msx) {
        if (("$FONTMAPFILE")) {
if (("$CONSOLE_MAP")) {
                run('--tty=', '-v', 'consolechars', '-f', ${FONTFILES} =~ s/ .*$//sr, '-u', "$FONTMAPFILE", '--acm', "$CONSOLE_MAP");
}
            else {
                run('--tty=', '-v', 'consolechars', '-f', ${FONTFILES} =~ s/ .*$//sr, '-u', "$FONTMAPFILE");
            }
}
        else {
if (("$CONSOLE_MAP")) {
                run('--tty=', '-v', 'consolechars', '-f', ${FONTFILES} =~ s/ .*$//sr, '--acm', "$CONSOLE_MAP");
}
            else {
                run('--tty=', '-v', 'consolechars', '-f', ${FONTFILES} =~ s/ .*$//sr);
            }
        }
    }
}
if ("$do_term" =~ /^linux.*$/msx) {
    if (("$unicode")) {
        run('out', 'FORK', 'printf', "\\033%%G");
}
    else {
        run('out', 'FORK', 'printf', "\\033%%@");
    }
}
if (("$do_term")) {
    $STTY = q{};
    if (!("$SCREEN_WIDTH" eq q{})) {
                $STTY = "$STTY cols $SCREEN_WIDTH";
    }
    if (!("$SCREEN_HEIGHT" eq q{})) {
                $STTY = "$STTY rows $SCREEN_HEIGHT";
    }
if (("$STTY")) {
        run('in', q{}, 'stty', $STTY);
    }
}
if ("$do_term" =~ /^linux.*$/msx) {
        $SETTERM = q{};
    if ("$BEEP" ne q{}) {
if ("$BEEP" =~ /^default$/msx) {
        } elsif ("$BEEP" =~ /^standard$/msx) {
                        $SETTERM = "\\033[11;100]\\033[10;750]";
        } elsif ("$BEEP" =~ /^short$/msx) {
                        $SETTERM = "\\033[11;40]\\033[10;750]";
        } elsif ("$BEEP" =~ /^shortest$/msx) {
                        $SETTERM = "\\033[11;9]\\033[10;750]";
        } elsif ("$BEEP" =~ /^polite$/msx) {
                        $SETTERM = "\\033[11;9]\\033[10;130]";
        } elsif ("$BEEP" =~ /^attention$/msx) {
                        $SETTERM = "\\033[11;600]\\033[10;130]";
        } elsif ("$BEEP" =~ /^annoying$/msx) {
                        $SETTERM = "\\033[11;1000]\\033[10;550]";
        } elsif ("$BEEP" =~ /^off$/msx) {
                        $SETTERM = "\\033[11;0]";
        } elsif (1) {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = 'setupcon:' . q{ } . 'Unrecognised' . q{ } . 'setting' . q{ } . 'BEEP' . q{ } . q{=} . q{ } . $BEEP;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
        }
if (("$SETTERM")) {
            run('out', 'FORK', 'printf', "$SETTERM");
        }
    }
}
if ("$do_kbd" eq linux) {
if (((-x '/sbin/sysctl') && (-r '/etc/sysctl.conf'))) {
if (!(        # Original bash: grep -v '^#' /etc/sysctl.conf | grep -q keycodes ;
{
            my $output_49 = q{};
            my $output_printed_49;
            my $pipeline_success_49 = 1;
                        my $grep_result_49_0;
            my @grep_lines_49_0 = ();
            my @grep_filenames_49_0 = ();
            if (-e "/etc/sysctl.conf") {
            open my $fh, '<', "/etc/sysctl.conf" or croak "Cannot open file: $ERRNO";
            while (my $line = <$fh>) {
            chomp $line;
            push @grep_lines_49_0, $line;
            push @grep_filenames_49_0, "/etc/sysctl.conf";
            }
            close $fh
            or croak "Close failed: $OS_ERROR";
            }
            else { print {*STDERR} "grep: /etc/sysctl.conf: No such file or directory\n"; }
            my @grep_filtered_49_0 = grep { !/^\#/msx } @grep_lines_49_0;
            $grep_result_49_0 = join "\n", @grep_filtered_49_0;
            if (!($grep_result_49_0 =~ m{\n\z}msx || $grep_result_49_0 eq q{})) {
            $grep_result_49_0 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_49_0 > 0 ? 0 : 1;
            $output_49 = $grep_result_49_0;
            $output_49 = $grep_result_49_0;

                        my $grep_result_49_1;
            my @grep_lines_49_1 = split /\n/msx, $output_49;
            my @grep_filtered_49_1 = grep { /keycodes/msx } @grep_lines_49_1;
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
            })) {
            # Original bash: grep keycodes /etc/sysctl.conf | grep -v "^#" \
{
                my $output_50 = q{};
                my $output_printed_50;
                my $pipeline_success_50 = 1;
                                my $grep_result_50_0;
                my @grep_lines_50_0 = ();
                my @grep_filenames_50_0 = ();
                if (-e "/etc/sysctl.conf") {
                open my $fh, '<', "/etc/sysctl.conf" or croak "Cannot open file: $ERRNO";
                while (my $line = <$fh>) {
                chomp $line;
                push @grep_lines_50_0, $line;
                push @grep_filenames_50_0, "/etc/sysctl.conf";
                }
                close $fh
                or croak "Close failed: $OS_ERROR";
                }
                else { print {*STDERR} "grep: /etc/sysctl.conf: No such file or directory\n"; }
                my @grep_filtered_50_0 = grep { /keycodes/msx } @grep_lines_50_0;
                $grep_result_50_0 = join "\n", @grep_filtered_50_0;
                if (!($grep_result_50_0 =~ m{\n\z}msx || $grep_result_50_0 eq q{})) {
                $grep_result_50_0 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_50_0 > 0 ? 0 : 1;
                $output_50 = $grep_result_50_0;
                $output_50 = $grep_result_50_0;

                                my $grep_result_50_1;
                my @grep_lines_50_1 = split /\n/msx, $output_50;
                my @grep_filtered_50_1 = grep { !/^\#/msx } @grep_lines_50_1;
                $grep_result_50_1 = join "\n", @grep_filtered_50_1;
                if (!($grep_result_50_1 =~ m{\n\z}msx || $grep_result_50_1 eq q{})) {
                $grep_result_50_1 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_50_1 > 0 ? 0 : 1;
                $output_50 = $grep_result_50_1;
                $output_50 = $grep_result_50_1;

                                my @lines = split /\n/msx, $output_50;
                my $result_50_2 = q{};
                for my $line (@lines) {
                chomp $line;
                my $L = $line;
                do {
                local *STDERR;
                open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                my $tmp_redirect_51 = q{};
                my $cmd_54 = '/sbin/sysctl';
                my ($in_53, $out_53);
                my $pid_53 = open3($in_53, $out_53, '>&STDERR', $cmd_54, '-w');
                print {$in_53} $output_50;
                close $in_53 or croak 'Close failed: $OS_ERROR';
                $tmp_redirect_51 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_53> };
                close $out_53 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_53, 0;
                $tmp_redirect_51;
                };
                if ($CHILD_ERROR != 0) {
                1;
                }
                }
                $output_50 = $result_50_2;
                if ($output_50 ne q{} && !defined $output_printed_50) {
                    print $output_50;
                    if (!($output_50 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_50 ) { $main_exit_code = 1; }
                }
        }
    }
}
if ("$do_kbd" eq linux) {
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'kbd_mode';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
if (("$unicode")) {
            run('in', q{}, 'kbd_mode', '-u');
}
        else {
            run('in', q{}, 'kbd_mode', '-a');
        }
}
    else {
        report('kbd_mode', 'is', 'not', 'accessible.', 'Unable', 'to', 'setup', 'unicode/non-unicode', 'keyboard', 'mode.');
    }
}
if ((("$KMAP" eq q{} && (-f "$cached")) && (("$CONFIG" -ot "$cached") && ("$CONFIG2" -ot "$cached")))) {
    $KMAP = "$cached";
}
if (("$KMAP")) {
if ("$do_kbd" =~ /^linux$/msx) {
                run('plain', 'NONE', 'loadkeys', "$KMAP");
    } elsif ("$do_kbd" =~ /^freebsd$/msx) {
                run('in', q{}, 'kbdcontrol', '-l', "$KMAP");
    }
}
else {
        tempfile();
    if ($CHILD_ERROR != 0) {
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print 'setupcon:' . q{ } . 'Can' . q{ } . 'not' . q{ } . 'create' . q{ } . 'temporary' . q{ } . 'file' . "\n";
                $CHILD_ERROR = 0;
            };
exit 1;
    }
if ("$do_kbd" =~ /^linux$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $TMPFILE
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
                run('plain', 'NONE', 'loadkeys', $TMPFILE);
    } elsif ("$do_kbd" =~ /^freebsd$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $TMPFILE
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
                run('in', q{}, 'kbdcontrol', '-l', $TMPFILE);
                run('in', q{}, 'kbdcontrol', '-f', '70', (do { my $_chomp_temp = sprintf('033[3~');
; chomp $_chomp_temp; $_chomp_temp; }));
    }
}
if (("$do_printonly")) {

sub fileargs {
        my $arg;
        my $args;
        my $f;
if (("$1")) {
            # Original bash: printf "%s" "$1" | {
{
                my $output_57 = q{};
                my $output_printed_57;
                my $pipeline_success_57 = 1;
                                my $output_57;
                {
                local *STDOUT;
                open STDOUT, '>', \$output_57 or die "Cannot redirect STDOUT";
                printf('%s', "$_[0]");
                }

                                my @_pcmd_59 = ('bash', '-c', "echo \"${output_57}\" | : \"Complex command cannot be converted to shell command\"");
                my ($in_58);
                my $pid_58 = open3($in_58, $out_58, '>&STDERR', @_pcmd_59);
                close $in_58 or croak 'Close failed: $OS_ERROR';
                my $temp_result;
                $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_58> };
                $output_57 = $temp_result;
                close $out_58 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_58, 0;
                if ($output_57 ne q{} && !defined $output_printed_57) {
                    print $output_57;
                    if (!($output_57 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_57 ) { $main_exit_code = 1; }
                }
        }
        return;
}
    # Original bash: printf "%s" "$SETUP" |
    my $output_60 = q{};
    my $output_printed_60;
    my $output_61 = q{};
    while (my $line = <>) {
        chomp $line;
        # printf doesn't support line-by-line processing
        my $L = $line;
            # printf doesn't support line-by-line processing
            # fileargs doesn't support line-by-line processing
                    print $line . "\n";
    }
    $output_61;
}
if (("$setupdir")) {

sub fileargs {
        my $arg;
        my $args;
        my $f;
if (("$1")) {
            # Original bash: printf "%s" "$1" | {
{
                my $output_62 = q{};
                my $output_printed_62;
                my $pipeline_success_62 = 1;
                                my $output_62;
                {
                local *STDOUT;
                open STDOUT, '>', \$output_62 or die "Cannot redirect STDOUT";
                printf('%s', "$_[0]");
                }

                                my @_pcmd_64 = ('bash', '-c', "echo \"${output_62}\" | : \"Complex command cannot be converted to shell command\"");
                my ($in_63);
                my $pid_63 = open3($in_63, $out_63, '>&STDERR', @_pcmd_64);
                close $in_63 or croak 'Close failed: $OS_ERROR';
                my $temp_result;
                $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_63> };
                $output_62 = $temp_result;
                close $out_63 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_63, 0;
                if ($output_62 ne q{} && !defined $output_printed_62) {
                    print $output_62;
                    if (!($output_62 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_62 ) { $main_exit_code = 1; }
                }
        }
        return;
}
    use File::Path qw(make_path);
    my $err;
    if ( !-d "$setupdir" ) {
        make_path( "$setupdir", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . "$setupdir" . ": $err->[0]\n";
        }
    }
    if ( !-d '/bin' ) {
        make_path( '/bin', { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . '/bin' . ": $err->[0]\n";
        }
    }
    use File::Path qw(make_path);
    if ( !-d "$setupdir" ) {
        make_path( "$setupdir", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . "$setupdir" . ": $err->[0]\n";
        }
    }
    if ( !-d '/etc/console-setup' ) {
        make_path( '/etc/console-setup', { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . '/etc/console-setup' . ": $err->[0]\n";
        }
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$setupdir"
      or die "Cannot open file: $OS_ERROR\n";
        print '#!/bin/sh' . q{ } . '/bin/setupcon' . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$setupdir"
      or die "Cannot open file: $OS_ERROR\n";
        print '# A micro-version of setupcon with static configuration.' . q{ } . '/bin/setupcon' . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
chmod(oct('+x'), ("$setupdir", '/bin/setupcon')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        tempfile();
    if ($CHILD_ERROR != 0) {
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print 'setupcon:' . q{ } . 'Can' . q{ } . 'not' . q{ } . 'create' . q{ } . 'temporary' . q{ } . 'file' . "\n";
                $CHILD_ERROR = 0;
            };
exit 1;
    }
    # Original bash: printf "%s" "$SETUP" |
{
        my $output_68 = q{};
        my $output_printed_68;
        my $pipeline_success_68 = 1;
                my $output_68;
        {
        local *STDOUT;
        open STDOUT, '>', \$output_68 or die "Cannot redirect STDOUT";
        printf('%s', "$SETUP");
        }

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$setupdir"
        or die "Cannot open file: $OS_ERROR\n";
        my $cmd;
        my $args;
        while ( my $L = <> ) {
        chomp $L;
        my @_fields = split /\s+/msx, $L;
        $cmd = $_fields[0] // q{};
        $args = $_fields[1] // q{};
        do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $TMPFILE
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp_redirect_69 = q{};
        my $_wa0 = "$cmd";
        my $which_prog = q{which};
        my $_which_out = qx{$which_prog $_wa0};
        print $_which_out;
        $CHILD_ERROR = $? >> 8;
        $tmp_redirect_69;
        $output_printed_68 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ($CHILD_ERROR != 0) {
        1;
        }
        printf('%s ', "$cmd");
        fileargs("$args");
        print "\n";
        $CHILD_ERROR = 0;
        }
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_68 ) { $main_exit_code = 1; }
        }
    $main_exit_code = system('bash', '/bin/setupcon') >> 8;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$setupdir"
      or die "Cannot open file: $OS_ERROR\n";
        print 'mkdir /run/console-setup' . q{ } . '/bin/setupcon' . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$setupdir"
      or die "Cannot open file: $OS_ERROR\n";
        print '>/run/console-setup/keymap_loaded' . q{ } . '/bin/setupcon' . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$setupdir"
      or die "Cannot open file: $OS_ERROR\n";
        print 'exit' . q{ } . q{0} . q{ } . '/bin/setupcon' . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    # Original bash: sort $TMPFILE | uniq | grep -v 'printf$' >"$setupdir"/morefiles
{
        my $output_73 = q{};
        my $output_printed_73;
        my $pipeline_success_73 = 1;
                my @sort_lines_73_0 = split /\n/msx, $;
        my @sort_sorted_73_0 = sort @sort_lines_73_0;
        $output_73 = join "\n", @sort_sorted_73_0;
        if ($output_73 ne q{} && !($output_73 =~ m{\n\z}msx)) {
        $output_73 .= "\n";
        }
        $ = $output_73;

                my @uniq_lines_73_1 = split /\n/msx, $output_73;
        @uniq_lines_73_1 = grep { $_ ne q{} } @uniq_lines_73_1; # Filter out empty lines
        my %uniq_seen_73_1;
        my @uniq_result_73_1;
        foreach my $line (@uniq_lines_73_1) {
        if (!$uniq_seen_73_1{$line}++) { push @uniq_result_73_1, $line; }
        }
        my $output_73_1 = join "\n", @uniq_result_73_1;
        if ($output_73_1 ne q{} && !($output_73_1 =~ m{\n\z}msx)) {
        $output_73_1 .= "\n";
        }
        $output_73 = $output_73_1;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$setupdir"
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_74 = q{};
        my $grep_result_75;
        my @grep_lines_75 = ();
        my @grep_filenames_75 = ();
        if (-e "/morefiles") {
        open my $fh, '<', "/morefiles" or croak "Cannot open file: $ERRNO";
        while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_75, $line;
        push @grep_filenames_75, "/morefiles";
        }
        close $fh
        or croak "Close failed: $OS_ERROR";
        }
        else { print {*STDERR} "grep: /morefiles: No such file or directory\n"; }
        my @grep_filtered_75 = grep { !/printf$/msx } @grep_lines_75;
        $grep_result_75 = join "\n", @grep_filtered_75;
        if (!($grep_result_75 =~ m{\n\z}msx || $grep_result_75 eq q{})) {
        $grep_result_75 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_75 > 0 ? 0 : 1;
        $tmp_redirect_74 = $grep_result_75;
        $tmp_redirect_74;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_73; }
        $output_printed_73 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_73 ) { $main_exit_code = 1; }
        }
}
exit 0;

exit $main_exit_code;
