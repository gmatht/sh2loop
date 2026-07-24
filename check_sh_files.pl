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
# Iterates over all *.sh scripts in the sh/ directory and checks that:
#   1. sh2perl can generate Perl from the .sh file
#   2. The generated Perl passes check_qx.pl (no builtin abuse)
#   3. The generated Perl passes Perl::Critic checks
#
# Does NOT run/execute the .sh files themselves.
#
# Each subprocess is timed out to prevent hangs.
#==============================================================================

my $ROOT      = realpath("$FindBin::RealBin");
my $SH_DIR    = "$ROOT/sh";
my $SH2PERL   = "$ROOT/sh2perl/target/debug/debashc";
my $CHECK_QX  = "$ROOT/check_qx.pl";
my $CRITIC_WRAPPER = "$ROOT/sh2perl/perlcritic_wrapper.pl";
my $CRITIC_PROFILE = "$ROOT/sh2perl/docs/perlcritic.conf";

# Per-step timeouts (seconds)
my $TIMEOUT_GEN   = 15;
my $TIMEOUT_QX    = 15;
my $TIMEOUT_CRITIC = 30;

# Check prerequisites
for my $path ($SH2PERL, $CHECK_QX, $CRITIC_WRAPPER, $CRITIC_PROFILE) {
    if (!-e $path) {
        die "ERROR: Required file not found: $path\n";
    }
}
if (!-d $SH_DIR) {
    die "ERROR: sh/ directory not found: $SH_DIR\n";
}

#------------------------------------------------------------------------------
# run_with_timeout( $timeout, @cmd ) -> ($output, $exit_code, $timed_out)
#
# Forks a child to run @cmd.  If the child does not exit within $timeout
# seconds it is killed.  Returns (stdout_text, exit_code, timed_out_flag).
#
# Child stdout is captured; stderr is inherited from the parent (so the
# user can see e.g. parse errors from debashc).
#------------------------------------------------------------------------------
sub run_with_timeout {
    my ($timeout, @cmd) = @_;

    # Create a pipe to capture child's stdout
    pipe(my $reader, my $writer) or die "pipe: $!";

    my $pid = fork;
    if (!defined $pid) {
        die "fork failed: $!\n";
    }

    if ($pid == 0) {
        # Child
        close $reader;
        open STDOUT, '>&', $writer or die "dup stdout: $!";
        open STDERR, '>', '/dev/null' or die "devnull: $!";
        close $writer;
        exec @cmd;
        die "exec @cmd failed: $!\n";
    }

    # Parent
    close $writer;
    my $output = '';
    my $timed_out = 0;
    my $reaped = 0;
    my $start = time;

    # Use select() to read from the pipe while also polling for timeout
    my $rin = '';
    vec($rin, fileno($reader), 1) = 1;

    while (1) {
        my $remaining = $timeout - (time - $start);
        if ($remaining <= 0) {
            $timed_out = 1;
            kill('TERM', $pid);
            sleep(0.2);
            kill('KILL', $pid) if kill(0, $pid);
            waitpid($pid, 0);
            $reaped = 1;
            last;
        }

        # Check if child has exited (non-blocking)
        my $kid = waitpid($pid, WNOHANG);
        if ($kid == $pid) {
            $reaped = 1;
            # Drain remaining output from the child (it may have closed
            # the pipe before exiting, but there could be buffered data).
            my $buf;
            while (sysread($reader, $buf, 8192)) {
                $output .= $buf;
            }
            last;
        }

        # Try to read from the pipe with a short timeout
        my $nfound = select(my $rout = $rin, undef, undef, 0.1);
        if ($nfound > 0) {
            my $buf;
            my $n = sysread($reader, $buf, 8192);
            last if !defined $n || $n == 0;  # EOF
            $output .= $buf;
        }
    }

    close $reader;

    # If the child wasn't reaped yet (shouldn't happen, but be safe)
    if (!$reaped) {
        waitpid($pid, 0);
    }

    my $exit_code = $? >> 8;
    return ($output, $exit_code, $timed_out);
}

#------------------------------------------------------------------------------
# run_cmd_capture( @cmd ) -> ($output, $exit_code)
# Captures stdout only (stderr remains visible).
#------------------------------------------------------------------------------
sub run_cmd_capture {
    my (@cmd) = @_;
    my $pid = open(my $fh, '-|');
    if (!defined $pid) {
        die "fork: $!\n";
    }
    if ($pid == 0) {
        # Child: stdout to parent, stderr to /dev/null
        open STDERR, '>', '/dev/null' or die "devnull: $!";
        exec @cmd;
        die "exec @cmd failed: $!\n";
    }
    my $output = '';
    while (<$fh>) {
        $output .= $_;
    }
    close $fh;
    my $exit_code = $? >> 8;
    return ($output, $exit_code);
}

#==============================================================================
# Main loop
#==============================================================================
my $total     = 0;
my $passed    = 0;
my $failed    = 0;
my $skipped   = 0;

# Collect all .sh files (sorted, for reproducible order)
my @sh_files = sort glob("$SH_DIR/*.sh");

print "=" x 72, "\n";
print "Checking all .sh files in $SH_DIR\n";
print "Found " . scalar(@sh_files) . " scripts to check.\n";
print "=" x 72, "\n\n";

for my $sh_file (@sh_files) {
    my $name = basename($sh_file);
    $total++;

    print "[$total] $name ... ";

    # --- Step 1: Generate Perl with sh2perl ---
    my ($tmp_fh, $tmp_path) = tempfile("sh2perl-XXXXXXXX", SUFFIX => '.pl', UNLINK => 1)
        or die "Cannot create temp file: $!\n";
    close $tmp_fh;

    my ($gen_out, $gen_exit, $gen_timed) = run_with_timeout(
        $TIMEOUT_GEN,
        $SH2PERL, '-i', $sh_file, '-o', $tmp_path
    );

    if ($gen_timed) {
        print "TIMEOUT (sh2perl generation)\n";
        unlink $tmp_path if -f $tmp_path;
        $failed++;
        next;
    }

    if ($gen_exit != 0 || !-s $tmp_path) {
        # Parse error: report the first line of error output if any
        my $err_line = (split /\n/, $gen_out)[0] // "(unknown error)";
        print "FAIL (sh2perl generation, exit=$gen_exit)\n";
        print "       $err_line\n" if $err_line;
        unlink $tmp_path if -f $tmp_path;
        $failed++;
        next;
    }

    # --- Step 2: Run check_qx.pl ---
    my ($qx_out, $qx_exit, $qx_timed) = run_with_timeout(
        $TIMEOUT_QX,
        'perl', $CHECK_QX, $tmp_path
    );

    if ($qx_timed) {
        print "TIMEOUT (check_qx)\n";
        unlink $tmp_path if -f $tmp_path;
        $failed++;
        next;
    }

    if ($qx_exit != 0) {
        print "FAIL (check_qx)\n";
        for my $line (split /\n/, $qx_out) {
            next if $line =~ /^\s*$/;
            print "       $line\n";
        }
        unlink $tmp_path if -f $tmp_path;
        $failed++;
        next;
    }

    # --- Step 3: Run Perl::Critic ---
    my ($cr_out, $cr_exit, $cr_timed) = run_with_timeout(
        $TIMEOUT_CRITIC,
        'perl', $CRITIC_WRAPPER, '--profile', $CRITIC_PROFILE, $tmp_path
    );

    if ($cr_timed) {
        print "TIMEOUT (perlcritic)\n";
        unlink $tmp_path if -f $tmp_path;
        $failed++;
        next;
    }

    if ($cr_exit != 0) {
        print "FAIL (perlcritic)\n";
        for my $line (split /\n/, $cr_out) {
            next if $line =~ /^\s*$/;
            print "       $line\n";
        }
        unlink $tmp_path if -f $tmp_path;
        $failed++;
        next;
    }

    # --- All checks passed ---
    print "ok\n";
    $passed++;
    unlink $tmp_path if -f $tmp_path;
}

# Summary
print "\n" . "=" x 72, "\n";
printf "SUMMARY: %d tested, %d passed, %d failed\n", $total, $passed, $failed;
print "=" x 72, "\n";

exit $failed;
