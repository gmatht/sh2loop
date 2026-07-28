#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy move);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $MARK;
my @MARK;
my %MARK;
my $ubuntu_pass;
my @ubuntu_pass;
my %ubuntu_pass;
my $val;
my @val;
my %val;
my $dev;
my @dev;
my %dev;

my $KEY;
my @KEY;
my %KEY;
$KEY = "xupdate";
my $UMOUNT;
my @UMOUNT;
my %UMOUNT;
$UMOUNT = "";
my $RMDIR;
my @RMDIR;
my %RMDIR;
$RMDIR = "";
$MARK = '/var/lib/cloud/sem/uncloud-init.once';
my $ROOT_RW;
my @ROOT_RW;
my %ROOT_RW;
$ROOT_RW = "";

sub doexec {
if ("$ROOT_RW" ne q{}) {
        use File::Path qw(make_path);
        my $err;
        if ( !-d ( ( dirname(${MARK}) ) =~ s|/[^/]*$||sr ) ) {
            make_path( ( ( dirname(${MARK}) ) =~ s|/[^/]*$||sr ), { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . ( ( dirname(${MARK}) ) =~ s|/[^/]*$||sr ) . ": $err->[0]\n";
            }
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', ${MARK}
      or die "Cannot open file: $OS_ERROR\n";
my $date = do {
require POSIX; POSIX::strftime('%a %b %e %H:%M:%S %Z %Y', localtime(time())) . "\n"
};
print $date;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    $main_exit_code = system('bash', 'cleanup') >> 8;
    $main_exit_code = system('log', "invoking /sbin/init @ARGV") >> 8;
# Builtin command 'exec' not implemented
    return;
}

sub log {
    do {
    my $__echo_line = "::" . ( ( basename($_[0]) ) =~ s|^.*/||sr ) . ":" . q{ } . @ARGV;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}

sub cleanup {
    if (!("${UMOUNT}" eq q{})) {
                    if (do {
$main_exit_code = system('umount', ${UMOUNT}) >> 8;
                $CHILD_ERROR == 0
            }) {
                undef $UMOUNT;
delete $ENV{UMOUNT};
            }
    }
    if (!("${RMDIR}" eq q{})) {
                    if (do {
do { my $rm_cmd_str = 'rm -Rf "${RMDIR}"'; system $rm_cmd_str; };
                $CHILD_ERROR == 0
            }) {
                undef $RMDIR;
delete $ENV{RMDIR};
            }
    }
    if (!("${ROOT_RW}" eq q{})) {
                    $main_exit_code = system('mount', '-o', 'remount,ro', q{/}) >> 8;
undef $ROOT_RW;
delete $ENV{ROOT_RW};
    }
    return;
}

sub updateFrom {
    my $dev = $_[0];
    my $fmt = $_[1];
    my $mp = "";
    if (!(("${fmt}" eq "tar" || "${fmt}" eq "mnt"))) {
                    log('FAIL', "unknown format " . ${fmt});
return q{1};
    }
    log('INFO', "updating from " . ${dev} . " format " . ${fmt});
    if (((!-e "${dev}") && (-e "/dev/${dev}"))) {
                $dev = "/dev/" . ${dev};
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if (!((-e "${dev}"))) {
                    do {
    my $__echo_line = "no file $dev";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
return q{2};
    }
        if (do {
$mp = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'mktemp', '-d', (defined (defined ($ENV{TEMPDIR} // q{}) && ($ENV{TEMPDIR} // q{}) ne q{} ? ($ENV{TEMPDIR} // q{}) : '/tmp') && (defined ($ENV{TEMPDIR} // q{}) && ($ENV{TEMPDIR} // q{}) ne q{} ? ($ENV{TEMPDIR} // q{}) : '/tmp') ne q{} ? (defined ($ENV{TEMPDIR} // q{}) && ($ENV{TEMPDIR} // q{}) ne q{} ? ($ENV{TEMPDIR} // q{}) : '/tmp') : '/tmp') . "/update.XXXXXX");
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
        $CHILD_ERROR == 0
    }) {
                $RMDIR = ${mp};
    }
    if ($CHILD_ERROR != 0) {
                    log('FAIL', "failed to mktemp");
return q{1};
    }
if ("$fmt" eq "tar") {
        {
            my $output_3 = q{};
            my $output_printed_3;
            my $pipeline_success_3 = 1;
                        my ($in_4, $out_4);
            my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'dd', );
            close $in_4 or croak 'Close failed: $OS_ERROR';
            $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
            close $out_4 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_4, 0;

                        $output_3 = q{};
            my @_pcmd_6 = ('sh', '-c', 'tar -C "${mp}" -xf -');
            my ($in_5, $out_5);
            my $pid_5 = open3($in_5, $out_5, '>&STDERR', @_pcmd_6);
            close $in_5 or croak 'Close failed: $OS_ERROR';
            $output_3 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
            close $out_5 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_5, 0;
            if ($output_3 ne q{} && !defined $output_printed_3) {
                print $output_3;
                if (!($output_3 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
            }
        if ($CHILD_ERROR != 0) {
                            log('FAIL', "failed to extract " . ${dev});
return q{1};
        }
}
    else {
        if ("$fmt" eq "mnt") {
                        if (do {
$main_exit_code = system('mount', '-o', 'ro', ${dev}, ${mp}) >> 8;
                $CHILD_ERROR == 0
            }) {
                                $UMOUNT = $mp;
            }
            if ($CHILD_ERROR != 0) {
                                    log('FAIL', "failed mount " . ${mp});
return q{1};
            }
}
        else {
            log('FAIL', "unknown format " . ${fmt});
return q{1};
        }
    }
if ((-d "${mp}/updates")) {
                $main_exit_code = system('rsync', '-av', ${mp} . "/updates/", "/") >> 8;
        if ($CHILD_ERROR != 0) {
                            log('FAIL', "failed rsync updates/ /");
return q{1};
        }
    }
if ((-f "${mp}/updates.tar")) {
                $main_exit_code = system('tar', '-C', q{/}, '-x', 'vf', ${mp} . "/updates.tar") >> 8;
        if ($CHILD_ERROR != 0) {
                            log('FAIL', "failed tar -C / -xvf " . ${mp} . "/updates.tar");
return q{1};
        }
    }
    my $script;
    my @script;
    my %script;
    $script = ${mp} . "/updates.script";
if (((-f "${script}") && (-x "${script}"))) {
        my $MP_DIR;
        my @MP_DIR;
        my %MP_DIR;
        $MP_DIR = $mp;
                $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) {
                            log('FAIL', "failed to run updates.script");
return q{1};
        }
    }
    return;
}

sub fail {
            if ((scalar(@ARGV) == 0)) {
                        log("FAILING");
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    if ($CHILD_ERROR != 0) {
                log("@ARGV");
    }
exit 1;
    return;
}
if (((-s "$MARK") > 0)) {
            log("already updated");
        doexec("@ARGV");
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
$main_exit_code = system('mount', '-o', 'remount,rw', q{/}) >> 8;
if ($CHILD_ERROR != 0) {
        fail("failed to mount rw");
}
$ROOT_RW = q{1};
if ((!-e /proc/cmdline)) {
    $main_exit_code = system('mount', '-t', 'proc', '/proc', '/proc') >> 8;
open STDIN, '<', '/proc/cmdline' or croak "Cannot open file: $OS_ERROR\n";
$cmdline = <>;
chomp $cmdline;
$CHILD_ERROR = defined($cmdline) ? 0 : 1;
    $main_exit_code = system('umount', '/proc') >> 8;
}
else {
open STDIN, '<', '/proc/cmdline' or croak "Cannot open file: $OS_ERROR\n";
$cmdline = <>;
chomp $cmdline;
$CHILD_ERROR = defined($cmdline) ? 0 : 1;
}
$ubuntu_pass = "";
my $x;
for my $x ($cmdline) {
if ("$x" =~ /^${KEY}=.*$/msx) {
                $val = ${x} =~ s/^\$\{KEY//r;
                $CHILD_ERROR = 0;
                $dev = scalar reverse( (scalar reverse ${val}) =~ s/^.*?://r );
                        if ("${dev}" eq "${val}") {
                        my $fmt;
            my @fmt;
            my %fmt;
            $fmt = "";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
                        $fmt = ${val} =~ s/^\$\{dev//r;
            $main_exit_code = system('bash', ':}') >> 8;
        }
                log("update from " . ${dev} . "," . ${fmt});
                        updateFrom(${dev}, ${fmt});
        if ($CHILD_ERROR != 0) {
                        fail("update failed");
        }
                log("end update  " . ${dev} . "," . ${fmt});
    } elsif ("$x" =~ /^ubuntu-pass=.*$/msx or "$x" =~ /^ubuntu_pass=.*$/msx) {
                $ubuntu_pass = ${x} =~ s/^.*?=//r;
    } elsif ("$x" =~ /^helpmount$/msx) {
                my $helpmount;
        my @helpmount;
        my %helpmount;
        $helpmount = q{1};
    } elsif ("$x" =~ /^root=.*$/msx) {
                my $rootspec;
        my @rootspec;
        my %rootspec;
        $rootspec = ${x} =~ s/^root=//r;
    }
}
if (("${ubuntu_pass}" eq "R" || "${ubuntu_pass}" eq "random")) {
    $ubuntu_pass = do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'python', '-c', "import string, random;\nrandom.seed(); print \"\".join(random.sample(string.letters+string.digits, 8))");
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
};
    log("setting ubuntu pass = " . ${ubuntu_pass});
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/ttyS0'
      or die "Cannot open file: $OS_ERROR\n";
printf("\n===\nubuntu_pass = %s\n===\n", ${ubuntu_pass});
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
if (!("${ubuntu_pass}" eq q{})) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/root/ubuntu-user-pass'
      or die "Cannot open file: $OS_ERROR\n";
printf("ubuntu:%s\n", ${ubuntu_pass});
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
if ((-e '/root/ubuntu-user-pass')) {
    log("changing ubuntu user's password!");
    open STDIN, '<', '/root/ubuntu-user-pass' or croak "Cannot open file: $OS_ERROR\n";
    $main_exit_code = system('bash', 'chpasswd') >> 8;
    if ($CHILD_ERROR != 0) {
                log("FAIL: failed changing pass");
    }
}
if (do {
if (do {
use File::Copy qw(copy);
if ( -e '/etc/init/tty2.conf' ) {
    if ( -d '/etc/init/ttyS0.conf' ) {
        require File::Copy; File::Copy::copy('/etc/init/tty2.conf', '/etc/init/ttyS0.conf' . '/' . ('/etc/init/tty2.conf' =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy('/etc/init/tty2.conf', '/etc/init/ttyS0.conf');
    }
} else {
    croak "cp: cannot stat '/etc/init/tty2.conf': No such file or directory\n";
}
    $CHILD_ERROR == 0
}) {
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my @sed_lines_13 = split /\n/msx, $;
my @sed_result_13;
foreach my $line (@sed_lines_13) {
chomp $line;
push @sed_result_13, $line;
}
$ = join "\n", @sed_result_13;

    };
}
    $CHILD_ERROR == 0
}) {
        log("enabled console on ttyS0");
}
my $pa;
my @pa;
my %pa;
$pa = 'PasswordAuthentication';
if (do {
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my @sed_lines_14 = split /\n/msx, $;
my @sed_result_14;
foreach my $line (@sed_lines_14) {
chomp $line;
push @sed_result_14, $line;
}
$ = join "\n", @sed_result_14;

    };
} == 0) {
        log("enabled passwd auth in ssh");
}
if ($CHILD_ERROR != 0) {
        log("failed to enable passwd ssh");
}
my $grep_result_15;
my @grep_lines_15 = ();
my @grep_filenames_15 = ();
if (-e "/etc/modprobe.d/blacklist.conf") {
    open my $fh, '<', "/etc/modprobe.d/blacklist.conf" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_15, $line;
        push @grep_filenames_15, "/etc/modprobe.d/blacklist.conf";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/modprobe.d/blacklist.conf: No such file or directory\n"; }
my @grep_filtered_15 = grep { /vga16fb/msx } @grep_lines_15;
$grep_result_15 = join "\n", @grep_filtered_15;
if (!($grep_result_15 =~ m{\n\z}msx || $grep_result_15 eq q{})) {
    $grep_result_15 .= "\n";
}
$CHILD_ERROR = scalar @grep_filtered_15 > 0 ? 0 : 1;
$grep_result_15 = q{};
if ($CHILD_ERROR != 0) {
            if (do {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', '/etc/modprobe.d/blacklist.conf'
      or die "Cannot open file: $OS_ERROR\n";
                print "blacklist vga16fb\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        } == 0) {
                        log("blacklisted vga16fb");
        }
}
doexec("@ARGV");

exit $main_exit_code;
