#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $SA_FILE;
my @SA_FILE;
my %SA_FILE;
my $XSLTFILE;
my @XSLTFILE;
my %XSLTFILE;
my $UNCOMPRESSED_SA_FILE;
my @UNCOMPRESSED_SA_FILE;
my %UNCOMPRESSED_SA_FILE;
my $GNUPLOTFILE;
my @GNUPLOTFILE;
my %GNUPLOTFILE;
my $DATAFILE;
my @DATAFILE;
my %DATAFILE;
my $DONE;
my @DONE;
my %DONE;

$__set_e = 1;
my $ZENITY;
my @ZENITY;
my %ZENITY;
$ZENITY = do { my $which_cmd = 'which zenity'; my $which_output = qx{$which_cmd}; $CHILD_ERROR = $? >> 8; $which_output; };
my $XSLTPROC;
my @XSLTPROC;
my %XSLTPROC;
$XSLTPROC = do { my $which_cmd = 'which xsltproc'; my $which_output = qx{$which_cmd}; $CHILD_ERROR = $? >> 8; $which_output; };
my $SADF;
my @SADF;
my %SADF;
$SADF = do { my $which_cmd = 'which sadf'; my $which_output = qx{$which_cmd}; $CHILD_ERROR = $? >> 8; $which_output; };
my $GNUPLOT;
my @GNUPLOT;
my %GNUPLOT;
$GNUPLOT = do { my $which_cmd = 'which gnuplot'; my $which_output = qx{$which_cmd}; $CHILD_ERROR = $? >> 8; $which_output; };
my $MKTEMP;
my @MKTEMP;
my %MKTEMP;
$MKTEMP = do { my $which_cmd = 'which mktemp'; my $which_output = qx{$which_cmd}; $CHILD_ERROR = $? >> 8; $which_output; };
my $FIND;
my @FIND;
my %FIND;
$FIND = do { my $which_cmd = 'which find'; my $which_output = qx{$which_cmd}; $CHILD_ERROR = $? >> 8; $which_output; };
my $SORT;
my @SORT;
my %SORT;
$SORT = do { my $which_cmd = 'which sort'; my $which_output = qx{$which_cmd}; $CHILD_ERROR = $? >> 8; $which_output; };
my $CUT;
my @CUT;
my %CUT;
$CUT = do { my $which_cmd = 'which cut'; my $which_output = qx{$which_cmd}; $CHILD_ERROR = $? >> 8; $which_output; };
my $GZIP;
my @GZIP;
my %GZIP;
$GZIP = do { my $which_cmd = 'which gzip'; my $which_output = qx{$which_cmd}; $CHILD_ERROR = $? >> 8; $which_output; };
# set +e not implemented
my $SA_DIR;
my @SA_DIR;
my %SA_DIR;
$SA_DIR = "/var/log/sysstat";
my $SA_REGEX;
my @SA_REGEX;
my %SA_REGEX;
$SA_REGEX = "/sa[0-9][0-9]+(\\.(gz|bz2|xz|lz|lzo))?$";
$__set_e = 1;
my $parsed_opts;
my @parsed_opts;
my %parsed_opts;
$parsed_opts = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'getopt', '-o', "", '-l', 'sa-dir:', '--', "@ARGV");
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
do { my $eval_input = "set" . "--" . $parsed_opts; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
$DONE = 'no';
while ( $DONE ne yes ) {
if ($arg1 =~ /^--sa-dir$/msx) {
        # Builtin command 'shift' not implemented
                $SA_DIR = "$_[0]";
    } elsif ($arg1 =~ /^--$/msx) {
                $DONE = 'yes';
    } elsif (1) {
                do {
    my $__echo_line = 'Unexpected' . q{ } . 'argument:' . q{ } . $1;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        exit 1;
    }
# Builtin command 'shift' not implemented
}
# set +e not implemented

sub cpu_xslt {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "<xsl:stylesheet version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\">
<xsl:strip-space elements=\"*\"/>
<xsl:template match=\"/sysstat/host/statistics\">
<xsl:text>&#10;</xsl:text>
<xsl:for-each select=\"timestamp\">
<xsl:value-of select=\"@time\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./cpu-load/cpu[@number='all']/@user\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./cpu-load/cpu[@number='all']/@nice\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./cpu-load/cpu[@number='all']/@system\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./cpu-load/cpu[@number='all']/@iowait\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./cpu-load/cpu[@number='all']/@steal\"/>
<xsl:text>&#10;</xsl:text>
</xsl:for-each>
</xsl:template>
</xsl:stylesheet>
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub cpu_gnuplot {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "set term x11
set title \"sar -u\"
set ylabel \"Percent\"
set timefmt \"%H:%M:%S\"
set xdata time
set format x \"%H:%M\"
plot \"$2\" using 1:2 t \"%user\" with line, \"$2\" using 1:3 t \"%nice\" with line, \"$2\" using 1:4 t \"%system\" with line, \"$2\" using 1:5 t \"%iowait\" with line, \"$2\" using 1:6 t \"%steal\" with line
pause mouse
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub rq_xslt {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "<xsl:stylesheet version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\">
<xsl:strip-space elements=\"*\"/>
<xsl:template match=\"/sysstat/host/statistics\">
<xsl:text>&#10;</xsl:text>
<xsl:for-each select=\"timestamp\">
<xsl:value-of select=\"@time\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./queue/@runq-sz\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./queue/@plist-sz\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./queue/@ldavg-1\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./queue/@ldavg-5\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./queue/@ldavg-15\"/>
<xsl:text>&#10;</xsl:text>
</xsl:for-each>
</xsl:template>
</xsl:stylesheet>
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub rq_gnuplot {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "set term x11
set title \"sar -q\"
set ylabel \"\"
set timefmt \"%H:%M:%S\"
set xdata time
set format x \"%H:%M\"
plot \"$2\" using 1:2 t \"runq-sz\" with line, \"$2\" using 1:3 t \"plist-sz\" with line, \"$2\" using 1:4 t \"ldavg-1\" with line, \"$2\" using 1:5 t \"ldavg-5\" with line, \"$2\" using 1:6 t \"ldavg-15\" with line
pause mouse
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub rqnoplistsz_xslt {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "<xsl:stylesheet version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\">
<xsl:strip-space elements=\"*\"/>
<xsl:template match=\"/sysstat/host/statistics\">
<xsl:text>&#10;</xsl:text>
<xsl:for-each select=\"timestamp\">
<xsl:value-of select=\"@time\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./queue/@runq-sz\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./queue/@ldavg-1\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./queue/@ldavg-5\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./queue/@ldavg-15\"/>
<xsl:text>&#10;</xsl:text>
</xsl:for-each>
</xsl:template>
</xsl:stylesheet>
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub rqnoplistsz_gnuplot {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "set term x11
set title \"sar -q\"
set ylabel \"\"
set timefmt \"%H:%M:%S\"
set xdata time
set format x \"%H:%M\"
plot \"$2\" using 1:2 t \"runq-sz\" with line, \"$2\" using 1:3 t \"ldavg-1\" with line, \"$2\" using 1:4 t \"ldavg-5\" with line, \"$2\" using 1:5 t \"ldavg-15\" with line
pause mouse
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub io_xslt {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "<xsl:stylesheet version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\">
<xsl:strip-space elements=\"*\"/>
<xsl:template match=\"/sysstat/host/statistics\">
<xsl:text>&#10;</xsl:text>
<xsl:for-each select=\"timestamp\">
<xsl:value-of select=\"@time\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./io/tps\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./io/io-reads/@rtps\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./io/io-writes/@wtps\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./io/io-reads/@bread\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./io/io-writes/@bwrtn\"/>
<xsl:text>&#10;</xsl:text>
</xsl:for-each>
</xsl:template>
</xsl:stylesheet>
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub io_gnuplot {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "set term x11
set title \"sar -b\"
set ylabel \"ops/s\"
set timefmt \"%H:%M:%S\"
set xdata time
set format x \"%H:%M\"
plot \"$2\" using 1:2 t \"rtps\" with line, \"$2\" using 1:3 t \"wtps\" with line, \"$2\" using 1:4 t \"bread/s\" with line,  \"$2\" using 1:5 t \"bwrtn/s\" with line
pause mouse
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub nfsclient_xslt {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "<xsl:stylesheet version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\">
<xsl:strip-space elements=\"*\"/>
<xsl:template match=\"/sysstat/host/statistics\">
<xsl:text>&#10;</xsl:text>
<xsl:for-each select=\"timestamp\">
<xsl:value-of select=\"@time\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./network/net-nfs/@call\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./network/net-nfs/@retrans\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./network/net-nfs/@read\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./network/net-nfs/@write\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./network/net-nfs/@access\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./network/net-nfs/@getatt\"/>
<xsl:text>&#10;</xsl:text>
</xsl:for-each>
</xsl:template>
</xsl:stylesheet>
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub nfsclient_gnuplot {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "set term x11
set title \"sar -n NFS\"
set ylabel \"ops/s\"
set timefmt \"%H:%M:%S\"
set xdata time
set format x \"%H:%M\"
plot \"$2\" using 1:2 t \"call/s\" with line, \"$2\" using 1:3 t \"retrans/s\" with line, \"$2\" using 1:4 t \"read/s\" with line,  \"$2\" using 1:5 t \"write/s\" with line, \"$2\" using 1:6 t \"access/s\" with line, \"$2\" using 1:7 t \"getatt/s\" with line
pause mouse
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub paging_xslt {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "<xsl:stylesheet version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\">
<xsl:strip-space elements=\"*\"/>
<xsl:template match=\"/sysstat/host/statistics\">
<xsl:text>&#10;</xsl:text>
<xsl:for-each select=\"timestamp\">
<xsl:value-of select=\"@time\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./paging/@pgpgin\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./paging/@pgpgout\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./paging/@fault\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./paging/@majflt\"/>
<xsl:text>&#10;</xsl:text>
</xsl:for-each>
</xsl:template>
</xsl:stylesheet>
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub paging_gnuplot {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "set term x11
set title \"sar -B\"
set ylabel \"pages/s\"
set timefmt \"%H:%M:%S\"
set xdata time
set format x \"%H:%M\"
plot \"$2\" using 1:2 t \"pgpgin/s\" with line, \"$2\" using 1:3 t \"pgpgout/s\" with line, \"$2\" using 1:4 t \"fault/s\" with line, \"$2\" using 1:5 t \"majflt/s\" with line
pause mouse
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub memuse_xslt {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "<xsl:stylesheet version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\">
<xsl:strip-space elements=\"*\"/>
<xsl:template match=\"/sysstat/host/statistics\">
<xsl:text>&#10;</xsl:text>
<xsl:for-each select=\"timestamp\">
<xsl:value-of select=\"@time\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./memory/memfree\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./memory/memused\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./memory/buffers\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./memory/cached\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./memory/swpfree\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./memory/swpused\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./memory/swpcad\"/>
<xsl:text>&#10;</xsl:text>
</xsl:for-each>
</xsl:template>
</xsl:stylesheet>
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub memuse_gnuplot {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "set term x11
set title \"sar -r\"
set ylabel \"kB\"
set timefmt \"%H:%M:%S\"
set xdata time
set format x \"%H:%M\"
plot \"$2\" using 1:2 t \"kbmemfree\" with line, \"$2\" using 1:3 t \"kbmemused\" with line, \"$2\" using 1:4 t \"kbbuffers\" with line, \"$2\" using 1:5 t \"kbcached\" with line, \"$2\" using 1:6 t \"swpfree\" with line, \"$2\" using 1:7 t \"swpused\" with line, \"$2\" using 1:8 t \"swpcad\" with line
pause mouse
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub swapuse_xslt {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "<xsl:stylesheet version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\">
<xsl:strip-space elements=\"*\"/>
<xsl:template match=\"/sysstat/host/statistics\">
<xsl:text>&#10;</xsl:text>
<xsl:for-each select=\"timestamp\">
<xsl:value-of select=\"@time\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./memory/swpfree\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./memory/swpused\"/>
<xsl:text> </xsl:text>
<xsl:value-of select=\"./memory/swpcad\"/>
<xsl:text>&#10;</xsl:text>
</xsl:for-each>
</xsl:template>
</xsl:stylesheet>
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub swapuse_gnuplot {
open my $fh_cat, '>', '$1' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "set term x11
set title \"sar -S\"
set ylabel \"kB\"
set timefmt \"%H:%M:%S\"
set xdata time
set format x \"%H:%M\"
plot \"$2\" using 1:2 t \"swpfree\" with line, \"$2\" using 1:3 t \"swpused\" with line, \"$2\" using 1:4 t \"swpcad\" with line
pause mouse
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}
my $SA_FILES;
my @SA_FILES;
my %SA_FILES;
$SA_FILES = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_1 = q{};
    my $output_printed_1;
    my $pipeline_success_1 = 1;

    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'unknown_command', '-type', q{f}, '-p', 'rintf', "%T@,%p\\n");
    close $in_2 or croak 'Close failed: $OS_ERROR';
    $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
    my $grep_result_1_1;
    my @grep_lines_1_1 = split /\n/msx, $output_1;
    my @grep_filtered_1_1 = grep { /$SA_REGEX/msx } @grep_lines_1_1;
    $grep_result_1_1 = join "\n", @grep_filtered_1_1;
        if (!($grep_result_1_1 =~ m{\n\z}msx || $grep_result_1_1 eq q{})) {
            $grep_result_1_1 .= "\n";
        }
    $CHILD_ERROR = scalar @grep_filtered_1_1 > 0 ? 0 : 1;
    $output_1 = $grep_result_1_1;

    my $cmd_4 = 'unknown_command';
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', $cmd_4, '-n', '-r');
    print {$in_3} $output_1;
    close $in_3 or croak 'Close failed: $OS_ERROR';
    $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;

    my $cmd_6 = 'unknown_command';
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', $cmd_6, '-d', q{,}, '-f', q{2});
    print {$in_5} $output_1;
    close $in_5 or croak 'Close failed: $OS_ERROR';
    $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_1 =~ s/\n+\z//msx;
    $output_1;
}; $_pipeline_result; };
$DONE = 'no';
while ( $DONE ne yes ) {
    $SA_FILE = do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', $ZENITY, '--list', '--text', "Select data source", '--column', "sa file", $SA_FILES);
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
};
if ("$SA_FILE" =~ /^""$/msx) {
exit $main_exit_code;
    }
if (!(    # Original bash: echo $SA_FILE | grep '.gz$'
{
        my $output_8 = q{};
        my $output_printed_8;
        my $pipeline_success_8 = 1;
        $output_8 .= $SA_FILE . "\n";
if ( !($output_8 =~ m{\n\z}msx) ) { $output_8 .= "\n"; }
$CHILD_ERROR = 0;

                my $grep_result_8_1;
        my @grep_lines_8_1 = split /\n/msx, $output_8;
        my @grep_filtered_8_1 = grep { /.gz$/msx } @grep_lines_8_1;
        $grep_result_8_1 = join "\n", @grep_filtered_8_1;
        if (!($grep_result_8_1 =~ m{\n\z}msx || $grep_result_8_1 eq q{})) {
        $grep_result_8_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_8_1 > 0 ? 0 : 1;
        $output_8 = $grep_result_8_1;
        $output_8 = $grep_result_8_1;
        if ((scalar @grep_filtered_8_1) == 0) {
            $pipeline_success_8 = 0;
        }
        if ($output_8 ne q{} && !defined $output_printed_8) {
            print $output_8;
            if (!($output_8 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
        })) {
        $UNCOMPRESSED_SA_FILE = do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'mktemp');
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
};
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $UNCOMPRESSED_SA_FILE
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
my @results;
if (-f q{c}) {
if (q{c}.gz =~ /[\[].]gz$/msx) {
my ($in_11);
my $pid_11 = open3($in_11, $out_11, $err_11, 'gunzip', '-c', 'q{c}.gz');
close $in_11 or croak 'Close failed: $OS_ERROR';
my $decompressed = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
close $out_11 or croak 'Close failed: $OS_ERROR';
waitpid $pid_11, 0;
if (defined $decompressed) {
push @results, "Decompressed: q{c}";
} else {
push @results, "Failed to decompress: q{c}";
}
} else {
push @results, "File not compressed: q{c}";
}
} else {
push @results, "File not found: q{c}";
}
if (-f $SA_FILE) {
if ($SA_FILE.gz =~ /[\[].]gz$/msx) {
my ($in_12);
my $pid_12 = open3($in_12, $out_12, $err_12, 'gunzip', '-c', '$SA_FILE.gz');
close $in_12 or croak 'Close failed: $OS_ERROR';
my $decompressed = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
close $out_12 or croak 'Close failed: $OS_ERROR';
waitpid $pid_12, 0;
if (defined $decompressed) {
push @results, "Decompressed: $SA_FILE";
} else {
push @results, "Failed to decompress: $SA_FILE";
}
} else {
push @results, "File not compressed: $SA_FILE";
}
} else {
push @results, "File not found: $SA_FILE";
}
 = join "\n", @results;

            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $SA_FILE = $UNCOMPRESSED_SA_FILE;
    }
    my $GRAPH;
    my @GRAPH;
    my %GRAPH;
    $GRAPH = do {
    my ($in_13, $out_13);
    my $pid_13 = open3($in_13, $out_13, '>&STDERR', $ZENITY, '--list', '--text', "Select a graph", '--column', "Graph Type", "CPU", "Run Queue", "Run Queue w/o Process List Size", "IO Transfer Rate", "NFS Client", "Paging Stats", "Memory Utilization", "Memory Utilization (Swap)");
    close $in_13 or croak 'Close failed: $OS_ERROR';
    my $result_13 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
    close $out_13 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_13, 0;
    $result_13
};
if ("$GRAPH" =~ /^CPU$/msx) {
                $XSLTFILE = do {
    my ($in_14, $out_14);
    my $pid_14 = open3($in_14, $out_14, '>&STDERR', 'mktemp');
    close $in_14 or croak 'Close failed: $OS_ERROR';
    my $result_14 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_14> };
    close $out_14 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_14, 0;
    $result_14
};
                cpu_xslt($XSLTFILE);
                $DATAFILE = do {
    my ($in_15, $out_15);
    my $pid_15 = open3($in_15, $out_15, '>&STDERR', 'mktemp');
    close $in_15 or croak 'Close failed: $OS_ERROR';
    my $result_15 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_15> };
    close $out_15 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_15, 0;
    $result_15
};
                # Original bash: $SADF -t -x $SA_FILE -- -u | $XSLTPROC --novalid $XSLTFILE - > $DATAFILE
{
            my $output_16 = q{};
            my $output_printed_16;
            my $pipeline_success_16 = 1;
                        my ($in_17, $out_17);
            my $pid_17 = open3($in_17, $out_17, '>&STDERR', 'unknown_command', '-t', '-x', '--', '-u');
            close $in_17 or croak 'Close failed: $OS_ERROR';
            $output_16 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> };
            close $out_17 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_17, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $DATAFILE
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp_redirect_18 = q{};
            my $cmd_21 = 'unknown_command';
            my ($in_20, $out_20);
            my $pid_20 = open3($in_20, $out_20, '>&STDERR', $cmd_21, '--novalid', q{-});
            print {$in_20} $output_16;
            close $in_20 or croak 'Close failed: $OS_ERROR';
            $tmp_redirect_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
            close $out_20 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_20, 0;
            $tmp_redirect_18;
            $output_printed_16 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_16 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
                $GNUPLOTFILE = do {
    my ($in_22, $out_22);
    my $pid_22 = open3($in_22, $out_22, '>&STDERR', 'mktemp');
    close $in_22 or croak 'Close failed: $OS_ERROR';
    my $result_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_22> };
    close $out_22 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_22, 0;
    $result_22
};
                cpu_gnuplot($GNUPLOTFILE, $DATAFILE);
                $CHILD_ERROR = 0;
    } elsif ("$GRAPH" =~ /^Run Queue$/msx) {
                $XSLTFILE = do {
    my ($in_23, $out_23);
    my $pid_23 = open3($in_23, $out_23, '>&STDERR', 'mktemp');
    close $in_23 or croak 'Close failed: $OS_ERROR';
    my $result_23 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
    close $out_23 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_23, 0;
    $result_23
};
                rq_xslt($XSLTFILE);
                $DATAFILE = do {
    my ($in_24, $out_24);
    my $pid_24 = open3($in_24, $out_24, '>&STDERR', 'mktemp');
    close $in_24 or croak 'Close failed: $OS_ERROR';
    my $result_24 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_24> };
    close $out_24 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_24, 0;
    $result_24
};
                # Original bash: $SADF -t -x $SA_FILE -- -q | $XSLTPROC --novalid $XSLTFILE - > $DATAFILE
{
            my $output_25 = q{};
            my $output_printed_25;
            my $pipeline_success_25 = 1;
                        my ($in_26, $out_26);
            my $pid_26 = open3($in_26, $out_26, '>&STDERR', 'unknown_command', '-t', '-x', '--', '-q');
            close $in_26 or croak 'Close failed: $OS_ERROR';
            $output_25 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_26> };
            close $out_26 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_26, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $DATAFILE
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp_redirect_27 = q{};
            my $cmd_30 = 'unknown_command';
            my ($in_29, $out_29);
            my $pid_29 = open3($in_29, $out_29, '>&STDERR', $cmd_30, '--novalid', q{-});
            print {$in_29} $output_25;
            close $in_29 or croak 'Close failed: $OS_ERROR';
            $tmp_redirect_27 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_29> };
            close $out_29 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_29, 0;
            $tmp_redirect_27;
            $output_printed_25 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_25 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
                $GNUPLOTFILE = do {
    my ($in_31, $out_31);
    my $pid_31 = open3($in_31, $out_31, '>&STDERR', 'mktemp');
    close $in_31 or croak 'Close failed: $OS_ERROR';
    my $result_31 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
    close $out_31 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_31, 0;
    $result_31
};
                rq_gnuplot($GNUPLOTFILE, $DATAFILE);
                $CHILD_ERROR = 0;
    } elsif ("$GRAPH" =~ /^Run Queue w/o Process List Size$/msx) {
                $XSLTFILE = do {
    my ($in_32, $out_32);
    my $pid_32 = open3($in_32, $out_32, '>&STDERR', 'mktemp');
    close $in_32 or croak 'Close failed: $OS_ERROR';
    my $result_32 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_32> };
    close $out_32 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_32, 0;
    $result_32
};
                rqnoplistsz_xslt($XSLTFILE);
                $DATAFILE = do {
    my ($in_33, $out_33);
    my $pid_33 = open3($in_33, $out_33, '>&STDERR', 'mktemp');
    close $in_33 or croak 'Close failed: $OS_ERROR';
    my $result_33 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_33> };
    close $out_33 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_33, 0;
    $result_33
};
                # Original bash: $SADF -t -x $SA_FILE -- -q | $XSLTPROC --novalid $XSLTFILE - > $DATAFILE
{
            my $output_34 = q{};
            my $output_printed_34;
            my $pipeline_success_34 = 1;
                        my ($in_35, $out_35);
            my $pid_35 = open3($in_35, $out_35, '>&STDERR', 'unknown_command', '-t', '-x', '--', '-q');
            close $in_35 or croak 'Close failed: $OS_ERROR';
            $output_34 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_35> };
            close $out_35 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_35, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $DATAFILE
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp_redirect_36 = q{};
            my $cmd_39 = 'unknown_command';
            my ($in_38, $out_38);
            my $pid_38 = open3($in_38, $out_38, '>&STDERR', $cmd_39, '--novalid', q{-});
            print {$in_38} $output_34;
            close $in_38 or croak 'Close failed: $OS_ERROR';
            $tmp_redirect_36 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_38> };
            close $out_38 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_38, 0;
            $tmp_redirect_36;
            $output_printed_34 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_34 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
                $GNUPLOTFILE = do {
    my ($in_40, $out_40);
    my $pid_40 = open3($in_40, $out_40, '>&STDERR', 'mktemp');
    close $in_40 or croak 'Close failed: $OS_ERROR';
    my $result_40 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_40> };
    close $out_40 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_40, 0;
    $result_40
};
                rqnoplistsz_gnuplot($GNUPLOTFILE, $DATAFILE);
                $CHILD_ERROR = 0;
    } elsif ("$GRAPH" =~ /^IO Transfer Rate$/msx) {
                $XSLTFILE = do {
    my ($in_41, $out_41);
    my $pid_41 = open3($in_41, $out_41, '>&STDERR', 'mktemp');
    close $in_41 or croak 'Close failed: $OS_ERROR';
    my $result_41 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_41> };
    close $out_41 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_41, 0;
    $result_41
};
                io_xslt($XSLTFILE);
                $DATAFILE = do {
    my ($in_42, $out_42);
    my $pid_42 = open3($in_42, $out_42, '>&STDERR', 'mktemp');
    close $in_42 or croak 'Close failed: $OS_ERROR';
    my $result_42 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_42> };
    close $out_42 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_42, 0;
    $result_42
};
                # Original bash: $SADF -t -x $SA_FILE -- -b | $XSLTPROC --novalid $XSLTFILE - > $DATAFILE
{
            my $output_43 = q{};
            my $output_printed_43;
            my $pipeline_success_43 = 1;
                        my ($in_44, $out_44);
            my $pid_44 = open3($in_44, $out_44, '>&STDERR', 'unknown_command', '-t', '-x', '--', '-b');
            close $in_44 or croak 'Close failed: $OS_ERROR';
            $output_43 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_44> };
            close $out_44 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_44, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $DATAFILE
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp_redirect_45 = q{};
            my $cmd_48 = 'unknown_command';
            my ($in_47, $out_47);
            my $pid_47 = open3($in_47, $out_47, '>&STDERR', $cmd_48, '--novalid', q{-});
            print {$in_47} $output_43;
            close $in_47 or croak 'Close failed: $OS_ERROR';
            $tmp_redirect_45 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_47> };
            close $out_47 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_47, 0;
            $tmp_redirect_45;
            $output_printed_43 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_43 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
                $GNUPLOTFILE = do {
    my ($in_49, $out_49);
    my $pid_49 = open3($in_49, $out_49, '>&STDERR', 'mktemp');
    close $in_49 or croak 'Close failed: $OS_ERROR';
    my $result_49 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_49> };
    close $out_49 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_49, 0;
    $result_49
};
                io_gnuplot($GNUPLOTFILE, $DATAFILE);
                $CHILD_ERROR = 0;
    } elsif ("$GRAPH" =~ /^NFS Client$/msx) {
                $XSLTFILE = do {
    my ($in_50, $out_50);
    my $pid_50 = open3($in_50, $out_50, '>&STDERR', 'mktemp');
    close $in_50 or croak 'Close failed: $OS_ERROR';
    my $result_50 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_50> };
    close $out_50 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_50, 0;
    $result_50
};
                nfsclient_xslt($XSLTFILE);
                $DATAFILE = do {
    my ($in_51, $out_51);
    my $pid_51 = open3($in_51, $out_51, '>&STDERR', 'mktemp');
    close $in_51 or croak 'Close failed: $OS_ERROR';
    my $result_51 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_51> };
    close $out_51 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_51, 0;
    $result_51
};
                # Original bash: $SADF -t -x $SA_FILE -- -n NFS | $XSLTPROC --novalid $XSLTFILE - > $DATAFILE
{
            my $output_52 = q{};
            my $output_printed_52;
            my $pipeline_success_52 = 1;
                        my ($in_53, $out_53);
            my $pid_53 = open3($in_53, $out_53, '>&STDERR', 'unknown_command', '-t', '-x', '--', '-n', 'NFS');
            close $in_53 or croak 'Close failed: $OS_ERROR';
            $output_52 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_53> };
            close $out_53 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_53, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $DATAFILE
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp_redirect_54 = q{};
            my $cmd_57 = 'unknown_command';
            my ($in_56, $out_56);
            my $pid_56 = open3($in_56, $out_56, '>&STDERR', $cmd_57, '--novalid', q{-});
            print {$in_56} $output_52;
            close $in_56 or croak 'Close failed: $OS_ERROR';
            $tmp_redirect_54 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_56> };
            close $out_56 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_56, 0;
            $tmp_redirect_54;
            $output_printed_52 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_52 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
                $GNUPLOTFILE = do {
    my ($in_58, $out_58);
    my $pid_58 = open3($in_58, $out_58, '>&STDERR', 'mktemp');
    close $in_58 or croak 'Close failed: $OS_ERROR';
    my $result_58 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_58> };
    close $out_58 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_58, 0;
    $result_58
};
                nfsclient_gnuplot($GNUPLOTFILE, $DATAFILE);
                $CHILD_ERROR = 0;
    } elsif ("$GRAPH" =~ /^Paging Stats$/msx) {
                $XSLTFILE = do {
    my ($in_59, $out_59);
    my $pid_59 = open3($in_59, $out_59, '>&STDERR', 'mktemp');
    close $in_59 or croak 'Close failed: $OS_ERROR';
    my $result_59 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_59> };
    close $out_59 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_59, 0;
    $result_59
};
                paging_xslt($XSLTFILE);
                $DATAFILE = do {
    my ($in_60, $out_60);
    my $pid_60 = open3($in_60, $out_60, '>&STDERR', 'mktemp');
    close $in_60 or croak 'Close failed: $OS_ERROR';
    my $result_60 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_60> };
    close $out_60 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_60, 0;
    $result_60
};
                # Original bash: $SADF -t -x $SA_FILE -- -B | $XSLTPROC --novalid $XSLTFILE - > $DATAFILE
{
            my $output_61 = q{};
            my $output_printed_61;
            my $pipeline_success_61 = 1;
                        my ($in_62, $out_62);
            my $pid_62 = open3($in_62, $out_62, '>&STDERR', 'unknown_command', '-t', '-x', '--', '-B');
            close $in_62 or croak 'Close failed: $OS_ERROR';
            $output_61 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_62> };
            close $out_62 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_62, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $DATAFILE
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp_redirect_63 = q{};
            my $cmd_66 = 'unknown_command';
            my ($in_65, $out_65);
            my $pid_65 = open3($in_65, $out_65, '>&STDERR', $cmd_66, '--novalid', q{-});
            print {$in_65} $output_61;
            close $in_65 or croak 'Close failed: $OS_ERROR';
            $tmp_redirect_63 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_65> };
            close $out_65 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_65, 0;
            $tmp_redirect_63;
            $output_printed_61 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_61 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
                $GNUPLOTFILE = do {
    my ($in_67, $out_67);
    my $pid_67 = open3($in_67, $out_67, '>&STDERR', 'mktemp');
    close $in_67 or croak 'Close failed: $OS_ERROR';
    my $result_67 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_67> };
    close $out_67 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_67, 0;
    $result_67
};
                paging_gnuplot($GNUPLOTFILE, $DATAFILE);
                $CHILD_ERROR = 0;
    } elsif ("$GRAPH" =~ /^Memory Utilization$/msx) {
                $XSLTFILE = do {
    my ($in_68, $out_68);
    my $pid_68 = open3($in_68, $out_68, '>&STDERR', 'mktemp');
    close $in_68 or croak 'Close failed: $OS_ERROR';
    my $result_68 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_68> };
    close $out_68 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_68, 0;
    $result_68
};
                memuse_xslt($XSLTFILE);
                $DATAFILE = do {
    my ($in_69, $out_69);
    my $pid_69 = open3($in_69, $out_69, '>&STDERR', 'mktemp');
    close $in_69 or croak 'Close failed: $OS_ERROR';
    my $result_69 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_69> };
    close $out_69 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_69, 0;
    $result_69
};
                # Original bash: $SADF -t -x $SA_FILE -- -r | $XSLTPROC --novalid $XSLTFILE - > $DATAFILE
{
            my $output_70 = q{};
            my $output_printed_70;
            my $pipeline_success_70 = 1;
                        my ($in_71, $out_71);
            my $pid_71 = open3($in_71, $out_71, '>&STDERR', 'unknown_command', '-t', '-x', '--', '-r');
            close $in_71 or croak 'Close failed: $OS_ERROR';
            $output_70 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_71> };
            close $out_71 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_71, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $DATAFILE
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp_redirect_72 = q{};
            my $cmd_75 = 'unknown_command';
            my ($in_74, $out_74);
            my $pid_74 = open3($in_74, $out_74, '>&STDERR', $cmd_75, '--novalid', q{-});
            print {$in_74} $output_70;
            close $in_74 or croak 'Close failed: $OS_ERROR';
            $tmp_redirect_72 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_74> };
            close $out_74 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_74, 0;
            $tmp_redirect_72;
            $output_printed_70 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_70 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
                $GNUPLOTFILE = do {
    my ($in_76, $out_76);
    my $pid_76 = open3($in_76, $out_76, '>&STDERR', 'mktemp');
    close $in_76 or croak 'Close failed: $OS_ERROR';
    my $result_76 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_76> };
    close $out_76 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_76, 0;
    $result_76
};
                memuse_gnuplot($GNUPLOTFILE, $DATAFILE);
                $CHILD_ERROR = 0;
    } elsif ("$GRAPH" =~ /^Memory Utilization (Swap)$/msx) {
                $XSLTFILE = do {
    my ($in_77, $out_77);
    my $pid_77 = open3($in_77, $out_77, '>&STDERR', 'mktemp');
    close $in_77 or croak 'Close failed: $OS_ERROR';
    my $result_77 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_77> };
    close $out_77 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_77, 0;
    $result_77
};
                swapuse_xslt($XSLTFILE);
                $DATAFILE = do {
    my ($in_78, $out_78);
    my $pid_78 = open3($in_78, $out_78, '>&STDERR', 'mktemp');
    close $in_78 or croak 'Close failed: $OS_ERROR';
    my $result_78 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_78> };
    close $out_78 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_78, 0;
    $result_78
};
                # Original bash: $SADF -t -x $SA_FILE -- -S | $XSLTPROC --novalid $XSLTFILE - > $DATAFILE
{
            my $output_79 = q{};
            my $output_printed_79;
            my $pipeline_success_79 = 1;
                        my ($in_80, $out_80);
            my $pid_80 = open3($in_80, $out_80, '>&STDERR', 'unknown_command', '-t', '-x', '--', '-S');
            close $in_80 or croak 'Close failed: $OS_ERROR';
            $output_79 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_80> };
            close $out_80 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_80, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $DATAFILE
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp_redirect_81 = q{};
            my $cmd_84 = 'unknown_command';
            my ($in_83, $out_83);
            my $pid_83 = open3($in_83, $out_83, '>&STDERR', $cmd_84, '--novalid', q{-});
            print {$in_83} $output_79;
            close $in_83 or croak 'Close failed: $OS_ERROR';
            $tmp_redirect_81 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_83> };
            close $out_83 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_83, 0;
            $tmp_redirect_81;
            $output_printed_79 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_79 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
                $GNUPLOTFILE = do {
    my ($in_85, $out_85);
    my $pid_85 = open3($in_85, $out_85, '>&STDERR', 'mktemp');
    close $in_85 or croak 'Close failed: $OS_ERROR';
    my $result_85 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_85> };
    close $out_85 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_85, 0;
    $result_85
};
                swapuse_gnuplot($GNUPLOTFILE, $DATAFILE);
                $CHILD_ERROR = 0;
    } elsif (1) {
                $DONE = 'yes';
    }
    if ((-f "$UNCOMPRESSED_SA_FILE")) {
        if ( -e "$UNCOMPRESSED_SA_FILE" ) {
            if ( -d "$UNCOMPRESSED_SA_FILE" ) {
                croak "rm: ", $UNCOMPRESSED_SA_FILE,
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$UNCOMPRESSED_SA_FILE" ) {
                                    }
                else {
                    croak "rm: cannot remove ", $UNCOMPRESSED_SA_FILE,
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 1;
            croak "rm: ", $UNCOMPRESSED_SA_FILE, ": No such file or directory\n";
        }
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ((-f "$GNUPLOTFILE")) {
        if ( -e "$GNUPLOTFILE" ) {
            if ( -d "$GNUPLOTFILE" ) {
                croak "rm: ", $GNUPLOTFILE,
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$GNUPLOTFILE" ) {
                                    }
                else {
                    croak "rm: cannot remove ", $GNUPLOTFILE,
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 1;
            croak "rm: ", $GNUPLOTFILE, ": No such file or directory\n";
        }
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ((-f "$DATAFILE")) {
        if ( -e "$DATAFILE" ) {
            if ( -d "$DATAFILE" ) {
                croak "rm: ", $DATAFILE,
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$DATAFILE" ) {
                                    }
                else {
                    croak "rm: cannot remove ", $DATAFILE,
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 1;
            croak "rm: ", $DATAFILE, ": No such file or directory\n";
        }
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ((-f "$XSLTFILE")) {
        if ( -e "$XSLTFILE" ) {
            if ( -d "$XSLTFILE" ) {
                croak "rm: ", $XSLTFILE,
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$XSLTFILE" ) {
                                    }
                else {
                    croak "rm: cannot remove ", $XSLTFILE,
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 1;
            croak "rm: ", $XSLTFILE, ": No such file or directory\n";
        }
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
}
exit $main_exit_code;

exit $main_exit_code;
