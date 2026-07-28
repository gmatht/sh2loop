#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

my $main_exit_code = 0;
my $output         = q{};
our $CHILD_ERROR;

my $DPKG_ROOT;
my $pathname;

$__set_e = 1;
my $PROGNAME = do { use File::Basename qw(basename); my $basename_output = basename("$PROGRAM_NAME"); $CHILD_ERROR = 0; $basename_output; };
my $version = "1.22.6";
my $EOL = "\n";
my $PKGDATADIR_DEFAULT = '/usr/share/dpkg';
my $PKGDATADIR = (defined (defined ($ENV{DPKG_DATADIR} // q{}) && ($ENV{DPKG_DATADIR} // q{}) ne q{} ? ($ENV{DPKG_DATADIR} // q{}) : '$PKGDATADIR_DEFAULT') && (defined ($ENV{DPKG_DATADIR} // q{}) && ($ENV{DPKG_DATADIR} // q{}) ne q{} ? ($ENV{DPKG_DATADIR} // q{}) : '$PKGDATADIR_DEFAULT') ne q{} ? (defined ($ENV{DPKG_DATADIR} // q{}) && ($ENV{DPKG_DATADIR} // q{}) ne q{} ? ($ENV{DPKG_DATADIR} // q{}) : '$PKGDATADIR_DEFAULT') : '$PKGDATADIR_DEFAULT');
$main_exit_code = system('.', "$PKGDATADIR/sh/dpkg-error.sh") >> 8;

sub show_version {
print "Debian $PROGNAME version $version.

This is free software; see the GNU General Public License version 2 or
later for copying conditions. There is NO warranty.
";
    return;
}

sub show_usage {
print "Usage: $PROGNAME [<option>...] <pathname>

Options:
  -z, --zero                   end output line with NUL, not newline.
      --instdir <directory>    set the root directory.
      --root <directory>       set the root directory.
      --version                show the version.
  -?, --help                   show this help message.
";
    return;
}

sub canonicalize {
    my ($file) = @_;
    my $src = "$_[0]";
    my $root = "$DPKG_ROOT";
    my $loop = "0";
    my $result = "$root";
    my $dst;
if ("$src" eq "${src#/}") {
        $src = (do { use Cwd; $CHILD_ERROR = 0; getcwd(); }) . "/$src";
        $src = (${src} =~ s/^"\$root"//r =~ s/^"\$root"//r);
    }
while ( "$src" ne "${src#/}" ) {
        $src = ${src} =~ s/^///r;
    }
    my $prefix;
while ( "$src" ne q{} ) {
        $prefix = dirname(($ENV{src%} // q{}));
        $src = ${src} =~ s/^"\$prefix"//r;
while ( "$src" ne "${src#/}" ) {
            $src = ${src} =~ s/^///r;
        }
if ("$prefix" eq .) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
            if ("$prefix" eq ..) {
                $result = dirname(${result});
if (("$root" ne q{} && "${result#"$root"}" eq "$result")) {
                    $result = "$root";
                }
}
            else {
                if (( -h "$result/$prefix")) {
                    $loop = eval { int($loop + 1) } // "";
if (($loop > 25)) {
                        $main_exit_code = system('error', "too many levels of symbolic links") >> 8;
                    }
                    $dst = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'readlink', "$result/$prefix");
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
if ("$dst" =~ /^/.*$/msx) {
                                                $result = $root;
                                                $src = "$dst" . (defined (defined ${src} && ${src} ne q{} ? ${src} : '/$src') && (defined ${src} && ${src} ne q{} ? ${src} : '/$src') ne q{} ? (defined ${src} && ${src} ne q{} ? ${src} : '/$src') : '/$src');
                        while ( "$src" ne "${src#/}" ) {
                            $src = ${src} =~ s/^///r;
                        }
                    } elsif (1) {
                                                $src = "$dst" . (defined (defined ${src} && ${src} ne q{} ? ${src} : '/$src') && (defined ${src} && ${src} ne q{} ? ${src} : '/$src') ne q{} ? (defined ${src} && ${src} ne q{} ? ${src} : '/$src') : '/$src');
                    }
}
                else {
                    $result = "$result/$prefix";
                }
            }
        }
    }
;
    $result = (${result} =~ s/^"\$root"//r =~ s/^"\$root"//r);
printf('%s', (defined (defined ${result} && ${result} ne q{} ? ${result} : '/') && (defined ${result} && ${result} ne q{} ? ${result} : '/') ne q{} ? (defined ${result} && ${result} ne q{} ? ${result} : '/') : '/'));
    return;
}
$main_exit_code = system('bash', 'setup_colors') >> 8;
$DPKG_ROOT = (defined (defined ${DPKG_ROOT} && ${DPKG_ROOT} ne q{} ? ${DPKG_ROOT} : '') && (defined ${DPKG_ROOT} && ${DPKG_ROOT} ne q{} ? ${DPKG_ROOT} : '') ne q{} ? (defined ${DPKG_ROOT} && ${DPKG_ROOT} ne q{} ? ${DPKG_ROOT} : '') : '');
$ENV{DPKG_ROOT} = $DPKG_ROOT;
while ( scalar(@ARGV) != 0 ) {
if ("$_[0]" =~ /^-z$/msx or "$_[0]" =~ /^--zero$/msx) {
                $EOL = "\0";
    } elsif ("$_[0]" =~ /^--instdir$/msx or "$_[0]" =~ /^--root$/msx) {
        # Builtin command 'shift' not implemented
                $DPKG_ROOT = $1;
    } elsif ("$_[0]" =~ /^--instdir=.*$/msx) {
                $DPKG_ROOT = ($_[0] =~ s/^--instdir=//r =~ s/^--instdir=//r);
    } elsif ("$_[0]" =~ /^--root=.*$/msx) {
                $DPKG_ROOT = ($_[0] =~ s/^--root=//r =~ s/^--root=//r);
    } elsif ("$_[0]" =~ /^--version$/msx) {
                show_version();
        exit 0;
    } elsif ("$_[0]" =~ /^--help$/msx or "$_[0]" =~ /^-\.$/msx) {
                show_usage();
        exit 0;
    } elsif ("$_[0]" =~ /^--$/msx) {
        # Builtin command 'shift' not implemented
                $pathname = "$_[0]";
    } elsif ("$_[0]" =~ /^-.*$/msx) {
                $main_exit_code = system('badusage', "unknown option: $_[0]") >> 8;
    } elsif (1) {
                $pathname = "$_[0]";
    }
# Builtin command 'shift' not implemented
}
$DPKG_ROOT = (defined (defined ${DPKG_ROOT} && ${DPKG_ROOT} ne q{} ? ${DPKG_ROOT} : do { my $_result = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'realpath', "$DPKG_ROOT");
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
}; $_result; }) && (defined ${DPKG_ROOT} && ${DPKG_ROOT} ne q{} ? ${DPKG_ROOT} : do { my $_result = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'realpath', "$DPKG_ROOT");
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
}; $_result; }) ne q{} ? (defined ${DPKG_ROOT} && ${DPKG_ROOT} ne q{} ? ${DPKG_ROOT} : do { my $_result = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'realpath', "$DPKG_ROOT");
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
}; $_result; }) : do { my $_result = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'realpath', "$DPKG_ROOT");
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
}; $_result; });
if ("$DPKG_ROOT" eq "/") {
    $DPKG_ROOT = "";
}
if (!("$pathname" ne q{})) {
        $main_exit_code = system('badusage', "missing pathname") >> 8;
}
if ("${pathname#"$DPKG_ROOT"}" ne "$pathname") {
    $main_exit_code = system('error', "link '$pathname' includes root prefix '$DPKG_ROOT'") >> 8;
}
canonicalize("$pathname");
exit 0;

exit $main_exit_code;
