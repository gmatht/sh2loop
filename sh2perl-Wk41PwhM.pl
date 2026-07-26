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

my $NEED_GSSD;
my @NEED_GSSD;
my %NEED_GSSD;
my $NEED_STATD;
my @NEED_STATD;
my %NEED_STATD;
my $DEFAULTFILE;
my @DEFAULTFILE;
my %DEFAULTFILE;
my $NEED_IDMAPD;
my @NEED_IDMAPD;
my %NEED_IDMAPD;
my $RET;
my @RET;
my %RET;

my $DESC;
my @DESC;
my %DESC;
$DESC = "NFS common utilities";
$DEFAULTFILE = '/etc/default/nfs-common';
$NEED_STATD = q{};
$NEED_GSSD = q{};
my $PIPEFS_MOUNTPOINT;
my @PIPEFS_MOUNTPOINT;
my %PIPEFS_MOUNTPOINT;
$PIPEFS_MOUNTPOINT = '/run/rpc_pipefs';
if ((-f $DEFAULTFILE)) {
    $main_exit_code = system('.', $DEFAULTFILE) >> 8;
}
$main_exit_code = system('.', '/lib/lsb/init-functions') >> 8;
if (!((-x '/usr/sbin/rpc.statd'))) {
    exit 0;
}
my $AUTO_NEED_GSSD;
my @AUTO_NEED_GSSD;
my %AUTO_NEED_GSSD;
$AUTO_NEED_GSSD = 'no';
if ((-f '/etc/fstab')) {
    do {
open STDIN, '<', '/etc/fstab' or croak "Cannot open file: $OS_ERROR\n";
open STDERR, '<', q{0} or croak "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
    };
    my $DEV;
    my $_;
    my $OPTS;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $DEV = $_fields[0] // q{};
    $_ = $_fields[1] // q{};
    $_ = $_fields[2] // q{};
    $OPTS = $_fields[3] // q{};
    $_ = $_fields[4] // q{};
if ($DEV =~ /^$/msx or $DEV =~ /^\#.*$/msx) {
            next;        }
        my $OLDIFS;
        my @OLDIFS;
        my %OLDIFS;
        $OLDIFS = "$ENV{IFS}";
        my $IFS;
        my @IFS;
        my %IFS;
        $IFS = ",";
        my $OPT;
        for my $OPT ($OPTS) {
if ("$OPT" =~ /^sec=krb5$/msx or "$OPT" =~ /^sec=krb5i$/msx or "$OPT" =~ /^sec=krb5p$/msx) {
                                $AUTO_NEED_GSSD = 'yes';
            }
        }
        $IFS = "$OLDIFS";
    }
    do {
open STDERR, '<', q{9} or croak "Cannot open file: $OS_ERROR\n";
open STDERR, '<', q{-} or croak "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
    };
}
if ("$NEED_STATD" =~ /^yes$/msx or "$NEED_STATD" =~ /^no$/msx) {
} elsif (1) {
        $NEED_STATD = 'yes';
}
if ("$NEED_IDMAPD" =~ /^yes$/msx or "$NEED_IDMAPD" =~ /^no$/msx) {
} elsif (1) {
        $NEED_IDMAPD = 'yes';
}
if ("$NEED_GSSD" =~ /^yes$/msx or "$NEED_GSSD" =~ /^no$/msx) {
} elsif (1) {
        $NEED_GSSD = $AUTO_NEED_GSSD;
}

sub do_modprobe {
if (((-x '/sbin/modprobe') && (-f '/proc/modules'))) {
                $main_exit_code = system('modprobe', '-q', "$_[0]") >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
    return;
}

sub do_mount {
    my ($file) = @_;
if (!(!(my $grep_result_1;
my @grep_lines_1 = ();
my @grep_filenames_1 = ();
if (-e "/proc/filesystems") {
    open my $fh, '<', "/proc/filesystems" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_1, $line;
        push @grep_filenames_1, "/proc/filesystems";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/filesystems: No such file or directory\n"; }
my @grep_filtered_1 = grep { /$_[0]$/msx } @grep_lines_1;
$grep_result_1 = join "\n", @grep_filtered_1;
    if (!($grep_result_1 =~ m{\n\z}msx || $grep_result_1 eq q{})) {
        $grep_result_1 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_1 > 0 ? 0 : 1;
$grep_result_1 = q{};))) {
return q{1};
    }
if (!(!($main_exit_code = system('mountpoint', '-q', "$_[1]") >> 8;))) {
        $main_exit_code = system('mount', '-t', "$_[0]", "$_[0]", "$_[1]") >> 8;
return;
    }
return q{0};
    return;
}

sub do_umount {
    my ($file) = @_;
if (!(    $main_exit_code = system('mountpoint', '-q', "$_[0]") >> 8)) {
        $main_exit_code = system('umount', "$_[0]") >> 8;
    }
return q{0};
    return;
}
if ("$_[0]" =~ /^start$/msx) {
        $main_exit_code = system('log_daemon_msg', "Starting $DESC") >> 8;
    if ("$NEED_STATD" eq yes) {
        $main_exit_code = system('log_progress_msg', "statd") >> 8;
if ((-x '/usr/sbin/rpcinfo')) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('/usr/sbin/rpcinfo', '-p') >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            $RET = $?;
if ($RET ne 0) {
                print "\n";
                $CHILD_ERROR = 0;
                $main_exit_code = system('log_warning_msg', "Not starting: portmapper is not running") >> 8;
exit 0;
            }
        }
        $main_exit_code = system('start-stop-daemon', '--start', '--oknodo', '--quiet', '--pidfile', '/run/rpc.statd.pid', '--exec', '/usr/sbin/rpc.statd') >> 8;
        $RET = $?;
if ($RET ne 0) {
            $main_exit_code = system('log_end_msg', $RET) >> 8;
}
        else {
if ((-d '/run/sendsigs.omit.d')) {
if ( -e "/run/sendsigs.omit.d/statd" ) {
                    if ( -d "/run/sendsigs.omit.d/statd" ) {
                        carp "rm: carping: ", "/run/sendsigs.omit.d/statd",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "/run/sendsigs.omit.d/statd" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "/run/sendsigs.omit.d/statd",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
symlink '/run/rpc.statd.pid', '/run/sendsigs.omit.d/statd' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
            }
        }
    }
        if (!((-x '/usr/sbin/rpc.idmapd'))) {
                $NEED_IDMAPD = 'no';
    }
        if (!((-x '/usr/sbin/rpc.gssd'))) {
                $NEED_GSSD = 'no';
    }
    if (("$NEED_IDMAPD" eq yes || "$NEED_GSSD" eq yes)) {
        do_modprobe('sunrpc');
        do_modprobe('nfs');
        do_modprobe('nfsd');
        use File::Path qw(make_path);
        my $err;
        if ( !-d "$PIPEFS_MOUNTPOINT" ) {
            make_path( "$PIPEFS_MOUNTPOINT", { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . "$PIPEFS_MOUNTPOINT" . ": $err->[0]\n";
            }
        }
if (!(        do_mount('rpc_pipefs', $PIPEFS_MOUNTPOINT))) {
if ("$NEED_IDMAPD" eq yes) {
                $main_exit_code = system('log_progress_msg', "idmapd") >> 8;
                $main_exit_code = system('start-stop-daemon', '--start', '--oknodo', '--quiet', '--exec', '/usr/sbin/rpc.idmapd') >> 8;
                $RET = $?;
if ($RET ne 0) {
                    $main_exit_code = system('log_end_msg', $RET) >> 8;
                }
            }
if ("$NEED_GSSD" eq yes) {
                do_modprobe('rpcsec_gss_krb5');
                $main_exit_code = system('log_progress_msg', "gssd") >> 8;
if (!(!(my $grep_result_4;
my @grep_lines_4 = ();
my @grep_filenames_4 = ();
if (-e "/etc/services") {
    open my $fh, '<', "/etc/services" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_4, $line;
        push @grep_filenames_4, "/etc/services";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/services: No such file or directory\n"; }
my @grep_filtered_4 = grep { /^nfs[\t\ ]/msx } @grep_lines_4;
$grep_result_4 = join "\n", @grep_filtered_4;
                if (!($grep_result_4 =~ m{\n\z}msx || $grep_result_4 eq q{})) {
                    $grep_result_4 .= "\n";
                }
$CHILD_ERROR = scalar @grep_filtered_4 > 0 ? 0 : 1;
$grep_result_4 = q{};))) {
                    $main_exit_code = system('log_action_end_msg', q{1}, "broken /etc/services, please see /usr/share/doc/nfs-common/README.Debian.nfsv4") >> 8;
exit 1;
                }
                $main_exit_code = system('start-stop-daemon', '--start', '--oknodo', '--quiet', '--exec', '/usr/sbin/rpc.gssd') >> 8;
                $RET = $?;
if ($RET ne 0) {
                    $main_exit_code = system('log_end_msg', $RET) >> 8;
                }
            }
        }
    }
        $main_exit_code = system('log_end_msg', q{0}) >> 8;
} elsif ("$_[0]" =~ /^stop$/msx) {
        $main_exit_code = system('log_daemon_msg', "Stopping $DESC") >> 8;
    if ("$NEED_GSSD" eq yes) {
        $main_exit_code = system('log_progress_msg', "gssd") >> 8;
        $main_exit_code = system('start-stop-daemon', '--stop', '--oknodo', '--quiet', '--name', 'rpc.gssd') >> 8;
        $RET = $?;
if ($RET ne 0) {
            $main_exit_code = system('log_end_msg', $RET) >> 8;
        }
    }
    if ("$NEED_IDMAPD" eq yes) {
        $main_exit_code = system('log_progress_msg', "idmapd") >> 8;
        $main_exit_code = system('start-stop-daemon', '--stop', '--oknodo', '--quiet', '--name', 'rpc.idmapd') >> 8;
        $RET = $?;
if ($RET ne 0) {
            $main_exit_code = system('log_end_msg', $RET) >> 8;
        }
    }
    if ("$NEED_STATD" eq yes) {
        $main_exit_code = system('log_progress_msg', "statd") >> 8;
        $main_exit_code = system('start-stop-daemon', '--stop', '--oknodo', '--quiet', '--name', 'rpc.statd') >> 8;
        $RET = $?;
if ($RET ne 0) {
            $main_exit_code = system('log_end_msg', $RET) >> 8;
        }
    }
            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        do_umount($PIPEFS_MOUNTPOINT);
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
        $main_exit_code = system('log_end_msg', q{0}) >> 8;
} elsif ("$_[0]" =~ /^status$/msx) {
    if ("$NEED_STATD" eq yes) {
if (!(!(do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('pidof', 'rpc.statd') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };))) {
            print "rpc.statd not running\n";
exit 3;
        }
    }
    if ("$NEED_GSSD" eq yes) {
if (!(!(do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('pidof', 'rpc.gssd') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };))) {
            print "rpc.gssd not running\n";
exit 3;
        }
    }
    if ("$NEED_IDMAPD" eq yes) {
if (!(!(do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('pidof', 'rpc.idmapd') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };))) {
            print "rpc.idmapd not running\n";
exit 3;
        }
    }
        print "all daemons running\n";
    exit 0;
} elsif ("$_[0]" =~ /^restart$/msx or "$_[0]" =~ /^force-reload$/msx) {
        $CHILD_ERROR = 0;
    require Time::HiRes; Time::HiRes::sleep(q{1});
        $CHILD_ERROR = 0;
} elsif (1) {
        $main_exit_code = system('log_success_msg', "Usage: nfs-common {start|stop|status|restart}") >> 8;
    exit 1;
}
exit 0;

exit $main_exit_code;
