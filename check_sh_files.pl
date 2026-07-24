#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use File::Temp qw(tempfile);
use File::Basename qw(basename);
use Cwd qw(realpath);
use POSIX qw(:sys_wait_h);

#==============================================================================
# check_sh_files.pl
#
# Checks all *.sh scripts in the sh/ directory in parallel:
#   1. sh2perl can generate Perl from the .sh file
#   2. The generated Perl passes check_qx.pl (no builtin abuse)
#   3. The generated Perl passes Perl::Critic checks
#
# Does NOT run/execute the .sh files themselves.
#==============================================================================

use constant MAX_WORKERS => 8;   # parallel worker count

my $ROOT      = realpath("$FindBin::RealBin");
my $SH_DIR    = "$ROOT/sh";
my $SH2PERL   = "$ROOT/sh2perl/target/debug/debashc";
my $CHECK_QX  = "$ROOT/check_qx.pl";
my $CRITIC_WRAPPER = "$ROOT/sh2perl/perlcritic_wrapper.pl";
my $CRITIC_PROFILE = "$ROOT/sh2perl/docs/perlcritic.conf";

# Per-step timeouts (seconds)
my $TIMEOUT_GEN    = 15;
my $TIMEOUT_QX     = 15;
my $TIMEOUT_CRITIC = 30;

for my $path ($SH2PERL, $CHECK_QX, $CRITIC_WRAPPER, $CRITIC_PROFILE) {
    die "ERROR: Required file not found: $path\n" unless -e $path;
}
die "ERROR: sh/ directory not found: $SH_DIR\n" unless -d $SH_DIR;

#==============================================================================
# run_with_timeout — fork & exec with timeout, captures stdout
#==============================================================================
sub run_with_timeout {
    my ($timeout, @cmd) = @_;
    pipe(my $reader, my $writer) or die "pipe: $!";
    my $pid = fork;
    die "fork: $!" unless defined $pid;

    if ($pid == 0) {
        close $reader;
        open STDOUT, '>&', $writer or die "dup: $!";
        open STDERR, '>', '/dev/null' or die "devnull: $!";
        close $writer;
        exec @cmd;
        die "exec failed: $!\n";
    }

    close $writer;
    my ($output, $timed_out, $reaped, $start) = ('', 0, 0, time);
    my $rin = ''; vec($rin, fileno($reader), 1) = 1;

    while (1) {
        my $remaining = $timeout - (time - $start);
        if ($remaining <= 0) {
            $timed_out = 1;
            kill('TERM', $pid); sleep(0.2);
            kill('KILL', $pid) if kill(0, $pid);
            waitpid($pid, 0); $reaped = 1; last;
        }
        my $kid = waitpid($pid, WNOHANG);
        if ($kid == $pid) {
            $reaped = 1;
            my $buf; while (sysread($reader, $buf, 8192)) { $output .= $buf; }
            last;
        }
        if (select(my $rout = $rin, undef, undef, 0.1) > 0) {
            my $buf; my $n = sysread($reader, $buf, 8192);
            last if !defined $n || $n == 0;
            $output .= $buf;
        }
    }
    close $reader;
    waitpid($pid, 0) unless $reaped;
    return ($output, $? >> 8, $timed_out);
}

#==============================================================================
# process_one_file($sh_file) -> ($name, $status, $detail)
#   status: 'ok', 'FAIL', 'TIMEOUT'
#   detail: short explanation string
#==============================================================================
sub process_one_file {
    my ($sh_file) = @_;
    my $name = basename($sh_file);

    my ($tmp_fh, $tmp_path) = tempfile("sh2perl-XXXXXXXX", SUFFIX => '.pl', UNLINK => 1);
    close $tmp_fh;

    # Step 1: Generate Perl
    my ($gen_out, $gen_exit, $gen_timed) = run_with_timeout($TIMEOUT_GEN, $SH2PERL, '-i', $sh_file, '-o', $tmp_path);
    if ($gen_timed)            { unlink $tmp_path if -f $tmp_path; return ($name, 'TIMEOUT', 'sh2perl generation'); }
    if ($gen_exit != 0 || !-s $tmp_path) {
        my $err = (split /\n/, $gen_out)[0] // "(unknown error)";
        unlink $tmp_path if -f $tmp_path;
        return ($name, 'FAIL', "sh2perl generation, exit=$gen_exit ($err)");
    }

    # Step 2: check_qx
    my ($qx_out, $qx_exit, $qx_timed) = run_with_timeout($TIMEOUT_QX, 'perl', $CHECK_QX, $tmp_path);
    if ($qx_timed)  { unlink $tmp_path if -f $tmp_path; return ($name, 'TIMEOUT', 'check_qx'); }
    if ($qx_exit != 0) {
        my @lines = grep { !/^\s*$/ } split /\n/, $qx_out;
        my $detail = 'check_qx';
        $detail .= " — $lines[0]" if @lines;
        unlink $tmp_path if -f $tmp_path;
        return ($name, 'FAIL', $detail);
    }

    # Step 3: Perl::Critic
    my ($cr_out, $cr_exit, $cr_timed) = run_with_timeout($TIMEOUT_CRITIC, 'perl', $CRITIC_WRAPPER,
        '--profile', $CRITIC_PROFILE, $tmp_path);
    if ($cr_timed)  { unlink $tmp_path if -f $tmp_path; return ($name, 'TIMEOUT', 'perlcritic'); }
    if ($cr_exit != 0) {
        my @lines = grep { !/^\s*$/ } split /\n/, $cr_out;
        my $detail = 'perlcritic';
        $detail .= " — $lines[0]" if @lines;
        unlink $tmp_path if -f $tmp_path;
        return ($name, 'FAIL', $detail);
    }

    unlink $tmp_path if -f $tmp_path;
    return ($name, 'ok', '');
}

#==============================================================================
# MAIN — parallel worker farm
#==============================================================================
my @all_sh = sort glob("$SH_DIR/*.sh");
my $total  = scalar @all_sh;
my $next_idx = 0;            # next file index to hand out (locked update)
my $result_fh;               # shared results file

# Open a temp file to collect results from workers
my ($res_fh, $res_path) = tempfile("csf-results-XXXXXXXX", UNLINK => 0);
$result_fh = $res_fh;

print "=" x 72, "\n";
printf "Checking %d .sh files in %s (%d parallel workers)\n", $total, $SH_DIR, MAX_WORKERS;
print "=" x 72, "\n\n";

# We'll write results lines as they come in.  The parent reads the file
# after all workers finish.  Use a lock file for atomic updates.
my $lock_path = "$res_path.lock";

sub get_next_file {
    my ($lock_fh);
    open $lock_fh, '>', $lock_path or die "lock: $!";
    flock($lock_fh, 2) or die "flock: $!";  # exclusive lock
    my $idx = $next_idx;
    $next_idx++ if $idx < $total;
    close $lock_fh;
    return $idx < $total ? $all_sh[$idx] : undef;
}

sub write_result {
    my ($name, $status, $detail) = @_;
    open my $lfh, '>>', $res_path or die "append: $!";
    flock($lfh, 2) or die "flock: $!";
    printf $lfh "%s\t%s\t%s\n", $status, $name, $detail;
    close $lfh;
}

# Fork workers
my @worker_pids;
for (1 .. MAX_WORKERS) {
    my $pid = fork;
    die "fork: $!" unless defined $pid;
    if ($pid == 0) {
        # Child
        close $res_fh;
        while (my $file = get_next_file()) {
            my ($name, $status, $detail) = process_one_file($file);
            write_result($name, $status, $detail);
        }
        exit 0;
    }
    push @worker_pids, $pid;
}

# Parent: wait for all workers
close $res_fh;
for my $pid (@worker_pids) {
    waitpid($pid, 0);
}
unlink $lock_path;

# Read and display results in order
open my $rfh, '<', $res_path or die "read: $!";
my @result_lines = <$rfh>;
close $rfh;
unlink $res_path;

my (%by_name, $passed, $failed);
for my $line (@result_lines) {
    chomp $line;
    my ($status, $name, $detail) = split /\t/, $line, 3;
    $by_name{$name} = { status => $status, detail => $detail };
}

# Print in original file order
my $idx = 0;
for my $sh_file (@all_sh) {
    my $name = basename($sh_file);
    $idx++;
    my $r = $by_name{$name} // { status => '?', detail => 'no result' };
    printf "[%d] %s ... %s\n", $idx, $name, $r->{status};
    if ($r->{status} ne 'ok') {
        print "       $r->{detail}\n" if $r->{detail};
        $failed++;
    } else {
        $passed++;
    }
}

printf "\n%s\nSUMMARY: %d tested, %d passed, %d failed\n%s\n",
    '=' x 72, $total, $passed, $failed, '=' x 72;

exit $failed;
