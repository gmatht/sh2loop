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

my $LOCALDIR;
my @LOCALDIR;
my %LOCALDIR;

my $MAGIC_2775 = 2_775;

$__set_e = 1;
my $CONFAVAIL;
my @CONFAVAIL;
my %CONFAVAIL;
$CONFAVAIL = '/usr/share/fontconfig/conf.avail';
my $CONFDIR;
my @CONFDIR;
my %CONFDIR;
$CONFDIR = '/etc/fonts/conf.d';
$LOCALDIR = '/usr/local/share/fonts';
if ((!-d $LOCALDIR)) {
if (!(    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        use File::Path qw(make_path);
        my $err;
        if ( mkdir $LOCALDIR ) {
            }
        else {
            croak "mkdir: cannot create directory " . $LOCALDIR . ": File exists\n";
        }
    })) {
chmod(oct('2775'), ($LOCALDIR)) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
do {
    my ($owner, $group) = split /:/, 'root:staff', 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ($LOCALDIR) or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
    }
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10-antialias.conf', "2.14.1-3ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/05', '-r', 'eset-dirs-sample.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/09-autohint-if-no-hinting.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10-autohint.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10', '-h', 'inting-full.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10', '-h', 'inting-medium.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10', '-h', 'inting-none.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10', '-h', 'inting-slight.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10', '-n', 'o-antialias.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10', '-n', 'o-sub-pixel.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10', '-s', 'cale-bitmap-fonts.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10', '-s', 'ub-pixel-bgr.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10', '-s', 'ub-pixel-rgb.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10', '-s', 'ub-pixel-vbgr.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10', '-s', 'ub-pixel-vrgb.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10', '-u', 'nhinted.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/10-yes-antialias.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/11-lcdfilter-default.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/11-lcdfilter-legacy.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/11-lcdfilter-light.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/20', '-u', 'nhint-small-vera.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/25', '-u', 'nhint-nonlatin.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/30-metric-aliases.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/35-lang-normalize.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/40', '-n', 'onlatin.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/45', '-ge', 'neric.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/45-latin.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/48', '-s', 'pacing.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/49', '-s', 'ansserif.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/50', '-u', 'ser.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/51-local.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/53-monospace-lcd-filter.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/60', '-ge', 'neric.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/60-latin.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/65', '-f', 'onts-persian.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/65', '-k', 'hmer.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/65', '-n', 'onlatin.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/69', '-u', 'nifont.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/70', '-f', 'orce-bitmaps.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/70', '-n', 'o-bitmaps.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/70-yes-bitmaps.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/80', '-d', 'elicious.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/fonts/conf.avail/90', '-s', 'ynthetic.conf', "2.14.1-3ubuntu3\\~", '--', "@ARGV") >> 8;

exit $main_exit_code;
