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

# readonly PYTHON not implemented in Perl
# readonly = not implemented in Perl
# readonly HERE not implemented in Perl
# readonly = not implemented in Perl
if (do {
$main_exit_code = system('test', '-f', $1) >> 8;
    $CHILD_ERROR == 0
}) {
    # Builtin command 'source' not implemented
}
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('bash', ':') >> 8;
}
if (StringInterpolation(StringInterpolation { parts: [Variable("DOCDIR")] }, None) ne q{}) {
# readonly DOCDIR not implemented in Perl
# readonly = not implemented in Perl
}
else {
# readonly DOCDIR not implemented in Perl
# readonly = not implemented in Perl
}
if (StringInterpolation(StringInterpolation { parts: [Variable("BINDIR")] }, None) ne q{}) {
# readonly BINDIR not implemented in Perl
# readonly = not implemented in Perl
}
else {
# readonly BINDIR not implemented in Perl
# readonly = not implemented in Perl
}
# readonly DATADIR not implemented in Perl
# readonly = not implemented in Perl
if (StringInterpolation(StringInterpolation { parts: [Variable("LIBDIR")] }, None) ne q{}) {
# readonly PLUGINDIR not implemented in Perl
# readonly = not implemented in Perl
# readonly / not implemented in Perl
}
else {
# readonly PLUGINDIR not implemented in Perl
# readonly = not implemented in Perl
# readonly /../plugins/.libs not implemented in Perl
}
chdir($DATADIR);
$CHILD_ERROR = 0;
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', 'drivers.yaml'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('lirc-lsplugins', '-U', $PLUGINDIR, '--yaml') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('ping', '-c', q{1}, 'sourceforge.net') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
    my $XDG_CACHE_HOME = $DATADIR;
    $main_exit_code = system('irdb-get', 'update') >> 8;
}
    $XDG_CACHE_HOME = $DATADIR;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', 'confs_by_driver.yaml'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('irdb-get', 'yaml-config') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
# readonly TOOLDOCDIR not implemented in Perl
# readonly = not implemented in Perl
# readonly DESTDOCDIR not implemented in Perl
# readonly = not implemented in Perl
# readonly PLUGINDOCS not implemented in Perl
# readonly = not implemented in Perl
# readonly PYTHON_PKG not implemented in Perl
# readonly = not implemented in Perl
# readonly PYTHON_PATH not implemented in Perl
# readonly = not implemented in Perl
my @sed_lines_0 = split /\n/msx, $;
my @sed_result_0;
foreach my $line (@sed_lines_0) {
chomp $line;
push @sed_result_0, $line;
}
$ = join "\n", @sed_result_0;

my $table;
for my $table ($DESTDOCDIR, '/html/table.html', $DESTDOCDIR, '/lirc.org/html/table.html') {
    my $PYTHONPATH;
    my @PYTHONPATH;
    my %PYTHONPATH;
    $PYTHONPATH = "$ENV{PYTHON_PATH}";
    # Original bash: $PYTHON $BINDIR/lirc-data2table $PWD $PWD \
{
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
                my ($in_2, $out_2);
        my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'unknown_command', '/lirc-data2table');
        close $in_2 or croak 'Close failed: $OS_ERROR';
        $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
        close $out_2 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_2, 0;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', $table
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp_redirect_3 = q{};
        my $cmd_6 = 'xsltproc';
        my ($in_5, $out_5);
        my $pid_5 = open3($in_5, $out_5, '>&STDERR', $cmd_6, '--html', '/docpage.xsl', q{-});
        print {$in_5} $output_1;
        close $in_5 or croak 'Close failed: $OS_ERROR';
        $tmp_redirect_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
        close $out_5 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_5, 0;
        $tmp_redirect_3;
        $output_printed_1 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        }
}
$main_exit_code = system('make', '-C', $PLUGINDOCS) >> 8;

exit $main_exit_code;
