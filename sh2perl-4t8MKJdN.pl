#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy move);
use POSIX qw(time);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $SOURCE_DATE_EPOCH;
my @SOURCE_DATE_EPOCH;
my %SOURCE_DATE_EPOCH;
my $version;
my @version;
my %version;
my $MODULESDIR;
my @MODULESDIR;
my %MODULESDIR;
my $TMPDIR;
my @TMPDIR;
my %TMPDIR;
my $i;
my @i;
my %i;
my $BUSYBOXDIR;
my @BUSYBOXDIR;
my %BUSYBOXDIR;
my $x;
my @x;
my %x;
my $DESTDIR;
my @DESTDIR;
my %DESTDIR;
my $CONFDIR;
my @CONFDIR;
my %CONFDIR;
my $outfile;
my @outfile;
my %outfile;
my $b;
my @b;
my %b;
my $UMASK;
my @UMASK;
my %UMASK;
my $option;
my @option;
my %option;
my $ROOT;
my @ROOT;
my %ROOT;
my $compress;
my @compress;
my %compress;
my $verbose;
my @verbose;
my %verbose;
my $BUSYBOX;
my @BUSYBOX;
my %BUSYBOX;
my $compresslevel;
my @compresslevel;
my %compresslevel;

my $MAGIC_22  = 22;
my $MAGIC_755 = 755;

$main_exit_code = system('umask', '0022') >> 8;
$ENV{PATH} = '/usr/bin:/sbin:/bin';
my $keep;
my @keep;
my %keep;
$keep = "n";
$CONFDIR = "/etc/initramfs-tools";
$verbose = "n";
$BUSYBOXDIR = q{};
$ENV{BUSYBOXDIR} = $BUSYBOXDIR;

sub usage {
print "
Usage: mkinitramfs [option]... -o outfile [version]

Options:
  -c compress\tOverride COMPRESS setting in initramfs.conf.
  -d confdir\tSpecify an alternative configuration directory.
  -l level\tOverride COMPRESSLEVEL setting in initramfs.conf.
  -k\t\tKeep temporary directory used to make the image.
  -o outfile\tWrite to outfile.
  -r root\tOverride ROOT setting in initramfs.conf.

See mkinitramfs(8) for further details.

";
    return;
}

sub usage_error {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        usage();
    };
exit 2;
    return;
}
my $OPTIONS;
my @OPTIONS;
my %OPTIONS;
$OPTIONS = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'getopt', '-o', 'c:d:hl:ko:r:v', '--long', 'help', '-n', "$PROGRAM_NAME", '--', "@ARGV");
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
if ($CHILD_ERROR != 0) {
        usage_error();
}
do { my $eval_input = "set" . "--" . $OPTIONS; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
while ( 1 ) {
if ("$_[0]" =~ /^-c$/msx) {
                $compress = "$_[1]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-d$/msx) {
                $CONFDIR = "$_[1]";
        # Builtin command 'shift' not implemented
        if ((!-d "${CONFDIR}")) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print $_[0] . ": " . ${CONFDIR} . ": Not a directory";
if ( !( ($_[0] . ": " . ${CONFDIR} . ": Not a directory") =~ m{\n\z}msx ) ) { print "\n"; }
            };
exit 1;
        }
    } elsif ("$_[0]" =~ /^-h$/msx or "$_[0]" =~ /^--help$/msx) {
                usage();
        exit 0;
    } elsif ("$_[0]" =~ /^-l$/msx) {
                $compresslevel = "$_[1]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-o$/msx) {
                $outfile = "$_[1]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-k$/msx) {
                $keep = "y";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-r$/msx) {
                $ROOT = "$_[1]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-v$/msx) {
                $verbose = "y";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--$/msx) {
        # Builtin command 'shift' not implemented
        last;    } elsif (1) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "Internal error!\n";
        };
        exit 1;
    }
}
$main_exit_code = system('.', '/usr/share/initramfs-tools/scripts/functions') >> 8;
$main_exit_code = system('.', '/usr/share/initramfs-tools/hook-functions') >> 8;
# set -a not implemented
$main_exit_code = system('.', ${CONFDIR} . "/initramfs.conf") >> 8;
my $EXTRA_CONF;
my @EXTRA_CONF;
my %EXTRA_CONF;
$EXTRA_CONF = q{};

sub maybe_add_conf {
    my ($file) = @_;
if (((-e "$1") && !(    my $output_2 = q{};
    my $output_printed_2;
    my $output_3 = q{};
    while (my $line = <>) {
        chomp $line;
        # basename doesn't support line-by-line processing
                if (!($line =~ /^[[:alnum:]][[:alnum:][.]_-]*$/msx)) {
            next;
        }
                if (!($line =~ /[.]dpkg-.*$/msx)) {
            next;
        }
        print $line . "\n";
    }
    $output_3))) {
if ((-d "$1")) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "W: $_[0] is a directory instead of file";
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
        else {
            $EXTRA_CONF = ${EXTRA_CONF} . " $_[0]";
            $main_exit_code = system('.', "$_[0]") >> 8;
        }
    }
    return;
}
for my $i ('/usr/share/initramfs-tools/conf.d/*') {
if (!(!((-e "${CONFDIR}"/conf.d/"$(basename "${i}")")))) {
        maybe_add_conf(${i});
    }
}
for my $i (${CONFDIR}, '/conf.d/*') {
    maybe_add_conf(${i});
}
$i = '/conf.d/*';
for my $i ('/usr/share/initramfs-tools/conf-hooks.d/*') {
if ((-d "${i}")) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "W: " . ${i} . " is a directory instead of file.";
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
    else {
        if ((-e "${i}")) {
            $main_exit_code = system('.', ${i}) >> 8;
        }
    }
}
# set +a not implemented
if (("${BUSYBOX}" eq "y" && "${BUSYBOXDIR}" eq q{})) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $main_exit_code = system('bash', 'E: busybox-initramfs, version 1:1.30.1-4ubuntu5~ or later, is required but not installed') >> 8;
exit 1;
}
if ("${UMASK:-}" ne q{}) {
    $main_exit_code = system('umask', ${UMASK}) >> 8;
}
if ("${outfile}" eq q{}) {
    usage_error();
}
if ( -e "$outfile" ) {
    my $current_time = time;
    utime $current_time, $current_time, "$outfile";
}
else {
    if ( open my $fh, '>', "$outfile" ) {
        close $fh or croak "Close failed: $ERRNO";
    }
    else {
        croak "touch: cannot create ", "$outfile",
          ": $ERRNO\n";
    }
}
$outfile = (do { my $_chomp_temp = do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'readlink', '-f', "$outfile");
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
}; chomp $_chomp_temp; $_chomp_temp; });
if ((${#} != 1)) {
    $version = (do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; }; chomp $_chomp_temp; $_chomp_temp; });
}
else {
    $version = $_[0];
}
if (${version} =~ /^/lib/modules/.*/\[!/\].*$/msx) {
} elsif (${version} =~ /^/lib/modules/\[!/\].*$/msx) {
        $version = (${version} =~ s/^/lib/modules///r =~ s/^/lib/modules///r);
        $version = ( ( dirname(($ENV{version%} // q{})) ) =~ s|/[^/]*$||sr );
}
if (${version} =~ /^.*/.*$/msx) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "$ENV{PROG}: " . ${version} . " is not a valid kernel version";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    exit 2;
}
if ("${compress:-}" eq q{}) {
    $compress = $COMPRESS?;
}
delete $ENV{COMPRESS};
if (!(!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('command', '-v', ${compress}) >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "W: No " . ${compress} . " in " . ($ENV{PATH} // q{}) . ", using gzip";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    $compress = 'gzip';
}
if (${compress} =~ /^gzip$/msx) {
        my $kconfig_sym;
    my @kconfig_sym;
    my %kconfig_sym;
    $kconfig_sym = 'CONFIG_RD_GZIP';
} elsif (${compress} =~ /^bzip2$/msx) {
        $kconfig_sym = 'CONFIG_RD_BZIP2';
} elsif (${compress} =~ /^lzma$/msx) {
        $kconfig_sym = 'CONFIG_RD_LZMA';
} elsif (${compress} =~ /^xz$/msx) {
        $kconfig_sym = 'CONFIG_RD_XZ';
} elsif (${compress} =~ /^lzop$/msx) {
        $kconfig_sym = 'CONFIG_RD_LZO';
} elsif (${compress} =~ /^lz4$/msx) {
        $kconfig_sym = 'CONFIG_RD_LZ4';
} elsif (${compress} =~ /^zstd$/msx) {
        $kconfig_sym = 'CONFIG_RD_ZSTD';
}
if ((-e "/boot/config-${version}")) {
while ( !(my $grep_result_6;
my @grep_lines_6 = ();
my @grep_filtered_6 = grep { /^$kconfig_sym=y/msx } @grep_lines_6;
$grep_result_6 = join "\n", @grep_filtered_6;
    if (!($grep_result_6 =~ m{\n\z}msx || $grep_result_6 eq q{})) {
        $grep_result_6 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_6 > 0 ? 0 : 1;
$grep_result_6 = q{};) ) {
if ("${compress}" eq gzip) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "E: gzip compression ($kconfig_sym) not supported by kernel";
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
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "W: " . ${compress} . " compression ($kconfig_sym) not supported by kernel, using gzip";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        $compress = 'gzip';
        $kconfig_sym = 'CONFIG_RD_GZIP';
    }
}
else {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "W: Kernel configuration /boot/config-" . ${version} . " is missing," . q{ } . "cannot check for " . ${compress} . " compression support ($kconfig_sym)";
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
if ("${compresslevel:-}" eq q{}) {
    $compresslevel = (defined ($ENV{COMPRESSLEVEL} // q{}) && ($ENV{COMPRESSLEVEL} // q{}) ne q{} ? ($ENV{COMPRESSLEVEL} // q{}) : '');
}
if (${compress} =~ /^lz4$/msx) {
        $compresslevel = "-" . (defined (defined ${compresslevel} && ${compresslevel} ne q{} ? ${compresslevel} : '2') && (defined ${compresslevel} && ${compresslevel} ne q{} ? ${compresslevel} : '2') ne q{} ? (defined ${compresslevel} && ${compresslevel} ne q{} ? ${compresslevel} : '2') : '2');
} elsif (${compress} =~ /^zstd$/msx) {
        $compresslevel = "-" . (defined (defined ${compresslevel} && ${compresslevel} ne q{} ? ${compresslevel} : '1') && (defined ${compresslevel} && ${compresslevel} ne q{} ? ${compresslevel} : '1') ne q{} ? (defined ${compresslevel} && ${compresslevel} ne q{} ? ${compresslevel} : '1') : '1');
} elsif (1) {
        $compresslevel = (defined (defined ${compresslevel} && ${compresslevel} ne q{} ? ${compresslevel} : '-${compresslevel}') && (defined ${compresslevel} && ${compresslevel} ne q{} ? ${compresslevel} : '-${compresslevel}') ne q{} ? (defined ${compresslevel} && ${compresslevel} ne q{} ? ${compresslevel} : '-${compresslevel}') : '-${compresslevel}');
}
delete $ENV{COMPRESSLEVEL};
if (${compress} =~ /^gzip$/msx) {
    if ("${SOURCE_DATE_EPOCH}" ne q{}) {
        $compress = "gzip -n";
}
    else {
        if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('command', '-v', 'pigz') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $compress = 'pigz';
        }
    }
    if ("${compresslevel}" ne q{}) {
        $compress = ${compress} . " " . ${compresslevel};
    }
} elsif (${compress} =~ /^lz4$/msx) {
        $compress = "lz4 " . ${compresslevel} . " -l";
} elsif (${compress} =~ /^zstd$/msx) {
        $compress = "zstd -q " . ${compresslevel};
        if (do {
$main_exit_code = system('test', '-z', ${SOURCE_DATE_EPOCH}) >> 8;
        $CHILD_ERROR == 0
    }) {
                $compress = "$compress -T0";
    }
} elsif (${compress} =~ /^xz$/msx) {
        $compress = "xz " . ${compresslevel} . " --check=crc32";
        if (do {
$main_exit_code = system('test', '-z', ${SOURCE_DATE_EPOCH}) >> 8;
        $CHILD_ERROR == 0
    }) {
                $compress = "$compress --threads=0";
    }
} elsif (${compress} =~ /^bzip2$/msx or ${compress} =~ /^lzma$/msx or ${compress} =~ /^lzop$/msx) {
        $compress = ${compress} . " " . ${compresslevel};
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "W: Unknown compression command " . ${compress};
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
if ((-d "${outfile}")) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print ${outfile} . " is a directory";
if ( !( (${outfile} . " is a directory") =~ m{\n\z}msx ) ) { print "\n"; }
    };
exit 1;
}
$MODULESDIR = "/lib/modules/" . ${version};
if ((!-e "${MODULESDIR}")) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "W: missing " . ${MODULESDIR};
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "W: Ensure all necessary drivers are built into the linux image!\n";
    };
}
if ((!-e "${MODULESDIR}/modules.dep")) {
    $main_exit_code = system('depmod', ${version}) >> 8;
}
$DESTDIR = q{};
my $__TMPMAINFILES;
my @__TMPMAINFILES;
my %__TMPMAINFILES;
$__TMPMAINFILES = q{};
my $__TMPUNCOMPRESSEDFILES;
my @__TMPUNCOMPRESSEDFILES;
my %__TMPUNCOMPRESSEDFILES;
$__TMPUNCOMPRESSEDFILES = q{};
my $__TMPCPIOGZ;
my @__TMPCPIOGZ;
my %__TMPCPIOGZ;
$__TMPCPIOGZ = q{};
my $__TMPEARLYCPIO;
my @__TMPEARLYCPIO;
my %__TMPEARLYCPIO;
$__TMPEARLYCPIO = q{};

sub clean_on_exit {
if ("${keep}" eq "y") {
        print "Working files in " . (defined (defined ${DESTDIR} && ${DESTDIR} ne q{} ? ${DESTDIR} : '<not yet created>') && (defined ${DESTDIR} && ${DESTDIR} ne q{} ? ${DESTDIR} : '<not yet created>') ne q{} ? (defined ${DESTDIR} && ${DESTDIR} ne q{} ? ${DESTDIR} : '<not yet created>') : '<not yet created>') . "," . q{ } . "list of files for main initramfs in " . (defined (defined ${__TMPMAINFILES} && ${__TMPMAINFILES} ne q{} ? ${__TMPMAINFILES} : '<not yet created>') && (defined ${__TMPMAINFILES} && ${__TMPMAINFILES} ne q{} ? ${__TMPMAINFILES} : '<not yet created>') ne q{} ? (defined ${__TMPMAINFILES} && ${__TMPMAINFILES} ne q{} ? ${__TMPMAINFILES} : '<not yet created>') : '<not yet created>') . "," . q{ } . "list of files for uncompressed initramfs in " . (defined (defined ${__TMPUNCOMPRESSEDFILES} && ${__TMPUNCOMPRESSEDFILES} ne q{} ? ${__TMPUNCOMPRESSEDFILES} : '<not yet created>') && (defined ${__TMPUNCOMPRESSEDFILES} && ${__TMPUNCOMPRESSEDFILES} ne q{} ? ${__TMPUNCOMPRESSEDFILES} : '<not yet created>') ne q{} ? (defined ${__TMPUNCOMPRESSEDFILES} && ${__TMPUNCOMPRESSEDFILES} ne q{} ? ${__TMPUNCOMPRESSEDFILES} : '<not yet created>') : '<not yet created>') . "," . q{ } . "early initramfs in " . (defined (defined ${__TMPEARLYCPIO} && ${__TMPEARLYCPIO} ne q{} ? ${__TMPEARLYCPIO} : '<not yet created>') && (defined ${__TMPEARLYCPIO} && ${__TMPEARLYCPIO} ne q{} ? ${__TMPEARLYCPIO} : '<not yet created>') ne q{} ? (defined ${__TMPEARLYCPIO} && ${__TMPEARLYCPIO} ne q{} ? ${__TMPEARLYCPIO} : '<not yet created>') : '<not yet created>') . " and" . q{ } . "overlay in " . (defined (defined ${__TMPCPIOGZ} && ${__TMPCPIOGZ} ne q{} ? ${__TMPCPIOGZ} : '<not yet created>') && (defined ${__TMPCPIOGZ} && ${__TMPCPIOGZ} ne q{} ? ${__TMPCPIOGZ} : '<not yet created>') ne q{} ? (defined ${__TMPCPIOGZ} && ${__TMPCPIOGZ} ne q{} ? ${__TMPCPIOGZ} : '<not yet created>') : '<not yet created>') . "\n";
        $CHILD_ERROR = 0;
}
    else {
        my $path;
        for my $path (${DESTDIR}, ${__TMPMAINFILES}, ${__TMPUNCOMPRESSEDFILES}, ${__TMPCPIOGZ}, ${__TMPEARLYCPIO}) {
                        $main_exit_code = system('test', '-z', ${path}) >> 8;
            if ($CHILD_ERROR != 0) {
                if ( -e "${path}" ) {
                    if ( -d "${path}" ) {
                        my $err;
                        require File::Path;
                        File::Path::remove_tree("${path}", {error => \$err});
                        if (@{$err}) {
                            carp "rm: carping: could not remove ", ${path}, ": $err->[0]\n";
                        }
                        else {
                                                    }
                    }
                    else {
                        if ( unlink "${path}" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", ${path},
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
            }
        }
    }
    return;
}
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'clean_on_exit 2>&1'; print $end_out if $end_out ne q{}; }
$SIG{INT} = sub { qx'exit 1'; };
if (do {
if ("${TMPDIR}" ne q{}) {
    (!-w "${TMPDIR}")    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
    $CHILD_ERROR == 0
}) {
    delete $ENV{TMPDIR};
}
$DESTDIR = (do { my $_chomp_temp = do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'mktemp', '-d', (defined (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') && (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') ne q{} ? (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') : '/var/tmp') . "/mkinitramfs_XXXXXX");
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
}; chomp $_chomp_temp; $_chomp_temp; });
if ($CHILD_ERROR != 0) {
    exit 1;
}
chmod(oct('755'), (${DESTDIR})) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
$__TMPMAINFILES = (do { my $_chomp_temp = do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'mktemp', (defined (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') && (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') ne q{} ? (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') : '/var/tmp') . "/mkinitramfs-MAIN_files_XXXXXX");
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
}; chomp $_chomp_temp; $_chomp_temp; });
if ($CHILD_ERROR != 0) {
    exit 1;
}
$__TMPUNCOMPRESSEDFILES = (do { my $_chomp_temp = do {
    my ($in_10, $out_10);
    my $pid_10 = open3($in_10, $out_10, '>&STDERR', 'mktemp', (defined (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') && (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') ne q{} ? (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') : '/var/tmp') . "/mkinitramfs-UNCOMPRESSED_files_XXXXXX");
    close $in_10 or croak 'Close failed: $OS_ERROR';
    my $result_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
    close $out_10 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_10, 0;
    $result_10
}; chomp $_chomp_temp; $_chomp_temp; });
if ($CHILD_ERROR != 0) {
    exit 1;
}
$__TMPCPIOGZ = (do { my $_chomp_temp = do {
    my ($in_11, $out_11);
    my $pid_11 = open3($in_11, $out_11, '>&STDERR', 'mktemp', (defined (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') && (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') ne q{} ? (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') : '/var/tmp') . "/mkinitramfs-OL_XXXXXX");
    close $in_11 or croak 'Close failed: $OS_ERROR';
    my $result_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
    close $out_11 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_11, 0;
    $result_11
}; chomp $_chomp_temp; $_chomp_temp; });
if ($CHILD_ERROR != 0) {
    exit 1;
}
$__TMPEARLYCPIO = (do { my $_chomp_temp = do {
    my ($in_12, $out_12);
    my $pid_12 = open3($in_12, $out_12, '>&STDERR', 'mktemp', (defined (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') && (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') ne q{} ? (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/var/tmp') : '/var/tmp') . "/mkinitramfs-FW_XXXXXX");
    close $in_12 or croak 'Close failed: $OS_ERROR';
    my $result_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
    close $out_12 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_12, 0;
    $result_12
}; chomp $_chomp_temp; $_chomp_temp; });
if ($CHILD_ERROR != 0) {
    exit 1;
}
my $DPKG_ARCH;
my @DPKG_ARCH;
my %DPKG_ARCH;
$DPKG_ARCH = do {
    my ($in_13, $out_13);
    my $pid_13 = open3($in_13, $out_13, '>&STDERR', 'dpkg', '--print-architecture');
    close $in_13 or croak 'Close failed: $OS_ERROR';
    my $result_13 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
    close $out_13 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_13, 0;
    $result_13
};
$ENV{MODULESDIR} = $MODULESDIR;
$ENV{version} = $version;
$ENV{CONFDIR} = $CONFDIR;
$ENV{DESTDIR} = $DESTDIR;
$ENV{DPKG_ARCH} = $DPKG_ARCH;
$ENV{verbose} = $verbose;
$ENV{MODULES} = $MODULES;
$ENV{BUSYBOX} = $BUSYBOX;
$ENV{RESUME} = $RESUME;
$ENV{FSTYPE} = $FSTYPE;
$ENV{__TMPCPIOGZ} = $__TMPCPIOGZ;
$ENV{__TMPEARLYCPIO} = $__TMPEARLYCPIO;
my $d;
for my $d ('/bin', '/lib*', '/sbin') {
    use File::Path qw(make_path);
    my $err;
    if ( !-d ${DESTDIR} . "/usr" . ${d} ) {
        make_path( ${DESTDIR} . "/usr" . ${d}, { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ${DESTDIR} . "/usr" . ${d} . ": $err->[0]\n";
        }
    }
symlink "usr" . ${d}, ${DESTDIR} . ${d} or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
for my $d ('conf/conf.d', 'etc', 'run', 'scripts', $MODULESDIR) {
    use File::Path qw(make_path);
    if ( !-d ${DESTDIR} . "/" . ${d} ) {
        make_path( ${DESTDIR} . "/" . ${d}, { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ${DESTDIR} . "/" . ${d} . ": $err->[0]\n";
        }
    }
}
for my $x ('modules.builtin', 'modules.builtin.bin', 'modules.builtin.modinfo', 'modules.order') {
if ((-f "${MODULESDIR}/${x}")) {
        use File::Copy qw(copy);
        if ( -e ${MODULESDIR} . "/" . ${x} ) {
            if ( -d ${DESTDIR} . ${MODULESDIR} . "/" . ${x} ) {
                require File::Copy; File::Copy::copy(${MODULESDIR} . "/" . ${x}, ${DESTDIR} . ${MODULESDIR} . "/" . ${x} . '/' . (${MODULESDIR} . "/" . ${x} =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy(${MODULESDIR} . "/" . ${x}, ${DESTDIR} . ${MODULESDIR} . "/" . ${x});
            }
        } else {
            croak "cp: cannot stat '-p': No such file or directory\n";
        }
    }
}
$x = 'modules.order';
for my $x (${CONFDIR} . "/modules", '/usr/share/initramfs-tools/modules.d/*') {
if ((-f "${x}")) {
        $main_exit_code = system('add_modules_from_file', ${x}) >> 8;
    }
}
$x = '/usr/share/initramfs-tools/modules.d/*';
if (($ENV{MODULES} // q{}) =~ /^dep$/msx) {
        $main_exit_code = system('bash', 'dep_add_modules') >> 8;
} elsif (($ENV{MODULES} // q{}) =~ /^most$/msx) {
        $main_exit_code = system('bash', 'auto_add_modules') >> 8;
} elsif (($ENV{MODULES} // q{}) =~ /^netboot$/msx) {
        $main_exit_code = system('auto_add_modules', 'base') >> 8;
        $main_exit_code = system('auto_add_modules', 'net') >> 8;
} elsif (($ENV{MODULES} // q{}) =~ /^list$/msx) {
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "W: mkinitramfs: unsupported MODULES setting: " . ($ENV{MODULES} // q{}) . ".";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "W: mkinitramfs: Falling back to MODULES=most.\n";
    };
        $main_exit_code = system('bash', 'auto_add_modules') >> 8;
}
$main_exit_code = system('bash', 'add_builtin_firmware') >> 8;
use File::Copy qw(copy);
if ( -e '/usr/share/initramfs-tools/init' ) {
    if ( -d ${DESTDIR} . "/init" ) {
        require File::Copy; File::Copy::copy('/usr/share/initramfs-tools/init', ${DESTDIR} . "/init" . '/' . ('/usr/share/initramfs-tools/init' =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy('/usr/share/initramfs-tools/init', ${DESTDIR} . "/init");
    }
} else {
    croak "cp: cannot stat '-p': No such file or directory\n";
}
for my $b (do {
    my $left_result_19 = do { chdir('/usr/share/initramfs-tools/scripts/'); q{} };
;
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_19 = do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { if (-f $_) { push @find_results, $File::Find::name; } }, q{.});
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
};
        $left_result_19 . $right_result_19;
    } else {
        q{};
    }
}) {
    $option = do { my @_qx_cmd = (q(sed '/^OPTION=/!d;$d;s/^OPTION=//;s/[[:space:]]*$//' "/usr/share/initramfs-tools/scripts/${b}")); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        if (!("$option" eq q{})) {
        do { my $eval_input = "test" . "-n" . "\\\"\\${" . $option . "}\\\"" . "-a" . "\\\"\\${" . $option . "}\\\"" . "!" . "=" . "\\\"n\\\""; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    }
    if ($CHILD_ERROR != 0) {
        next;    }
    if (!((-d "${DESTDIR}/scripts/$(dirname "${b}")"))) {
                use File::Path qw(make_path);
        if ( !-d ${DESTDIR} . "/scripts/" . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname(${b}); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) ) {
            make_path( ${DESTDIR} . "/scripts/" . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname(${b}); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }), { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . ${DESTDIR} . "/scripts/" . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname(${b}); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) . ": $err->[0]\n";
            }
        }
    }
    use File::Copy qw(copy);
    if ( -e "/usr/share/initramfs-tools/scripts/" . ${b} ) {
        if ( -d ${DESTDIR} . "/scripts/" . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname(${b}); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) . "/" ) {
            require File::Copy; File::Copy::copy("/usr/share/initramfs-tools/scripts/" . ${b}, ${DESTDIR} . "/scripts/" . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname(${b}); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) . "/" . '/' . ("/usr/share/initramfs-tools/scripts/" . ${b} =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy("/usr/share/initramfs-tools/scripts/" . ${b}, ${DESTDIR} . "/scripts/" . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname(${b}); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) . "/");
        }
    } else {
        croak "cp: cannot stat '-p': No such file or directory\n";
    }
}
for my $b (do {
    my $left_result_22 = do { chdir(${CONFDIR} . "/scripts"); q{} };
;
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_22 = do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { my $maxdepth = 2; my $depth = ($File::Find::dir =~ tr/\///) + 1; next if $depth > $maxdepth; if (-f $_ && $_ =~ /^\...*$/msx) { push @find_results, $File::Find::name; } }, q{.});
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
};
        $left_result_22 . $right_result_22;
    } else {
        q{};
    }
}) {
    $option = do { my @_qx_cmd = (q(sed '/^OPTION=/!d;$d;s/^OPTION=//;s/[[:space:]]*$//' "${CONFDIR}/scripts/${b}")); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        if (!("$option" eq q{})) {
        do { my $eval_input = "test" . "-n" . "\\\"\\${" . $option . "}\\\"" . "-a" . "\\\"\\${" . $option . "}\\\"" . "!" . "=" . "\\\"n\\\""; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    }
    if ($CHILD_ERROR != 0) {
        next;    }
    if (!((-d "${DESTDIR}/scripts/$(dirname "${b}")"))) {
                use File::Path qw(make_path);
        if ( !-d ${DESTDIR} . "/scripts/" . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname(${b}); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) ) {
            make_path( ${DESTDIR} . "/scripts/" . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname(${b}); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }), { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . ${DESTDIR} . "/scripts/" . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname(${b}); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) . ": $err->[0]\n";
            }
        }
    }
    use File::Copy qw(copy);
    if ( -e ${CONFDIR} . "/scripts/" . ${b} ) {
        if ( -d ${DESTDIR} . "/scripts/" . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname(${b}); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) . "/" ) {
            require File::Copy; File::Copy::copy(${CONFDIR} . "/scripts/" . ${b}, ${DESTDIR} . "/scripts/" . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname(${b}); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) . "/" . '/' . (${CONFDIR} . "/scripts/" . ${b} =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy(${CONFDIR} . "/scripts/" . ${b}, ${DESTDIR} . "/scripts/" . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname(${b}); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) . "/");
        }
    } else {
        croak "cp: cannot stat '-p': No such file or directory\n";
    }
}
$b = .*$/msx) { push @find_results, $File::Find::name; } }, q{.});
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
};
        $left_result_22 . $right_result_22;
    } else {
        q{};
    }
};
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', ${DESTDIR} . "/conf/arch.conf"
      or die "Cannot open file: $OS_ERROR\n";
    do {
    my $__echo_line = "DPKG_ARCH=" . ${DPKG_ARCH};
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
use File::Copy qw(copy);
if ( -e ${CONFDIR} . "/initramfs.conf" ) {
    if ( -d ${DESTDIR} . "/conf" ) {
        require File::Copy; File::Copy::copy(${CONFDIR} . "/initramfs.conf", ${DESTDIR} . "/conf" . '/' . (${CONFDIR} . "/initramfs.conf" =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy(${CONFDIR} . "/initramfs.conf", ${DESTDIR} . "/conf");
    }
} else {
    croak "cp: cannot stat '-p': No such file or directory\n";
}
for my $i ($EXTRA_CONF) {
    $main_exit_code = system('copy_file', 'config', ${i}, '/conf/conf.d') >> 8;
}
if ("${ROOT:-}" ne q{}) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', ${DESTDIR} . "/conf/conf.d/root"
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "ROOT=" . ${ROOT};
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
if (!(!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('command', '-v', 'ldd') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "E: no ldd around - install libc-bin\n";
    };
exit 1;
}
if ( -e "${DESTDIR} . "/etc/fstab"" ) {
    my $current_time = time;
    utime $current_time, $current_time, "${DESTDIR} . "/etc/fstab"";
}
else {
    if ( open my $fh, '>', "${DESTDIR} . "/etc/fstab"" ) {
        close $fh or croak "Close failed: $ERRNO";
    }
    else {
        croak "touch: cannot create ", "${DESTDIR} . "/etc/fstab"",
          ": $ERRNO\n";
    }
}
symlink '/proc/mounts', ${DESTDIR} . "/etc/mtab" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
$main_exit_code = system('copy_exec', '/usr/lib/initramfs-tools/bin/gcc_s1-stub', '/usr/lib/initramfs-tools/bin/gcc_s1-stub') >> 8;
$main_exit_code = system('copy_exec', '/usr/lib/initramfs-tools/bin/wait-for-root', '/sbin') >> 8;
$main_exit_code = system('copy_exec', '/sbin/modprobe', '/sbin') >> 8;
$main_exit_code = system('copy_exec', '/sbin/rmmod', '/sbin') >> 8;
use File::Path qw(make_path);
if ( !-d ${DESTDIR} . "/etc/modprobe.d" ) {
    make_path( ${DESTDIR} . "/etc/modprobe.d", { error => \$err } );
    if ( @{$err} ) {
        croak "mkdir: cannot create directory " . ${DESTDIR} . "/etc/modprobe.d" . ": $err->[0]\n";
    }
}
if ( !-d ${DESTDIR} . "/lib/modprobe.d" ) {
    make_path( ${DESTDIR} . "/lib/modprobe.d", { error => \$err } );
    if ( @{$err} ) {
        croak "mkdir: cannot create directory " . ${DESTDIR} . "/lib/modprobe.d" . ": $err->[0]\n";
    }
}
my $file;
for my $file ('/etc/modprobe.d/*.conf', '/lib/modprobe.d/*.conf') {
if ((!(    $main_exit_code = system('test', '-e', "$file") >> 8) || !(    $main_exit_code = system('test', '-L', "$file") >> 8))) {
        $main_exit_code = system('copy_file', 'config', "$file") >> 8;
    }
}
$main_exit_code = system('run_scripts_optional', '/usr/share/initramfs-tools/hooks') >> 8;
$main_exit_code = system('run_scripts_optional', ${CONFDIR}, '/hooks') >> 8;
for my $b (do {
    my $left_result_29 = do { chdir(${DESTDIR} . "/scripts"); q{} };
;
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_29 = do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { if (-d $_) { push @find_results, $File::Find::name; } }, q{.});
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
};
        $left_result_29 . $right_result_29;
    } else {
        q{};
    }
}) {
    $main_exit_code = system('cache_run_scripts', ${DESTDIR}, "/scripts/" . (${b} =~ s/^\.///r =~ s/^\.///r)) >> 8;
}
$main_exit_code = system('bash', 'hidden_dep_add_modules') >> 8;
$main_exit_code = system('depmod', '-a', '-b', ${DESTDIR}, ${version}) >> 8;
if ( -e "${DESTDIR} . "/lib/modules/" . ${version}" ) {
    if ( -d "${DESTDIR} . "/lib/modules/" . ${version}" ) {
        carp "rm: carping: ", ${DESTDIR} . "/lib/modules/" . ${version},
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "${DESTDIR} . "/lib/modules/" . ${version}" ) {
                    }
        else {
            carp "rm: carping: could not remove ", ${DESTDIR} . "/lib/modules/" . ${version},
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
if ( -e "/modules." ) {
    if ( -d "/modules." ) {
        carp "rm: carping: ", "/modules.",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "/modules." ) {
                    }
        else {
            carp "rm: carping: could not remove ", "/modules.",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
my @files_to_remove = glob("*map");
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
use File::Copy qw(copy);
if ( -e 'Pr' ) {
    if ( -d '/etc/' ) {
        require File::Copy; File::Copy::copy('Pr', '/etc/' . '/' . ('Pr' =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy('Pr', '/etc/');
    }
} else {
    croak "cp: cannot stat '-p': No such file or directory\n";
}
if ( -e '/etc/ld.so.conf*' ) {
    if ( -d '/etc/' ) {
        require File::Copy; File::Copy::copy('/etc/ld.so.conf*', '/etc/' . '/' . ('/etc/ld.so.conf*' =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy('/etc/ld.so.conf*', '/etc/');
    }
} else {
    croak "cp: cannot stat '-p': No such file or directory\n";
}
if ( -e "$DESTDIR" ) {
    if ( -d '/etc/' ) {
        require File::Copy; File::Copy::copy("$DESTDIR", '/etc/' . '/' . ("$DESTDIR" =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy("$DESTDIR", '/etc/');
    }
} else {
    croak "cp: cannot stat '-p': No such file or directory\n";
}
if (!(!($main_exit_code = system('ldconfig', '-r', "$DESTDIR") >> 8;))) {
    if ("$(id -u)" ne "0") {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "ldconfig might need uid=0 (root) for chroot()\n";
        };
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
}
if ((-d "${DESTDIR}"/var/cache/ldconfig)) {
if ( -e "${DESTDIR}" ) {
        if ( -d "${DESTDIR}" ) {
            carp "rm: carping: ", ${DESTDIR},
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "${DESTDIR}" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ${DESTDIR},
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/var/cache/ldconfig/aux-cache" ) {
        if ( -d "/var/cache/ldconfig/aux-cache" ) {
            carp "rm: carping: ", "/var/cache/ldconfig/aux-cache",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/var/cache/ldconfig/aux-cache" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/cache/ldconfig/aux-cache",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
rmdir (${DESTDIR}, '/var/cache/ldconfig') or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
if ((-e "${CONFDIR}/DSDT.aml")) {
    $main_exit_code = system('copy_file', 'DSDT', ${CONFDIR} . "/DSDT.aml") >> 8;
}
if (($ENV{MODULES} // q{}) =~ /^netboot$/msx or ($ENV{MODULES} // q{}) =~ /^most$/msx) {
        $main_exit_code = system('add_dns', ${DESTDIR} . "/") >> 8;
}
if ("${verbose}" eq y) {
        my $xargs_verbose;
    my @xargs_verbose;
    my %xargs_verbose;
    $xargs_verbose = "-t";
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
do {
    local %ENV = %ENV;
    my $OPTIONS = $OPTIONS;
    my $DPKG_ARCH = $DPKG_ARCH;
    my $file = $file;
    my $err = $err;
    my $__TMPUNCOMPRESSEDFILES = $__TMPUNCOMPRESSEDFILES;
    my $__TMPCPIOGZ = $__TMPCPIOGZ;
    my $EXTRA_CONF = $EXTRA_CONF;
    my $__TMPMAINFILES = $__TMPMAINFILES;
    my $__TMPEARLYCPIO = $__TMPEARLYCPIO;
    my $keep = $keep;
    my $kconfig_sym = $kconfig_sym;
    my $d = $d;
    my $xargs_verbose = $xargs_verbose;
    if (do {
chdir(${DESTDIR});
$CHILD_ERROR = 0;
        $CHILD_ERROR == 0
    }) {
        {
            my $output_32 = q{};
            my $output_printed_32;
            my $pipeline_success_32 = 1;
                        $output_32 = do {
            require File::Find;
            my @find_results;
            File::Find::find(sub { if (-l $_) { push @find_results, $File::Find::name; } }, q{.});
            my $result = join "\n", @find_results;
            if ($result ne q{}) { $result .= "\n"; }
            $CHILD_ERROR = 0;
            $result;
            };

                        my @sed_lines_32 = split /\n/msx, $output_32;
            my @sed_result_32;
            foreach my $line (@sed_lines_32) {
            chomp $line;
            push @sed_result_32, $line;
            }
            $output_32 = join "\n", @sed_result_32;

                        my @xargs_input_32_2 = grep { $_ ne q{} } split /\s+/msx, $output_32;
            my @xargs_output_32_2;
            for my $i (0..scalar @xargs_input_32_2-1) {
            my @xargs_args_32_2;
            for my $j (0..1-1) {
            push @xargs_args_32_2, $xargs_input_32_2[$i + $j];
            }
            my ($in_32_2, $out_32_2, $err_32_2);
            my $cmd_xargs_32_2 = 'L1';
            my $pid_32_2 = open3($in_32_2, $out_32_2, $err_32_2, $cmd_xargs_32_2, 'rm', '-f', @xargs_args_32_2);
            close $in_32_2 or croak 'Close failed: $OS_ERROR';
            my $xargs_result_32_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_32_2> };
            close $out_32_2 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_32_2, 0;
            chomp $xargs_result_32_2;
            push @xargs_output_32_2, $xargs_result_32_2;
            }
            my $xargs_result_32_2 = join "\n", @xargs_output_32_2;
            if ($xargs_result_32_2 ne q{} && !( $xargs_result_32_2 =~ m{\n\z}msx )) { $xargs_result_32_2 .= "\n"; }
            $output_32 = $xargs_result_32_2;
            $output_32 = $xargs_result_32_2;
            if ($output_32 ne q{} && !defined $output_printed_32) {
                print $output_32;
                if (!($output_32 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_32 ) { $main_exit_code = 1; }
            }
    }
    q{};
};
if ("${verbose}" eq y) {
        do {
    my $__echo_line = "Building cpio " . ${outfile} . " initramfs";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if ("$(id -ru)" ne 0) {
        my $cpio_owner_root;
    my @cpio_owner_root;
    my %cpio_owner_root;
    $cpio_owner_root = "-R 0:0";
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if ("${SOURCE_DATE_EPOCH}" ne q{}) {
    # Original bash: find "${DESTDIR}" -newermt "@${SOURCE_DATE_EPOCH}" -print0 | \
{
        my $output_33 = q{};
        my $output_printed_33;
        my $pipeline_success_33 = 1;
                $output_33 = do {
        require File::Find;
        my @find_results;
        File::Find::find(sub { if (1) { push @find_results, $File::Find::name; } }, 'wermt');
        my $result = join "\n", @find_results;
        if ($result ne q{}) { $result .= "\n"; }
        $CHILD_ERROR = 0;
        $result;
        };

                my @xargs_input_33_1 = grep { $_ ne q{} } split /\s+/msx, $output_33;
        my @xargs_output_33_1;
        for my $i (0..scalar @xargs_input_33_1-1) {
        my @xargs_args_33_1;
        for my $j (0..1-1) {
        push @xargs_args_33_1, $xargs_input_33_1[$i + $j];
        }
        my ($in_33_1, $out_33_1, $err_33_1);
        my $cmd_xargs_33_1 = 'touch';
        my $pid_33_1 = open3($in_33_1, $out_33_1, $err_33_1, $cmd_xargs_33_1, '--no-dereference', '--date=@${SOURCE_DATE_EPOCH}', @xargs_args_33_1);
        close $in_33_1 or croak 'Close failed: $OS_ERROR';
        my $xargs_result_33_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_33_1> };
        close $out_33_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_33_1, 0;
        chomp $xargs_result_33_1;
        push @xargs_output_33_1, $xargs_result_33_1;
        }
        my $xargs_result_33_1 = join "\n", @xargs_output_33_1;
        if ($xargs_result_33_1 ne q{} && !( $xargs_result_33_1 =~ m{\n\z}msx )) { $xargs_result_33_1 .= "\n"; }
        $output_33 = $xargs_result_33_1;
        $output_33 = $xargs_result_33_1;
        if ($output_33 ne q{} && !defined $output_printed_33) {
            print $output_33;
            if (!($output_33 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_33 ) { $main_exit_code = 1; }
        }
    my $cpio_reproducible;
    my @cpio_reproducible;
    my %cpio_reproducible;
    $cpio_reproducible = "--reproducible";
}

sub add_directories {
    my $last_dir;
    my $path;
    my $dir;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $path = $_fields[0] // q{};
        $dir = ( ( dirname(${path}) ) =~ s|/[^/]*$||sr );
        my $parent;
        my @parent;
        my %parent;
        $parent = ${dir};
while (1) {
            last unless ("$parent" ne "$last_dir");
            last unless ("$parent" ne ".");
            print $parent;
if ( !( ($parent) =~ m{\n\z}msx ) ) { print "\n"; }
            $parent = ( ( dirname(${parent}) ) =~ s|/[^/]*$||sr );
        }
        $last_dir = "$dir";
        print $path;
if ( !( ($path) =~ m{\n\z}msx ) ) { print "\n"; }
    }
if ("$last_dir" ne q{}) {
        print ".\n";
    }
    return;
}
chdir(${DESTDIR});
$CHILD_ERROR = 0;
if ($CHILD_ERROR != 0) {
    exit 1;
}
{
    my $output_34 = q{};
    my $output_printed_34;
    my $pipeline_success_34 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            {
                my $pipeline_success_34 = 1;
                                my @_pcmd_36 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
                my ($in_35);
                my $pid_35 = open3($in_35, $out_35, '>&STDERR', @_pcmd_36);
                close $in_35 or croak 'Close failed: $OS_ERROR';
                my $temp_result;
                $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_35> };
                $output_34 = $temp_result;
                close $out_35 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_35, 0;

                                my $cmd_38 = 'add_directories';
                my ($in_37, $out_37);
                my $pid_37 = open3($in_37, $out_37, '>&STDERR', $cmd_38, );
                print {$in_37} $output_34;
                close $in_37 or croak 'Close failed: $OS_ERROR';
                $output_34 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_37> };
                close $out_37 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_37, 0;

                                my @_pcmd_40 = ('bash', '-c', "echo \"${output_34}\" | : \"Complex command cannot be converted to shell command\"");
                my ($in_39);
                my $pid_39 = open3($in_39, $out_39, '>&STDERR', @_pcmd_40);
                close $in_39 or croak 'Close failed: $OS_ERROR';
                my $temp_result;
                $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_39> };
                $output_34 = $temp_result;
                close $out_39 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_39, 0;

                                do {
                open my $original_stdout, '>&', STDOUT
                or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', ${__TMPMAINFILES}
                or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                my $tmp_redirect_41 = q{};
                my @uniq_lines_42 = split /\n/msx, $output_34;
                @uniq_lines_42 = grep { $_ ne q{} } @uniq_lines_42; # Filter out empty lines
                my %uniq_seen_42;
                my @uniq_result_42;
                foreach my $line (@uniq_lines_42) {
                if (!$uniq_seen_42{$line}++) { push @uniq_result_42, $line; }
                }
                $tmp_redirect_41 = join "\n", @uniq_result_42;
                if ($tmp_redirect_41 ne q{} && !($tmp_redirect_41 =~ m{\n\z}msx)) {
                $tmp_redirect_41 .= "\n";
                }
                $tmp_redirect_41;
                };
                print $tmp;
                if ($tmp eq q{}) { print $output_34; }
                $output_printed_34 = 1;
                open STDOUT, '>&', $original_stdout
                or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
                or die "Close failed: $OS_ERROR\n";
                };
                if ( !$pipeline_success_34 ) { $main_exit_code = 1; }
                }
            if ($CHILD_ERROR != 0) {
                                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_43 = q{};
$tmp_redirect_43 .= "E: mkinitramfs failure uniq ${\($? >> 8)}\n";
if ( !($tmp_redirect_43 =~ m{\n\z}msx) ) { $tmp_redirect_43 .= "\n"; }
$CHILD_ERROR = 0;
$tmp_redirect_43;
                    };
                    do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_45 = q{};
$tmp_redirect_45 .= q{1} . "\n";
if ( !($tmp_redirect_45 =~ m{\n\z}msx) ) { $tmp_redirect_45 .= "\n"; }
$CHILD_ERROR = 0;
$tmp_redirect_45;
                    };
exit $main_exit_code;
            }
    };
    $output_34 = $output;

        my @_pcmd_48 = ('bash', '-c', "echo \"${output_34}\" | : \"Complex command cannot be converted to shell command\"");
    my ($in_47);
    my $pid_47 = open3($in_47, $out_47, '>&STDERR', @_pcmd_48);
    close $in_47 or croak 'Close failed: $OS_ERROR';
    my $temp_result;
    $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_47> };
    $output_34 = $temp_result;
    close $out_47 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_47, 0;
    if ($output_34 ne q{} && !defined $output_printed_34) {
        print $output_34;
        if (!($output_34 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_34 ) { $main_exit_code = 1; }
    }
if ($CHILD_ERROR != 0) {
    }
{
    my $output_49 = q{};
    my $output_printed_49;
    my $pipeline_success_49 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            {
                my $pipeline_success_49 = 1;
                                my @_pcmd_51 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
                my ($in_50);
                my $pid_50 = open3($in_50, $out_50, '>&STDERR', @_pcmd_51);
                close $in_50 or croak 'Close failed: $OS_ERROR';
                my $temp_result;
                $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_50> };
                $output_49 = $temp_result;
                close $out_50 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_50, 0;

                                my $cmd_53 = 'add_directories';
                my ($in_52, $out_52);
                my $pid_52 = open3($in_52, $out_52, '>&STDERR', $cmd_53, );
                print {$in_52} $output_49;
                close $in_52 or croak 'Close failed: $OS_ERROR';
                $output_49 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_52> };
                close $out_52 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_52, 0;

                                my @_pcmd_55 = ('bash', '-c', "echo \"${output_49}\" | : \"Complex command cannot be converted to shell command\"");
                my ($in_54);
                my $pid_54 = open3($in_54, $out_54, '>&STDERR', @_pcmd_55);
                close $in_54 or croak 'Close failed: $OS_ERROR';
                my $temp_result;
                $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_54> };
                $output_49 = $temp_result;
                close $out_54 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_54, 0;

                                do {
                open my $original_stdout, '>&', STDOUT
                or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', ${__TMPUNCOMPRESSEDFILES}
                or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                my $tmp_redirect_56 = q{};
                my @uniq_lines_57 = split /\n/msx, $output_49;
                @uniq_lines_57 = grep { $_ ne q{} } @uniq_lines_57; # Filter out empty lines
                my %uniq_seen_57;
                my @uniq_result_57;
                foreach my $line (@uniq_lines_57) {
                if (!$uniq_seen_57{$line}++) { push @uniq_result_57, $line; }
                }
                $tmp_redirect_56 = join "\n", @uniq_result_57;
                if ($tmp_redirect_56 ne q{} && !($tmp_redirect_56 =~ m{\n\z}msx)) {
                $tmp_redirect_56 .= "\n";
                }
                $tmp_redirect_56;
                };
                print $tmp;
                if ($tmp eq q{}) { print $output_49; }
                $output_printed_49 = 1;
                open STDOUT, '>&', $original_stdout
                or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
                or die "Close failed: $OS_ERROR\n";
                };
                if ( !$pipeline_success_49 ) { $main_exit_code = 1; }
                }
            if ($CHILD_ERROR != 0) {
                                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_58 = q{};
$tmp_redirect_58 .= "E: mkinitramfs failure uniq ${\($? >> 8)}\n";
if ( !($tmp_redirect_58 =~ m{\n\z}msx) ) { $tmp_redirect_58 .= "\n"; }
$CHILD_ERROR = 0;
$tmp_redirect_58;
                    };
                    do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_60 = q{};
$tmp_redirect_60 .= q{1} . "\n";
if ( !($tmp_redirect_60 =~ m{\n\z}msx) ) { $tmp_redirect_60 .= "\n"; }
$CHILD_ERROR = 0;
$tmp_redirect_60;
                    };
exit $main_exit_code;
            }
    };
    $output_49 = $output;

        my @_pcmd_63 = ('bash', '-c', "echo \"${output_49}\" | : \"Complex command cannot be converted to shell command\"");
    my ($in_62);
    my $pid_62 = open3($in_62, $out_62, '>&STDERR', @_pcmd_63);
    close $in_62 or croak 'Close failed: $OS_ERROR';
    my $temp_result;
    $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_62> };
    $output_49 = $temp_result;
    close $out_62 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_62, 0;
    if ($output_49 ne q{} && !defined $output_printed_49) {
        print $output_49;
        if (!($output_49 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_49 ) { $main_exit_code = 1; }
    }
if ($CHILD_ERROR != 0) {
    }
{
    my $output_64 = q{};
    my $output_printed_64;
    my $pipeline_success_64 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', ${outfile}
      or die "Cannot open file: $OS_ERROR\n";
if (((-s "${__TMPEARLYCPIO}") > 0)) {
                        print do { my $cat_chunk = q{}; if ( open my $fh, '<', ${__TMPEARLYCPIO} ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . ${__TMPEARLYCPIO} . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                        if ($CHILD_ERROR != 0) {
                                                            do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_66 = q{};
$tmp_redirect_66 .= q{1} . "\n";
if ( !($tmp_redirect_66 =~ m{\n\z}msx) ) { $tmp_redirect_66 .= "\n"; }
$CHILD_ERROR = 0;
$tmp_redirect_66;
                                };
exit $main_exit_code;
                        }
                    }
if (((-s "${__TMPUNCOMPRESSEDFILES}") > 0)) {
                        open STDIN, '<', ${__TMPUNCOMPRESSEDFILES} or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_68 = q{};

my $cmd_71 = 'cpio';
my ($in_70, $out_70);
my $pid_70 = open3($in_70, $out_70, '>&STDERR', $cmd_71, '--quiet', '-o', '-H', 'newc', '-D');
print {$in_70} $output_64;
close $in_70 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_68 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_70> };
close $out_70 or croak 'Close failed: $OS_ERROR';
waitpid $pid_70, 0;
$tmp_redirect_68;
                        if ($CHILD_ERROR != 0) {
                                                            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_72 = q{};
$tmp_redirect_72 .= "E: mkinitramfs failure uncompressed cpio ${\($? >> 8)}\n";
if ( !($tmp_redirect_72 =~ m{\n\z}msx) ) { $tmp_redirect_72 .= "\n"; }
$CHILD_ERROR = 0;
$tmp_redirect_72;
                                };
                                do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_74 = q{};
$tmp_redirect_74 .= q{1} . "\n";
if ( !($tmp_redirect_74 =~ m{\n\z}msx) ) { $tmp_redirect_74 .= "\n"; }
$CHILD_ERROR = 0;
$tmp_redirect_74;
                                };
exit $main_exit_code;
                        }
                    }
                    {
                        my $pipeline_success_64 = 1;
                                                my @_pcmd_77 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
                        my ($in_76);
                        my $pid_76 = open3($in_76, $out_76, '>&STDERR', @_pcmd_77);
                        close $in_76 or croak 'Close failed: $OS_ERROR';
                        my $temp_result;
                        $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_76> };
                        $output_64 = $temp_result;
                        close $out_76 or croak 'Close failed: $OS_ERROR';
                        waitpid $pid_76, 0;

                                                my $cmd_79 = 'unknown_command';
                        my ($in_78, $out_78);
                        my $pid_78 = open3($in_78, $out_78, '>&STDERR', $cmd_79, '-c');
                        print {$in_78} $output_64;
                        close $in_78 or croak 'Close failed: $OS_ERROR';
                        $output_64 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_78> };
                        close $out_78 or croak 'Close failed: $OS_ERROR';
                        waitpid $pid_78, 0;
                        if ($output_64 ne q{} && !defined $output_printed_64) {
                            print $output_64;
                            if (!($output_64 =~ m{\n\z}msx)) {
                                print "\n";
                            }
                        }
                        if ( !$pipeline_success_64 ) { $main_exit_code = 1; }
                        }
                    if ($CHILD_ERROR != 0) {
                                                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_80 = q{};
$tmp_redirect_80 .= "E: mkinitramfs failure $compress ${\($? >> 8)}\n";
if ( !($tmp_redirect_80 =~ m{\n\z}msx) ) { $tmp_redirect_80 .= "\n"; }
$CHILD_ERROR = 0;
$tmp_redirect_80;
                            };
                            do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_82 = q{};
$tmp_redirect_82 .= q{1} . "\n";
if ( !($tmp_redirect_82 =~ m{\n\z}msx) ) { $tmp_redirect_82 .= "\n"; }
$CHILD_ERROR = 0;
$tmp_redirect_82;
                            };
exit $main_exit_code;
                    }
if (((-s "${__TMPCPIOGZ}") > 0)) {
                        print do { my $cat_chunk = q{}; if ( open my $fh, '<', ${__TMPCPIOGZ} ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . ${__TMPCPIOGZ} . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                        if ($CHILD_ERROR != 0) {
                                                            do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_85 = q{};
$tmp_redirect_85 .= q{1} . "\n";
if ( !($tmp_redirect_85 =~ m{\n\z}msx) ) { $tmp_redirect_85 .= "\n"; }
$CHILD_ERROR = 0;
$tmp_redirect_85;
                                };
exit $main_exit_code;
                        }
                    }
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            if ($CHILD_ERROR != 0) {
                                do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_87 = q{};
$tmp_redirect_87 .= $? . "\n";
if ( !($tmp_redirect_87 =~ m{\n\z}msx) ) { $tmp_redirect_87 .= "\n"; }
$CHILD_ERROR = 0;
$tmp_redirect_87;
                };
            }
    };
    $output_64 = $output;

        my @_pcmd_90 = ('bash', '-c', "echo \"${output_64}\" | : \"Complex command cannot be converted to shell command\"");
    my ($in_89);
    my $pid_89 = open3($in_89, $out_89, '>&STDERR', @_pcmd_90);
    close $in_89 or croak 'Close failed: $OS_ERROR';
    my $temp_result;
    $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_89> };
    $output_64 = $temp_result;
    close $out_89 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_89, 0;
    if ($output_64 ne q{} && !defined $output_printed_64) {
        print $output_64;
        if (!($output_64 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_64 ) { $main_exit_code = 1; }
    }
if ($CHILD_ERROR != 0) {
    }
exit 0;

exit $main_exit_code;
