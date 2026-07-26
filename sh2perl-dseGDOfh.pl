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

my $prefix;
my @prefix;
my %prefix;
$prefix = "/usr";
my $exec_prefix;
my @exec_prefix;
my %exec_prefix;
$exec_prefix = ${prefix};
my $datarootdir;
my @datarootdir;
my %datarootdir;
$datarootdir = ${prefix} . "/share";
my $datadir;
my @datadir;
my %datadir;
$datadir = ${datarootdir};
my $libdir;
my @libdir;
my %libdir;
$libdir = ${prefix} . "/lib/aarch64-linux-gnu";
my $localedir;
my @localedir;
my %localedir;
$localedir = ${datarootdir} . "/locale";
if (StringInterpolation(StringInterpolation { parts: [Literal("no")] }, None) eq yes) {
    my $orig_installdir;
    my @orig_installdir;
    my %orig_installdir;
    $orig_installdir = "$libdir";
    $main_exit_code = system('bash', '/gettext') >> 8;
    my $curr_installdir;
    my @curr_installdir;
    my %curr_installdir;
    $curr_installdir = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
        $output_0 .= $0 . "\n";
        if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
        my @sed_lines_0 = split /\n/msx, $output_0;
        my @sed_result_0;
        foreach my $line (@sed_lines_0) {
        chomp $line;
        push @sed_result_0, $line;
        }
        $output_0 = join "\n", @sed_result_0;

        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        $output_0 =~ s/\n+\z//msx;
        $output_0;
}; $_pipeline_result; };
    $curr_installdir = do {
    my $left_result_1 = do { chdir("$curr_installdir"); q{} };
;
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_1 = do { use Cwd; getcwd(); };
        $left_result_1 . $right_result_1;
    } else {
        q{};
    }
};
while ( 1 ) {
        my $orig_last;
        my @orig_last;
        my %orig_last;
        $orig_last = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_3 = q{};
            my $output_printed_3;
            my $pipeline_success_3 = 1;
            $output_3 .= $orig_installdir . "\n";
            if ( !($output_3 =~ m{\n\z}msx) ) { $output_3 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_3 = 0; }
            my @sed_lines_3 = split /\n/msx, $output_3;
            my @sed_result_3;
            foreach my $line (@sed_lines_3) {
            chomp $line;
            push @sed_result_3, $line;
            }
            $output_3 = join "\n", @sed_result_3;

            if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
            $output_3 =~ s/\n+\z//msx;
            $output_3;
}; $_pipeline_result; };
        my $curr_last;
        my @curr_last;
        my %curr_last;
        $curr_last = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_4 = q{};
            my $output_printed_4;
            my $pipeline_success_4 = 1;
            $output_4 .= $curr_installdir . "\n";
            if ( !($output_4 =~ m{\n\z}msx) ) { $output_4 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_4 = 0; }
            my @sed_lines_4 = split /\n/msx, $output_4;
            my @sed_result_4;
            foreach my $line (@sed_lines_4) {
            chomp $line;
            push @sed_result_4, $line;
            }
            $output_4 = join "\n", @sed_result_4;

            if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
            $output_4 =~ s/\n+\z//msx;
            $output_4;
}; $_pipeline_result; };
if ((!(        $main_exit_code = system('test', '-z', "$orig_last") >> 8) || !(        $main_exit_code = system('test', '-z', "$curr_last") >> 8))) {
last;
        }
if ((!StringInterpolation(StringInterpolation { parts: [Variable("orig_last")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("curr_last")] }, None))) {
last;
        }
        $orig_installdir = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_5 = q{};
            my $output_printed_5;
            my $pipeline_success_5 = 1;
            $output_5 .= $orig_installdir . "\n";
            if ( !($output_5 =~ m{\n\z}msx) ) { $output_5 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_5 = 0; }
            my @sed_lines_5 = split /\n/msx, $output_5;
            my @sed_result_5;
            foreach my $line (@sed_lines_5) {
            chomp $line;
            push @sed_result_5, $line;
            }
            $output_5 = join "\n", @sed_result_5;

            if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
            $output_5 =~ s/\n+\z//msx;
            $output_5;
}; $_pipeline_result; };
        $curr_installdir = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_6 = q{};
            my $output_printed_6;
            my $pipeline_success_6 = 1;
            $output_6 .= $curr_installdir . "\n";
            if ( !($output_6 =~ m{\n\z}msx) ) { $output_6 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_6 = 0; }
            my @sed_lines_6 = split /\n/msx, $output_6;
            my @sed_result_6;
            foreach my $line (@sed_lines_6) {
            chomp $line;
            push @sed_result_6, $line;
            }
            $output_6 = join "\n", @sed_result_6;

            if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
            $output_6 =~ s/\n+\z//msx;
            $output_6;
}; $_pipeline_result; };
    }
    $libdir = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_7 = q{};
        my $output_printed_7;
        my $pipeline_success_7 = 1;
        $output_7 .= "$libdir/\n";
        if ( !($output_7 =~ m{\n\z}msx) ) { $output_7 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_7 = 0; }
        my @sed_lines_7 = split /\n/msx, $output_7;
        my @sed_result_7;
        foreach my $line (@sed_lines_7) {
        chomp $line;
        push @sed_result_7, $line;
        }
        $output_7 = join "\n", @sed_result_7;

        my @sed_lines_7 = split /\n/msx, $output_7;
        my @sed_result_7;
        foreach my $line (@sed_lines_7) {
        chomp $line;
        push @sed_result_7, $line;
        }
        $output_7 = join "\n", @sed_result_7;

        if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
        $output_7 =~ s/\n+\z//msx;
        $output_7;
}; $_pipeline_result; };
    $localedir = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_8 = q{};
        my $output_printed_8;
        my $pipeline_success_8 = 1;
        $output_8 .= "$localedir/\n";
        if ( !($output_8 =~ m{\n\z}msx) ) { $output_8 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_8 = 0; }
        my @sed_lines_8 = split /\n/msx, $output_8;
        my @sed_result_8;
        foreach my $line (@sed_lines_8) {
        chomp $line;
        push @sed_result_8, $line;
        }
        $output_8 = join "\n", @sed_result_8;

        my @sed_lines_8 = split /\n/msx, $output_8;
        my @sed_result_8;
        foreach my $line (@sed_lines_8) {
        chomp $line;
        push @sed_result_8, $line;
        }
        $output_8 = join "\n", @sed_result_8;

        if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
        $output_8 =~ s/\n+\z//msx;
        $output_8;
}; $_pipeline_result; };
}
$main_exit_code = system('.', 'gettext.sh') >> 8;
my $TEXTDOMAIN;
my @TEXTDOMAIN;
my %TEXTDOMAIN;
$TEXTDOMAIN = 'gettext-tools';
$ENV{TEXTDOMAIN} = $TEXTDOMAIN;
my $TEXTDOMAINDIR;
my @TEXTDOMAINDIR;
my %TEXTDOMAINDIR;
$TEXTDOMAINDIR = "$localedir";
$ENV{TEXTDOMAINDIR} = $TEXTDOMAINDIR;
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/tty'
      or die "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if ((!Variable("#", false, None) eq 0)) {
    do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        print $1;
if ( !( ($1) =~ m{\n\z}msx ) ) { print "\n"; }
    };
}
my $user;
my @user;
my %user;
$user = do { my @_qx_cmd = ("id -u -n 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if (StringInterpolation(StringInterpolation { parts: [Variable("user")] }, None) eq q{}) {
    $user = "$ENV{USER}";
if (StringInterpolation(StringInterpolation { parts: [Variable("user")] }, None) eq q{}) {
        $user = "$ENV{LOGNAME}";
if (StringInterpolation(StringInterpolation { parts: [Variable("user")] }, None) eq q{}) {
            $user = 'unknown';
        }
    }
}
my $host;
my @host;
my %host;
$host = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_9 = q{};
    my $output_printed_9;
    my $pipeline_success_9 = 1;
    my ($in_10, $out_10);
    my $pid_10 = open3($in_10, $out_10, '>&STDERR', 'unknown_command', '/gettext/hostname', '--short');
    close $in_10 or croak 'Close failed: $OS_ERROR';
    $output_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
    close $out_10 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_10, 0;
    my @sed_lines_9 = split /\n/msx, $output_9;
    my @sed_result_9;
    foreach my $line (@sed_lines_9) {
    chomp $line;
    push @sed_result_9, $line;
    }
    $output_9 = join "\n", @sed_result_9;
    if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
    $output_9 =~ s/\n+\z//msx;
    $output_9;
}; $_pipeline_result; };
my $hostfqdn;
my @hostfqdn;
my %hostfqdn;
$hostfqdn = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_11 = q{};
    my $output_printed_11;
    my $pipeline_success_11 = 1;
    my ($in_12, $out_12);
    my $pid_12 = open3($in_12, $out_12, '>&STDERR', 'unknown_command', '/gettext/hostname', '--fqdn');
    close $in_12 or croak 'Close failed: $OS_ERROR';
    $output_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
    close $out_12 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_12, 0;
    my @sed_lines_11 = split /\n/msx, $output_11;
    my @sed_result_11;
    foreach my $line (@sed_lines_11) {
    chomp $line;
    push @sed_result_11, $line;
    }
    $output_11 = join "\n", @sed_result_11;
    if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
    $output_11 =~ s/\n+\z//msx;
    $output_11;
}; $_pipeline_result; };
chdir($HOME);
$CHILD_ERROR = 0;
my $files;
my @files;
my %files;
$files = "";
$files = "$files .thunderbird/*/prefs.js";
$files = "$files .mozilla/*/prefs.js";
$files = "$files .netscape/liprefs.js .netscape/preferences.js";
$files = "$files .netscape/preferences";
$files = "$files .emacs .emacs.el";
$files = "$files .kde2/share/config/emaildefaults";
$files = "$files .kde2/share/config/kmailrc";
$files = "$files .gconf/apps/evolution/mail/%gconf.xml";
$files = "$files evolution/config.xmldb";
$files = "$files .gnome/balsa";
my $sed_dos2unix;
my @sed_dos2unix;
my %sed_dos2unix;
$sed_dos2unix = "s/\\r$//";
my $sed_soffice51;
my @sed_soffice51;
my %sed_soffice51;
$sed_soffice51 = "s,StarOffice 5\\.1=\\(.*\\)$,\\1/sofficerc,p";
my $sed_soffice52;
my @sed_soffice52;
my %sed_soffice52;
$sed_soffice52 = "s,StarOffice 5\\.2=\\(.*\\)$,\\1/user/sofficerc,p";
my $sed_ooffice;
my @sed_ooffice;
my %sed_ooffice;
$sed_ooffice = "s,^OpenOffice[^=]*=\\(.*\\)$,\\1/user/config/registry/instance/org/openoffice/UserProfile.xml,p";
$files = "$files Office51/sofficerc Office52/user/sofficerc ";
$files = "$files .muttrc";
$files = "$files .pinerc";
$files = "$files .xfmail/.xfmailrc";
$files = "$files .ratatosk/ratatoskrc";
my $nfiles;
my @nfiles;
my %nfiles;
$nfiles = "";
my $file;
for my $file ($files) {
if ((!(    $main_exit_code = system('test', '-r', "$file") >> 8) && !(    $main_exit_code = system('test', q{!}, '-d', "$file") >> 8))) {
        $nfiles = "$nfiles $file";
    }
}
$files = "$nfiles";
my $addresses;
my @addresses;
my %addresses;
$addresses = "";
if (StringInterpolation(StringInterpolation { parts: [Variable("files")] }, None) ne q{}) {
    for my $file (do {
    my @ls_files_13 = ();
    if ( -f q{.} ) {
        push @ls_files_13, q{.};
    }
    elsif ( -d q{.} ) {
        if ( opendir my $dh, q{.} ) {
            while ( my $file = readdir $dh ) {
                next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                push @ls_files_13, $file;
            }
            closedir $dh;
            @ls_files_13 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_files_13;
        }
    }
    (@ls_files_13 ? join("\n", @ls_files_13) . "\n" : q{});
};
) {
if ("$file" =~ /^.mozilla/.*/prefs.js$/msx or "$file" =~ /^.thunderbird/.*/prefs.js$/msx) {
                        $addresses = "$addresses ";
                        $CHILD_ERROR = 0;
        } elsif ("$file" =~ /^.netscape/liprefs.js$/msx or "$file" =~ /^.netscape/preferences.js$/msx) {
                        $addresses = "$addresses ";
                        $CHILD_ERROR = 0;
        } elsif ("$file" =~ /^.netscape/preferences$/msx) {
                        $addresses = "$addresses ";
                        $CHILD_ERROR = 0;
        } elsif ("$file" =~ /^.emacs$/msx or "$file" =~ /^.emacs.el$/msx) {
                        $addresses = "$addresses ";
                        $CHILD_ERROR = 0;
                        my $domains;
            my @domains;
            my %domains;
            $domains = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_15 = q{};
                my $output_printed_15;
                my $pipeline_success_15 = 1;
                my $grep_result_15_0;
                my @grep_lines_15_0 = ();
                my @grep_filtered_15_0 = grep { /[\ (]mew-mail-domain\ "[^"]*"/msx } @grep_lines_15_0;
                $grep_result_15_0 = join "\n", @grep_filtered_15_0;
                if (!($grep_result_15_0 =~ m{\n\z}msx || $grep_result_15_0 eq q{})) {
                $grep_result_15_0 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_15_0 > 0 ? 0 : 1;
                $output_15 = $grep_result_15_0;
                my @sed_lines_15 = split /\n/msx, $output_15;
                my @sed_result_15;
                foreach my $line (@sed_lines_15) {
                chomp $line;
                push @sed_result_15, $line;
                }
                $output_15 = join "\n", @sed_result_15;
                if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
                $output_15 =~ s/\n+\z//msx;
                $output_15;
}; $_pipeline_result; };
            if (StringInterpolation(StringInterpolation { parts: [Variable("domains")] }, None) ne q{}) {
                my $domain;
                for my $domain ($domains) {
                    $addresses = "$addresses " . ${user} . "@$domain";
                }
            }
        } elsif ("$file" =~ /^.kde2/share/config/emaildefaults$/msx) {
                        $addresses = "$addresses ";
                        $CHILD_ERROR = 0;
        } elsif ("$file" =~ /^.kde2/share/config/kmailrc$/msx) {
                        $addresses = "$addresses ";
                        $CHILD_ERROR = 0;
        } elsif ("$file" =~ /^.gconf/apps/evolution/mail/%gconf.xml$/msx) {
                        my $sedexpr0;
            my @sedexpr0;
            my %sedexpr0;
            $sedexpr0 = "s,^.*&lt;addr-spec&gt;\\(.*\\)&lt;/addr-spec&gt;.*$,\\1,p";
                        $addresses = "$addresses ";
                        $CHILD_ERROR = 0;
        } elsif ("$file" =~ /^evolution/config.xmldb$/msx) {
                        $sedexpr0 = "s/^.*<entry name=\"identity_address_[0-9]*\" type=\"string\" value=\"\\([^\"]*\\)\".*$/\\1/p";
                        my $sedexpr1;
            my @sedexpr1;
            my %sedexpr1;
            $sedexpr1 = "s/\\(..\\)/\\\\x\\1/g";
                        my $sedexpr2;
            my @sedexpr2;
            my %sedexpr2;
            $sedexpr2 = "s,$,\\\\n,";
                        $addresses = "$addresses ";
                        $CHILD_ERROR = 0;
        } elsif ("$file" =~ /^.gnome/balsa$/msx) {
                        $addresses = "$addresses ";
                        $CHILD_ERROR = 0;
        } elsif ("$file" =~ /^.*/UserProfile.xml$/msx) {
                        $addresses = "$addresses ";
                        $CHILD_ERROR = 0;
        } elsif ("$file" =~ /^.*/sofficerc$/msx) {
                        $addresses = "$addresses ";
                        $CHILD_ERROR = 0;
        } elsif ("$file" =~ /^.muttrc$/msx) {
                        my $mutt_addresses;
            my @mutt_addresses;
            my %mutt_addresses;
            $mutt_addresses = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_16 = q{};
                my $output_printed_16;
                my $pipeline_success_16 = 1;
                my $grep_result_16_0;
                my @grep_lines_16_0 = ();
                my @grep_filtered_16_0 = grep { /^set\ from="[^"]*"[\ \t]*$/msx } @grep_lines_16_0;
                $grep_result_16_0 = join "\n", @grep_filtered_16_0;
                if (!($grep_result_16_0 =~ m{\n\z}msx || $grep_result_16_0 eq q{})) {
                $grep_result_16_0 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_16_0 > 0 ? 0 : 1;
                $output_16 = $grep_result_16_0;
                my @sed_lines_16 = split /\n/msx, $output_16;
                my @sed_result_16;
                foreach my $line (@sed_lines_16) {
                chomp $line;
                push @sed_result_16, $line;
                }
                $output_16 = join "\n", @sed_result_16;
                if ( !$pipeline_success_16 ) { $main_exit_code = 1; }
                $output_16 =~ s/\n+\z//msx;
                $output_16;
}; $_pipeline_result; };
            if (StringInterpolation(StringInterpolation { parts: [Variable("mutt_addresses")] }, None) ne q{}) {
                $addresses = "$addresses $mutt_addresses";
}
            else {
if (StringInterpolation(StringInterpolation { parts: [Variable("EMAIL")] }, None) ne q{}) {
                    $addresses = "$addresses $ENV{EMAIL}";
                }
            }
        } elsif ("$file" =~ /^.pinerc$/msx) {
                        $domains = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_17 = q{};
                my $output_printed_17;
                my $pipeline_success_17 = 1;
                my $grep_result_17_0;
                my @grep_lines_17_0 = ();
                my @grep_filtered_17_0 = grep { /^user-domain=/msx } @grep_lines_17_0;
                $grep_result_17_0 = join "\n", @grep_filtered_17_0;
                if (!($grep_result_17_0 =~ m{\n\z}msx || $grep_result_17_0 eq q{})) {
                $grep_result_17_0 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_17_0 > 0 ? 0 : 1;
                $output_17 = $grep_result_17_0;
                my @sed_lines_17 = split /\n/msx, $output_17;
                my @sed_result_17;
                foreach my $line (@sed_lines_17) {
                chomp $line;
                push @sed_result_17, $line;
                }
                $output_17 = join "\n", @sed_result_17;
                if ( !$pipeline_success_17 ) { $main_exit_code = 1; }
                $output_17 =~ s/\n+\z//msx;
                $output_17;
}; $_pipeline_result; };
            if (StringInterpolation(StringInterpolation { parts: [Variable("domains")] }, None) ne q{}) {
                for my $domain ($domains) {
                    $addresses = "$addresses " . ${user} . "@$domain";
                }
}
            else {
                $domains = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_18 = q{};
                    my $output_printed_18;
                    my $pipeline_success_18 = 1;
                    my $grep_result_18_0;
                    my @grep_lines_18_0 = ();
                    my @grep_filtered_18_0 = grep { /^use-only-domain-name=/msx } @grep_lines_18_0;
                    $grep_result_18_0 = join "\n", @grep_filtered_18_0;
                    if (!($grep_result_18_0 =~ m{\n\z}msx || $grep_result_18_0 eq q{})) {
                    $grep_result_18_0 .= "\n";
                    }
                    $CHILD_ERROR = scalar @grep_filtered_18_0 > 0 ? 0 : 1;
                    $output_18 = $grep_result_18_0;
                    my @sed_lines_18 = split /\n/msx, $output_18;
                    my @sed_result_18;
                    foreach my $line (@sed_lines_18) {
                    chomp $line;
                    push @sed_result_18, $line;
                    }
                    $output_18 = join "\n", @sed_result_18;
                    if ( !$pipeline_success_18 ) { $main_exit_code = 1; }
                    $output_18 =~ s/\n+\z//msx;
                    $output_18;
}; $_pipeline_result; };
if (StringInterpolation(StringInterpolation { parts: [Literal("Yes")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("domains")] }, None)) {
                    $addresses = "$addresses " . ${user} . "@";
                    $CHILD_ERROR = 0;
                }
            }
        } elsif ("$file" =~ /^.xfmail/.xfmailrc$/msx) {
                        $addresses = "$addresses ";
                        $CHILD_ERROR = 0;
        } elsif ("$file" =~ /^.ratatosk/ratatoskrc$/msx) {
                        $domains = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_19 = q{};
                my $output_printed_19;
                my $pipeline_success_19 = 1;
                my $grep_result_19_0;
                my @grep_lines_19_0 = ();
                my @grep_filtered_19_0 = grep { /^set\ option(masquerade_as)\ /msx } @grep_lines_19_0;
                $grep_result_19_0 = join "\n", @grep_filtered_19_0;
                if (!($grep_result_19_0 =~ m{\n\z}msx || $grep_result_19_0 eq q{})) {
                $grep_result_19_0 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_19_0 > 0 ? 0 : 1;
                $output_19 = $grep_result_19_0;
                my @sed_lines_19 = split /\n/msx, $output_19;
                my @sed_result_19;
                foreach my $line (@sed_lines_19) {
                chomp $line;
                push @sed_result_19, $line;
                }
                $output_19 = join "\n", @sed_result_19;
                if ( !$pipeline_success_19 ) { $main_exit_code = 1; }
                $output_19 =~ s/\n+\z//msx;
                $output_19;
}; $_pipeline_result; };
            if (StringInterpolation(StringInterpolation { parts: [Variable("domains")] }, None) ne q{}) {
                for my $domain ($domains) {
                    $addresses = "$addresses " . ${user} . "@$domain";
                }
}
            else {
                $domains = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_20 = q{};
                    my $output_printed_20;
                    my $pipeline_success_20 = 1;
                    my $grep_result_20_0;
                    my @grep_lines_20_0 = ();
                    my @grep_filtered_20_0 = grep { /^set\ option(domain)\ /msx } @grep_lines_20_0;
                    $grep_result_20_0 = join "\n", @grep_filtered_20_0;
                    if (!($grep_result_20_0 =~ m{\n\z}msx || $grep_result_20_0 eq q{})) {
                    $grep_result_20_0 .= "\n";
                    }
                    $CHILD_ERROR = scalar @grep_filtered_20_0 > 0 ? 0 : 1;
                    $output_20 = $grep_result_20_0;
                    my @sed_lines_20 = split /\n/msx, $output_20;
                    my @sed_result_20;
                    foreach my $line (@sed_lines_20) {
                    chomp $line;
                    push @sed_result_20, $line;
                    }
                    $output_20 = join "\n", @sed_result_20;
                    if ( !$pipeline_success_20 ) { $main_exit_code = 1; }
                    $output_20 =~ s/\n+\z//msx;
                    $output_20;
}; $_pipeline_result; };
if (StringInterpolation(StringInterpolation { parts: [Variable("domains")] }, None) ne q{}) {
                    for my $domain ($domains) {
                        $addresses = "$addresses " . ${user} . "@" . ${host} . ".$domain";
                    }
                }
            }
        }
    }
}
if ((-r '/etc/mailname')) {
    my $hostmailname;
    my @hostmailname;
    my %hostmailname;
    $hostmailname = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/mailname' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/mailname' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
if (StringInterpolation(StringInterpolation { parts: [Variable("hostmailname")] }, None) ne q{}) {
        $addresses = "$addresses " . ${user} . "@$hostmailname";
    }
}
if ((-r '/etc/sysconfig/mail')) {
    $hostmailname = do {
    my $left_result_21 = do {
    my ($in_22, $out_22);
    my $pid_22 = open3($in_22, $out_22, '>&STDERR', q{.}, '/etc/sysconfig/mail');
    close $in_22 or croak 'Close failed: $OS_ERROR';
    my $result_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_22> };
    close $out_22 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_22, 0;
    $result_22
};
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_21 = do { ("$ENV{FROM_HEADER}") };
        $left_result_21 . $right_result_21;
    } else {
        q{};
    }
};
if (StringInterpolation(StringInterpolation { parts: [Variable("hostmailname")] }, None) ne q{}) {
        $addresses = "$addresses " . ${user} . "@$hostmailname";
    }
}
$addresses = "$addresses " . ${user} . "@$hostfqdn";
my $lowercase_sed;
my @lowercase_sed;
my %lowercase_sed;
$lowercase_sed = "{\nh\ns/^[^@]*@\\(.*\\)$/\\1/\ny/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/\nx\ns/^\\([^@]*\\)@.*/\\1@/\nG\ns/\\n//\np\n}";
my $naddresses;
my @naddresses;
my %naddresses;
$naddresses = "";
my $addr;
for my $addr ($addresses) {
if ("$addr" =~ /^<".*">$/msx) {
                $addr = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_23 = q{};
            my $output_printed_23;
            my $pipeline_success_23 = 1;
            $output_23 .= $addr . "\n";
            if ( !($output_23 =~ m{\n\z}msx) ) { $output_23 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_23 = 0; }
            my @sed_lines_23 = split /\n/msx, $output_23;
            my @sed_result_23;
            foreach my $line (@sed_lines_23) {
            chomp $line;
            push @sed_result_23, $line;
            }
            $output_23 = join "\n", @sed_result_23;

            if ( !$pipeline_success_23 ) { $main_exit_code = 1; }
            $output_23 =~ s/\n+\z//msx;
            $output_23;
}; $_pipeline_result; };
    }
if ("$addr" =~ /^.*@.*$/msx) {
                $addr = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_24 = q{};
            my $output_printed_24;
            my $pipeline_success_24 = 1;
            $output_24 .= $addr . "\n";
            if ( !($output_24 =~ m{\n\z}msx) ) { $output_24 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_24 = 0; }
            my @sed_lines_24 = split /\n/msx, $output_24;
            my @sed_result_24;
            foreach my $line (@sed_lines_24) {
            chomp $line;
            push @sed_result_24, $line;
            }
            $output_24 = join "\n", @sed_result_24;

            if ( !$pipeline_success_24 ) { $main_exit_code = 1; }
            $output_24 =~ s/\n+\z//msx;
            $output_24;
}; $_pipeline_result; };
        if (" $naddresses " =~ /^.*" $addr ".*$/msx) {
        } elsif (1) {
                        $naddresses = "$naddresses $addr";
        }
    }
}
$addresses = "$naddresses";
if ("$addresses" =~ /^ ".*" ".*$/msx) {
        my $lines;
    my @lines;
    my %lines;
    $lines = "";
        my $i;
    my @i;
    my %i;
    $i = q{0};
        for my $addr ($addresses) {
        $i = do {
    my ($in_25, $out_25);
    my $pid_25 = open3($in_25, $out_25, '>&STDERR', 'expr', $i, q{+}, q{1});
    close $in_25 or croak 'Close failed: $OS_ERROR';
    my $result_25 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_25> };
    close $out_25 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_25, 0;
    $result_25
};
        $lines = ${lines} . ${i} . " " . ${addr} . "
";
    }
    while ( 1 ) {
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                $main_exit_code = system('gettext', "Which is your email address?") >> 8;
                print "\n";
                $CHILD_ERROR = 0;
        };
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            print $lines;
if ( !( ($lines) =~ m{\n\z}msx ) ) { print "\n"; }
        };
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                $main_exit_code = system('gettext', "Please choose the number, or enter your email address.") >> 8;
                print "\n";
                $CHILD_ERROR = 0;
        };
open STDIN, '<', '/dev/tty' or croak "Cannot open file: $OS_ERROR\n";
$answer = <>;
chomp $answer;
$CHILD_ERROR = defined($answer) ? 0 : 1;
if ("$ENV{answer}" =~ /^.*@.*$/msx) {
        } elsif ("$ENV{answer}" =~ /^\[0-9\].*$/msx) {
                        $i = q{0};
                        for my $addr ($addresses) {
                $i = do {
    my ($in_28, $out_28);
    my $pid_28 = open3($in_28, $out_28, '>&STDERR', 'expr', $i, q{+}, q{1});
    close $in_28 or croak 'Close failed: $OS_ERROR';
    my $result_28 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_28> };
    close $out_28 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_28, 0;
    $result_28
};
if (StringInterpolation(StringInterpolation { parts: [Variable("i")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("answer")] }, None)) {
last LABEL2;
                }
            }
        }
if ("$ENV{answer}" =~ /^<".*">$/msx) {
                        my $answer;
            my @answer;
            my %answer;
            $answer = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_29 = q{};
                my $output_printed_29;
                my $pipeline_success_29 = 1;
                $output_29 .= $answer . "\n";
                if ( !($output_29 =~ m{\n\z}msx) ) { $output_29 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_29 = 0; }
                my @sed_lines_29 = split /\n/msx, $output_29;
                my @sed_result_29;
                foreach my $line (@sed_lines_29) {
                chomp $line;
                push @sed_result_29, $line;
                }
                $output_29 = join "\n", @sed_result_29;

                if ( !$pipeline_success_29 ) { $main_exit_code = 1; }
                $output_29 =~ s/\n+\z//msx;
                $output_29;
}; $_pipeline_result; };
        }
if ("$answer" =~ /^.*" ".*$/msx) {
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                    $main_exit_code = system('gettext', "Invalid email address: invalid character.") >> 8;
                    print "\n";
                    $CHILD_ERROR = 0;
                    print "\n";
                    $CHILD_ERROR = 0;
            };
            next;        } elsif ("$answer" =~ /^.*@.*..*$/msx) {
        } elsif ("$answer" =~ /^.*@.*$/msx) {
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                    $main_exit_code = system('gettext', "Invalid email address: need a fully qualified host name or domain name.") >> 8;
                    print "\n";
                    $CHILD_ERROR = 0;
                    print "\n";
                    $CHILD_ERROR = 0;
            };
            next;        } elsif (1) {
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                    $main_exit_code = system('gettext', "Invalid email address: missing @") >> 8;
                    print "\n";
                    $CHILD_ERROR = 0;
                    print "\n";
                    $CHILD_ERROR = 0;
            };
            next;        }
        $addr = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_30 = q{};
            my $output_printed_30;
            my $pipeline_success_30 = 1;
            $output_30 .= $answer . "\n";
            if ( !($output_30 =~ m{\n\z}msx) ) { $output_30 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_30 = 0; }
            my @sed_lines_30 = split /\n/msx, $output_30;
            my @sed_result_30;
            foreach my $line (@sed_lines_30) {
            chomp $line;
            push @sed_result_30, $line;
            }
            $output_30 = join "\n", @sed_result_30;

            if ( !$pipeline_success_30 ) { $main_exit_code = 1; }
            $output_30 =~ s/\n+\z//msx;
            $output_30;
}; $_pipeline_result; };
last;
    }
} elsif ("$addresses" =~ /^ ".*$/msx) {
    while ( 1 ) {
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                $main_exit_code = system('gettext', "Is the following your email address?") >> 8;
                print "\n";
                $CHILD_ERROR = 0;
        };
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = " $addresses";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                $main_exit_code = system('gettext', "Please confirm by pressing Return, or enter your email address.") >> 8;
                print "\n";
                $CHILD_ERROR = 0;
        };
open STDIN, '<', '/dev/tty' or croak "Cannot open file: $OS_ERROR\n";
$answer = <>;
chomp $answer;
$CHILD_ERROR = defined($answer) ? 0 : 1;
if (StringInterpolation(StringInterpolation { parts: [Variable("answer")] }, None) eq q{}) {
            $addr = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_33 = q{};
                my $output_printed_33;
                my $pipeline_success_33 = 1;
                $output_33 .= $addresses . "\n";
                if ( !($output_33 =~ m{\n\z}msx) ) { $output_33 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_33 = 0; }
                my @sed_lines_33 = split /\n/msx, $output_33;
                my @sed_result_33;
                foreach my $line (@sed_lines_33) {
                chomp $line;
                push @sed_result_33, $line;
                }
                $output_33 = join "\n", @sed_result_33;

                if ( !$pipeline_success_33 ) { $main_exit_code = 1; }
                $output_33 =~ s/\n+\z//msx;
                $output_33;
}; $_pipeline_result; };
last;
        }
if ("$answer" =~ /^<".*">$/msx) {
                        $answer = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_34 = q{};
                my $output_printed_34;
                my $pipeline_success_34 = 1;
                $output_34 .= $answer . "\n";
                if ( !($output_34 =~ m{\n\z}msx) ) { $output_34 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_34 = 0; }
                my @sed_lines_34 = split /\n/msx, $output_34;
                my @sed_result_34;
                foreach my $line (@sed_lines_34) {
                chomp $line;
                push @sed_result_34, $line;
                }
                $output_34 = join "\n", @sed_result_34;

                if ( !$pipeline_success_34 ) { $main_exit_code = 1; }
                $output_34 =~ s/\n+\z//msx;
                $output_34;
}; $_pipeline_result; };
        }
if ("$answer" =~ /^.*" ".*$/msx) {
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                    $main_exit_code = system('gettext', "Invalid email address: invalid character.") >> 8;
                    print "\n";
                    $CHILD_ERROR = 0;
                    print "\n";
                    $CHILD_ERROR = 0;
            };
            next;        } elsif ("$answer" =~ /^.*@.*..*$/msx) {
        } elsif ("$answer" =~ /^.*@.*$/msx) {
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                    $main_exit_code = system('gettext', "Invalid email address: need a fully qualified host name or domain name.") >> 8;
                    print "\n";
                    $CHILD_ERROR = 0;
                    print "\n";
                    $CHILD_ERROR = 0;
            };
            next;        } elsif (1) {
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                    $main_exit_code = system('gettext', "Invalid email address: missing @") >> 8;
                    print "\n";
                    $CHILD_ERROR = 0;
                    print "\n";
                    $CHILD_ERROR = 0;
            };
            next;        }
        $addr = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_35 = q{};
            my $output_printed_35;
            my $pipeline_success_35 = 1;
            $output_35 .= $answer . "\n";
            if ( !($output_35 =~ m{\n\z}msx) ) { $output_35 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_35 = 0; }
            my @sed_lines_35 = split /\n/msx, $output_35;
            my @sed_result_35;
            foreach my $line (@sed_lines_35) {
            chomp $line;
            push @sed_result_35, $line;
            }
            $output_35 = join "\n", @sed_result_35;

            if ( !$pipeline_success_35 ) { $main_exit_code = 1; }
            $output_35 =~ s/\n+\z//msx;
            $output_35;
}; $_pipeline_result; };
last;
    }
} elsif ("$addresses" =~ /^$/msx) {
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            $main_exit_code = system('gettext', "Couldn't find out about your email address.") >> 8;
            print "\n";
            $CHILD_ERROR = 0;
    };
    while ( 1 ) {
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                $main_exit_code = system('gettext', "Please enter your email address.") >> 8;
                print "\n";
                $CHILD_ERROR = 0;
        };
open STDIN, '<', '/dev/tty' or croak "Cannot open file: $OS_ERROR\n";
$answer = <>;
chomp $answer;
$CHILD_ERROR = defined($answer) ? 0 : 1;
if ("$answer" =~ /^<".*">$/msx) {
                        $answer = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_38 = q{};
                my $output_printed_38;
                my $pipeline_success_38 = 1;
                $output_38 .= $answer . "\n";
                if ( !($output_38 =~ m{\n\z}msx) ) { $output_38 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_38 = 0; }
                my @sed_lines_38 = split /\n/msx, $output_38;
                my @sed_result_38;
                foreach my $line (@sed_lines_38) {
                chomp $line;
                push @sed_result_38, $line;
                }
                $output_38 = join "\n", @sed_result_38;

                if ( !$pipeline_success_38 ) { $main_exit_code = 1; }
                $output_38 =~ s/\n+\z//msx;
                $output_38;
}; $_pipeline_result; };
        }
if ("$answer" =~ /^.*" ".*$/msx) {
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                    $main_exit_code = system('gettext', "Invalid email address: invalid character.") >> 8;
                    print "\n";
                    $CHILD_ERROR = 0;
                    print "\n";
                    $CHILD_ERROR = 0;
            };
            next;        } elsif ("$answer" =~ /^.*@.*..*$/msx) {
        } elsif ("$answer" =~ /^.*@.*$/msx) {
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                    $main_exit_code = system('gettext', "Invalid email address: need a fully qualified host name or domain name.") >> 8;
                    print "\n";
                    $CHILD_ERROR = 0;
                    print "\n";
                    $CHILD_ERROR = 0;
            };
            next;        } elsif (1) {
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                    $main_exit_code = system('gettext', "Invalid email address: missing @") >> 8;
                    print "\n";
                    $CHILD_ERROR = 0;
                    print "\n";
                    $CHILD_ERROR = 0;
            };
            next;        }
        $addr = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_39 = q{};
            my $output_printed_39;
            my $pipeline_success_39 = 1;
            $output_39 .= $answer . "\n";
            if ( !($output_39 =~ m{\n\z}msx) ) { $output_39 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_39 = 0; }
            my @sed_lines_39 = split /\n/msx, $output_39;
            my @sed_result_39;
            foreach my $line (@sed_lines_39) {
            chomp $line;
            push @sed_result_39, $line;
            }
            $output_39 = join "\n", @sed_result_39;

            if ( !$pipeline_success_39 ) { $main_exit_code = 1; }
            $output_39 =~ s/\n+\z//msx;
            $output_39;
}; $_pipeline_result; };
last;
    }
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        print "internal error\n";
    };
    exit 1;
}
print $addr;
if ( !( ($addr) =~ m{\n\z}msx ) ) { print "\n"; }

exit $main_exit_code;
