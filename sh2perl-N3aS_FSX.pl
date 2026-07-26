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

my $DEBCONF_REDIR;
my @DEBCONF_REDIR;
my %DEBCONF_REDIR;
my $DEBCONF_USE_CDEBCONF;
my @DEBCONF_USE_CDEBCONF;
my %DEBCONF_USE_CDEBCONF;
my $DEBIAN_HAS_FRONTEND;
my @DEBIAN_HAS_FRONTEND;
my %DEBIAN_HAS_FRONTEND;

if ((!"${DEBIAN_HAS_FRONTEND:-}")) {
    my $PERL_DL_NONLAZY;
    my @PERL_DL_NONLAZY;
    my %PERL_DL_NONLAZY;
    $PERL_DL_NONLAZY = q{1};
$ENV{PERL_DL_NONLAZY} = $PERL_DL_NONLAZY;
if (("${DEBCONF_USE_CDEBCONF:-}")) {
# Builtin command 'exec' not implemented
}
    else {
# Builtin command 'exec' not implemented
    }
}
if ("${DEBCONF_REDIR:-}" eq q{}) {
    do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
    };
if (("${DEBCONF_USE_CDEBCONF:-}")) {
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
        };
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
        };
    }
    $DEBCONF_REDIR = q{1};
$ENV{DEBCONF_REDIR} = $DEBCONF_REDIR;
}

sub _db_cmd {
    my $_db_internal_IFS;
    my @_db_internal_IFS;
    my %_db_internal_IFS;
    $_db_internal_IFS = "$ENV{IFS}";
    my $IFS;
    my @IFS;
    my %IFS;
    $IFS = q{ };
    do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
foreach my $item (@ARGV) {
    printf("%s\n", $item);
}
    };
    $IFS = "\n";
$_db_internal_line = <>;
chomp $_db_internal_line;
$CHILD_ERROR = defined($_db_internal_line) ? 0 : 1;
    $IFS = "$_db_internal_IFS";
    my $RET;
    my @RET;
    my %RET;
    $RET = $_db_internal_line#[eval { int(! 	][ 	) } // ""];
if (q{} =~ /^1$/msx) {
                $RET = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_2 = q{};
            my $output_printed_2;
            my $pipeline_success_2 = 1;
            my $output_2;
            {
                local *STDOUT;
                open STDOUT, '>', \$output_2 or die "Cannot redirect STDOUT";
                printf('%s', "$RET");
            }
            if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }

            my $cmd_4 = 'debconf-escape';
            my ($in_3, $out_3);
            my $pid_3 = open3($in_3, $out_3, '>&STDERR', $cmd_4, '-u');
            print {$in_3} $output_2;
            close $in_3 or croak 'Close failed: $OS_ERROR';
            $output_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
            close $out_3 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_3, 0;
            if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
            $output_2 =~ s/\n+\z//msx;
            $output_2;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
        return q{0};    }
return q{};
    return;
}

sub db_capb {
    _db_cmd("CAPB @ARGV");
    return;
}

sub db_set {
    _db_cmd("SET @ARGV");
    return;
}

sub db_reset {
    _db_cmd("RESET @ARGV");
    return;
}

sub db_title {
    _db_cmd("TITLE @ARGV");
    return;
}

sub db_input {
    _db_cmd("INPUT @ARGV");
    return;
}

sub db_beginblock {
    _db_cmd("BEGINBLOCK @ARGV");
    return;
}

sub db_endblock {
    _db_cmd("ENDBLOCK @ARGV");
    return;
}

sub db_go {
    _db_cmd("GO @ARGV");
    return;
}

sub db_get {
    _db_cmd("GET @ARGV");
    return;
}

sub db_register {
    _db_cmd("REGISTER @ARGV");
    return;
}

sub db_unregister {
    _db_cmd("UNREGISTER @ARGV");
    return;
}

sub db_subst {
    _db_cmd("SUBST @ARGV");
    return;
}

sub db_fset {
    _db_cmd("FSET @ARGV");
    return;
}

sub db_fget {
    _db_cmd("FGET @ARGV");
    return;
}

sub db_purge {
    _db_cmd("PURGE @ARGV");
    return;
}

sub db_metaget {
    _db_cmd("METAGET @ARGV");
    return;
}

sub db_version {
    _db_cmd("VERSION @ARGV");
    return;
}

sub db_clear {
    _db_cmd("CLEAR @ARGV");
    return;
}

sub db_settitle {
    _db_cmd("SETTITLE @ARGV");
    return;
}

sub db_info {
    _db_cmd("INFO @ARGV");
    return;
}

sub db_progress {
    _db_cmd("PROGRESS @ARGV");
    return;
}

sub db_data {
    _db_cmd("DATA @ARGV");
    return;
}

sub db_x_loadtemplatefile {
    _db_cmd("X_LOADTEMPLATEFILE @ARGV");
    return;
}

sub db_text {
    db_input(@ARGV);
    return;
}

sub db_stop {
    do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        print 'STOP' . "\n";
        $CHILD_ERROR = 0;
    };
    return;
}

exit $main_exit_code;
