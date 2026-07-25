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

use constant MAX_WORKERS => 8;

my $ROOT      = realpath("$FindBin::RealBin");
my $SH_DIR    = "$ROOT/sh";
my $SH2PERL   = "$ROOT/sh2perl/target/debug/debashc";
my $CHECK_QX  = "$ROOT/check_qx.pl";
my $CRITIC_WRAPPER = "$ROOT/sh2perl/perlcritic_wrapper.pl";
my $CRITIC_PROFILE = "$ROOT/sh2perl/docs/perlcritic.conf";

my $TIMEOUT_GEN    = 15;
my $TIMEOUT_QX     = 15;
my $TIMEOUT_CRITIC = 30;

for my $path ($SH2PERL, $CHECK_QX, $CRITIC_WRAPPER, $CRITIC_PROFILE) {
    die "ERROR: not found: $path\n" unless -e $path;
}
die "ERROR: sh/ not found: $SH_DIR\n" unless -d $SH_DIR;

#==============================================================================
# run_with_timeout — fork & exec with timeout, captures stdout
#==============================================================================
sub run_with_timeout {
    my ($timeout, @cmd) = @_;
    pipe(my $reader, my $writer) or die "pipe: $!";
    my $pid = fork; die "fork: $!" unless defined $pid;

    if ($pid == 0) {
        close $reader;
        open STDOUT, '>&', $writer or die "dup: $!";
        open STDERR, '>', '/dev/null' or die "devnull: $!";
        close $writer; exec @cmd; die "exec: $!\n";
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
#==============================================================================
sub process_one_file {
    my ($sh_file) = @_;
    my $name = basename($sh_file);

    my ($tmp_fh, $tmp_path) = tempfile("sh2perl-XXXXXXXX", SUFFIX => '.pl', UNLINK => 1);
    close $tmp_fh;

    my ($gen_out, $gen_exit, $gen_timed) = run_with_timeout($TIMEOUT_GEN, $SH2PERL, '-i', $sh_file, '-o', $tmp_path);
    if ($gen_timed)            { unlink $tmp_path if -f $tmp_path; return ($name, 'TIMEOUT', 'sh2perl generation'); }
    if ($gen_exit != 0 || !-s $tmp_path) {
        my $err = (split /\n/, $gen_out)[0] // "(unknown error)";
        unlink $tmp_path if -f $tmp_path;
        return ($name, 'FAIL', "sh2perl generation, exit=$gen_exit ($err)");
    }

    my ($qx_out, $qx_exit, $qx_timed) = run_with_timeout($TIMEOUT_QX, 'perl', $CHECK_QX, $tmp_path);
    if ($qx_timed)  { unlink $tmp_path if -f $tmp_path; return ($name, 'TIMEOUT', 'check_qx'); }
    if ($qx_exit != 0) {
        my @l = grep { !/^\s*$/ } split /\n/, $qx_out;
        my $d = 'check_qx'; $d .= " — $l[0]" if @l;
        unlink $tmp_path if -f $tmp_path; return ($name, 'FAIL', $d);
    }

    my ($cr_out, $cr_exit, $cr_timed) = run_with_timeout($TIMEOUT_CRITIC, 'perl', $CRITIC_WRAPPER, '--profile', $CRITIC_PROFILE, $tmp_path);
    if ($cr_timed)  { unlink $tmp_path if -f $tmp_path; return ($name, 'TIMEOUT', 'perlcritic'); }
    if ($cr_exit != 0) {
        my @l = grep { !/^\s*$/ } split /\n/, $cr_out;
        my $d = 'perlcritic'; $d .= " — $l[0]" if @l;
        unlink $tmp_path if -f $tmp_path; return ($name, 'FAIL', $d);
    }

    unlink $tmp_path if -f $tmp_path;
    return ($name, 'ok', '');
}

#==============================================================================
# MAIN — parallel via static chunking (no locking needed)
#==============================================================================
my @all_sh = sort glob("$SH_DIR/*");
my $total  = scalar @all_sh;

print "=" x 72, "\n";
printf "Checking %d .sh files in %s (%d parallel workers)\n", $total, $SH_DIR, MAX_WORKERS;
print "=" x 72, "\n\n";
$| = 1;

# Divide files into equal chunks
my @chunks;
my $base = int($total / MAX_WORKERS);
my $rem  = $total % MAX_WORKERS;
my $pos  = 0;
for my $w (0 .. MAX_WORKERS - 1) {
    my $n = $base + ($w < $rem ? 1 : 0);
    push @chunks, [ @all_sh[$pos .. $pos + $n - 1] ];
    $pos += $n;
}

my $res_dir = "$ROOT/check_sh_results";
# Start fresh — remove any stale files from a killed previous run
if (-d $res_dir) {
    opendir(my $dh, $res_dir) or die "opendir $res_dir: $!";
    while (my $e = readdir $dh) { unlink "$res_dir/$e" if $e =~ /^worker_/; }
    closedir $dh;
    rmdir $res_dir;
}
mkdir $res_dir;

my @worker_pids;
for my $w (0 .. MAX_WORKERS - 1) {
    my $pid = fork; die "fork: $!" unless defined $pid;
    if ($pid == 0) {
        # Worker — process its chunk, write results to its own temp file
        my $outfile = "$res_dir/worker_${w}.txt";
        open my $wf, '>', $outfile or die "write $outfile: $!";
        for my $file (@{$chunks[$w]}) {
            my ($name, $status, $detail) = process_one_file($file);
            $detail =~ s/\t/ /g;
            print $wf "$status\t$name\t$detail\n";
        }
        close $wf;
        exit 0;
    }
    push @worker_pids, $pid;
}

# Parent: wait with progress
my $done = 0;
while ($done < MAX_WORKERS) {
    $done = 0;
    for my $pid (@worker_pids) {
        my $kid = waitpid($pid, WNOHANG);
        $done++ if $kid == $pid || $kid == -1;
    }
    # Count results files with >0 lines
    my @completed_files;
    for my $w (0 .. MAX_WORKERS - 1) {
        my $f = "$res_dir/worker_${w}.txt";
        next unless -f $f && -s $f;
        open my $cf, '<', $f or next;
        my @cl = <$cf>; close $cf;
        push @completed_files, $w if @cl > 0;
    }
    my $files_label = @completed_files ? (join ',', map { $_ + 1 } @completed_files) : 'none';
    printf "\r  progress: %d/%d workers done, filesets: [%s]", $done, MAX_WORKERS, $files_label;
    sleep 1 if $done < MAX_WORKERS;
}
print "\n";

# Collect results from all workers
my (%by_name, $passed, $failed);
for my $w (0 .. MAX_WORKERS - 1) {
    my $f = "$res_dir/worker_${w}.txt";
    next unless -f $f && -s $f;  # skip missing/empty
    open my $wf, '<', $f or next;
    while (<$wf>) {
        chomp; next unless $_;
        my ($status, $name, $detail) = split /\t/, $_, 3;
        # Only keep first result per name (avoid races if chunks overlap)
        $by_name{$name} //= { status => $status, detail => $detail // '' };
    }
    close $wf;
    unlink $f;
}
rmdir $res_dir;

# Display results in sorted filename order (deterministic)
my $idx = 0;
for my $name (sort keys %by_name) {
    my $r = $by_name{$name}; $idx++;
    if ($r->{status} ne 'ok') {
        $failed++;
        my $short = $r->{detail};
        $short =~ s/\s*\(.*//;
        printf "[%d] %s ... %s (%s)\n", $idx, $name, $r->{status}, $short;
        print "       $r->{detail}\n" if $r->{detail};
    } else {
        printf "[%d] %s ... %s\n", $idx, $name, $r->{status};
        $passed++;
    }
}
# Warn about missing files (worker may have crashed)
my $missing = $total - scalar(keys %by_name);
if ($missing) {
    printf "  (warning: %d files have no result — worker may have crashed)\n", $missing;
}

printf "\n%s\nSUMMARY: %d tested, %d passed, %d failed\n%s\n",
    '=' x 72, $total, $passed, $failed, '=' x 72;

exit $failed;
