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

my $db;
my @db;
my %db;
my $DEBCONF_RECONFIGURE;
my @DEBCONF_RECONFIGURE;
my %DEBCONF_RECONFIGURE;
my $EE;
my @EE;
my %EE;
my $LG;
my @LG;
my %LG;
my $SELECTED_LOCALES;
my @SELECTED_LOCALES;
my %SELECTED_LOCALES;
my $LEGACY_EE;
my @LEGACY_EE;
my %LEGACY_EE;
my $DEFAULT_ENVIRONMENT;
my @DEFAULT_ENVIRONMENT;
my %DEFAULT_ENVIRONMENT;

$__set_e = 1;
$LG = "/etc/locale.gen";
$EE = "/etc/locale.conf";
$LEGACY_EE = "/etc/default/locale";
my $LC_ALL;
my @LC_ALL;
my %LC_ALL;
$LC_ALL = q{C};
my $LANG;
my @LANG;
my %LANG;
$LANG = q{C};
if ("$1" eq configure) {
if ((((-f "$LEGACY_EE") && (!-L "$LEGACY_EE")) && (!-e "$EE"))) {
        my $err;
        my $force = 0;
        if ( -e "$LEGACY_EE" ) {
            my $dest = "$EE";
            if ( -e $dest && -d $dest ) {
                my $source_name = "$LEGACY_EE";
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
            if ( File::Copy::move( "$LEGACY_EE", $dest ) ) {
            } else {
                croak
  "mv: cannot move "$LEGACY_EE" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "$LEGACY_EE": No such file or directory\n";
        }
    }
if ((!-e "$LEGACY_EE")) {
symlink 'fr', "$LEGACY_EE" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
    $main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;
    $main_exit_code = system('db_version', '2.0') >> 8;
    if (do {
$main_exit_code = system('db_get', 'locales/default_environment_locale') >> 8;
        $CHILD_ERROR == 0
    }) {
                $DEFAULT_ENVIRONMENT = "$ENV{RET}";
    }
    if (do {
$main_exit_code = system('db_get', 'locales/locales_to_be_generated') >> 8;
        $CHILD_ERROR == 0
    }) {
                $SELECTED_LOCALES = $RET;
    }
    $SELECTED_LOCALES = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_2 = q{};
        my $output_printed_2;
        my $pipeline_success_2 = 1;
        $output_2 .= $SELECTED_LOCALES . "\n";
        if ( !($output_2 =~ m{\n\z}msx) ) { $output_2 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }
        my @sed_lines_2 = split /\n/msx, $output_2;
        my @sed_result_2;
        foreach my $line (@sed_lines_2) {
        chomp $line;
        push @sed_result_2, $line;
        }
        $output_2 = join "\n", @sed_result_2;

        if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_2 =~ s/\n+\z//msx;
        $output_2;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
if ("$SELECTED_LOCALES" eq "All locales") {
        if ((-e $LG)) {
            if ( -e "$LG" ) {
                if ( -d "$LG" ) {
                    carp "rm: carping: ", $LG,
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$LG" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", $LG,
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
symlink '/usr/share/i18n/SUPPORTED', $LG or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
    else {
        if (do {
if ((-l $LG)) {
    "$(readlink $LG)" eq "/usr/share/i18n/SUPPORTED"    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
            $CHILD_ERROR == 0
        }) {
            if ( -e "$LG" ) {
                if ( -d "$LG" ) {
                    carp "rm: carping: ", $LG,
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$LG" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", $LG,
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
if ((!-e $LG)) {
open my $fh_cat, '>', '$LG' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "# This file lists locales that you wish to have built. You can find a list
# of valid supported locales at /usr/share/i18n/SUPPORTED, and you can add
# user defined locales to /usr/local/share/i18n/SUPPORTED. If you change
# this file, you need to rerun locale-gen.
#

";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
        }
my @sed_lines_4 = split /\n/msx, $;
my @sed_result_4;
foreach my $line (@sed_lines_4) {
chomp $line;
push @sed_result_4, $line;
}
$ = join "\n", @sed_result_4;

if ((-f "/usr/local/share/i18n/SUPPORTED")) {
            my $SUPPORTED_LOCALES;
            my @SUPPORTED_LOCALES;
            my %SUPPORTED_LOCALES;
            $SUPPORTED_LOCALES = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_5 = q{};
                my $output_printed_5;
                my $pipeline_success_5 = 1;
                my @sed_lines_5 = split /\n/msx, $;
                my @sed_result_5;
                foreach my $line (@sed_lines_5) {
                chomp $line;
                push @sed_result_5, $line;
                }
                $ = join "\n", @sed_result_5;

                if ($CHILD_ERROR != 0) { $pipeline_success_5 = 0; }
                my @sort_lines_5_1 = split /\n/msx, $output_5;
                my @sort_sorted_5_1 = sort @sort_lines_5_1;
                $output_5 = join "\n", @sort_sorted_5_1;
                                if ($output_5 ne q{} && !($output_5 =~ m{\n\z}msx)) {
                                    $output_5 .= "\n";
                                }
                if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
                exit $main_exit_code if $__set_e && $main_exit_code != 0;
                $output_5 =~ s/\n+\z//msx;
                $output_5;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
}
        else {
            $SUPPORTED_LOCALES = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_6 = q{};
                my $output_printed_6;
                my $pipeline_success_6 = 1;
                my @sed_lines_6 = split /\n/msx, $;
                my @sed_result_6;
                foreach my $line (@sed_lines_6) {
                chomp $line;
                push @sed_result_6, $line;
                }
                $ = join "\n", @sed_result_6;

                if ($CHILD_ERROR != 0) { $pipeline_success_6 = 0; }
                my @sort_lines_6_1 = split /\n/msx, $output_6;
                my @sort_sorted_6_1 = sort @sort_lines_6_1;
                $output_6 = join "\n", @sort_sorted_6_1;
                                if ($output_6 ne q{} && !($output_6 =~ m{\n\z}msx)) {
                                    $output_6 .= "\n";
                                }
                if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
                exit $main_exit_code if $__set_e && $main_exit_code != 0;
                $output_6 =~ s/\n+\z//msx;
                $output_6;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
        }
        # Original bash: echo "$SUPPORTED_LOCALES" | while read locale ; do
{
            my $output_7 = q{};
            my $output_printed_7;
            my $pipeline_success_7 = 1;
            $output_7 .= $SUPPORTED_LOCALES . "\n";
if ( !($output_7 =~ m{\n\z}msx) ) { $output_7 .= "\n"; }
$CHILD_ERROR = 0;

                        my @lines = split /\n/msx, $output_7;
            my $result_7_1 = q{};
            for my $line (@lines) {
            chomp $line;
            my $L = $line;
            if (!(!(my $grep_result_8;
            my @grep_lines_8 = ();
            my @grep_filtered_8 = grep { /^[\#\ ]*$ENV{locale}\ *$/msx } @grep_lines_8;
            $grep_result_8 = join "\n", @grep_filtered_8;
            if (!($grep_result_8 =~ m{\n\z}msx || $grep_result_8 eq q{})) {
            $grep_result_8 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_8 > 0 ? 0 : 1;
            $grep_result_8 = q{};))) {
            do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $LG
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_9 = q{};
            $tmp_redirect_9 .= "# $ENV{locale}\n";
            if ( !($tmp_redirect_9 =~ m{\n\z}msx) ) { $tmp_redirect_9 .= "\n"; }
            $CHILD_ERROR = 0;
            $tmp_redirect_9;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_7; }
            $output_printed_7 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            }
            }
            $output_7 = $result_7_1;
            if ($output_7 ne q{} && !defined $output_printed_7) {
                print $output_7;
                if (!($output_7 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
        # Original bash: echo "$SELECTED_LOCALES" | while read locale ; do
{
            my $output_11 = q{};
            my $output_printed_11;
            my $pipeline_success_11 = 1;
            $output_11 .= $SELECTED_LOCALES . "\n";
if ( !($output_11 =~ m{\n\z}msx) ) { $output_11 .= "\n"; }
$CHILD_ERROR = 0;

                        my @lines = split /\n/msx, $output_11;
            my $result_11_1 = q{};
            for my $line (@lines) {
            chomp $line;
            my $L = $line;
            my @sed_lines_12 = split /\n/msx, $;
            my @sed_result_12;
            foreach my $line (@sed_lines_12) {
            chomp $line;
            push @sed_result_12, $line;
            }
            $ = join "\n", @sed_result_12;
            }
            $output_11 = $result_11_1;
            if ($output_11 ne q{} && !defined $output_printed_11) {
                print $output_11;
                if (!($output_11 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
    }
if (0) {
        print "locales-all installed, skipping locales generation\n";
}
    else {
        $main_exit_code = system('bash', 'locale-gen') >> 8;
    }
if (!(!(if (!((-e $EE))) {
        "$DEBCONF_RECONFIGURE" ne q{}    }))) {
        $main_exit_code = system('update-locale', '--no-checks', 'LANG') >> 8;
if (("$DEFAULT_ENVIRONMENT" ne q{} && "$DEFAULT_ENVIRONMENT" ne "None")) {
            $main_exit_code = system('update-locale', "LANG=$DEFAULT_ENVIRONMENT") >> 8;
        }
    }
}
exit 0;

exit $main_exit_code;
