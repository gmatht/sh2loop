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

my $DPKG_ROOT;
my @DPKG_ROOT;
my %DPKG_ROOT;

$__set_e = 1;
if ("$1" eq install) {
if ((!-e "$DPKG_ROOT/etc/passwd")) {
open my $fh_cat, '>', "\"$DPKG_ROOT/etc/passwd\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} q{root:*:0:0:root:/root:/bin/bash
daemon:*:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:*:2:2:bin:/bin:/usr/sbin/nologin
sys:*:3:3:sys:/dev:/usr/sbin/nologin
sync:*:4:65534:sync:/bin:/bin/sync
games:*:5:60:games:/usr/games:/usr/sbin/nologin
man:*:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:*:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:*:8:8:mail:/var/mail:/usr/sbin/nologin
news:*:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:*:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:*:13:13:proxy:/bin:/usr/sbin/nologin
www-data:*:33:33:www-data:/var/www:/usr/sbin/nologin
backup:*:34:34:backup:/var/backups:/usr/sbin/nologin
list:*:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:*:39:39:ircd:/run/ircd:/usr/sbin/nologin
_apt:*:42:65534::/nonexistent:/usr/sbin/nologin
nobody:*:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
};
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    }
if ((!-e "$DPKG_ROOT/etc/group")) {
open my $fh_cat, '>', "\"$DPKG_ROOT/etc/group\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} q{root:*:0:
daemon:*:1:
bin:*:2:
sys:*:3:
adm:*:4:
tty:*:5:
disk:*:6:
lp:*:7:
mail:*:8:
news:*:9:
uucp:*:10:
man:*:12:
proxy:*:13:
kmem:*:15:
dialout:*:20:
fax:*:21:
voice:*:22:
cdrom:*:24:
floppy:*:25:
tape:*:26:
sudo:*:27:
audio:*:29:
dip:*:30:
www-data:*:33:
backup:*:34:
operator:*:37:
list:*:38:
irc:*:39:
src:*:40:
shadow:*:42:
utmp:*:43:
video:*:44:
sasl:*:45:
plugdev:*:46:
staff:*:50:
games:*:60:
users:*:100:
nogroup:*:65534:
};
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    }
}
exit 0;

exit $main_exit_code;
