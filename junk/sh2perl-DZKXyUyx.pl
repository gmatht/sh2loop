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

my $GHD;
my @GHD;
my %GHD;
my $VERSION;
my @VERSION;
my %VERSION;

$__set_e = 1;
my $GPG;
my @GPG;
my %GPG;
$GPG = (defined (defined ${GPG} && ${GPG} ne q{} ? ${GPG} : 'gpg') && (defined ${GPG} && ${GPG} ne q{} ? ${GPG} : 'gpg') ne q{} ? (defined ${GPG} && ${GPG} ne q{} ? ${GPG} : 'gpg') : 'gpg');
$GHD = (defined ($ENV{GNUPGHOME} // q{}) && ($ENV{GNUPGHOME} // q{}) ne q{} ? ($ENV{GNUPGHOME} // q{}) : '${HOME:-$(getent passwd "$(id -u)" | cut -f6 -d:)}/.gnupg');
$VERSION = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;

    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'unknown_command', '--version');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
    my $num_lines       = 1;
    my $head_line_count = 0;
    my $result          = q{};
    my $input           = $output_0;
    my $pos             = 0;

    while ( $pos < length $input && $head_line_count < $num_lines ) {
        my $line_end = index $input, "\n", $pos;
        if ( $line_end == -1 ) {
            $line_end = length $input;
        }
        my $head_line = substr $input, $pos, $line_end - $pos;
        $result .= $head_line . "\n";
        $pos = $line_end + 1;
        ++$head_line_count;
    }
    $output_0 = $result;

    my @lines_2 = split /\n/msx, $output_0;
    my @result_2;
    foreach my $line (@lines_2) {
    chomp $line;
    my @fields = split /\\ \ /msx, $line;
    if (@fields > 2) {
        push @result_2, $fields[2];
    }
    }
    $output_0 = join "\n", @result_2;
    if ($output_0 ne q{} && !($output_0  =~ m{\n\z}msx)) { $output_0 .= "\n"; }

    my @lines_3 = split /\n/msx, $output_0;
    my @result_3;
    foreach my $line (@lines_3) {
    chomp $line;
    my @fields = split /./msx, $line;
    my @sel = ();
    if (@fields > 0) { push @sel, $fields[0]; }
    if (@fields > 1) { push @sel, $fields[1]; }
    push @result_3, join(q{.}, @sel);
    }
    $output_0 = join "\n", @result_3;
    if ($output_0 ne q{} && !($output_0  =~ m{\n\z}msx)) { $output_0 .= "\n"; }

    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_0 =~ s/\n+\z//msx;
    $output_0;
}; $_pipeline_result; };
if ((("$VERSION" ne 2.1 && "$VERSION" ne 2.2) && "$VERSION" ne "2.4")) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s is version %s not version 2.1, 2.2, or 2.4, this script might be wrong\n", "$GPG", "$VERSION");
    };
exit 1;
}

sub usage {
    my ($file) = @_;
printf("Usage: %s [GPGHOMEDIR|--default]\n\tMigrate public keyring in GPGHOMEDIR from \"classic\" to \"modern\" GnuPG\n\tusing %s version %s.\n\n\t--default migrates the GnuPG home directory at \"%s\"\n", "$PROGRAM_NAME", "$GPG", "$VERSION", "$GHD");
    return;
}
if ("$1" eq q{}) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        usage();
    };
exit 1;
}
else {
if ("$_[0]" =~ /^--help$/msx or "$_[0]" =~ /^--usage$/msx or "$_[0]" =~ /^-h$/msx) {
                usage();
        exit $main_exit_code;
    } elsif ("$_[0]" =~ /^--default$/msx) {
    } elsif (1) {
                $GHD = "$_[0]";
    }
}
@GPG = ($GPG, '--homedir', $GHD, '--batch');
if (!(!((-f "$GHD/pubring.gpg")))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("There is no %s/pubring.gpg, no need to migrate\n", "$GHD");
    };
exit $main_exit_code;
}
if (!(!(((-s "$GHD/pubring.gpg") > 0)))) {
do {
    my $mv_cmd_str = 'mv -- "$GHD/pubring.gpg" "$GHD/pubring.gpg.empty"';
    system $mv_cmd_str;
};
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("%s/pubring.gpg was empty (and has been moved out of the way), no need to migrate\n", "$GHD");
    };
exit $main_exit_code;
}
my $BACKUP;
my @BACKUP;
my %BACKUP;
$BACKUP = (do { my $_chomp_temp = do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'mktemp', '-d', "$GHD/migrate-from-classic-backup." . (do { my $_chomp_temp = do {
require POSIX; POSIX::strftime('%F', localtime(time())) . "\n"
}; chomp $_chomp_temp; $_chomp_temp; }) . ".XXXXXX");
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
}; chomp $_chomp_temp; $_chomp_temp; });
do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("Migrating from:\n%s\n[Backing up to %s]\n", (do { my $_chomp_temp = do { my @_qx_cmd = ('ls -l "$GHD/pubring.gpg"'); my $result = qx{$_qx_cmd[0]}; $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; }), "$BACKUP");
};
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', "$BACKUP/ownertrust.txt"
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $CHILD_ERROR = 0;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
my $err;
my $force = 0;
if ( -e "$GHD/pubring.gpg" ) {
    my $dest = "$BACKUP/";
    if ( -e $dest && -d $dest ) {
        my $source_name = "$GHD/pubring.gpg";
        $source_name =~ s{^.*[\/]}{};
        $dest = "$dest/$source_name";
    }
    if ( -e $dest && !$force ) {
        croak "mv: $dest: File exists (use -f to force overwrite)\n";
    }
    my $dest_dir = $dest;
    $dest_dir =~ s/\/[^\/]*$//msx;
    if ( $dest_dir eq $dest ) {
        $dest_dir = q{};
    }
    if ( $dest_dir ne q{} && !-d $dest_dir ) {
        my $err;
        make_path( $dest_dir, { error => \$err } );
        if ( @{$err} ) {
            croak "mv: cannot create directory $dest_dir: $err->[0]\n";
        }
    }
    require File::Copy;
    if ( File::Copy::move( "$GHD/pubring.gpg", $dest ) ) {
    } else {
        croak
  "mv: cannot move "$GHD/pubring.gpg" to $dest: $ERRNO\n";
    }
} else {
    croak "mv: "$GHD/pubring.gpg": No such file or directory\n";
}

sub revert {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
carp "printf: no format string specified";
exit 1;
    };
    $main_exit_code = system('bash', 'Restoring pubring.gpg...\n') >> 8;
    use File::Copy qw(copy);
    if ( -e "$BACKUP/pubring.gpg" ) {
        if ( -d "$GHD/pubring.gpg" ) {
            require File::Copy; File::Copy::copy("$BACKUP/pubring.gpg", "$GHD/pubring.gpg" . '/' . ("$BACKUP/pubring.gpg" =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy("$BACKUP/pubring.gpg", "$GHD/pubring.gpg");
        }
    } else {
        croak "cp: cannot stat '$BACKUP/pubring.gpg': No such file or directory\n";
    }
    return;
}
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'revert 2>&1'; print $end_out if $end_out ne q{}; }
if (!(!(open STDIN, '<', "$BACKUP/pubring.gpg" or croak "Cannot open file: $OS_ERROR\n";
$CHILD_ERROR = 0;))) {
print "Keyring import was not completely successful (see error message above,
and the LIMITATIONS section of migrate-pubring-from-classic-gpg(1) for
more details).

If you suspect a bug in the migration script, please use:

    reportbug gnupg-utils --subject='migrate-pubring-from-classic-gpg partial failure'

And include the above output (redacted for privacy as needed) in the
body of the report.

Continuing with the rest of the migration anyway...
";
}
open STDIN, '<', "$BACKUP/ownertrust.txt" or croak "Cannot open file: $OS_ERROR\n";
$CHILD_ERROR = 0;
$CHILD_ERROR = 0;
if (!(!((-f "$GHD/pubring.kbx")))) {
print "No keybox was created at $GHD/pubring.kbx.  Something went wrong!

Please report a bug in the migration script, using:

    reportbug gnupg-utils --subject='migrate-pubring-from-classic-gpg no pubring.kbx ($BACKUP)'
";
exit 1;
}
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'- 2>&1'; print $end_out if $end_out ne q{}; }
do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
printf("Migration completed successfully:\n%s\n", (do { my $_chomp_temp = do { my @_qx_cmd = ('ls -l "$GHD/pubring.kbx"'); my $result = qx{$_qx_cmd[0]}; $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; }));
};

exit $main_exit_code;
