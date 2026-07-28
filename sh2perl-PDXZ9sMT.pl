#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

my $main_exit_code = 0;
my $output         = q{};
our $CHILD_ERROR;

my $FONT_MAP;
my $CONFIGFILE;
my $fontface;
my $CONSOLE_MAP;
my $RET;
my $FONT;

$__set_e = 1;
$main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;
my $CONFIGDIR = '/etc/console-setup';
$CONFIGFILE = '/etc/default/console-setup';
if (((!-L /usr/share/doc/console-setup) && (-d '/usr/share/doc/console-setup'))) {
if (!(    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
rmdir ('/usr/share/doc/console-setup') or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    };)) {
symlink q{f}, '/usr/share/doc/console-setup' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
}
my $fontsize;
my $charmap;
my $consoles;
my $codeset;
if (("$1" eq "configure" && (!-L "$CONFIGFILE"))) {
    $main_exit_code = system('db_get', 'console-setup/codesetcode') >> 8;
    $codeset = "$RET";
    $main_exit_code = system('db_get', 'console-setup/fontface47') >> 8;
    $fontface = "$RET";
    $main_exit_code = system('db_metaget', "console-setup/use_" . "sys" . "tem" . "_font", 'description') >> 8;
if ("$fontface" eq "$RET") {
        $fontface = q{};
    }
    $main_exit_code = system('db_metaget', 'console-setup/guess_font', 'description') >> 8;
if ("$fontface" eq "$RET") {
        $fontface = 'guess';
    }
    $main_exit_code = system('db_get', 'console-setup/fontsize') >> 8;
    $fontsize = "$RET";
if ("$fontface" eq q{}) {
        $fontsize = q{};
    }
    $main_exit_code = system('db_get', 'console-setup/charmap47') >> 8;
    $charmap = (defined (defined ${RET} && ${RET} ne q{} ? ${RET} : 'UTF-8') && (defined ${RET} && ${RET} ne q{} ? ${RET} : 'UTF-8') ne q{} ? (defined ${RET} && ${RET} ne q{} ? ${RET} : 'UTF-8') : 'UTF-8');
if ((!-e $CONFIGFILE)) {
if (do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; } =~ /^.*Linux.*$/msx) {
                        $consoles = '/dev/tty[1-6]';
        } elsif (do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; } =~ /^.*FreeBSD.*$/msx) {
                        $consoles = '/dev/ttyv[0-5]';
        }
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $CONFIGFILE
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
my @sed_lines_2 = split /\n/, $;
my @sed_result_2;
foreach my $line (@sed_lines_2) {
chomp $line;
push @sed_result_2, $line;
}
$ = join "\n", @sed_result_2;

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
        $main_exit_code = system('.', $CONFIGFILE) >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
;
    $CONSOLE_MAP = (defined ${CONSOLE_MAP} && ${CONSOLE_MAP} ne q{} ? ${CONSOLE_MAP} : '$ACM');
if ((!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
my $grep_result_5;
my @grep_lines_5 = ();
my @grep_filtered_5 = grep { /^\ *XKBLAYOUT=/msx } @grep_lines_5;
$grep_result_5 = join "\n", @grep_filtered_5;
        if (!($grep_result_5 =~ m{\n\z} || $grep_result_5 eq q{})) {
            $grep_result_5 .= "\n";
        }
print $grep_result_5;
$CHILD_ERROR = scalar @grep_filtered_5 > 0 ? 0 : 1;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }) || !(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
!(my $grep_result_6;
my @grep_lines_6 = ();
my @grep_filtered_6 = grep { /^\ *CHARMAP=/msx } @grep_lines_6;
$grep_result_6 = join "\n", @grep_filtered_6;
        if (!($grep_result_6 =~ m{\n\z} || $grep_result_6 eq q{})) {
            $grep_result_6 .= "\n";
        }
print $grep_result_6;
$CHILD_ERROR = scalar @grep_filtered_6 > 0 ? 0 : 1;)
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }))) {
        use File::Copy qw(copy);
        if ( -e $CONFIGFILE ) {
            if ( -d "$CONFIGFILE.tmp" ) {
                require File::Copy; File::Copy::copy($CONFIGFILE, "$CONFIGFILE.tmp" . '/' . ($CONFIGFILE =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy($CONFIGFILE, "$CONFIGFILE.tmp");
            }
        } else {
            croak "cp: cannot stat '-a': No such file or directory\n";
        }
;
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$CONFIGFILE.tmp"
      or die "Cannot access file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', '/usr/share/console-setup/console-setup' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/usr/share/console-setup/console-setup' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
open my $fh_cat, '>', "\"\$CONFIGFILE.tmp\"" or croak "Cannot access file: $OS_ERROR\n";
print {$fh_cat} "
######################################################################
# You can remove the lines that follow.  They contain the contents of
# this file before version 1.47 of console-setup.
######################################################################
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
open STDIN, '<', $CONFIGFILE or croak "Cannot read file: $OS_ERROR\n";
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$CONFIGFILE.tmp"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
my @sed_lines_9 = split /\n/, $;
my @sed_result_9;
foreach my $line (@sed_lines_9) {
chomp $line;
$line =~ s/^/# /gmsx;
push @sed_result_9, $line;
}
$ = join "\n", @sed_result_9;

            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        my $err;
        my $force = 1;
        if ( -e "$CONFIGFILE.tmp" ) {
            my $dest = $CONFIGFILE;
            if ( -e $dest && -d $dest ) {
                my $source_name = "$CONFIGFILE.tmp";
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
            if ( File::Copy::move( "$CONFIGFILE.tmp", $dest ) ) {
            } else {
                croak
  "mv: cannot move "$CONFIGFILE.tmp" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "$CONFIGFILE.tmp": No such file or directory\n";
        }
;
    }
    use File::Copy qw(copy);
    if ( -e $CONFIGFILE ) {
        if ( -d "$CONFIGFILE.tmp" ) {
            require File::Copy; File::Copy::copy($CONFIGFILE, "$CONFIGFILE.tmp" . '/' . ($CONFIGFILE =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy($CONFIGFILE, "$CONFIGFILE.tmp");
        }
    } else {
        croak "cp: cannot stat '-a': No such file or directory\n";
    }
;
    my $var;
    for my $var ('ACTIVE_CONSOLES', 'CHARMAP', 'CODESET', 'FONTFACE', 'FONTSIZE') {
if (        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
my $grep_result_12;
my @grep_lines_12 = ();
my @grep_filtered_12 = grep { /^\ *"\ .\ ${var}\ .\ "=/msx } @grep_lines_12;
$grep_result_12 = join "\n", @grep_filtered_12;
            if (!($grep_result_12 =~ m{\n\z} || $grep_result_12 eq q{})) {
                $grep_result_12 .= "\n";
            }
print $grep_result_12;
$CHILD_ERROR = scalar @grep_filtered_12 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        }) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $CONFIGFILE
      or die "Cannot access file: $OS_ERROR\n";
                my $tmp = do {
                say ${var} . "=";
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
    }
;
if ((("$FONT") && !(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
!(my $grep_result_13;
my @grep_lines_13 = ();
my @grep_filtered_13 = grep { /^\ *FONT=/msx } @grep_lines_13;
$grep_result_13 = join "\n", @grep_filtered_13;
        if (!($grep_result_13 =~ m{\n\z} || $grep_result_13 eq q{})) {
            $grep_result_13 .= "\n";
        }
print $grep_result_13;
$CHILD_ERROR = scalar @grep_filtered_13 > 0 ? 0 : 1;)
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }))) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $CONFIGFILE
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            say "FONT=";
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if ((("$FONT_MAP") && !(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
!(my $grep_result_14;
my @grep_lines_14 = ();
my @grep_filtered_14 = grep { /^\ *FONT_MAP=/msx } @grep_lines_14;
$grep_result_14 = join "\n", @grep_filtered_14;
        if (!($grep_result_14 =~ m{\n\z} || $grep_result_14 eq q{})) {
            $grep_result_14 .= "\n";
        }
print $grep_result_14;
$CHILD_ERROR = scalar @grep_filtered_14 > 0 ? 0 : 1;)
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }))) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $CONFIGFILE
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            say "FONT_MAP=";
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if (((("$CONSOLE_MAP") && !(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
!(my $grep_result_15;
my @grep_lines_15 = ();
my @grep_filtered_15 = grep { /^\ *CONSOLE_MAP=/msx } @grep_lines_15;
$grep_result_15 = join "\n", @grep_filtered_15;
        if (!($grep_result_15 =~ m{\n\z} || $grep_result_15 eq q{})) {
            $grep_result_15 .= "\n";
        }
print $grep_result_15;
$CHILD_ERROR = scalar @grep_filtered_15 > 0 ? 0 : 1;)
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) && !(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
!(my $grep_result_16;
my @grep_lines_16 = ();
my @grep_filtered_16 = grep { /^\ *ACM=/msx } @grep_lines_16;
$grep_result_16 = join "\n", @grep_filtered_16;
        if (!($grep_result_16 =~ m{\n\z} || $grep_result_16 eq q{})) {
            $grep_result_16 .= "\n";
        }
print $grep_result_16;
$CHILD_ERROR = scalar @grep_filtered_16 > 0 ? 0 : 1;)
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }))) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $CONFIGFILE
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            say "CONSOLE_MAP=";
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
open STDIN, '<', $CONFIGFILE or croak "Cannot read file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$CONFIGFILE.tmp"
      or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
my @sed_lines_17 = split /\n/, $;
my @sed_result_17;
foreach my $line (@sed_lines_17) {
chomp $line;
push @sed_result_17, $line;
}
$ = join "\n", @sed_result_17;

        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ( -e "$CONFIGFILE.tmp" ) {
        my $dest = $CONFIGFILE;
        if ( -e $dest && -d $dest ) {
            my $source_name = "$CONFIGFILE.tmp";
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
        if ( File::Copy::move( "$CONFIGFILE.tmp", $dest ) ) {
        } else {
            croak
  "mv: cannot move "$CONFIGFILE.tmp" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "$CONFIGFILE.tmp": No such file or directory\n";
    }
    $main_exit_code = system('db_set', 'console-setup/store_defaults_in_debconf_db', 'true') >> 8;
}
$main_exit_code = system('bash', 'db_stop') >> 8;
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
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
if ((!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('type', 'plymouth') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
}) && !(system('plymouth', '--ping') >> 8))) {
    $main_exit_code = system('bash', ':') >> 8;
}
else {
    if ((-d '/lib/debian-installer')) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('setupcon', '--force') >> 8;
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
    else {
if (        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('bash', 'setupcon') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        }) {
print "Your console font configuration will be updated the next time your system
boots. If you want to update it now, run 'setupcon' from a virtual console.
";
        }
    }
}
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
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
};)) {
    $main_exit_code = system('update-initramfs', '-u') >> 8;
}
exit 0;

exit $main_exit_code;
