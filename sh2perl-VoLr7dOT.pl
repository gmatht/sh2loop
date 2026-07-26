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

my $mode;
my @mode;
my %mode;
my $dir;
my @dir;
my %dir;
my $DPKG_ROOT;
my @DPKG_ROOT;
my %DPKG_ROOT;

$__set_e = 1;
if ((("$1" eq "configure" && (-x "`command -v update-menus`")) && (-x "$DPKG_ROOT`command -v update-menus`"))) {
    $main_exit_code = system('bash', 'update-menus') >> 8;
}
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
my $temp_content = '/usr/local/share default
/usr/local/share/zsh default
/usr/local/share/zsh/site-functions default
';
use File::Path qw(make_path);
if (!-d q{/tmp}) { make_path(q{/tmp}); }
open my $fh_1, '>', q{/tmp} . '/heredoc_temp' or croak "Cannot create temp file: $OS_ERROR\n";
print $fh_1 $temp_content;
close $fh_1 or croak "Close failed: $OS_ERROR\n";
open STDIN, '<', q{/tmp} . '/heredoc_temp' or croak "Cannot open temp file: $OS_ERROR\n";
    do {
        local %ENV = %ENV;
            my $default_mode;
            my @default_mode;
            my %default_mode;
            $default_mode = '0755';
            my $default_user;
            my @default_user;
            my %default_user;
            $default_user = 'root';
            my $default_group;
            my @default_group;
            my %default_group;
            $default_group = 'root';
if ((-e '/etc/staff-group-for-usr-local')) {
                $default_mode = '02775';
                $default_group = 'staff';
            }
            my $line;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $line = $_fields[0] // q{};
# set -- not implemented
                $dir = "$_[0]";
                $mode = "$_[1]";
                my $user;
                my @user;
                my %user;
                $user = "$_[2]";
                my $group;
                my @group;
                my %group;
                $group = "$_[3]";
if ("$mode" eq "default") {
                    $mode = "$default_mode";
                    $user = "$default_user";
                    $group = "$default_group";
                }
if ((!-e "$dir")) {
if (!(                    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                        use File::Path qw(make_path);
                        my $err;
                        if ( mkdir "$dir" ) {
                            }
                        else {
                            croak "mkdir: cannot create directory " . "$dir" . ": File exists\n";
                        }
                    })) {
if (!(do {
    my ($owner, $group) = split /:/, "$user", 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, (q{:}, "$group", "$dir") or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
})) {
                            chmod(oct("$mode"), ("$dir")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
                            if ($CHILD_ERROR != 0) {
                                1;
                            }
                        }
                    }
                }
            }
        q{};
    };
}
$main_exit_code = system('dpkg-maintscript-helper', 'symlink_to_dir', '/usr/share/doc/zsh', 'zsh-common', '5.0.7-3', '--', "@ARGV") >> 8;

exit $main_exit_code;
