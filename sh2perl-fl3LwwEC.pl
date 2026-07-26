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


sub vampiredrivers_readme {
    # Original bash: echo -e " \n\
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
        $output_0 .= " \n\\\n############################################################################\n#\n#    About the \"Vampire Printer Drivers\" set of functions....\n#    --------------------------------------------------------\n#\n# (C) Kurt Pfeifle <kpfeifle@danka.de>, 2004\n# License: GPL\n#\n# ------------------------------------------------------------\n#\n# Version: 0.8 (largely \"self-documented\" now, but not yet\n#               completely -- if it ever will be....)\n#\n# Thanks a lot to Fabian Franz for helping me with some important\n# Bash-Scripting-Questions!\n#\n# This set of functions provides a framework to snatch all printer\n# driver info and related files from a Windows NT print server.\n# It then uploads and installs the drivers to a Samba server. (The\n# Samba server needs to be prepared for this: a valid [print$]\n# share, with write access set for a user with SePrintOperatorPrivilege.)\n#\n# The main commands used are \"smbclient\" and \"rpcclient\" combined\n# with \"grep\", \"sed\" and \"awk\". Probably a Perl or Python script\n# would be better suited to do this, mainly because we have to cope\n# with printer and driver names which are containing spaces in\n# them, so a lot of shell escaping is required to handle these.\n# Also, I am not very savvy in scripting, so I invented some very\n# obscure methods to work around my knowledge gaps. When I download\n# the driver files from the Windows NT box, I put all related driver\n# files into their own sub directory, using the same name as the\n# driver. Also, driver versions \"0\", \"2\" and \"3\" are placed in\n# further subdirectories.\n#\n#\n# Known problems:\n# ---------------\n#\n# 1) I found one printer driver containing a \"slash\" which is not\n#    handled by this script: \"HP Color LaserJet 5/5M PS\". (There\n#    are more of these in the wild, of course.)  -- The reason: I\n#    didn't find a way to create a Unix directory containing a \"slash\".\n#    UPDATE: The script replaces the \"/\" with a \"_\" and also renames\n#    the drivername accordingly, when it is uploaded to the Samba\n#    [print$] share....\n#\n# 2) There is an unsolved problem in case a real file name deviates\n#    in its case sensitive spelling from how it is displayed by the\n#    \"rpcclient enumdrivers\" command. I encountered cases where\n#    rpcclient displayed \"PS5UI.DLL\" as a file name, but \"smbclient\n#    mget\" retrieved \"ps5ui.dll\" from the NT printserver, and the\n#    driverinstallation failed because \"smbclient mput\" tried to put\n#    \"PS5UI.DLL\" back onto the Samba server where UNIX only had\n#    \"ps5ui.dll\" available (which of course failed). -- UPDATE: this\n#    is now solved. All files are renamed now to the same\n#    case-sensitive spelling as \"rpcclient ... enumdrivers 3\"\n#    announces. This includes renaming into both, uppercase or\n#    lowercase, as the case might be....\n#\n# 3) This script is probably not portable at all and relies on lots\n#    of Bash-isms.\n#\n# 4) This script runs with rpcclient from Samba-3.0.2a (or later) only\n#    (because it uses the \"Version\" parameter for \"adddriver\").\n#\n# The following functions use a few external variables to log\n# into the 2 hosts. We suggest that you create a file which\n# contains the variables and that you source that file at the\n# beginning of this script...\n#\n# #################################################################\n#\n# ntprinteradmin=Administrator   # any account on the NT host\n#                                # with SePrintOperatorPrivilege privileges\n# ntadminpasswd=not4you          # the printer admin password on\n#                                # the NT print server\n# nthost=windowsntprintserverbox # the netbios name of the NT print\n#                                # server\n#\n# smbprinteradmin=knoppix        # an account on the Samba server\n#                                # with SePrintOperatorPrivilege privileges\n# smbadminpasswd=2secret4you     # the printer admin password on\n#                                # the Samba server\n# smbhost=knoppix                # the netbios name of the Samba\n#                                # print server\n#\n# #################################################################\n#\n#\n# NOTE: these functions also work for 2 NT print servers: snatch all\n# drivers from the first, and upload them to the second server (which\n# takes the role of the \"Samba\" server). Of course they also work\n# for 2 Samba servers: snatch all drivers from the first (which takes\n# the role of the NT print server) and upload them to the second....\n#\n#\n#           ............PRESS \"q\" TO QUIT............";
if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_2 = 'less';
        my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', $cmd_2, );
        print {$in_1} $output_0;
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;
        if ($output_0 ne q{} && !defined $output_printed_0) {
            print $output_0;
            if (!($output_0 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        }
    return;
}

sub helpwithvampiredrivers {
if (!(    $main_exit_code = system('stringinstring', 'help', "@ARGV") >> 8)) {
        $main_exit_code = system('bash', 'helpwithvampiredrivers') >> 8;
}
    else {
        print "  \n";
        print "  1. Run the functions of this script one by one.\n";
        print "  \n";
        print "  2. List all functions with the \"enumallfunctions\" call.\n";
        print "  \n";
        print "  3. After each functions' run, check if it completed successfully.\n";
        print "  \n";
        print "  4. For each function, you can ask for separate help by typing\n";
        print "     \"<functionname> --help\".\n";
        print "  \n";
        print "  5. Often network conditions prevent the MS-RPC calls\n";
        print "     implemented by Samba to succeed at the first attempt.\n";
        print "     You may have more joy if you try more than once or twice....\n";
        print "  \n";
        print "  6. I can not support end-users who have problems with this script.\n";
        print "     However, we are available for paid, professional consulting,\n";
        print "     training and troubleshooting work.\n";
        print "  \n";
        print "  \n";
    }
    return;
}

sub enumallfunctions {
if (!(    $main_exit_code = system('stringinstring', 'help', "@ARGV") >> 8)) {
        helpwithvampiredrivers();
}
    else {
        print " \n";
        print " \n";
        print "--> Running now function enumallfunctions()...\n";
        print "==============================================\n";
        do {
    my $__echo_line = " \n\\\n\n       NOTE: run the listed functions in the same order as listed below.\n\n    EXAMPLE: \"knoppix@ttyp6[knoppix]$ helpwithvampiredrivers\"\n\n       HELP: the \"--help\" parameter prints usage hints regarding a function.\n\n    EXAMPLE: \"knoppix@ttyp6[knoppix]$ fetchenumdrivers3listfromNThost --help\"\n\n\n   function vampiredrivers_readme()\n   function enumallfunctions()\n   function helpwithvampiredrivers()\n   function fetchenumdrivers3listfromNThost()  # repeat, if no success at first\n   function createdrivernamelist()\n   function createprinterlistwithUNCnames()    # repeat, if no success at first\n   function createmapofprinterstodrivers()\n   function splitenumdrivers3list()\n   function makesubdirsforW32X86driverlist()\n     function splitW32X86fileintoindividualdriverfiles()\n     function fetchallW32X86driverfiles()\n     function uploadallW32X86drivers()\n   function makesubdirsforWIN40driverlist()\n     function splitWIN40fileintoindividualdriverfiles()\n     function fetchallWIN40driverfiles()\n     function uploadallWIN40drivers()";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print " \n";
    }
    return;
}

sub stringinstring {
if ("$_[1]" =~ /^.*$1.*$/msx) {
        return q{0};    }
return q{1};
    return;
}

sub helpwithfetchenumdrivers3listfromNThost {
    do {
    my $__echo_line = " \n\\\n################################################################################\n#\n#                About fetchenumdrivers3listfromNThost()....\n#                -------------------------------------------\n#\n# PRECONDITIONS: 1) This function expects write access to the current directory.\n#\t\t 2) This function expects to have the '$nthosts',\n#\t\t    '$ntprinteradmin' and '$ntadminpasswd' variables set to\n#\t\t    according values.\n#\n# WHAT IT DOES: This function connects to the '$nthost' (using the credentials\n#\t\t'$ntprinteradmin' with '$ntadminpasswd', retrieves a list of\n#\t\tdrivers (with related file names) from that host, and saves the\n#\t\tlist under the name of '${nthost}/enumdrivers3list.txt' (ie. it\n#\t\talso creates the '$nthost' subdirectory in the current one). It\n#\t\tfurther prints some more info to stdout.\n#\n# IF IT DOESN'T WORK: It may happen that the function doesn't work at the first\n#\t\t      time (there may be a connection problem). Just repeat a\n#\t\t      few times. It may work then. You will recognize if it\n#\t\t      does.\n#\n# HINT: The current values: 'nthost'=\"$nthost\n#\t\t\t    'ntprinteradmin'=$ntprinteradmin\"\n#\t\t\t    'ntadminpasswd'=<not shown here, check yourself!>\n#\n################################################################################";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print " \n";
    return;
}

sub fetchenumdrivers3listfromNThost {
if (!(    stringinstring('help', "@ARGV"))) {
        helpwithfetchenumdrivers3listfromNThost();
}
    else {
        print " \n";
        print " \n";
        print "--> Running now function fetchenumdrivers3listfromNThost\n";
        print "========================================================\n";
        if (!((-d ${nthost}))) {
                        use File::Path qw(make_path);
            my $err;
            if ( mkdir ($ENV{nthost} // q{}) ) {
                }
            else {
                croak "mkdir: cannot create directory " . ($ENV{nthost} // q{}) . ": File exists\n";
            }
        }
        # Original bash: rpcclient -U${ntprinteradmin}%${ntadminpasswd} -c 'enumdrivers 3' ${nthost} \
{
            my $output_4 = q{};
            my $output_printed_4;
            my $pipeline_success_4 = 1;
                        my ($in_5, $out_5);
            my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'rpcclient', '-U', q{%}, '-c', 'enumdrivers 3');
            close $in_5 or croak 'Close failed: $OS_ERROR';
            $output_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
            close $out_5 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_5, 0;

                        my @sed_lines_4 = split /\n/msx, $output_4;
            my @sed_result_4;
            foreach my $line (@sed_lines_4) {
            chomp $line;
            push @sed_result_4, $line;
            }
            $output_4 = join "\n", @sed_result_4;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_4;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/enumdrivers3list.txt' ) {
            print {$fh} $output_4;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/enumdrivers3list.txt': $ERRNO";
            }
            $output_4 = $output_4;
            if ($output_4 ne q{} && !defined $output_printed_4) {
                print $output_4;
                if (!($output_4 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
            }
        my $NUMBEROFDIFFERENTDRIVERNAMES;
        my @NUMBEROFDIFFERENTDRIVERNAMES;
        my %NUMBEROFDIFFERENTDRIVERNAMES;
        $NUMBEROFDIFFERENTDRIVERNAMES = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_6 = q{};
            my $output_printed_6;
            my $pipeline_success_6 = 1;
            my $grep_result_6_0;
            my @grep_lines_6_0 = ();
            my @grep_filenames_6_0 = ();
            if (-e "/enumdrivers3list.txt") {
                open my $fh, '<', "/enumdrivers3list.txt" or croak "Cannot open file: $ERRNO";
                while (my $line = <$fh>) {
                    chomp $line;
                    push @grep_lines_6_0, $line;
                    push @grep_filenames_6_0, "/enumdrivers3list.txt";
                }
                close $fh
                    or croak "Close failed: $OS_ERROR";
            }
            else { print {*STDERR} "grep: /enumdrivers3list.txt: No such file or directory\n"; }
            my @grep_filtered_6_0 = grep { /Driver\ Name:/msx } @grep_lines_6_0;
            $grep_result_6_0 = join "\n", @grep_filtered_6_0;
                        if (!($grep_result_6_0 =~ m{\n\z}msx || $grep_result_6_0 eq q{})) {
                            $grep_result_6_0 .= "\n";
                        }
            $CHILD_ERROR = scalar @grep_filtered_6_0 > 0 ? 0 : 1;
            $output_6 = $grep_result_6_0;
            if ($CHILD_ERROR != 0) { $pipeline_success_6 = 0; }
            my @sort_lines_6_1 = split /\n/msx, $output_6;
            my @sort_sorted_6_1 = sort @sort_lines_6_1;
            $output_6 = join "\n", @sort_sorted_6_1;
                        if ($output_6 ne q{} && !($output_6 =~ m{\n\z}msx)) {
                            $output_6 .= "\n";
                        }
            my @uniq_lines_6_2 = split /\n/msx, $output_6;
            @uniq_lines_6_2 = grep { $_ ne q{} } @uniq_lines_6_2; # Filter out empty lines
            my %uniq_seen_6_2;
            my @uniq_result_6_2;
            foreach my $line (@uniq_lines_6_2) {
            if (!$uniq_seen_6_2{$line}++) { push @uniq_result_6_2, $line; }
            }
            $output_6 = join "\n", @uniq_result_6_2;
                        if ($output_6 ne q{} && !($output_6 =~ m{\n\z}msx)) {
                            $output_6 .= "\n";
                        }
            $output_6 = do {
                            my $_wc_data = $output_6;
                            my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
                            my $_wc_result = q{};
                            $_wc_result .= sprintf q{%d}, $_wc_lines;
                            $_wc_result .= "\n";
                            $_wc_result;
                        };
            if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
            $output_6 =~ s/\n+\z//msx;
            $output_6;
}; $_pipeline_result; };
        print " \n";
        print "--> Finished in running function fetchenumdrivers3listfromNThost....\n";
        print "====================================================================\n";
        do {
    my $__echo_line = "NUMBEROFDIFFERENTDRIVERNAMES retrieved from \"" . ($ENV{nthost} // q{}) . "\" is $NUMBEROFDIFFERENTDRIVERNAMES" . q{ } . q{.};
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print "  -->  If you got \"0\" you may want to try again. <---\n";
        print "================================================================\n";
        print " \n";
        my $enumdrivers3list;
        my @enumdrivers3list;
        my %enumdrivers3list;
        $enumdrivers3list = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $nthost ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nthost . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/enumdrivers3list.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/enumdrivers3list.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
    }
    return;
}

sub helpwithcreatedrivernamelist {
    do {
    my $__echo_line = " \n\\\n################################################################################\n#\n#                About createdrivernamelist()...\n#                -------------------------------\n#\n# PRECONDITIONS: 1) This function expects to find the subdirectory '$nthost'\n#\t\t    and the file '${nthost}/enumdrivers3list.txt' to exist.\n#\t\t 2) This function expects to have the '$nthosts' variable set\n#\t\t    to an according value.\n#\n# WHAT IT DOES: This function dissects the '${nthost}/enumdrivers3list.txt'\n#\t\tand creates other textfiles from its contents:\n#\t\t- '${nthost}/drvrlst.txt'\n#\t\t- '${nthost}/completedriverlist.txt'\n#\t\tand further prints some more info to stdout.\n#\n# HINT: The current value: 'nthost'=\"$nthost\"\n#\n################################################################################";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}

sub createdrivernamelist {
    my ($file) = @_;
if (!(    stringinstring('help', "@ARGV"))) {
        helpwithcreatedrivernamelist();
}
    else {
        print " \n";
        print " \n";
        print "--> Running now function createdrivernamelist....\n";
        print "=================================================\n";
        # Original bash: cat ${nthost}/enumdrivers3list.txt \
{
            my $output_7 = q{};
            my $output_printed_7;
            my $pipeline_success_7 = 1;
                        $output_7 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $nthost ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nthost . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/enumdrivers3list.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/enumdrivers3list.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });

                        my $grep_result_7_1;
            my @grep_lines_7_1 = split /\n/msx, $output_7;
            my @grep_filtered_7_1 = grep { /Driver\ Name:/msx } @grep_lines_7_1;
            $grep_result_7_1 = join "\n", @grep_filtered_7_1;
            if (!($grep_result_7_1 =~ m{\n\z}msx || $grep_result_7_1 eq q{})) {
            $grep_result_7_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_7_1 > 0 ? 0 : 1;
            $output_7 = $grep_result_7_1;
            $output_7 = $grep_result_7_1;

                        my @lines = split /\n/msx, $output_7;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /[/msx, $line;
            push @result, ($fields[1] . "\n");
            }
            $output_7 = join "", @result;

                        my @lines = split /\n/msx, $output_7;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /]/msx, $line;
            push @result, ($fields[0] . "\n");
            }
            $output_7 = join "", @result;

                        my @sort_lines_7_4 = split /\n/msx, $output_7;
            my @sort_sorted_7_4 = sort @sort_lines_7_4;
            my $output_7_4 = join "\n", @sort_sorted_7_4;
            if ($output_7_4 ne q{} && !($output_7_4 =~ m{\n\z}msx)) {
            $output_7_4 .= "\n";
            }
            $output_7 = $output_7_4;
            $output_7 = $output_7_4;

                        my @uniq_lines_7_5 = split /\n/msx, $output_7;
            @uniq_lines_7_5 = grep { $_ ne q{} } @uniq_lines_7_5; # Filter out empty lines
            my %uniq_seen_7_5;
            my @uniq_result_7_5;
            foreach my $line (@uniq_lines_7_5) {
            if (!$uniq_seen_7_5{$line}++) { push @uniq_result_7_5, $line; }
            }
            my $output_7_5 = join "\n", @uniq_result_7_5;
            if ($output_7_5 ne q{} && !($output_7_5 =~ m{\n\z}msx)) {
            $output_7_5 .= "\n";
            }
            $output_7 = $output_7_5;

                        my $set1_8 = q{/};
            my $set2_8 = q{_};
            my $input_8 = $output_7;
            # Expand character ranges for tr command
            my $expanded_set1_8 = $set1_8;
            my $expanded_set2_8 = $set2_8;
            # Handle a-z range in set1
            if ($expanded_set1_8 =~ /a-z/msx) {
            $expanded_set1_8 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle A-Z range in set1
            if ($expanded_set1_8 =~ /A-Z/msx) {
            $expanded_set1_8 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:upper:] POSIX class in set1
            if ($expanded_set1_8 =~ /\[:upper:\]/msx) {
            $expanded_set1_8 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:lower:] POSIX class in set1
            if ($expanded_set1_8 =~ /\[:lower:\]/msx) {
            $expanded_set1_8 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle a-z range in set2
            if ($expanded_set2_8 =~ /a-z/msx) {
            $expanded_set2_8 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle A-Z range in set2
            if ($expanded_set2_8 =~ /A-Z/msx) {
            $expanded_set2_8 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:upper:] POSIX class in set2
            if ($expanded_set2_8 =~ /\[:upper:\]/msx) {
            $expanded_set2_8 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:lower:] POSIX class in set2
            if ($expanded_set2_8 =~ /\[:lower:\]/msx) {
            $expanded_set2_8 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
            }
            my $tr_result_7_6 = q{};
            for my $char ( split //msx, $input_8 ) {
            my $pos_8 = index $expanded_set1_8, $char;
            if ( $pos_8 >= 0 && $pos_8 < length $expanded_set2_8 ) {
            $tr_result_7_6 .= substr $expanded_set2_8, $pos_8, 1;
            } else {
            $tr_result_7_6 .= $char;
            }
            }
            if (!($tr_result_7_6 =~ m{\n\z}msx || $tr_result_7_6 eq q{})) {
            $tr_result_7_6 .= "\n";
            }
            $output_7 = $tr_result_7_6;
            $output_7 = $tr_result_7_6;

                        my @sed_lines_7 = split /\n/msx, $output_7;
            my @sed_result_7;
            foreach my $line (@sed_lines_7) {
            chomp $line;
            push @sed_result_7, $line;
            }
            $output_7 = join "\n", @sed_result_7;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_7;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/drvrlst.txt' ) {
            print {$fh} $output_7;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/drvrlst.txt': $ERRNO";
            }
            $output_7 = $output_7;
            if ($output_7 ne q{} && !defined $output_printed_7) {
                print $output_7;
                if (!($output_7 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
            }
        my $drvrlst;
        my @drvrlst;
        my %drvrlst;
        $drvrlst = ($nthost . q{ } . '/drvrlst.txt');
        # Original bash: cat ${nthost}/enumdrivers3list.txt \
{
            my $output_9 = q{};
            my $output_printed_9;
            my $pipeline_success_9 = 1;
                        $output_9 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $nthost ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nthost . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/enumdrivers3list.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/enumdrivers3list.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });

                        my $grep_result_9_1;
            my @grep_lines_9_1 = split /\n/msx, $output_9;
            my @grep_filtered_9_1 = grep { /Driver\ Name:/msx } @grep_lines_9_1;
            $grep_result_9_1 = join "\n", @grep_filtered_9_1;
            if (!($grep_result_9_1 =~ m{\n\z}msx || $grep_result_9_1 eq q{})) {
            $grep_result_9_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_9_1 > 0 ? 0 : 1;
            $output_9 = $grep_result_9_1;
            $output_9 = $grep_result_9_1;

                        my @lines = split /\n/msx, $output_9;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /[/msx, $line;
            push @result, ($fields[1] . "\n");
            }
            $output_9 = join "", @result;

                        my @lines = split /\n/msx, $output_9;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /]/msx, $line;
            push @result, ($fields[0] . "\n");
            }
            $output_9 = join "", @result;

                        my @sort_lines_9_4 = split /\n/msx, $output_9;
            my @sort_sorted_9_4 = sort @sort_lines_9_4;
            my $output_9_4 = join "\n", @sort_sorted_9_4;
            if ($output_9_4 ne q{} && !($output_9_4 =~ m{\n\z}msx)) {
            $output_9_4 .= "\n";
            }
            $output_9 = $output_9_4;
            $output_9 = $output_9_4;

                        my @uniq_lines_9_5 = split /\n/msx, $output_9;
            @uniq_lines_9_5 = grep { $_ ne q{} } @uniq_lines_9_5; # Filter out empty lines
            my %uniq_seen_9_5;
            my @uniq_result_9_5;
            foreach my $line (@uniq_lines_9_5) {
            if (!$uniq_seen_9_5{$line}++) { push @uniq_result_9_5, $line; }
            }
            my $output_9_5 = join "\n", @uniq_result_9_5;
            if ($output_9_5 ne q{} && !($output_9_5 =~ m{\n\z}msx)) {
            $output_9_5 .= "\n";
            }
            $output_9 = $output_9_5;

                        my @sed_lines_9 = split /\n/msx, $output_9;
            my @sed_result_9;
            foreach my $line (@sed_lines_9) {
            chomp $line;
            push @sed_result_9, $line;
            }
            $output_9 = join "\n", @sed_result_9;

                        $output_9 = do { my $cat_out = q{}; my $cat_pid = open3(my $cat_in, my $cat_out_r, undef, 'cat', '-n'); close $cat_in or croak 'Close failed: $OS_ERROR'; local $INPUT_RECORD_SEPARATOR = undef; $cat_out = <$cat_out_r>; close $cat_out_r or croak 'Close failed: $OS_ERROR'; waitpid $cat_pid, 0; $cat_out; };

                        my @sed_lines_9 = split /\n/msx, $output_9;
            my @sed_result_9;
            foreach my $line (@sed_lines_9) {
            chomp $line;
            push @sed_result_9, $line;
            }
            $output_9 = join "\n", @sed_result_9;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_9;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/completedriverlist.txt' ) {
            print {$fh} $output_9;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/completedriverlist.txt': $ERRNO";
            }
            $output_9 = $output_9;
            if ($output_9 ne q{} && !defined $output_printed_9) {
                print $output_9;
                if (!($output_9 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
            }
        my $NUMBEROFDRIVERS;
        my @NUMBEROFDRIVERS;
        my %NUMBEROFDRIVERS;
        $NUMBEROFDRIVERS = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_10 = q{};
            my $output_printed_10;
            my $pipeline_success_10 = 1;
            $output_10 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $nthost ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nthost . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/completedriverlist.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/completedriverlist.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
            if ($CHILD_ERROR != 0) { $pipeline_success_10 = 0; }
            $output_10 = do {
                            my $_wc_data = $output_10;
                            my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
                            my $_wc_result = q{};
                            $_wc_result .= sprintf q{%d}, $_wc_lines;
                            $_wc_result .= "\n";
                            $_wc_result;
                        };
            if ( !$pipeline_success_10 ) { $main_exit_code = 1; }
            $output_10 =~ s/\n+\z//msx;
            $output_10;
}; $_pipeline_result; };
        print " \n";
        print "--> Finished in running function createdrivernamelist....\n";
        print "===============================================================================\n";
        do {
    my $__echo_line = "NUMBEROFDRIVERS retrieve-able from \"" . ($ENV{nthost} // q{}) . "\" is $NUMBEROFDRIVERS" . q{ } . q{.};
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print "  -->  If you got \"0\" you may want to run \"fetchenumdrivers3listfromNThost\"\n";
        print "       again. <---\n";
        print "===============================================================================\n";
        print " \n";
        my $driverlist;
        my @driverlist;
        my %driverlist;
        $driverlist = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $nthost ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nthost . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/completedriverlist.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/completedriverlist.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
    }
    return;
}

sub helpwithcreateprinterlistwithUNCnames {
    do {
    my $__echo_line = " \n\\\n################################################################################\n#\n#                About createprinterlistwithUNCnames()...\n#                ----------------------------------------\n#\n# PRECONDITIONS: 1) This function expects write access to the current directory.\n#\t\t 2) This function expects to have the '$nthost',\n#\t\t    '$ntprinteradmin' and '$ntadminpasswd' variables set to\n#\t\t    according values.\n#\n# WHAT IT DOES: This function connects to the '$nthost' (using the credentials\n#\t\t'$ntprinteradmin' with '$ntadminpasswd'), retrieves a list of\n#\t\tprintqueues (with associated driver names) from that host (with\n#\t\tthe help of the 'rpcclient ... enumprinters' utility, and saves\n#\t\tit under name and path '${nthost}/printerlistwithUNCnames.txt'\n#\t\t(ie. it also creates the '$nthost' subdirectory in the current\n#\t\tone). It further prints some more info to stdout.\n#\n# IF IT DOESN'T WORK: It may happen that the function doesn't work at the first\n#\t\t      time (there may be a connection problem). Just repeat a\n#\t\t      few times. It may work then. You will recognize if it does.\n#\n# HINT: The current values: 'nthost'=\"$nthost\n#\t\t\t    'ntprinteradmin'=$ntprinteradmin\"\n#\t\t\t    'ntadminpasswd'=<not shown here, check yourself!>\n#\n################################################################################";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}

sub createprinterlistwithUNCnames {
    my ($file) = @_;
if (!(    stringinstring('help', "@ARGV"))) {
        helpwithcreateprinterlistwithUNCnames();
}
    else {
        if (!((-d ${nthost}))) {
                        use File::Path qw(make_path);
            my $err;
            if ( !-d $nthost ) {
                make_path( $nthost, { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . $nthost . ": $err->[0]\n";
                }
            }
        }
        print " \n";
        print " \n";
        print " \n";
        print "--> Running now function createprinterlistwithUNCnames()....\n";
        print "============================================================\n";
        # Original bash: rpcclient -U"${ntprinteradmin}%${ntadminpasswd}" -c 'enumprinters' ${nthost} \
{
            my $output_12 = q{};
            my $output_printed_12;
            my $pipeline_success_12 = 1;
                        my ($in_13, $out_13);
            my $pid_13 = open3($in_13, $out_13, '>&STDERR', 'rpcclient', '-U', '-c', 'enumprinters');
            close $in_13 or croak 'Close failed: $OS_ERROR';
            $output_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
            close $out_13 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_13, 0;

                        my $grep_result_12_1;
            my @grep_lines_12_1 = split /\n/msx, $output_12;
            my @grep_filtered_12_1 = grep { /description:/msx } @grep_lines_12_1;
            $grep_result_12_1 = join "\n", @grep_filtered_12_1;
            if (!($grep_result_12_1 =~ m{\n\z}msx || $grep_result_12_1 eq q{})) {
            $grep_result_12_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_12_1 > 0 ? 0 : 1;
            $output_12 = $grep_result_12_1;
            $output_12 = $grep_result_12_1;

                        my @lines = split /\n/msx, $output_12;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /[/msx, $line;
            push @result, ($fields[1] . "\n");
            }
            $output_12 = join "", @result;

                        my @lines = split /\n/msx, $output_12;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /]/msx, $line;
            push @result, ($fields[0] . "\n");
            }
            $output_12 = join "", @result;

                        my @sort_lines_12_4 = split /\n/msx, $output_12;
            my @sort_sorted_12_4 = sort @sort_lines_12_4;
            my $output_12_4 = join "\n", @sort_sorted_12_4;
            if ($output_12_4 ne q{} && !($output_12_4 =~ m{\n\z}msx)) {
            $output_12_4 .= "\n";
            }
            $output_12 = $output_12_4;
            $output_12 = $output_12_4;

                        my @uniq_lines_12_5 = split /\n/msx, $output_12;
            @uniq_lines_12_5 = grep { $_ ne q{} } @uniq_lines_12_5; # Filter out empty lines
            my %uniq_seen_12_5;
            my @uniq_result_12_5;
            foreach my $line (@uniq_lines_12_5) {
            if (!$uniq_seen_12_5{$line}++) { push @uniq_result_12_5, $line; }
            }
            my $output_12_5 = join "\n", @uniq_result_12_5;
            if ($output_12_5 ne q{} && !($output_12_5 =~ m{\n\z}msx)) {
            $output_12_5 .= "\n";
            }
            $output_12 = $output_12_5;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_12;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/printerlistwithUNCnames.txt' ) {
            print {$fh} $output_12;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/printerlistwithUNCnames.txt': $ERRNO";
            }
            $output_12 = $output_12;
            if ($output_12 ne q{} && !defined $output_printed_12) {
                print $output_12;
                if (!($output_12 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
            }
        my $NUMBEROFPRINTERS;
        my @NUMBEROFPRINTERS;
        my %NUMBEROFPRINTERS;
        $NUMBEROFPRINTERS = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_14 = q{};
            my $output_printed_14;
            my $pipeline_success_14 = 1;
            $output_14 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $nthost ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nthost . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/printerlistwithUNCnames.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/printerlistwithUNCnames.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
            if ($CHILD_ERROR != 0) { $pipeline_success_14 = 0; }
            $output_14 = do {
                            my $_wc_data = $output_14;
                            my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
                            my $_wc_result = q{};
                            $_wc_result .= sprintf q{%d}, $_wc_lines;
                            $_wc_result .= "\n";
                            $_wc_result;
                        };
            if ( !$pipeline_success_14 ) { $main_exit_code = 1; }
            $output_14 =~ s/\n+\z//msx;
            $output_14;
}; $_pipeline_result; };
        print " \n";
        print "--> Finished in running function createprinterlistwithUNCnames....\n";
        print "==========================================================================\n";
        do {
    my $__echo_line = "NUMBEROFPRINTERS retrieved from \"" . ($ENV{nthost} // q{}) . "\" is $NUMBEROFPRINTERS" . q{ } . q{.};
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print "  -->  If you got \"0\" you may want to try again. <---\n";
        print "==========================================================================\n";
        print " \n";
        my $printerlistwithUNCnames;
        my @printerlistwithUNCnames;
        my %printerlistwithUNCnames;
        $printerlistwithUNCnames = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $nthost ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nthost . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/printerlistwithUNCnames.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/printerlistwithUNCnames.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
    }
    return;
}

sub helpwithcreatemapofprinterstodrivers {
    do {
    my $__echo_line = " \n\\\n################################################################################\n#\n#                About createmapofprinterdrivers()...\n#                ------------------------------------\n#\n# PRECONDITIONS: 1) This function expects to find a subdirectory '$nthost' and\n#\t\t    the file '${nthost}/printerlistwithUNCnames.txt' to exist.\n#\t\t 2) This functions expects to have the '$nthosts' variable set\n#\t\t    to an according value.\n#\n# WHAT IT DOES: This function dissects '${nthost}/printerlistwithUNCnames.txt'\n#\t\tand creates some other textfiles from its contents:\n#\t\t- '${nthost}/allprinternames.txt'\n#\t\t- '${nthost}/alldrivernames.txt'\n#\t\t- '${nthost}/allnonrawprinters.txt'\n#\t\t- '${nthost}/allrawprinters.txt'\n#\t\t- '${nthost}/printertodrivermap.txt'\n#\t\tand further prints some more info to stdout.\n#\n# HINT: You currently have defined: 'nthost'=\"$nthost\", which resolves above\n#\tmentioned paths to:\n#\t\t\t    - '($ENV{nthost} // q{})/allprinternames.txt'\n#\t\t\t    - '($ENV{nthost} // q{})/alldrivernames.txt'\n#\t\t\t    - '($ENV{nthost} // q{})/allnonrawprinters.txt'\n#\t\t\t    - '($ENV{nthost} // q{})/allrawprinters.txt'\n#\t\t\t    - '($ENV{nthost} // q{})/printertodrivermap.txt'\n#\n################################################################################";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}

sub createmapofprinterstodrivers {
    my ($file) = @_;
if (!(    stringinstring('help', "@ARGV"))) {
        helpwithcreatemapofprinterstodrivers();
}
    else {
        print " \n";
        print " \n";
        print "--> Running now function createmapofprinterstodrivers()....\n";
        print "===========================================================\n";
        print " \n";
        print " \n";
        print "ALL PRINTERNAMES:\n";
        print "=================\n";
        print " \n";
        # Original bash: cat ${nthost}/printerlistwithUNCnames.txt \
{
            my $output_15 = q{};
            my $output_printed_15;
            my $pipeline_success_15 = 1;
                        $output_15 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $nthost ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nthost . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/printerlistwithUNCnames.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/printerlistwithUNCnames.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });

                        my @lines = split /\n/msx, $output_15;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\/msx, $line;
            push @result, ($fields[3] . "\n");
            }
            $output_15 = join "", @result;

                        my @lines = split /\n/msx, $output_15;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /,/msx, $line;
            push @result, ($fields[0] . "\n");
            }
            $output_15 = join "", @result;

                        my @sort_lines_15_3 = split /\n/msx, $output_15;
            my @sort_sorted_15_3 = sort @sort_lines_15_3;
            my $output_15_3 = join "\n", @sort_sorted_15_3;
            if ($output_15_3 ne q{} && !($output_15_3 =~ m{\n\z}msx)) {
            $output_15_3 .= "\n";
            }
            $output_15 = $output_15_3;
            $output_15 = $output_15_3;

                        my @uniq_lines_15_4 = split /\n/msx, $output_15;
            @uniq_lines_15_4 = grep { $_ ne q{} } @uniq_lines_15_4; # Filter out empty lines
            my %uniq_seen_15_4;
            my @uniq_result_15_4;
            foreach my $line (@uniq_lines_15_4) {
            if (!$uniq_seen_15_4{$line}++) { push @uniq_result_15_4, $line; }
            }
            my $output_15_4 = join "\n", @uniq_result_15_4;
            if ($output_15_4 ne q{} && !($output_15_4 =~ m{\n\z}msx)) {
            $output_15_4 .= "\n";
            }
            $output_15 = $output_15_4;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_15;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/allprinternames.txt' ) {
            print {$fh} $output_15;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/allprinternames.txt': $ERRNO";
            }
            $output_15 = $output_15;
            if ($output_15 ne q{} && !defined $output_printed_15) {
                print $output_15;
                if (!($output_15 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
            }
        print " \n";
        print " \n";
        print "ALL non-RAW PRINTERS:\n";
        print "=====================\n";
        print " \n";
        # Original bash: cat ${nthost}/printerlistwithUNCnames.txt \
{
            my $output_16 = q{};
            my $output_printed_16;
            my $pipeline_success_16 = 1;
                        $output_16 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $nthost ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nthost . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/printerlistwithUNCnames.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/printerlistwithUNCnames.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });

                        my $grep_result_16_1;
            my @grep_lines_16_1 = split /\n/msx, $output_16;
            my @grep_filtered_16_1 = grep { !/,,/msx } @grep_lines_16_1;
            $grep_result_16_1 = join "\n", @grep_filtered_16_1;
            if (!($grep_result_16_1 =~ m{\n\z}msx || $grep_result_16_1 eq q{})) {
            $grep_result_16_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_16_1 > 0 ? 0 : 1;
            $output_16 = $grep_result_16_1;
            $output_16 = $grep_result_16_1;

                        my @lines = split /\n/msx, $output_16;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\/msx, $line;
            push @result, ($fields[3] . "\n");
            }
            $output_16 = join "", @result;

                        my @lines = split /\n/msx, $output_16;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /,/msx, $line;
            push @result, ($fields[0] . "\n");
            }
            $output_16 = join "", @result;

                        my @sort_lines_16_4 = split /\n/msx, $output_16;
            my @sort_sorted_16_4 = sort @sort_lines_16_4;
            my $output_16_4 = join "\n", @sort_sorted_16_4;
            if ($output_16_4 ne q{} && !($output_16_4 =~ m{\n\z}msx)) {
            $output_16_4 .= "\n";
            }
            $output_16 = $output_16_4;
            $output_16 = $output_16_4;

                        my @uniq_lines_16_5 = split /\n/msx, $output_16;
            @uniq_lines_16_5 = grep { $_ ne q{} } @uniq_lines_16_5; # Filter out empty lines
            my %uniq_seen_16_5;
            my @uniq_result_16_5;
            foreach my $line (@uniq_lines_16_5) {
            if (!$uniq_seen_16_5{$line}++) { push @uniq_result_16_5, $line; }
            }
            my $output_16_5 = join "\n", @uniq_result_16_5;
            if ($output_16_5 ne q{} && !($output_16_5 =~ m{\n\z}msx)) {
            $output_16_5 .= "\n";
            }
            $output_16 = $output_16_5;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_16;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/allnonrawprinters.txt' ) {
            print {$fh} $output_16;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/allnonrawprinters.txt': $ERRNO";
            }
            $output_16 = $output_16;
            if ($output_16 ne q{} && !defined $output_printed_16) {
                print $output_16;
                if (!($output_16 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_16 ) { $main_exit_code = 1; }
            }
        print " \n";
        print " \n";
        print "ALL RAW PRINTERS:\n";
        print "================\n";
        print " \n";
        # Original bash: cat ${nthost}/printerlistwithUNCnames.txt \
{
            my $output_17 = q{};
            my $output_printed_17;
            my $pipeline_success_17 = 1;
                        $output_17 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $nthost ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nthost . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/printerlistwithUNCnames.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/printerlistwithUNCnames.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });

                        my $grep_result_17_1;
            my @grep_lines_17_1 = split /\n/msx, $output_17;
            my @grep_filtered_17_1 = grep { /,,/msx } @grep_lines_17_1;
            $grep_result_17_1 = join "\n", @grep_filtered_17_1;
            if (!($grep_result_17_1 =~ m{\n\z}msx || $grep_result_17_1 eq q{})) {
            $grep_result_17_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_17_1 > 0 ? 0 : 1;
            $output_17 = $grep_result_17_1;
            $output_17 = $grep_result_17_1;

                        my @lines = split /\n/msx, $output_17;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\/msx, $line;
            push @result, ($fields[3] . "\n");
            }
            $output_17 = join "", @result;

                        my @lines = split /\n/msx, $output_17;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /,/msx, $line;
            push @result, ($fields[0] . "\n");
            }
            $output_17 = join "", @result;

                        my @sort_lines_17_4 = split /\n/msx, $output_17;
            my @sort_sorted_17_4 = sort @sort_lines_17_4;
            my $output_17_4 = join "\n", @sort_sorted_17_4;
            if ($output_17_4 ne q{} && !($output_17_4 =~ m{\n\z}msx)) {
            $output_17_4 .= "\n";
            }
            $output_17 = $output_17_4;
            $output_17 = $output_17_4;

                        my @uniq_lines_17_5 = split /\n/msx, $output_17;
            @uniq_lines_17_5 = grep { $_ ne q{} } @uniq_lines_17_5; # Filter out empty lines
            my %uniq_seen_17_5;
            my @uniq_result_17_5;
            foreach my $line (@uniq_lines_17_5) {
            if (!$uniq_seen_17_5{$line}++) { push @uniq_result_17_5, $line; }
            }
            my $output_17_5 = join "\n", @uniq_result_17_5;
            if ($output_17_5 ne q{} && !($output_17_5 =~ m{\n\z}msx)) {
            $output_17_5 .= "\n";
            }
            $output_17 = $output_17_5;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_17;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/allrawprinters.txt' ) {
            print {$fh} $output_17;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/allrawprinters.txt': $ERRNO";
            }
            $output_17 = $output_17;
            if ($output_17 ne q{} && !defined $output_printed_17) {
                print $output_17;
                if (!($output_17 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_17 ) { $main_exit_code = 1; }
            }
        print " \n";
        print " \n";
        print "THE DRIVERNAMES:\n";
        print "================\n";
        # Original bash: cat ${nthost}/printerlistwithUNCnames.txt \
{
            my $output_18 = q{};
            my $output_printed_18;
            my $pipeline_success_18 = 1;
                        $output_18 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $nthost ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nthost . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/printerlistwithUNCnames.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/printerlistwithUNCnames.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });

                        my @lines = split /\n/msx, $output_18;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /,/msx, $line;
            push @result, ($fields[1] . "\n");
            }
            $output_18 = join "", @result;

                        my $grep_result_18_2;
            my @grep_lines_18_2 = split /\n/msx, $output_18;
            my @grep_filtered_18_2 = grep { !/^$/msx } @grep_lines_18_2;
            $grep_result_18_2 = join "\n", @grep_filtered_18_2;
            if (!($grep_result_18_2 =~ m{\n\z}msx || $grep_result_18_2 eq q{})) {
            $grep_result_18_2 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_18_2 > 0 ? 0 : 1;
            $output_18 = $grep_result_18_2;
            $output_18 = $grep_result_18_2;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_18;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/alldrivernames.txt' ) {
            print {$fh} $output_18;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/alldrivernames.txt': $ERRNO";
            }
            $output_18 = $output_18;
            if ($output_18 ne q{} && !defined $output_printed_18) {
                print $output_18;
                if (!($output_18 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_18 ) { $main_exit_code = 1; }
            }
        print " \n";
        print " \n";
        print "THE PRINTER-TO-DRIVER-MAP-FOR-non-RAW-PRINTERS:\n";
        print "===============================================\n";
        # Original bash: cat ${nthost}/printerlistwithUNCnames.txt \
{
            my $output_19 = q{};
            my $output_printed_19;
            my $pipeline_success_19 = 1;
                        $output_19 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $nthost ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nthost . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/printerlistwithUNCnames.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/printerlistwithUNCnames.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });

                        my @lines = split /\n/msx, $output_19;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\/msx, $line;
            push @result, ($fields[3] . "\n");
            }
            $output_19 = join "", @result;

                        my @lines = split /\n/msx, $output_19;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /,/msx, $line;
            push @result, ("\"\" $1 \"\":\"\" $2 \"\"" . "\n");
            }
            $output_19 = join "", @result;

                        my $grep_result_19_3;
            my @grep_lines_19_3 = split /\n/msx, $output_19;
            my @grep_filtered_19_3 = grep { !/:\"\"$/msx } @grep_lines_19_3;
            $grep_result_19_3 = join "\n", @grep_filtered_19_3;
            if (!($grep_result_19_3 =~ m{\n\z}msx || $grep_result_19_3 eq q{})) {
            $grep_result_19_3 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_19_3 > 0 ? 0 : 1;
            $output_19 = $grep_result_19_3;
            $output_19 = $grep_result_19_3;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_19;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/printertodrivermap.txt' ) {
            print {$fh} $output_19;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/printertodrivermap.txt': $ERRNO";
            }
            $output_19 = $output_19;
            if ($output_19 ne q{} && !defined $output_printed_19) {
                print $output_19;
                if (!($output_19 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_19 ) { $main_exit_code = 1; }
            }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $nthost
      or die "Cannot open file: $OS_ERROR\n";
            print "##########################\n#  printer:driver  #" . "\n";
            $CHILD_ERROR = 0;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $main_exit_code = system('bash', '/printertodrivermap.txt') >> 8;
    }
    return;
}

sub helpwithgetdrivernamelist {
    do {
    my $__echo_line = " \n\\\n################################################################################\n#\n#                About getdrivernamelist()...\n#                ----------------------------\n#\n# PRECONDITIONS: 1) This function expects to find the subdirectory '$nthost\\'\n#\t\t    otherwise it creates it...\n#\n# WHAT IT DOES: This function creates the '${nthost}/printernamelist.txt'\n#\t\tand also prints it to <stdout>. To do so, it must contact the\n#\t\t'$nthost' via rpcclient (which in turn needs '$ntprinteradmin'\n#\t\t'$ntadminpasswd' to log in....).\n#\n# HINT: The current values: 'nthost'=\"$nthost\n#\t\t\t    'ntprinteradmin'=$ntprinteradmin\"\n#\t\t\t    'ntadminpasswd'=<not shown here, check yourself!>\n#       which resolves above mentioned path to:\n#\t\t\t\t    - '($ENV{nthost} // q{})/printernamelist.txt'\n#\n################################################################################";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}

sub getdrivernamelist {
    my ($file) = @_;
if (!(    stringinstring('help', "@ARGV"))) {
        helpwithgetdrivernamelist();
}
    else {
        if (!((-d ${nthost}))) {
                        use File::Path qw(make_path);
            my $err;
            if ( !-d $nthost ) {
                make_path( $nthost, { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . $nthost . ": $err->[0]\n";
                }
            }
        }
        print " \n";
        print " \n";
        print "--> Running now function getdrivernamelist()....\n";
        print "================================================\n";
        # Original bash: rpcclient -U${ntprinteradmin}%${ntadminpasswd} -c 'enumprinters' ${nthost} \
{
            my $output_21 = q{};
            my $output_printed_21;
            my $pipeline_success_21 = 1;
                        my ($in_22, $out_22);
            my $pid_22 = open3($in_22, $out_22, '>&STDERR', 'rpcclient', '-U', q{%}, '-c', 'enumprinters');
            close $in_22 or croak 'Close failed: $OS_ERROR';
            $output_21 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_22> };
            close $out_22 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_22, 0;

                        my $grep_result_21_1;
            my @grep_lines_21_1 = split /\n/msx, $output_21;
            my @grep_filtered_21_1 = grep { /description:/msx } @grep_lines_21_1;
            $grep_result_21_1 = join "\n", @grep_filtered_21_1;
            if (!($grep_result_21_1 =~ m{\n\z}msx || $grep_result_21_1 eq q{})) {
            $grep_result_21_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_21_1 > 0 ? 0 : 1;
            $output_21 = $grep_result_21_1;
            $output_21 = $grep_result_21_1;

                        my $grep_result_21_2;
            my @grep_lines_21_2 = split /\n/msx, $output_21;
            my @grep_filtered_21_2 = grep { !/,,/msx } @grep_lines_21_2;
            $grep_result_21_2 = join "\n", @grep_filtered_21_2;
            if (!($grep_result_21_2 =~ m{\n\z}msx || $grep_result_21_2 eq q{})) {
            $grep_result_21_2 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_21_2 > 0 ? 0 : 1;
            $output_21 = $grep_result_21_2;
            $output_21 = $grep_result_21_2;

                        my @lines = split /\n/msx, $output_21;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /,/msx, $line;
            push @result, ($fields[1] . "\n");
            }
            $output_21 = join "", @result;

                        my @sort_lines_21_4 = split /\n/msx, $output_21;
            my @sort_sorted_21_4 = sort @sort_lines_21_4;
            my $output_21_4 = join "\n", @sort_sorted_21_4;
            if ($output_21_4 ne q{} && !($output_21_4 =~ m{\n\z}msx)) {
            $output_21_4 .= "\n";
            }
            $output_21 = $output_21_4;
            $output_21 = $output_21_4;

                        my @uniq_lines_21_5 = split /\n/msx, $output_21;
            @uniq_lines_21_5 = grep { $_ ne q{} } @uniq_lines_21_5; # Filter out empty lines
            my %uniq_seen_21_5;
            my @uniq_result_21_5;
            foreach my $line (@uniq_lines_21_5) {
            if (!$uniq_seen_21_5{$line}++) { push @uniq_result_21_5, $line; }
            }
            my $output_21_5 = join "\n", @uniq_result_21_5;
            if ($output_21_5 ne q{} && !($output_21_5 =~ m{\n\z}msx)) {
            $output_21_5 .= "\n";
            }
            $output_21 = $output_21_5;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_21;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/drivernamelist.txt' ) {
            print {$fh} $output_21;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/drivernamelist.txt': $ERRNO";
            }
            $output_21 = $output_21;
            if ($output_21 ne q{} && !defined $output_printed_21) {
                print $output_21;
                if (!($output_21 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_21 ) { $main_exit_code = 1; }
            }
    }
    return;
}

sub helpwithsplitenumdrivers3list {
    do {
    my $__echo_line = " \n\\\n################################################################################\n#\n#                About splitenumdrivers3list()...\n#                --------------------------------\n#\n# PRECONDITIONS: 1) This function expects write access to the current directory\n#\t\t    and its subdirs '$nthost/*'.\n#\t\t 2) This function expects to have the '$nthost' variable set to\n#\t\t    the according value.\n#\n# WHAT IT DOES: This function dissects the '$nthost/enumdrivers3list.txt'\n#\t\t(using " . q{ } . "sed" . q{ } . ", " . q{ } . "cat" . q{ } . ", " . q{ } . "awk" . q{ } . " and " . q{ } . "grep" . q{ } . "). It splits the list up\n#\t\tinto two different files representing a complete list of drivers\n#\t\tand files for each of the 2 supported architectures. It creates\n#\t\t'${nthost}/W32X86/($ENV{nthost} // q{})-enumdrivers3list-NTx86.txt'\n#\t\tand '${nthost}/WIN40/($ENV{nthost} // q{})-enumdrivers3list-WIN40.txt'.\n#\n# IF IT DOESN'T WORK: The function " . q{ } . "fetchenumdrivers3listfromNThost" . q{ } . " may not\n#\t\t      have been run successfully. This is a precondition for\n#\t\t      the current function.\n#\n# HINT: You currently have defined: 'nthost'=\"$nthost\", which resolves above\n# mentioned paths to:\n#\t\t      - '($ENV{nthost} // q{})/WIN40/($ENV{nthost} // q{})-enumdrivers3list-NTx86.txt'\n#\t\t      - '($ENV{nthost} // q{})/W32X86/($ENV{nthost} // q{})-enumdrivers3list-NTx86.txt'\n#\n################################################################################";
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

sub splitenumdrivers3list {
    my ($file) = @_;
if (!(    stringinstring('help', "@ARGV"))) {
        helpwithsplitenumdrivers3list();
}
    else {
        print " \n";
        print " \n";
        print "--> Running now function splitenumdrivers3list()....\n";
        print "====================================================\n";
        if (!((-d ${nthost}/WIN40))) {
                        use File::Path qw(make_path);
            my $err;
            if ( !-d $nthost ) {
                make_path( $nthost, { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . $nthost . ": $err->[0]\n";
                }
            }
            if ( !-d '/WIN40' ) {
                make_path( '/WIN40', { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . '/WIN40' . ": $err->[0]\n";
                }
            }
        }
        if (!((-d ${nthost}/W32X86))) {
                        use File::Path qw(make_path);
            if ( !-d $nthost ) {
                make_path( $nthost, { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . $nthost . ": $err->[0]\n";
                }
            }
            if ( !-d '/W32X86' ) {
                make_path( '/W32X86', { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . '/W32X86' . ": $err->[0]\n";
                }
            }
        }
        # Original bash: cat ${nthost}/enumdrivers3list.txt \
{
            my $output_25 = q{};
            my $output_printed_25;
            my $pipeline_success_25 = 1;
                        $output_25 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $nthost ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nthost . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/enumdrivers3list.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/enumdrivers3list.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });

                        my @sed_lines_25 = split /\n/msx, $output_25;
            my @sed_result_25;
            foreach my $line (@sed_lines_25) {
            chomp $line;
            push @sed_result_25, $line;
            }
            $output_25 = join "\n", @sed_result_25;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_25;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/WIN40/' ) {
            print {$fh} $output_25;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/WIN40/': $ERRNO";
            }
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_25;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', 'numdrivers3list-WIN40.txt' ) {
            print {$fh} $output_25;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open 'numdrivers3list-WIN40.txt': $ERRNO";
            }
            $output_25 = $output_25;
            if ($output_25 ne q{} && !defined $output_printed_25) {
                print $output_25;
                if (!($output_25 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_25 ) { $main_exit_code = 1; }
            }
        # Original bash: cat ${nthost}/WIN40/${nthost}-enumdrivers3list-WIN40.txt \
{
            my $output_26 = q{};
            my $output_printed_26;
            my $pipeline_success_26 = 1;
                        $output_26 = do { my $cat_out = q{}; my $cat_pid = open3(my $cat_in, my $cat_out_r, undef, 'cat', '$nthost', '/WIN40/', '$nthost', '-e', 'numdrivers3list-WIN40.txt'); close $cat_in or croak 'Close failed: $OS_ERROR'; local $INPUT_RECORD_SEPARATOR = undef; $cat_out = <$cat_out_r>; close $cat_out_r or croak 'Close failed: $OS_ERROR'; waitpid $cat_pid, 0; $cat_out; };

                        my $grep_result_26_1;
            my @grep_lines_26_1 = split /\n/msx, $output_26;
            my @grep_filtered_26_1 = grep { /Version/msx } @grep_lines_26_1;
            $grep_result_26_1 = join "\n", @grep_filtered_26_1;
            if (!($grep_result_26_1 =~ m{\n\z}msx || $grep_result_26_1 eq q{})) {
            $grep_result_26_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_26_1 > 0 ? 0 : 1;
            $output_26 = $grep_result_26_1;
            $output_26 = $grep_result_26_1;

                        my @sort_lines_26_2 = split /\n/msx, $output_26;
            my @sort_sorted_26_2 = sort @sort_lines_26_2;
            my $output_26_2 = join "\n", @sort_sorted_26_2;
            if ($output_26_2 ne q{} && !($output_26_2 =~ m{\n\z}msx)) {
            $output_26_2 .= "\n";
            }
            $output_26 = $output_26_2;
            $output_26 = $output_26_2;

                        my @uniq_lines_26_3 = split /\n/msx, $output_26;
            @uniq_lines_26_3 = grep { $_ ne q{} } @uniq_lines_26_3; # Filter out empty lines
            my %uniq_seen_26_3;
            my @uniq_result_26_3;
            foreach my $line (@uniq_lines_26_3) {
            if (!$uniq_seen_26_3{$line}++) { push @uniq_result_26_3, $line; }
            }
            my $output_26_3 = join "\n", @uniq_result_26_3;
            if ($output_26_3 ne q{} && !($output_26_3 =~ m{\n\z}msx)) {
            $output_26_3 .= "\n";
            }
            $output_26 = $output_26_3;

                        my @lines = split /\n/msx, $output_26;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /[/msx, $line;
            push @result, ($fields[1] . "\n");
            }
            $output_26 = join "", @result;

                        my @lines = split /\n/msx, $output_26;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /]/msx, $line;
            push @result, ($fields[0] . "\n");
            }
            $output_26 = join "", @result;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_26;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/WIN40/availableversionsWIN40.txt' ) {
            print {$fh} $output_26;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/WIN40/availableversionsWIN40.txt': $ERRNO";
            }
            $output_26 = $output_26;
            if ($output_26 ne q{} && !defined $output_printed_26) {
                print $output_26;
                if (!($output_26 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_26 ) { $main_exit_code = 1; }
            }
        # Original bash: cat ${nthost}/enumdrivers3list.txt \
{
            my $output_27 = q{};
            my $output_printed_27;
            my $pipeline_success_27 = 1;
                        $output_27 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $nthost ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nthost . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/enumdrivers3list.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/enumdrivers3list.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });

                        my @sed_lines_27 = split /\n/msx, $output_27;
            my @sed_result_27;
            foreach my $line (@sed_lines_27) {
            chomp $line;
            push @sed_result_27, $line;
            }
            $output_27 = join "\n", @sed_result_27;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_27;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/W32X86/' ) {
            print {$fh} $output_27;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/W32X86/': $ERRNO";
            }
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_27;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', 'numdrivers3list-NTx86.txt' ) {
            print {$fh} $output_27;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open 'numdrivers3list-NTx86.txt': $ERRNO";
            }
            $output_27 = $output_27;
            if ($output_27 ne q{} && !defined $output_printed_27) {
                print $output_27;
                if (!($output_27 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_27 ) { $main_exit_code = 1; }
            }
        # Original bash: cat ${nthost}/W32X86/${nthost}-enumdrivers3list-NTx86.txt \
{
            my $output_28 = q{};
            my $output_printed_28;
            my $pipeline_success_28 = 1;
                        $output_28 = do { my $cat_out = q{}; my $cat_pid = open3(my $cat_in, my $cat_out_r, undef, 'cat', '$nthost', '/W32X86/', '$nthost', '-e', 'numdrivers3list-NTx86.txt'); close $cat_in or croak 'Close failed: $OS_ERROR'; local $INPUT_RECORD_SEPARATOR = undef; $cat_out = <$cat_out_r>; close $cat_out_r or croak 'Close failed: $OS_ERROR'; waitpid $cat_pid, 0; $cat_out; };

                        my $grep_result_28_1;
            my @grep_lines_28_1 = split /\n/msx, $output_28;
            my @grep_filtered_28_1 = grep { /Version/msx } @grep_lines_28_1;
            $grep_result_28_1 = join "\n", @grep_filtered_28_1;
            if (!($grep_result_28_1 =~ m{\n\z}msx || $grep_result_28_1 eq q{})) {
            $grep_result_28_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_28_1 > 0 ? 0 : 1;
            $output_28 = $grep_result_28_1;
            $output_28 = $grep_result_28_1;

                        my @sort_lines_28_2 = split /\n/msx, $output_28;
            my @sort_sorted_28_2 = sort @sort_lines_28_2;
            my $output_28_2 = join "\n", @sort_sorted_28_2;
            if ($output_28_2 ne q{} && !($output_28_2 =~ m{\n\z}msx)) {
            $output_28_2 .= "\n";
            }
            $output_28 = $output_28_2;
            $output_28 = $output_28_2;

                        my @uniq_lines_28_3 = split /\n/msx, $output_28;
            @uniq_lines_28_3 = grep { $_ ne q{} } @uniq_lines_28_3; # Filter out empty lines
            my %uniq_seen_28_3;
            my @uniq_result_28_3;
            foreach my $line (@uniq_lines_28_3) {
            if (!$uniq_seen_28_3{$line}++) { push @uniq_result_28_3, $line; }
            }
            my $output_28_3 = join "\n", @uniq_result_28_3;
            if ($output_28_3 ne q{} && !($output_28_3 =~ m{\n\z}msx)) {
            $output_28_3 .= "\n";
            }
            $output_28 = $output_28_3;

                        my @lines = split /\n/msx, $output_28;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /[/msx, $line;
            push @result, ($fields[1] . "\n");
            }
            $output_28 = join "", @result;

                        my @lines = split /\n/msx, $output_28;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /]/msx, $line;
            push @result, ($fields[0] . "\n");
            }
            $output_28 = join "", @result;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_28;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/W32X86/availableversionsW32X86.txt' ) {
            print {$fh} $output_28;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/W32X86/availableversionsW32X86.txt': $ERRNO";
            }
            $output_28 = $output_28;
            if ($output_28 ne q{} && !defined $output_printed_28) {
                print $output_28;
                if (!($output_28 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_28 ) { $main_exit_code = 1; }
            }
    }
    return;
}

sub helpwithmakesubdirsforWIN40driverlist {
    # Original bash: echo -e " \n\
{
        my $output_29 = q{};
        my $output_printed_29;
        my $pipeline_success_29 = 1;
        $output_29 .= " \n\\\n################################################################################\n#\n# About makesubdirsforWIN40driverlist() and makesubdirsforWIN40driverlist ()...\n# -----------------------------------------------------------------------------\n#\n# PRECONDITIONS: 1) These functions expect write access to the current directory\n#\t\t 2) These functions expect to have the '$nthost' variable set\n#\t\t    to the according value.\n#\t\t 3) These functions expect to find the two files\n#\t\t    '${nthost}/WIN40/${nthost}-enumdrivers3list-WIN40.txt' and\n#\t\t    '${nthost}/W32X86/${nthost}-enumdrivers3list-NTx86.txt' to\n#\t\t    work on.\n#\n# WHAT IT DOES: These functions dissect the '$nthost/enumdrivers3list.txt'\n#\t\t(using " . q{ } . "sed" . q{ } . ", " . q{ } . "cat" . q{ } . ", " . q{ } . "awk" . q{ } . " and " . q{ } . "grep" . q{ } . "). They split the input\n#\t\tfiles up into individual files representing driver(version)s and\n#\t\tcreate appropriate subdirectories for each driver and version\n#\t\tunderneath './$nthost/<architecture>'. They use the drivernames\n#\t\t(including spaces) for the directory names. (" . q{ } . "/" . q{ } . " -- slashes --\n#\t\tin drivernames are converted to underscores).\n#\n# IF IT DOESN'T WORK: The function " . q{ } . "fetchenumdrivers3listfromNThost" . q{ } . " and\n#\t\t      consecutive ones may not have been run successfully. This\n#\t\t      is a precondition for the current function.\n#\n# HINT: You currently have defined: 'nthost'=\"$nthost\", which resolves above\n#\tmentioned paths to:\n#\t\t     - '${nthost}/WIN40/${nthost}-enumdrivers3list-NTx86.txt'\n#\t\t     - '${nthost}/W32X86/${nthost}-enumdrivers3list-NTx86.txt'\n#\n################################################################################\n#           ............PRESS \"q\" TO QUIT............" . "\n";
if ( !($output_29 =~ m{\n\z}msx) ) { $output_29 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_31 = 'less';
        my ($in_30, $out_30);
        my $pid_30 = open3($in_30, $out_30, '>&STDERR', $cmd_31, );
        print {$in_30} $output_29;
        close $in_30 or croak 'Close failed: $OS_ERROR';
        $output_29 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
        close $out_30 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_30, 0;
        if ($output_29 ne q{} && !defined $output_printed_29) {
            print $output_29;
            if (!($output_29 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_29 ) { $main_exit_code = 1; }
        }
    return;
}

sub makesubdirsforWIN40driverlist {
    my ($file) = @_;
if (!(    stringinstring('help', "@ARGV"))) {
        helpwithmakesubdirsforWIN40driverlist();
}
    else {
        # Original bash: cat ${nthost}/WIN40/${nthost}-enumdrivers3list-WIN40.txt \
{
            my $output_32 = q{};
            my $output_printed_32;
            my $pipeline_success_32 = 1;
                        $output_32 = do { my $cat_out = q{}; my $cat_pid = open3(my $cat_in, my $cat_out_r, undef, 'cat', '$nthost', '/WIN40/', '$nthost', '-e', 'numdrivers3list-WIN40.txt'); close $cat_in or croak 'Close failed: $OS_ERROR'; local $INPUT_RECORD_SEPARATOR = undef; $cat_out = <$cat_out_r>; close $cat_out_r or croak 'Close failed: $OS_ERROR'; waitpid $cat_pid, 0; $cat_out; };

                        my $grep_result_32_1;
            my @grep_lines_32_1 = split /\n/msx, $output_32;
            my @grep_filtered_32_1 = grep { /Driver\ Name:/msx } @grep_lines_32_1;
            $grep_result_32_1 = join "\n", @grep_filtered_32_1;
            if (!($grep_result_32_1 =~ m{\n\z}msx || $grep_result_32_1 eq q{})) {
            $grep_result_32_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_32_1 > 0 ? 0 : 1;
            $output_32 = $grep_result_32_1;
            $output_32 = $grep_result_32_1;

                        my @lines = split /\n/msx, $output_32;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /[/msx, $line;
            push @result, ($fields[1] . "\n");
            }
            $output_32 = join "", @result;

                        my @lines = split /\n/msx, $output_32;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /]/msx, $line;
            push @result, ($fields[0] . "\n");
            }
            $output_32 = join "", @result;

                        my @sort_lines_32_4 = split /\n/msx, $output_32;
            my @sort_sorted_32_4 = sort @sort_lines_32_4;
            my $output_32_4 = join "\n", @sort_sorted_32_4;
            if ($output_32_4 ne q{} && !($output_32_4 =~ m{\n\z}msx)) {
            $output_32_4 .= "\n";
            }
            $output_32 = $output_32_4;
            $output_32 = $output_32_4;

                        my @uniq_lines_32_5 = split /\n/msx, $output_32;
            @uniq_lines_32_5 = grep { $_ ne q{} } @uniq_lines_32_5; # Filter out empty lines
            my %uniq_seen_32_5;
            my @uniq_result_32_5;
            foreach my $line (@uniq_lines_32_5) {
            if (!$uniq_seen_32_5{$line}++) { push @uniq_result_32_5, $line; }
            }
            my $output_32_5 = join "\n", @uniq_result_32_5;
            if ($output_32_5 ne q{} && !($output_32_5 =~ m{\n\z}msx)) {
            $output_32_5 .= "\n";
            }
            $output_32 = $output_32_5;

                        my $set1_33 = q{/};
            my $set2_33 = q{_};
            my $input_33 = $output_32;
            # Expand character ranges for tr command
            my $expanded_set1_33 = $set1_33;
            my $expanded_set2_33 = $set2_33;
            # Handle a-z range in set1
            if ($expanded_set1_33 =~ /a-z/msx) {
            $expanded_set1_33 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle A-Z range in set1
            if ($expanded_set1_33 =~ /A-Z/msx) {
            $expanded_set1_33 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:upper:] POSIX class in set1
            if ($expanded_set1_33 =~ /\[:upper:\]/msx) {
            $expanded_set1_33 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:lower:] POSIX class in set1
            if ($expanded_set1_33 =~ /\[:lower:\]/msx) {
            $expanded_set1_33 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle a-z range in set2
            if ($expanded_set2_33 =~ /a-z/msx) {
            $expanded_set2_33 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle A-Z range in set2
            if ($expanded_set2_33 =~ /A-Z/msx) {
            $expanded_set2_33 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:upper:] POSIX class in set2
            if ($expanded_set2_33 =~ /\[:upper:\]/msx) {
            $expanded_set2_33 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:lower:] POSIX class in set2
            if ($expanded_set2_33 =~ /\[:lower:\]/msx) {
            $expanded_set2_33 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
            }
            my $tr_result_32_6 = q{};
            for my $char ( split //msx, $input_33 ) {
            my $pos_33 = index $expanded_set1_33, $char;
            if ( $pos_33 >= 0 && $pos_33 < length $expanded_set2_33 ) {
            $tr_result_32_6 .= substr $expanded_set2_33, $pos_33, 1;
            } else {
            $tr_result_32_6 .= $char;
            }
            }
            if (!($tr_result_32_6 =~ m{\n\z}msx || $tr_result_32_6 eq q{})) {
            $tr_result_32_6 .= "\n";
            }
            $output_32 = $tr_result_32_6;
            $output_32 = $tr_result_32_6;

                        my @sed_lines_32 = split /\n/msx, $output_32;
            my @sed_result_32;
            foreach my $line (@sed_lines_32) {
            chomp $line;
            push @sed_result_32, $line;
            }
            $output_32 = join "\n", @sed_result_32;

                        my @sed_lines_32 = split /\n/msx, $output_32;
            my @sed_result_32;
            foreach my $line (@sed_lines_32) {
            chomp $line;
            push @sed_result_32, $line;
            }
            $output_32 = join "\n", @sed_result_32;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_32;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/makesubdirsforWIN40driverlist.txt' ) {
            print {$fh} $output_32;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/makesubdirsforWIN40driverlist.txt': $ERRNO";
            }
            $output_32 = $output_32;
            if ($output_32 ne q{} && !defined $output_printed_32) {
                print $output_32;
                if (!($output_32 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_32 ) { $main_exit_code = 1; }
            }
        $main_exit_code = system('sh', '-x', $nthost, '/makesubdirsforWIN40driverlist.txt') >> 8;
    }
    return;
}

sub makesubdirsforW32X86driverlist {
    my ($file) = @_;
if (!(    stringinstring('help', "@ARGV"))) {
        helpwithvampiredrivers();
}
    else {
        # Original bash: cat ${nthost}/W32X86/${nthost}-enumdrivers3list-NTx86.txt \
{
            my $output_34 = q{};
            my $output_printed_34;
            my $pipeline_success_34 = 1;
                        $output_34 = do { my $cat_out = q{}; my $cat_pid = open3(my $cat_in, my $cat_out_r, undef, 'cat', '$nthost', '/W32X86/', '$nthost', '-e', 'numdrivers3list-NTx86.txt'); close $cat_in or croak 'Close failed: $OS_ERROR'; local $INPUT_RECORD_SEPARATOR = undef; $cat_out = <$cat_out_r>; close $cat_out_r or croak 'Close failed: $OS_ERROR'; waitpid $cat_pid, 0; $cat_out; };

                        my $grep_result_34_1;
            my @grep_lines_34_1 = split /\n/msx, $output_34;
            my @grep_filtered_34_1 = grep { /Driver\ Name:/msx } @grep_lines_34_1;
            $grep_result_34_1 = join "\n", @grep_filtered_34_1;
            if (!($grep_result_34_1 =~ m{\n\z}msx || $grep_result_34_1 eq q{})) {
            $grep_result_34_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_34_1 > 0 ? 0 : 1;
            $output_34 = $grep_result_34_1;
            $output_34 = $grep_result_34_1;

                        my @lines = split /\n/msx, $output_34;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /[/msx, $line;
            push @result, ($fields[1] . "\n");
            }
            $output_34 = join "", @result;

                        my @lines = split /\n/msx, $output_34;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /]/msx, $line;
            push @result, ($fields[0] . "\n");
            }
            $output_34 = join "", @result;

                        my @sort_lines_34_4 = split /\n/msx, $output_34;
            my @sort_sorted_34_4 = sort @sort_lines_34_4;
            my $output_34_4 = join "\n", @sort_sorted_34_4;
            if ($output_34_4 ne q{} && !($output_34_4 =~ m{\n\z}msx)) {
            $output_34_4 .= "\n";
            }
            $output_34 = $output_34_4;
            $output_34 = $output_34_4;

                        my @uniq_lines_34_5 = split /\n/msx, $output_34;
            @uniq_lines_34_5 = grep { $_ ne q{} } @uniq_lines_34_5; # Filter out empty lines
            my %uniq_seen_34_5;
            my @uniq_result_34_5;
            foreach my $line (@uniq_lines_34_5) {
            if (!$uniq_seen_34_5{$line}++) { push @uniq_result_34_5, $line; }
            }
            my $output_34_5 = join "\n", @uniq_result_34_5;
            if ($output_34_5 ne q{} && !($output_34_5 =~ m{\n\z}msx)) {
            $output_34_5 .= "\n";
            }
            $output_34 = $output_34_5;

                        my $set1_35 = q{/};
            my $set2_35 = q{_};
            my $input_35 = $output_34;
            # Expand character ranges for tr command
            my $expanded_set1_35 = $set1_35;
            my $expanded_set2_35 = $set2_35;
            # Handle a-z range in set1
            if ($expanded_set1_35 =~ /a-z/msx) {
            $expanded_set1_35 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle A-Z range in set1
            if ($expanded_set1_35 =~ /A-Z/msx) {
            $expanded_set1_35 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:upper:] POSIX class in set1
            if ($expanded_set1_35 =~ /\[:upper:\]/msx) {
            $expanded_set1_35 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:lower:] POSIX class in set1
            if ($expanded_set1_35 =~ /\[:lower:\]/msx) {
            $expanded_set1_35 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle a-z range in set2
            if ($expanded_set2_35 =~ /a-z/msx) {
            $expanded_set2_35 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle A-Z range in set2
            if ($expanded_set2_35 =~ /A-Z/msx) {
            $expanded_set2_35 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:upper:] POSIX class in set2
            if ($expanded_set2_35 =~ /\[:upper:\]/msx) {
            $expanded_set2_35 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:lower:] POSIX class in set2
            if ($expanded_set2_35 =~ /\[:lower:\]/msx) {
            $expanded_set2_35 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
            }
            my $tr_result_34_6 = q{};
            for my $char ( split //msx, $input_35 ) {
            my $pos_35 = index $expanded_set1_35, $char;
            if ( $pos_35 >= 0 && $pos_35 < length $expanded_set2_35 ) {
            $tr_result_34_6 .= substr $expanded_set2_35, $pos_35, 1;
            } else {
            $tr_result_34_6 .= $char;
            }
            }
            if (!($tr_result_34_6 =~ m{\n\z}msx || $tr_result_34_6 eq q{})) {
            $tr_result_34_6 .= "\n";
            }
            $output_34 = $tr_result_34_6;
            $output_34 = $tr_result_34_6;

                        my @sed_lines_34 = split /\n/msx, $output_34;
            my @sed_result_34;
            foreach my $line (@sed_lines_34) {
            chomp $line;
            push @sed_result_34, $line;
            }
            $output_34 = join "\n", @sed_result_34;

                        my @sed_lines_34 = split /\n/msx, $output_34;
            my @sed_result_34;
            foreach my $line (@sed_lines_34) {
            chomp $line;
            push @sed_result_34, $line;
            }
            $output_34 = join "\n", @sed_result_34;

                        use Carp qw(carp croak);
            if ( open my $fh, '>', $nthost ) {
            print {$fh} $output_34;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open $nthost: $ERRNO";
            }
            if ( open my $fh, '>', '/makesubdirsforW32X86driverlist.txt' ) {
            print {$fh} $output_34;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open '/makesubdirsforW32X86driverlist.txt': $ERRNO";
            }
            $output_34 = $output_34;
            if ($output_34 ne q{} && !defined $output_printed_34) {
                print $output_34;
                if (!($output_34 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_34 ) { $main_exit_code = 1; }
            }
        $main_exit_code = system('sh', '-x', $nthost, '/makesubdirsforW32X86driverlist.txt') >> 8;
    }
    return;
}

sub helpwithmakesubdirsforWIN40driverlist {
    # Original bash: echo -e " \n\
{
        my $output_36 = q{};
        my $output_printed_36;
        my $pipeline_success_36 = 1;
        $output_36 .= " \n\\\n################################################################################\n#\n#\t    About splitWIN40fileintoindividualdriverfiles() and\n#\t       splitW32X86fileintoindividualdriverfiles()...\n#           ---------------------------------------------------\n#\n# PRECONDITIONS: 1) These functions expect write access to the current directory\n#\t\t    and its subdirs '$nthost/*/'.\n#\t\t 2) These functions expect to have the '$nthost' variable set\n#\t\t    to the according value.\n#\t\t 3) These functions expect to find the two files\n#\t\t    '${nthost}/WIN40/${nthost}-enumdrivers3list-WIN40.txt' and\n#\t\t    '${nthost}/W32X86/${nthost}-enumdrivers3list-NTx86.txt' to\n#\t\t    work on.\n#\n# WHAT IT DOES: 1) These functions create a directory for each printer driver.\n#\t\t   The directory name is identical to the driver name.\n#\t\t2) For each supported driver version (\"0\", \"2\" and \"3\") it\n#\t\t   creates a subdirectory as required underneath\n#\t\t   './$nthost/<architecture>'.\n#\t\t3) The directories use the drivernames (including spaces) for\n#\t\t   their names. (" . q{ } . "/" . q{ } . " - slashes - in drivernames are converted to\n#\t\t   underscores).\n#\t\t4) In each subdirectory they dissect the original\n#\t\t   '$nthost/enumdrivers3list.txt' (using " . q{ } . "sed" . q{ } . ", " . q{ } . "cat" . q{ } . ", " . q{ } . "awk" . q{ } . "\n#\t\t   and " . q{ } . "grep" . q{ } . ") and store that part describing the related driver\n#\t\t   (under the name \"driverfilesversion.txt\".\n#\t\t5) For each driver the files \"Drivername\", \"DriverPath\",\n#\t\t   \"Drivername\", \"Configfile\", \"Helpfile\", \"AllFiles\" and\n#\t\t   \"Dependentfilelist\" are stored in the according directory\n#\t\t   which hold contend that is used by other (downstream)\n#\t\t   functions.\n#\t\t6) It creates a file named \"AllFilesIAskFor\" which holds the\n#\t\t   case sensitive names of files it wanted to download. It also\n#\t\t   creates a file named \"AllFilesIGot\" which holds the case\n#\t\t   sensitive spelling of the downloaded files. (Due to\n#\t\t   Microsoft's ingenious file naming tradition, you may have\n#\t\t   asked for a \"PS5UI.DLL\" but gotten a \"ps5ui.dll\".\n#\t\t7) The 2 files from 6) will be later compared with the help of\n#\t\t   the \"sdiff\" utility to decide how to re-name the files so\n#\t\t   that the subsequent driver upload command's spelling\n#\t\t   convention is met.\n#\n# IF IT DOESN'T WORK: The function \"fetchenumdrivers3listfromNThost\" and\n#\t\t      consecutive ones may not have been run successfully. This\n#\t\t      is a precondition for the current function.\n#\n# HINT: You currently have defined: 'nthost'=\"$nthost\".\n#\n################################################################################\n#           ............PRESS \"q\" TO QUIT............" . "\n";
if ( !($output_36 =~ m{\n\z}msx) ) { $output_36 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_38 = 'less';
        my ($in_37, $out_37);
        my $pid_37 = open3($in_37, $out_37, '>&STDERR', $cmd_38, );
        print {$in_37} $output_36;
        close $in_37 or croak 'Close failed: $OS_ERROR';
        $output_36 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_37> };
        close $out_37 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_37, 0;
        if ($output_36 ne q{} && !defined $output_printed_36) {
            print $output_36;
            if (!($output_36 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_36 ) { $main_exit_code = 1; }
        }
    return;
}

sub splitWIN40fileintoindividualdriverfiles {
    my ($file) = @_;
if (!(    stringinstring('help', "@ARGV"))) {
        helpwithmakesubdirsforWIN40driverlist();
}
    else {
        print " \n";
        print " \n";
        print "--> Running now function splitWIN40fileintoindividualdriverfiles()...\n";
        print "=====================================================================\n";
        my $i;
        for my $i ($nthost, '/WIN40/*/') {
            my $CWD1;
            my @CWD1;
            my %CWD1;
            $CWD1 = (do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; });
            chdir(${i});
            $CHILD_ERROR = 0;
            print " \n";
            print " \n";
            print " ###########################################################################################\n";
            print " \n";
            do {
    my $__echo_line = "   Next driver is \"" . (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename((do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; }) . "\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print " \n";
            print " ###########################################################################################\n";
unlink 'numdrivers3list-WIN40.lnk';
symlink '../', 'numdrivers3list-WIN40.lnk' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
            # Original bash: tac ${nthost}-enumdrivers3list-WIN40.lnk \
{
                my $output_40 = q{};
                my $output_printed_40;
                my $pipeline_success_40 = 1;
                                my ($in_41, $out_41);
                my $pid_41 = open3($in_41, $out_41, '>&STDERR', 'tac', '-e', 'numdrivers3list-WIN40.lnk');
                close $in_41 or croak 'Close failed: $OS_ERROR';
                $output_40 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_41> };
                close $out_41 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_41, 0;

                                my @sed_lines_40 = split /\n/msx, $output_40;
                my @sed_result_40;
                foreach my $line (@sed_lines_40) {
                chomp $line;
                push @sed_result_40, $line;
                }
                $output_40 = join "\n", @sed_result_40;

                                my $grep_result_40_2;
                my @grep_lines_40_2 = split /\n/msx, $output_40;
                my @grep_filtered_40_2 = grep { /Version/msx } @grep_lines_40_2;
                $grep_result_40_2 = join "\n", @grep_filtered_40_2;
                if (!($grep_result_40_2 =~ m{\n\z}msx || $grep_result_40_2 eq q{})) {
                $grep_result_40_2 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_40_2 > 0 ? 0 : 1;
                $output_40 = $grep_result_40_2;
                $output_40 = $grep_result_40_2;

                                my @uniq_lines_40_3 = split /\n/msx, $output_40;
                @uniq_lines_40_3 = grep { $_ ne q{} } @uniq_lines_40_3; # Filter out empty lines
                my %uniq_seen_40_3;
                my @uniq_result_40_3;
                foreach my $line (@uniq_lines_40_3) {
                if (!$uniq_seen_40_3{$line}++) { push @uniq_result_40_3, $line; }
                }
                my $output_40_3 = join "\n", @uniq_result_40_3;
                if ($output_40_3 ne q{} && !($output_40_3 =~ m{\n\z}msx)) {
                $output_40_3 .= "\n";
                }
                $output_40 = $output_40_3;

                                my @lines = split /\n/msx, $output_40;
                my @result;
                foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /[/msx, $line;
                push @result, ($fields[1] . "\n");
                }
                $output_40 = join "", @result;

                                my @lines = split /\n/msx, $output_40;
                my @result;
                foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /]/msx, $line;
                push @result, ("mkdir \"\" $1 \"\"" . "\n");
                }
                $output_40 = join "", @result;

                                use Carp qw(carp croak);
                if ( open my $fh, '>', 'mkversiondir.txt' ) {
                print {$fh} $output_40;
                close $fh or croak "Close failed: $ERRNO";
                }
                else {
                carp "tee: Cannot open 'mkversiondir.txt': $ERRNO";
                }
                $output_40 = $output_40;
                if ($output_40 ne q{} && !defined $output_printed_40) {
                    print $output_40;
                    if (!($output_40 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_40 ) { $main_exit_code = 1; }
                }
            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                $main_exit_code = system('sh', 'mkversiondir.txt') >> 8;
            };
            # Original bash: cat ${nthost}-enumdrivers3list-WIN40.lnk \
{
                my $output_42 = q{};
                my $output_printed_42;
                my $pipeline_success_42 = 1;
                                $output_42 = do { my $cat_out = q{}; my $cat_pid = open3(my $cat_in, my $cat_out_r, undef, 'cat', '$nthost', '-e', 'numdrivers3list-WIN40.lnk'); close $cat_in or croak 'Close failed: $OS_ERROR'; local $INPUT_RECORD_SEPARATOR = undef; $cat_out = <$cat_out_r>; close $cat_out_r or croak 'Close failed: $OS_ERROR'; waitpid $cat_pid, 0; $cat_out; };

                                my @sed_lines_42 = split /\n/msx, $output_42;
                my @sed_result_42;
                foreach my $line (@sed_lines_42) {
                chomp $line;
                push @sed_result_42, $line;
                }
                $output_42 = join "\n", @sed_result_42;
                if ($output_42 ne q{} && !defined $output_printed_42) {
                    print $output_42;
                    if (!($output_42 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_42 ) { $main_exit_code = 1; }
                }
            for my $i ('*/') {
                my $CWD2;
                my @CWD2;
                my %CWD2;
                $CWD2 = (do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; });
                chdir(${i});
                $CHILD_ERROR = 0;
                # Original bash: echo "yes" | cp ../alldriverfiles.txt . 2> /dev/null ;
{
                    my $output_43 = q{};
                    my $output_printed_43;
                    my $pipeline_success_43 = 1;
                    $output_43 .= 'yes' . "\n";
if ( !($output_43 =~ m{\n\z}msx) ) { $output_43 .= "\n"; }
$CHILD_ERROR = 0;

                                        use File::Copy qw(copy);
                    if ( -e '../alldriverfiles.txt' ) {
                    if ( -d q{.} ) {
                    require File::Copy; File::Copy::copy('../alldriverfiles.txt', q{.} . '/' . ('../alldriverfiles.txt' =~ m|([^/]+)$|)[0]);
                    } else {
                    require File::Copy; File::Copy::copy('../alldriverfiles.txt', q{.});
                    }
                    } else {
                    croak "cp: cannot stat '../alldriverfiles.txt': No such file or directory\n";
                    }
                    if ($output_43 ne q{} && !defined $output_printed_43) {
                        print $output_43;
                        if (!($output_43 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_43 ) { $main_exit_code = 1; }
                    }
                # Original bash: cat alldriverfiles.txt \
{
                    my $output_44 = q{};
                    my $output_printed_44;
                    my $pipeline_success_44 = 1;
                                        $output_44 = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'alldriverfiles.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'alldriverfiles.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };

                                        my $cmd_46 = 'egrep';
                    my ($in_45, $out_45);
                    my $pid_45 = open3($in_45, $out_45, '>&STDERR', $cmd_46, "(\\\\", "\\\\|Driver Name)");
                    print {$in_45} $output_44;
                    close $in_45 or croak 'Close failed: $OS_ERROR';
                    $output_44 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_45> };
                    close $out_45 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_45, 0;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'driverfilesversion.txt' ) {
                    print {$fh} $output_44;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'driverfilesversion.txt': $ERRNO";
                    }
                    $output_44 = $output_44;
                    if ($output_44 ne q{} && !defined $output_printed_44) {
                        print $output_44;
                        if (!($output_44 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_44 ) { $main_exit_code = 1; }
                    }
                my $Drivername;
                my @Drivername;
                my %Drivername;
                $Drivername = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_47 = q{};
                    my $output_printed_47;
                    my $pipeline_success_47 = 1;
                    my $grep_result_47_0;
                    my @grep_lines_47_0 = ();
                    my @grep_filenames_47_0 = ();
                    if (-e "driverfilesversion.txt") {
                        open my $fh, '<', "driverfilesversion.txt" or croak "Cannot open file: $ERRNO";
                        while (my $line = <$fh>) {
                            chomp $line;
                            push @grep_lines_47_0, $line;
                            push @grep_filenames_47_0, "driverfilesversion.txt";
                        }
                        close $fh
                            or croak "Close failed: $OS_ERROR";
                    }
                    else { print {*STDERR} "grep: driverfilesversion.txt: No such file or directory\n"; }
                    my @grep_filtered_47_0 = grep { /Driver\ Name:/msx } @grep_lines_47_0;
                    $grep_result_47_0 = join "\n", @grep_filtered_47_0;
                                        if (!($grep_result_47_0 =~ m{\n\z}msx || $grep_result_47_0 eq q{})) {
                                            $grep_result_47_0 .= "\n";
                                        }
                    $CHILD_ERROR = scalar @grep_filtered_47_0 > 0 ? 0 : 1;
                    $output_47 = $grep_result_47_0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_47 = 0; }
                    my @lines = split /\n/msx, $output_47;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /[/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_47 = join "", @result;

                    my @lines = split /\n/msx, $output_47;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /]/msx, $line;
                        push @result, ($fields[0] . "\n");
                    }
                    $output_47 = join "", @result;

                    my @sort_lines_47_3 = split /\n/msx, $output_47;
                    my @sort_sorted_47_3 = sort @sort_lines_47_3;
                    $output_47 = join "\n", @sort_sorted_47_3;
                                        if ($output_47 ne q{} && !($output_47 =~ m{\n\z}msx)) {
                                            $output_47 .= "\n";
                                        }
                    my @uniq_lines_47_4 = split /\n/msx, $output_47;
                    @uniq_lines_47_4 = grep { $_ ne q{} } @uniq_lines_47_4; # Filter out empty lines
                    my %uniq_seen_47_4;
                    my @uniq_result_47_4;
                    foreach my $line (@uniq_lines_47_4) {
                    if (!$uniq_seen_47_4{$line}++) { push @uniq_result_47_4, $line; }
                    }
                    $output_47 = join "\n", @uniq_result_47_4;
                                        if ($output_47 ne q{} && !($output_47 =~ m{\n\z}msx)) {
                                            $output_47 .= "\n";
                                        }
                    use Carp qw(carp croak);
                    if ( open my $fh, '>', 'Drivername' ) {
                        print {$fh} $output_47;
                        close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                        carp "tee: Cannot open 'Drivername': $ERRNO";
                    }
                    $output_47 = $output_47;
                    if ( !$pipeline_success_47 ) { $main_exit_code = 1; }
                    $output_47 =~ s/\n+\z//msx;
                    $output_47;
}; $_pipeline_result; };
                my $DriverPath;
                my @DriverPath;
                my %DriverPath;
                $DriverPath = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_48 = q{};
                    my $output_printed_48;
                    my $pipeline_success_48 = 1;
                    my $grep_result_48_0;
                    my @grep_lines_48_0 = ();
                    my @grep_filenames_48_0 = ();
                    if (-e "driverfilesversion.txt") {
                        open my $fh, '<', "driverfilesversion.txt" or croak "Cannot open file: $ERRNO";
                        while (my $line = <$fh>) {
                            chomp $line;
                            push @grep_lines_48_0, $line;
                            push @grep_filenames_48_0, "driverfilesversion.txt";
                        }
                        close $fh
                            or croak "Close failed: $OS_ERROR";
                    }
                    else { print {*STDERR} "grep: driverfilesversion.txt: No such file or directory\n"; }
                    my @grep_filtered_48_0 = grep { /Driver\ Path:/msx } @grep_lines_48_0;
                    $grep_result_48_0 = join "\n", @grep_filtered_48_0;
                                        if (!($grep_result_48_0 =~ m{\n\z}msx || $grep_result_48_0 eq q{})) {
                                            $grep_result_48_0 .= "\n";
                                        }
                    $CHILD_ERROR = scalar @grep_filtered_48_0 > 0 ? 0 : 1;
                    $output_48 = $grep_result_48_0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_48 = 0; }
                    my @lines = split /\n/msx, $output_48;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /[/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_48 = join "", @result;

                    my @lines = split /\n/msx, $output_48;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /]/msx, $line;
                        push @result, ($fields[0] . "\n");
                    }
                    $output_48 = join "", @result;

                    my @lines = split /\n/msx, $output_48;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /WIN40/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_48 = join "", @result;

                    my @lines = split /\n/msx, $output_48;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /\/msx, $line;
                        push @result, ($fields[2] . "\n");
                    }
                    $output_48 = join "", @result;

                    my @sort_lines_48_5 = split /\n/msx, $output_48;
                    my @sort_sorted_48_5 = sort @sort_lines_48_5;
                    $output_48 = join "\n", @sort_sorted_48_5;
                                        if ($output_48 ne q{} && !($output_48 =~ m{\n\z}msx)) {
                                            $output_48 .= "\n";
                                        }
                    my @uniq_lines_48_6 = split /\n/msx, $output_48;
                    @uniq_lines_48_6 = grep { $_ ne q{} } @uniq_lines_48_6; # Filter out empty lines
                    my %uniq_seen_48_6;
                    my @uniq_result_48_6;
                    foreach my $line (@uniq_lines_48_6) {
                    if (!$uniq_seen_48_6{$line}++) { push @uniq_result_48_6, $line; }
                    }
                    $output_48 = join "\n", @uniq_result_48_6;
                                        if ($output_48 ne q{} && !($output_48 =~ m{\n\z}msx)) {
                                            $output_48 .= "\n";
                                        }
                    if ( !$pipeline_success_48 ) { $main_exit_code = 1; }
                    $output_48 =~ s/\n+\z//msx;
                    $output_48;
}; $_pipeline_result; };
                # Original bash: echo "${DriverPath}" \
{
                    my $output_49 = q{};
                    my $output_printed_49;
                    my $pipeline_success_49 = 1;
                    $output_49 .= ${DriverPath} . "\n";
if ( !($output_49 =~ m{\n\z}msx) ) { $output_49 .= "\n"; }
$CHILD_ERROR = 0;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'DriverPath' ) {
                    print {$fh} $output_49;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'DriverPath': $ERRNO";
                    }
                    $output_49 = $output_49;
                    if ($output_49 ne q{} && !defined $output_printed_49) {
                        print $output_49;
                        if (!($output_49 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_49 ) { $main_exit_code = 1; }
                    }
                my $Datafile;
                my @Datafile;
                my %Datafile;
                $Datafile = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_50 = q{};
                    my $output_printed_50;
                    my $pipeline_success_50 = 1;
                    my $grep_result_50_0;
                    my @grep_lines_50_0 = ();
                    my @grep_filenames_50_0 = ();
                    if (-e "driverfilesversion.txt") {
                        open my $fh, '<', "driverfilesversion.txt" or croak "Cannot open file: $ERRNO";
                        while (my $line = <$fh>) {
                            chomp $line;
                            push @grep_lines_50_0, $line;
                            push @grep_filenames_50_0, "driverfilesversion.txt";
                        }
                        close $fh
                            or croak "Close failed: $OS_ERROR";
                    }
                    else { print {*STDERR} "grep: driverfilesversion.txt: No such file or directory\n"; }
                    my @grep_filtered_50_0 = grep { /Datafile:/msx } @grep_lines_50_0;
                    $grep_result_50_0 = join "\n", @grep_filtered_50_0;
                                        if (!($grep_result_50_0 =~ m{\n\z}msx || $grep_result_50_0 eq q{})) {
                                            $grep_result_50_0 .= "\n";
                                        }
                    $CHILD_ERROR = scalar @grep_filtered_50_0 > 0 ? 0 : 1;
                    $output_50 = $grep_result_50_0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_50 = 0; }
                    my @lines = split /\n/msx, $output_50;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /[/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_50 = join "", @result;

                    my @lines = split /\n/msx, $output_50;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /]/msx, $line;
                        push @result, ($fields[0] . "\n");
                    }
                    $output_50 = join "", @result;

                    my @lines = split /\n/msx, $output_50;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /WIN40/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_50 = join "", @result;

                    my @lines = split /\n/msx, $output_50;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /\/msx, $line;
                        push @result, ($fields[2] . "\n");
                    }
                    $output_50 = join "", @result;

                    my @sort_lines_50_5 = split /\n/msx, $output_50;
                    my @sort_sorted_50_5 = sort @sort_lines_50_5;
                    $output_50 = join "\n", @sort_sorted_50_5;
                                        if ($output_50 ne q{} && !($output_50 =~ m{\n\z}msx)) {
                                            $output_50 .= "\n";
                                        }
                    my @uniq_lines_50_6 = split /\n/msx, $output_50;
                    @uniq_lines_50_6 = grep { $_ ne q{} } @uniq_lines_50_6; # Filter out empty lines
                    my %uniq_seen_50_6;
                    my @uniq_result_50_6;
                    foreach my $line (@uniq_lines_50_6) {
                    if (!$uniq_seen_50_6{$line}++) { push @uniq_result_50_6, $line; }
                    }
                    $output_50 = join "\n", @uniq_result_50_6;
                                        if ($output_50 ne q{} && !($output_50 =~ m{\n\z}msx)) {
                                            $output_50 .= "\n";
                                        }
                    if ( !$pipeline_success_50 ) { $main_exit_code = 1; }
                    $output_50 =~ s/\n+\z//msx;
                    $output_50;
}; $_pipeline_result; };
                # Original bash: echo "${Datafile}" \
{
                    my $output_51 = q{};
                    my $output_printed_51;
                    my $pipeline_success_51 = 1;
                    $output_51 .= ${Datafile} . "\n";
if ( !($output_51 =~ m{\n\z}msx) ) { $output_51 .= "\n"; }
$CHILD_ERROR = 0;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'Datafile' ) {
                    print {$fh} $output_51;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'Datafile': $ERRNO";
                    }
                    $output_51 = $output_51;
                    if ($output_51 ne q{} && !defined $output_printed_51) {
                        print $output_51;
                        if (!($output_51 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_51 ) { $main_exit_code = 1; }
                    }
                my $Configfile;
                my @Configfile;
                my %Configfile;
                $Configfile = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_52 = q{};
                    my $output_printed_52;
                    my $pipeline_success_52 = 1;
                    my $grep_result_52_0;
                    my @grep_lines_52_0 = ();
                    my @grep_filenames_52_0 = ();
                    if (-e "driverfilesversion.txt") {
                        open my $fh, '<', "driverfilesversion.txt" or croak "Cannot open file: $ERRNO";
                        while (my $line = <$fh>) {
                            chomp $line;
                            push @grep_lines_52_0, $line;
                            push @grep_filenames_52_0, "driverfilesversion.txt";
                        }
                        close $fh
                            or croak "Close failed: $OS_ERROR";
                    }
                    else { print {*STDERR} "grep: driverfilesversion.txt: No such file or directory\n"; }
                    my @grep_filtered_52_0 = grep { /Configfile:/msx } @grep_lines_52_0;
                    $grep_result_52_0 = join "\n", @grep_filtered_52_0;
                                        if (!($grep_result_52_0 =~ m{\n\z}msx || $grep_result_52_0 eq q{})) {
                                            $grep_result_52_0 .= "\n";
                                        }
                    $CHILD_ERROR = scalar @grep_filtered_52_0 > 0 ? 0 : 1;
                    $output_52 = $grep_result_52_0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_52 = 0; }
                    my @lines = split /\n/msx, $output_52;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /[/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_52 = join "", @result;

                    my @lines = split /\n/msx, $output_52;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /]/msx, $line;
                        push @result, ($fields[0] . "\n");
                    }
                    $output_52 = join "", @result;

                    my @lines = split /\n/msx, $output_52;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /WIN40/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_52 = join "", @result;

                    my @lines = split /\n/msx, $output_52;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /\/msx, $line;
                        push @result, ($fields[2] . "\n");
                    }
                    $output_52 = join "", @result;

                    my @sort_lines_52_5 = split /\n/msx, $output_52;
                    my @sort_sorted_52_5 = sort @sort_lines_52_5;
                    $output_52 = join "\n", @sort_sorted_52_5;
                                        if ($output_52 ne q{} && !($output_52 =~ m{\n\z}msx)) {
                                            $output_52 .= "\n";
                                        }
                    my @uniq_lines_52_6 = split /\n/msx, $output_52;
                    @uniq_lines_52_6 = grep { $_ ne q{} } @uniq_lines_52_6; # Filter out empty lines
                    my %uniq_seen_52_6;
                    my @uniq_result_52_6;
                    foreach my $line (@uniq_lines_52_6) {
                    if (!$uniq_seen_52_6{$line}++) { push @uniq_result_52_6, $line; }
                    }
                    $output_52 = join "\n", @uniq_result_52_6;
                                        if ($output_52 ne q{} && !($output_52 =~ m{\n\z}msx)) {
                                            $output_52 .= "\n";
                                        }
                    if ( !$pipeline_success_52 ) { $main_exit_code = 1; }
                    $output_52 =~ s/\n+\z//msx;
                    $output_52;
}; $_pipeline_result; };
                # Original bash: echo "${Configfile}" \
{
                    my $output_53 = q{};
                    my $output_printed_53;
                    my $pipeline_success_53 = 1;
                    $output_53 .= ${Configfile} . "\n";
if ( !($output_53 =~ m{\n\z}msx) ) { $output_53 .= "\n"; }
$CHILD_ERROR = 0;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'Configfile' ) {
                    print {$fh} $output_53;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'Configfile': $ERRNO";
                    }
                    $output_53 = $output_53;
                    if ($output_53 ne q{} && !defined $output_printed_53) {
                        print $output_53;
                        if (!($output_53 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_53 ) { $main_exit_code = 1; }
                    }
                my $Helpfile;
                my @Helpfile;
                my %Helpfile;
                $Helpfile = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_54 = q{};
                    my $output_printed_54;
                    my $pipeline_success_54 = 1;
                    my $grep_result_54_0;
                    my @grep_lines_54_0 = ();
                    my @grep_filenames_54_0 = ();
                    if (-e "driverfilesversion.txt") {
                        open my $fh, '<', "driverfilesversion.txt" or croak "Cannot open file: $ERRNO";
                        while (my $line = <$fh>) {
                            chomp $line;
                            push @grep_lines_54_0, $line;
                            push @grep_filenames_54_0, "driverfilesversion.txt";
                        }
                        close $fh
                            or croak "Close failed: $OS_ERROR";
                    }
                    else { print {*STDERR} "grep: driverfilesversion.txt: No such file or directory\n"; }
                    my @grep_filtered_54_0 = grep { /Helpfile:/msx } @grep_lines_54_0;
                    $grep_result_54_0 = join "\n", @grep_filtered_54_0;
                                        if (!($grep_result_54_0 =~ m{\n\z}msx || $grep_result_54_0 eq q{})) {
                                            $grep_result_54_0 .= "\n";
                                        }
                    $CHILD_ERROR = scalar @grep_filtered_54_0 > 0 ? 0 : 1;
                    $output_54 = $grep_result_54_0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_54 = 0; }
                    my @lines = split /\n/msx, $output_54;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /[/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_54 = join "", @result;

                    my @lines = split /\n/msx, $output_54;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /]/msx, $line;
                        push @result, ($fields[0] . "\n");
                    }
                    $output_54 = join "", @result;

                    my @lines = split /\n/msx, $output_54;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /WIN40/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_54 = join "", @result;

                    my @lines = split /\n/msx, $output_54;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /\/msx, $line;
                        push @result, ($fields[2] . "\n");
                    }
                    $output_54 = join "", @result;

                    my @sort_lines_54_5 = split /\n/msx, $output_54;
                    my @sort_sorted_54_5 = sort @sort_lines_54_5;
                    $output_54 = join "\n", @sort_sorted_54_5;
                                        if ($output_54 ne q{} && !($output_54 =~ m{\n\z}msx)) {
                                            $output_54 .= "\n";
                                        }
                    my @uniq_lines_54_6 = split /\n/msx, $output_54;
                    @uniq_lines_54_6 = grep { $_ ne q{} } @uniq_lines_54_6; # Filter out empty lines
                    my %uniq_seen_54_6;
                    my @uniq_result_54_6;
                    foreach my $line (@uniq_lines_54_6) {
                    if (!$uniq_seen_54_6{$line}++) { push @uniq_result_54_6, $line; }
                    }
                    $output_54 = join "\n", @uniq_result_54_6;
                                        if ($output_54 ne q{} && !($output_54 =~ m{\n\z}msx)) {
                                            $output_54 .= "\n";
                                        }
                    if ( !$pipeline_success_54 ) { $main_exit_code = 1; }
                    $output_54 =~ s/\n+\z//msx;
                    $output_54;
}; $_pipeline_result; };
                # Original bash: echo "${Helpfile}" \
{
                    my $output_55 = q{};
                    my $output_printed_55;
                    my $pipeline_success_55 = 1;
                    $output_55 .= ${Helpfile} . "\n";
if ( !($output_55 =~ m{\n\z}msx) ) { $output_55 .= "\n"; }
$CHILD_ERROR = 0;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'Helpfile' ) {
                    print {$fh} $output_55;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'Helpfile': $ERRNO";
                    }
                    $output_55 = $output_55;
                    if ($output_55 ne q{} && !defined $output_printed_55) {
                        print $output_55;
                        if (!($output_55 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_55 ) { $main_exit_code = 1; }
                    }
                my $Dependentfilelist;
                my @Dependentfilelist;
                my %Dependentfilelist;
                $Dependentfilelist = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_56 = q{};
                    my $output_printed_56;
                    my $pipeline_success_56 = 1;
                    my $grep_result_56_0;
                    my @grep_lines_56_0 = ();
                    my @grep_filenames_56_0 = ();
                    if (-e "driverfilesversion.txt") {
                        open my $fh, '<', "driverfilesversion.txt" or croak "Cannot open file: $ERRNO";
                        while (my $line = <$fh>) {
                            chomp $line;
                            push @grep_lines_56_0, $line;
                            push @grep_filenames_56_0, "driverfilesversion.txt";
                        }
                        close $fh
                            or croak "Close failed: $OS_ERROR";
                    }
                    else { print {*STDERR} "grep: driverfilesversion.txt: No such file or directory\n"; }
                    my @grep_filtered_56_0 = grep { /Dependentfiles:/msx } @grep_lines_56_0;
                    $grep_result_56_0 = join "\n", @grep_filtered_56_0;
                                        if (!($grep_result_56_0 =~ m{\n\z}msx || $grep_result_56_0 eq q{})) {
                                            $grep_result_56_0 .= "\n";
                                        }
                    $CHILD_ERROR = scalar @grep_filtered_56_0 > 0 ? 0 : 1;
                    $output_56 = $grep_result_56_0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_56 = 0; }
                    my @lines = split /\n/msx, $output_56;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /[/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_56 = join "", @result;

                    my @lines = split /\n/msx, $output_56;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /]/msx, $line;
                        push @result, ($fields[0] . "\n");
                    }
                    $output_56 = join "", @result;

                    my @lines = split /\n/msx, $output_56;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /WIN40/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_56 = join "", @result;

                    my @lines = split /\n/msx, $output_56;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /\/msx, $line;
                        push @result, ($fields[2] . "\n");
                    }
                    $output_56 = join "", @result;

                    my @sort_lines_56_5 = split /\n/msx, $output_56;
                    my @sort_sorted_56_5 = sort @sort_lines_56_5;
                    $output_56 = join "\n", @sort_sorted_56_5;
                                        if ($output_56 ne q{} && !($output_56 =~ m{\n\z}msx)) {
                                            $output_56 .= "\n";
                                        }
                    my @uniq_lines_56_6 = split /\n/msx, $output_56;
                    @uniq_lines_56_6 = grep { $_ ne q{} } @uniq_lines_56_6; # Filter out empty lines
                    my %uniq_seen_56_6;
                    my @uniq_result_56_6;
                    foreach my $line (@uniq_lines_56_6) {
                    if (!$uniq_seen_56_6{$line}++) { push @uniq_result_56_6, $line; }
                    }
                    $output_56 = join "\n", @uniq_result_56_6;
                                        if ($output_56 ne q{} && !($output_56 =~ m{\n\z}msx)) {
                                            $output_56 .= "\n";
                                        }
                    if ( !$pipeline_success_56 ) { $main_exit_code = 1; }
                    $output_56 =~ s/\n+\z//msx;
                    $output_56;
}; $_pipeline_result; };
                my $Dependentfiles;
                my @Dependentfiles;
                my %Dependentfiles;
                $Dependentfiles = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_57 = q{};
                    my $output_printed_57;
                    my $pipeline_success_57 = 1;
                    $output_57 .= $Dependentfilelist . "\n";
                    if ( !($output_57 =~ m{\n\z}msx) ) { $output_57 .= "\n"; }
                    $CHILD_ERROR = 0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_57 = 0; }
                    my @sed_lines_57 = split /\n/msx, $output_57;
                    my @sed_result_57;
                    foreach my $line (@sed_lines_57) {
                    chomp $line;
                    push @sed_result_57, $line;
                    }
                    $output_57 = join "\n", @sed_result_57;

                    if ( !$pipeline_success_57 ) { $main_exit_code = 1; }
                    $output_57 =~ s/\n+\z//msx;
                    $output_57;
}; $_pipeline_result; };
                # Original bash: echo "${Dependentfiles}" \
{
                    my $output_58 = q{};
                    my $output_printed_58;
                    my $pipeline_success_58 = 1;
                    $output_58 .= ${Dependentfiles} . "\n";
if ( !($output_58 =~ m{\n\z}msx) ) { $output_58 .= "\n"; }
$CHILD_ERROR = 0;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'Dependentfiles' ) {
                    print {$fh} $output_58;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'Dependentfiles': $ERRNO";
                    }
                    $output_58 = $output_58;
                    if ($output_58 ne q{} && !defined $output_printed_58) {
                        print $output_58;
                        if (!($output_58 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_58 ) { $main_exit_code = 1; }
                    }
                my $AllFiles;
                my @AllFiles;
                my %AllFiles;
                $AllFiles = ($Dependentfilelist);
                # Original bash: echo "${AllFiles}" \
{
                    my $output_59 = q{};
                    my $output_printed_59;
                    my $pipeline_success_59 = 1;
                    $output_59 .= ${AllFiles} . "\n";
if ( !($output_59 =~ m{\n\z}msx) ) { $output_59 .= "\n"; }
$CHILD_ERROR = 0;

                                        my @sort_lines_59_1 = split /\n/msx, $output_59;
                    my @sort_sorted_59_1 = sort @sort_lines_59_1;
                    my $output_59_1 = join "\n", @sort_sorted_59_1;
                    if ($output_59_1 ne q{} && !($output_59_1 =~ m{\n\z}msx)) {
                    $output_59_1 .= "\n";
                    }
                    $output_59 = $output_59_1;
                    $output_59 = $output_59_1;

                                        my @uniq_lines_59_2 = split /\n/msx, $output_59;
                    @uniq_lines_59_2 = grep { $_ ne q{} } @uniq_lines_59_2; # Filter out empty lines
                    my %uniq_seen_59_2;
                    my @uniq_result_59_2;
                    foreach my $line (@uniq_lines_59_2) {
                    if (!$uniq_seen_59_2{$line}++) { push @uniq_result_59_2, $line; }
                    }
                    my $output_59_2 = join "\n", @uniq_result_59_2;
                    if ($output_59_2 ne q{} && !($output_59_2 =~ m{\n\z}msx)) {
                    $output_59_2 .= "\n";
                    }
                    $output_59 = $output_59_2;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'AllFiles' ) {
                    print {$fh} $output_59;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'AllFiles': $ERRNO";
                    }
                    $output_59 = $output_59;
                    if ($output_59 ne q{} && !defined $output_printed_59) {
                        print $output_59;
                        if (!($output_59 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_59 ) { $main_exit_code = 1; }
                    }
                # Original bash: #!/bin/bash
{
                    my $output_60 = q{};
                    my $output_printed_60;
                    my $pipeline_success_60 = 1;
                                        $output_60 = q{};
                    my @output_60_items = (do { my $cat_chunk = q{}; if ( open my $fh, '<', 'AllFiles' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'AllFiles' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
                    for my $i (@output_60_items) {
                    $output_60 .= $i. "\n";
                    }

                                        my @sort_lines_60_1 = split /\n/msx, $output_60;
                    my @sort_sorted_60_1 = sort @sort_lines_60_1;
                    my $output_60_1 = join "\n", @sort_sorted_60_1;
                    if ($output_60_1 ne q{} && !($output_60_1 =~ m{\n\z}msx)) {
                    $output_60_1 .= "\n";
                    }
                    $output_60 = $output_60_1;
                    $output_60 = $output_60_1;

                                        my @uniq_lines_60_2 = split /\n/msx, $output_60;
                    @uniq_lines_60_2 = grep { $_ ne q{} } @uniq_lines_60_2; # Filter out empty lines
                    my %uniq_seen_60_2;
                    my @uniq_result_60_2;
                    foreach my $line (@uniq_lines_60_2) {
                    if (!$uniq_seen_60_2{$line}++) { push @uniq_result_60_2, $line; }
                    }
                    my $output_60_2 = join "\n", @uniq_result_60_2;
                    if ($output_60_2 ne q{} && !($output_60_2 =~ m{\n\z}msx)) {
                    $output_60_2 .= "\n";
                    }
                    $output_60 = $output_60_2;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'AllFilesIAskFor' ) {
                    print {$fh} $output_60;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'AllFilesIAskFor': $ERRNO";
                    }
                    $output_60 = $output_60;
                    if ($output_60 ne q{} && !defined $output_printed_60) {
                        print $output_60;
                        if (!($output_60 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_60 ) { $main_exit_code = 1; }
                    }
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
                    chdir(${CWD2});
                    $CHILD_ERROR = 0;
                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
            }
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                chdir(${CWD1});
                $CHILD_ERROR = 0;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
    }
    return;
}

sub splitW32X86fileintoindividualdriverfiles {
    my ($file) = @_;
if (!(    stringinstring('help', "@ARGV"))) {
        helpwithmakesubdirsforWIN40driverlist();
}
    else {
        print " \n";
        print " \n";
        print "--> Running now function splitW32X86fileintoindividualdriverfiles()...\n";
        print "======================================================================\n";
        my $i;
        for my $i ($nthost, '/W32X86/*/') {
            my $CWD1;
            my @CWD1;
            my %CWD1;
            $CWD1 = (do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; });
            chdir(${i});
            $CHILD_ERROR = 0;
            print " \n";
            print " \n";
            print " ###########################################################################################\n";
            print " \n";
            do {
    my $__echo_line = "   Next driver is \"" . (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename((do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; }) . "\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print " \n";
            print " ###########################################################################################\n";
unlink 'numdrivers3list-NTx86.lnk';
symlink '../', 'numdrivers3list-NTx86.lnk' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
            # Original bash: tac ${nthost}-enumdrivers3list-NTx86.lnk \
{
                my $output_62 = q{};
                my $output_printed_62;
                my $pipeline_success_62 = 1;
                                my ($in_63, $out_63);
                my $pid_63 = open3($in_63, $out_63, '>&STDERR', 'tac', '-e', 'numdrivers3list-NTx86.lnk');
                close $in_63 or croak 'Close failed: $OS_ERROR';
                $output_62 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_63> };
                close $out_63 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_63, 0;

                                my @sed_lines_62 = split /\n/msx, $output_62;
                my @sed_result_62;
                foreach my $line (@sed_lines_62) {
                chomp $line;
                push @sed_result_62, $line;
                }
                $output_62 = join "\n", @sed_result_62;

                                my $grep_result_62_2;
                my @grep_lines_62_2 = split /\n/msx, $output_62;
                my @grep_filtered_62_2 = grep { /Version/msx } @grep_lines_62_2;
                $grep_result_62_2 = join "\n", @grep_filtered_62_2;
                if (!($grep_result_62_2 =~ m{\n\z}msx || $grep_result_62_2 eq q{})) {
                $grep_result_62_2 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_62_2 > 0 ? 0 : 1;
                $output_62 = $grep_result_62_2;
                $output_62 = $grep_result_62_2;

                                my @uniq_lines_62_3 = split /\n/msx, $output_62;
                @uniq_lines_62_3 = grep { $_ ne q{} } @uniq_lines_62_3; # Filter out empty lines
                my %uniq_seen_62_3;
                my @uniq_result_62_3;
                foreach my $line (@uniq_lines_62_3) {
                if (!$uniq_seen_62_3{$line}++) { push @uniq_result_62_3, $line; }
                }
                my $output_62_3 = join "\n", @uniq_result_62_3;
                if ($output_62_3 ne q{} && !($output_62_3 =~ m{\n\z}msx)) {
                $output_62_3 .= "\n";
                }
                $output_62 = $output_62_3;

                                my @lines = split /\n/msx, $output_62;
                my @result;
                foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /[/msx, $line;
                push @result, ($fields[1] . "\n");
                }
                $output_62 = join "", @result;

                                my @lines = split /\n/msx, $output_62;
                my @result;
                foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /]/msx, $line;
                push @result, ("mkdir \"\" $1 \"\"" . "\n");
                }
                $output_62 = join "", @result;

                                use Carp qw(carp croak);
                if ( open my $fh, '>', 'mkversiondir.txt' ) {
                print {$fh} $output_62;
                close $fh or croak "Close failed: $ERRNO";
                }
                else {
                carp "tee: Cannot open 'mkversiondir.txt': $ERRNO";
                }
                $output_62 = $output_62;
                if ($output_62 ne q{} && !defined $output_printed_62) {
                    print $output_62;
                    if (!($output_62 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_62 ) { $main_exit_code = 1; }
                }
            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                $main_exit_code = system('sh', 'mkversiondir.txt') >> 8;
            };
            # Original bash: cat ${nthost}-enumdrivers3list-NTx86.lnk \
{
                my $output_64 = q{};
                my $output_printed_64;
                my $pipeline_success_64 = 1;
                                $output_64 = do { my $cat_out = q{}; my $cat_pid = open3(my $cat_in, my $cat_out_r, undef, 'cat', '$nthost', '-e', 'numdrivers3list-NTx86.lnk'); close $cat_in or croak 'Close failed: $OS_ERROR'; local $INPUT_RECORD_SEPARATOR = undef; $cat_out = <$cat_out_r>; close $cat_out_r or croak 'Close failed: $OS_ERROR'; waitpid $cat_pid, 0; $cat_out; };

                                my @sed_lines_64 = split /\n/msx, $output_64;
                my @sed_result_64;
                foreach my $line (@sed_lines_64) {
                chomp $line;
                push @sed_result_64, $line;
                }
                $output_64 = join "\n", @sed_result_64;
                if ($output_64 ne q{} && !defined $output_printed_64) {
                    print $output_64;
                    if (!($output_64 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_64 ) { $main_exit_code = 1; }
                }
            for my $i ('*/') {
                my $CWD2;
                my @CWD2;
                my %CWD2;
                $CWD2 = (do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; });
                chdir(${i});
                $CHILD_ERROR = 0;
                # Original bash: echo "yes" | cp ../alldriverfiles.txt . 2> /dev/null ;
{
                    my $output_65 = q{};
                    my $output_printed_65;
                    my $pipeline_success_65 = 1;
                    $output_65 .= 'yes' . "\n";
if ( !($output_65 =~ m{\n\z}msx) ) { $output_65 .= "\n"; }
$CHILD_ERROR = 0;

                                        use File::Copy qw(copy);
                    if ( -e '../alldriverfiles.txt' ) {
                    if ( -d q{.} ) {
                    require File::Copy; File::Copy::copy('../alldriverfiles.txt', q{.} . '/' . ('../alldriverfiles.txt' =~ m|([^/]+)$|)[0]);
                    } else {
                    require File::Copy; File::Copy::copy('../alldriverfiles.txt', q{.});
                    }
                    } else {
                    croak "cp: cannot stat '../alldriverfiles.txt': No such file or directory\n";
                    }
                    if ($output_65 ne q{} && !defined $output_printed_65) {
                        print $output_65;
                        if (!($output_65 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_65 ) { $main_exit_code = 1; }
                    }
                # Original bash: cat alldriverfiles.txt \
{
                    my $output_66 = q{};
                    my $output_printed_66;
                    my $pipeline_success_66 = 1;
                                        $output_66 = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'alldriverfiles.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'alldriverfiles.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };

                                        my $cmd_68 = 'egrep';
                    my ($in_67, $out_67);
                    my $pid_67 = open3($in_67, $out_67, '>&STDERR', $cmd_68, "(\\\\", "\\\\|Driver Name)");
                    print {$in_67} $output_66;
                    close $in_67 or croak 'Close failed: $OS_ERROR';
                    $output_66 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_67> };
                    close $out_67 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_67, 0;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'driverfilesversion.txt' ) {
                    print {$fh} $output_66;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'driverfilesversion.txt': $ERRNO";
                    }
                    $output_66 = $output_66;
                    if ($output_66 ne q{} && !defined $output_printed_66) {
                        print $output_66;
                        if (!($output_66 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_66 ) { $main_exit_code = 1; }
                    }
                my $Drivername;
                my @Drivername;
                my %Drivername;
                $Drivername = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_69 = q{};
                    my $output_printed_69;
                    my $pipeline_success_69 = 1;
                    my $grep_result_69_0;
                    my @grep_lines_69_0 = ();
                    my @grep_filenames_69_0 = ();
                    if (-e "driverfilesversion.txt") {
                        open my $fh, '<', "driverfilesversion.txt" or croak "Cannot open file: $ERRNO";
                        while (my $line = <$fh>) {
                            chomp $line;
                            push @grep_lines_69_0, $line;
                            push @grep_filenames_69_0, "driverfilesversion.txt";
                        }
                        close $fh
                            or croak "Close failed: $OS_ERROR";
                    }
                    else { print {*STDERR} "grep: driverfilesversion.txt: No such file or directory\n"; }
                    my @grep_filtered_69_0 = grep { /Driver\ Name:/msx } @grep_lines_69_0;
                    $grep_result_69_0 = join "\n", @grep_filtered_69_0;
                                        if (!($grep_result_69_0 =~ m{\n\z}msx || $grep_result_69_0 eq q{})) {
                                            $grep_result_69_0 .= "\n";
                                        }
                    $CHILD_ERROR = scalar @grep_filtered_69_0 > 0 ? 0 : 1;
                    $output_69 = $grep_result_69_0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_69 = 0; }
                    my @lines = split /\n/msx, $output_69;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /[/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_69 = join "", @result;

                    my @lines = split /\n/msx, $output_69;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /]/msx, $line;
                        push @result, ($fields[0] . "\n");
                    }
                    $output_69 = join "", @result;

                    my @sort_lines_69_3 = split /\n/msx, $output_69;
                    my @sort_sorted_69_3 = sort @sort_lines_69_3;
                    $output_69 = join "\n", @sort_sorted_69_3;
                                        if ($output_69 ne q{} && !($output_69 =~ m{\n\z}msx)) {
                                            $output_69 .= "\n";
                                        }
                    my @uniq_lines_69_4 = split /\n/msx, $output_69;
                    @uniq_lines_69_4 = grep { $_ ne q{} } @uniq_lines_69_4; # Filter out empty lines
                    my %uniq_seen_69_4;
                    my @uniq_result_69_4;
                    foreach my $line (@uniq_lines_69_4) {
                    if (!$uniq_seen_69_4{$line}++) { push @uniq_result_69_4, $line; }
                    }
                    $output_69 = join "\n", @uniq_result_69_4;
                                        if ($output_69 ne q{} && !($output_69 =~ m{\n\z}msx)) {
                                            $output_69 .= "\n";
                                        }
                    use Carp qw(carp croak);
                    if ( open my $fh, '>', 'Drivername' ) {
                        print {$fh} $output_69;
                        close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                        carp "tee: Cannot open 'Drivername': $ERRNO";
                    }
                    $output_69 = $output_69;
                    if ( !$pipeline_success_69 ) { $main_exit_code = 1; }
                    $output_69 =~ s/\n+\z//msx;
                    $output_69;
}; $_pipeline_result; };
                my $DriverPath;
                my @DriverPath;
                my %DriverPath;
                $DriverPath = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_70 = q{};
                    my $output_printed_70;
                    my $pipeline_success_70 = 1;
                    my $grep_result_70_0;
                    my @grep_lines_70_0 = ();
                    my @grep_filenames_70_0 = ();
                    if (-e "driverfilesversion.txt") {
                        open my $fh, '<', "driverfilesversion.txt" or croak "Cannot open file: $ERRNO";
                        while (my $line = <$fh>) {
                            chomp $line;
                            push @grep_lines_70_0, $line;
                            push @grep_filenames_70_0, "driverfilesversion.txt";
                        }
                        close $fh
                            or croak "Close failed: $OS_ERROR";
                    }
                    else { print {*STDERR} "grep: driverfilesversion.txt: No such file or directory\n"; }
                    my @grep_filtered_70_0 = grep { /Driver\ Path:/msx } @grep_lines_70_0;
                    $grep_result_70_0 = join "\n", @grep_filtered_70_0;
                                        if (!($grep_result_70_0 =~ m{\n\z}msx || $grep_result_70_0 eq q{})) {
                                            $grep_result_70_0 .= "\n";
                                        }
                    $CHILD_ERROR = scalar @grep_filtered_70_0 > 0 ? 0 : 1;
                    $output_70 = $grep_result_70_0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_70 = 0; }
                    my @lines = split /\n/msx, $output_70;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /[/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_70 = join "", @result;

                    my @lines = split /\n/msx, $output_70;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /]/msx, $line;
                        push @result, ($fields[0] . "\n");
                    }
                    $output_70 = join "", @result;

                    my @lines = split /\n/msx, $output_70;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /W32X86/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_70 = join "", @result;

                    my @lines = split /\n/msx, $output_70;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /\/msx, $line;
                        push @result, ($fields[2] . "\n");
                    }
                    $output_70 = join "", @result;

                    my @sort_lines_70_5 = split /\n/msx, $output_70;
                    my @sort_sorted_70_5 = sort @sort_lines_70_5;
                    $output_70 = join "\n", @sort_sorted_70_5;
                                        if ($output_70 ne q{} && !($output_70 =~ m{\n\z}msx)) {
                                            $output_70 .= "\n";
                                        }
                    my @uniq_lines_70_6 = split /\n/msx, $output_70;
                    @uniq_lines_70_6 = grep { $_ ne q{} } @uniq_lines_70_6; # Filter out empty lines
                    my %uniq_seen_70_6;
                    my @uniq_result_70_6;
                    foreach my $line (@uniq_lines_70_6) {
                    if (!$uniq_seen_70_6{$line}++) { push @uniq_result_70_6, $line; }
                    }
                    $output_70 = join "\n", @uniq_result_70_6;
                                        if ($output_70 ne q{} && !($output_70 =~ m{\n\z}msx)) {
                                            $output_70 .= "\n";
                                        }
                    if ( !$pipeline_success_70 ) { $main_exit_code = 1; }
                    $output_70 =~ s/\n+\z//msx;
                    $output_70;
}; $_pipeline_result; };
                # Original bash: echo "${DriverPath}" \
{
                    my $output_71 = q{};
                    my $output_printed_71;
                    my $pipeline_success_71 = 1;
                    $output_71 .= ${DriverPath} . "\n";
if ( !($output_71 =~ m{\n\z}msx) ) { $output_71 .= "\n"; }
$CHILD_ERROR = 0;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'DriverPath' ) {
                    print {$fh} $output_71;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'DriverPath': $ERRNO";
                    }
                    $output_71 = $output_71;
                    if ($output_71 ne q{} && !defined $output_printed_71) {
                        print $output_71;
                        if (!($output_71 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_71 ) { $main_exit_code = 1; }
                    }
                my $Datafile;
                my @Datafile;
                my %Datafile;
                $Datafile = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_72 = q{};
                    my $output_printed_72;
                    my $pipeline_success_72 = 1;
                    my $grep_result_72_0;
                    my @grep_lines_72_0 = ();
                    my @grep_filenames_72_0 = ();
                    if (-e "driverfilesversion.txt") {
                        open my $fh, '<', "driverfilesversion.txt" or croak "Cannot open file: $ERRNO";
                        while (my $line = <$fh>) {
                            chomp $line;
                            push @grep_lines_72_0, $line;
                            push @grep_filenames_72_0, "driverfilesversion.txt";
                        }
                        close $fh
                            or croak "Close failed: $OS_ERROR";
                    }
                    else { print {*STDERR} "grep: driverfilesversion.txt: No such file or directory\n"; }
                    my @grep_filtered_72_0 = grep { /Datafile:/msx } @grep_lines_72_0;
                    $grep_result_72_0 = join "\n", @grep_filtered_72_0;
                                        if (!($grep_result_72_0 =~ m{\n\z}msx || $grep_result_72_0 eq q{})) {
                                            $grep_result_72_0 .= "\n";
                                        }
                    $CHILD_ERROR = scalar @grep_filtered_72_0 > 0 ? 0 : 1;
                    $output_72 = $grep_result_72_0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_72 = 0; }
                    my @lines = split /\n/msx, $output_72;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /[/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_72 = join "", @result;

                    my @lines = split /\n/msx, $output_72;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /]/msx, $line;
                        push @result, ($fields[0] . "\n");
                    }
                    $output_72 = join "", @result;

                    my @lines = split /\n/msx, $output_72;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /W32X86/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_72 = join "", @result;

                    my @lines = split /\n/msx, $output_72;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /\/msx, $line;
                        push @result, ($fields[2] . "\n");
                    }
                    $output_72 = join "", @result;

                    my @sort_lines_72_5 = split /\n/msx, $output_72;
                    my @sort_sorted_72_5 = sort @sort_lines_72_5;
                    $output_72 = join "\n", @sort_sorted_72_5;
                                        if ($output_72 ne q{} && !($output_72 =~ m{\n\z}msx)) {
                                            $output_72 .= "\n";
                                        }
                    my @uniq_lines_72_6 = split /\n/msx, $output_72;
                    @uniq_lines_72_6 = grep { $_ ne q{} } @uniq_lines_72_6; # Filter out empty lines
                    my %uniq_seen_72_6;
                    my @uniq_result_72_6;
                    foreach my $line (@uniq_lines_72_6) {
                    if (!$uniq_seen_72_6{$line}++) { push @uniq_result_72_6, $line; }
                    }
                    $output_72 = join "\n", @uniq_result_72_6;
                                        if ($output_72 ne q{} && !($output_72 =~ m{\n\z}msx)) {
                                            $output_72 .= "\n";
                                        }
                    if ( !$pipeline_success_72 ) { $main_exit_code = 1; }
                    $output_72 =~ s/\n+\z//msx;
                    $output_72;
}; $_pipeline_result; };
                # Original bash: echo "${Datafile}" \
{
                    my $output_73 = q{};
                    my $output_printed_73;
                    my $pipeline_success_73 = 1;
                    $output_73 .= ${Datafile} . "\n";
if ( !($output_73 =~ m{\n\z}msx) ) { $output_73 .= "\n"; }
$CHILD_ERROR = 0;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'Datafile' ) {
                    print {$fh} $output_73;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'Datafile': $ERRNO";
                    }
                    $output_73 = $output_73;
                    if ($output_73 ne q{} && !defined $output_printed_73) {
                        print $output_73;
                        if (!($output_73 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_73 ) { $main_exit_code = 1; }
                    }
                my $Configfile;
                my @Configfile;
                my %Configfile;
                $Configfile = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_74 = q{};
                    my $output_printed_74;
                    my $pipeline_success_74 = 1;
                    my $grep_result_74_0;
                    my @grep_lines_74_0 = ();
                    my @grep_filenames_74_0 = ();
                    if (-e "driverfilesversion.txt") {
                        open my $fh, '<', "driverfilesversion.txt" or croak "Cannot open file: $ERRNO";
                        while (my $line = <$fh>) {
                            chomp $line;
                            push @grep_lines_74_0, $line;
                            push @grep_filenames_74_0, "driverfilesversion.txt";
                        }
                        close $fh
                            or croak "Close failed: $OS_ERROR";
                    }
                    else { print {*STDERR} "grep: driverfilesversion.txt: No such file or directory\n"; }
                    my @grep_filtered_74_0 = grep { /Configfile:/msx } @grep_lines_74_0;
                    $grep_result_74_0 = join "\n", @grep_filtered_74_0;
                                        if (!($grep_result_74_0 =~ m{\n\z}msx || $grep_result_74_0 eq q{})) {
                                            $grep_result_74_0 .= "\n";
                                        }
                    $CHILD_ERROR = scalar @grep_filtered_74_0 > 0 ? 0 : 1;
                    $output_74 = $grep_result_74_0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_74 = 0; }
                    my @lines = split /\n/msx, $output_74;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /[/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_74 = join "", @result;

                    my @lines = split /\n/msx, $output_74;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /]/msx, $line;
                        push @result, ($fields[0] . "\n");
                    }
                    $output_74 = join "", @result;

                    my @lines = split /\n/msx, $output_74;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /W32X86/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_74 = join "", @result;

                    my @lines = split /\n/msx, $output_74;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /\/msx, $line;
                        push @result, ($fields[2] . "\n");
                    }
                    $output_74 = join "", @result;

                    my @sort_lines_74_5 = split /\n/msx, $output_74;
                    my @sort_sorted_74_5 = sort @sort_lines_74_5;
                    $output_74 = join "\n", @sort_sorted_74_5;
                                        if ($output_74 ne q{} && !($output_74 =~ m{\n\z}msx)) {
                                            $output_74 .= "\n";
                                        }
                    my @uniq_lines_74_6 = split /\n/msx, $output_74;
                    @uniq_lines_74_6 = grep { $_ ne q{} } @uniq_lines_74_6; # Filter out empty lines
                    my %uniq_seen_74_6;
                    my @uniq_result_74_6;
                    foreach my $line (@uniq_lines_74_6) {
                    if (!$uniq_seen_74_6{$line}++) { push @uniq_result_74_6, $line; }
                    }
                    $output_74 = join "\n", @uniq_result_74_6;
                                        if ($output_74 ne q{} && !($output_74 =~ m{\n\z}msx)) {
                                            $output_74 .= "\n";
                                        }
                    if ( !$pipeline_success_74 ) { $main_exit_code = 1; }
                    $output_74 =~ s/\n+\z//msx;
                    $output_74;
}; $_pipeline_result; };
                # Original bash: echo "${Configfile}" \
{
                    my $output_75 = q{};
                    my $output_printed_75;
                    my $pipeline_success_75 = 1;
                    $output_75 .= ${Configfile} . "\n";
if ( !($output_75 =~ m{\n\z}msx) ) { $output_75 .= "\n"; }
$CHILD_ERROR = 0;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'Configfile' ) {
                    print {$fh} $output_75;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'Configfile': $ERRNO";
                    }
                    $output_75 = $output_75;
                    if ($output_75 ne q{} && !defined $output_printed_75) {
                        print $output_75;
                        if (!($output_75 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_75 ) { $main_exit_code = 1; }
                    }
                my $Helpfile;
                my @Helpfile;
                my %Helpfile;
                $Helpfile = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_76 = q{};
                    my $output_printed_76;
                    my $pipeline_success_76 = 1;
                    my $grep_result_76_0;
                    my @grep_lines_76_0 = ();
                    my @grep_filenames_76_0 = ();
                    if (-e "driverfilesversion.txt") {
                        open my $fh, '<', "driverfilesversion.txt" or croak "Cannot open file: $ERRNO";
                        while (my $line = <$fh>) {
                            chomp $line;
                            push @grep_lines_76_0, $line;
                            push @grep_filenames_76_0, "driverfilesversion.txt";
                        }
                        close $fh
                            or croak "Close failed: $OS_ERROR";
                    }
                    else { print {*STDERR} "grep: driverfilesversion.txt: No such file or directory\n"; }
                    my @grep_filtered_76_0 = grep { /Helpfile:/msx } @grep_lines_76_0;
                    $grep_result_76_0 = join "\n", @grep_filtered_76_0;
                                        if (!($grep_result_76_0 =~ m{\n\z}msx || $grep_result_76_0 eq q{})) {
                                            $grep_result_76_0 .= "\n";
                                        }
                    $CHILD_ERROR = scalar @grep_filtered_76_0 > 0 ? 0 : 1;
                    $output_76 = $grep_result_76_0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_76 = 0; }
                    my @lines = split /\n/msx, $output_76;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /[/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_76 = join "", @result;

                    my @lines = split /\n/msx, $output_76;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /]/msx, $line;
                        push @result, ($fields[0] . "\n");
                    }
                    $output_76 = join "", @result;

                    my @lines = split /\n/msx, $output_76;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /W32X86/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_76 = join "", @result;

                    my @lines = split /\n/msx, $output_76;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /\/msx, $line;
                        push @result, ($fields[2] . "\n");
                    }
                    $output_76 = join "", @result;

                    my @sort_lines_76_5 = split /\n/msx, $output_76;
                    my @sort_sorted_76_5 = sort @sort_lines_76_5;
                    $output_76 = join "\n", @sort_sorted_76_5;
                                        if ($output_76 ne q{} && !($output_76 =~ m{\n\z}msx)) {
                                            $output_76 .= "\n";
                                        }
                    my @uniq_lines_76_6 = split /\n/msx, $output_76;
                    @uniq_lines_76_6 = grep { $_ ne q{} } @uniq_lines_76_6; # Filter out empty lines
                    my %uniq_seen_76_6;
                    my @uniq_result_76_6;
                    foreach my $line (@uniq_lines_76_6) {
                    if (!$uniq_seen_76_6{$line}++) { push @uniq_result_76_6, $line; }
                    }
                    $output_76 = join "\n", @uniq_result_76_6;
                                        if ($output_76 ne q{} && !($output_76 =~ m{\n\z}msx)) {
                                            $output_76 .= "\n";
                                        }
                    if ( !$pipeline_success_76 ) { $main_exit_code = 1; }
                    $output_76 =~ s/\n+\z//msx;
                    $output_76;
}; $_pipeline_result; };
                # Original bash: echo "${Helpfile}" \
{
                    my $output_77 = q{};
                    my $output_printed_77;
                    my $pipeline_success_77 = 1;
                    $output_77 .= ${Helpfile} . "\n";
if ( !($output_77 =~ m{\n\z}msx) ) { $output_77 .= "\n"; }
$CHILD_ERROR = 0;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'Helpfile' ) {
                    print {$fh} $output_77;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'Helpfile': $ERRNO";
                    }
                    $output_77 = $output_77;
                    if ($output_77 ne q{} && !defined $output_printed_77) {
                        print $output_77;
                        if (!($output_77 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_77 ) { $main_exit_code = 1; }
                    }
                my $Dependentfilelist;
                my @Dependentfilelist;
                my %Dependentfilelist;
                $Dependentfilelist = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_78 = q{};
                    my $output_printed_78;
                    my $pipeline_success_78 = 1;
                    my $grep_result_78_0;
                    my @grep_lines_78_0 = ();
                    my @grep_filenames_78_0 = ();
                    if (-e "driverfilesversion.txt") {
                        open my $fh, '<', "driverfilesversion.txt" or croak "Cannot open file: $ERRNO";
                        while (my $line = <$fh>) {
                            chomp $line;
                            push @grep_lines_78_0, $line;
                            push @grep_filenames_78_0, "driverfilesversion.txt";
                        }
                        close $fh
                            or croak "Close failed: $OS_ERROR";
                    }
                    else { print {*STDERR} "grep: driverfilesversion.txt: No such file or directory\n"; }
                    my @grep_filtered_78_0 = grep { /Dependentfiles:/msx } @grep_lines_78_0;
                    $grep_result_78_0 = join "\n", @grep_filtered_78_0;
                                        if (!($grep_result_78_0 =~ m{\n\z}msx || $grep_result_78_0 eq q{})) {
                                            $grep_result_78_0 .= "\n";
                                        }
                    $CHILD_ERROR = scalar @grep_filtered_78_0 > 0 ? 0 : 1;
                    $output_78 = $grep_result_78_0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_78 = 0; }
                    my @lines = split /\n/msx, $output_78;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /[/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_78 = join "", @result;

                    my @lines = split /\n/msx, $output_78;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /]/msx, $line;
                        push @result, ($fields[0] . "\n");
                    }
                    $output_78 = join "", @result;

                    my @lines = split /\n/msx, $output_78;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /W32X86/msx, $line;
                        push @result, ($fields[1] . "\n");
                    }
                    $output_78 = join "", @result;

                    my @lines = split /\n/msx, $output_78;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /\/msx, $line;
                        push @result, ($fields[2] . "\n");
                    }
                    $output_78 = join "", @result;

                    my @sort_lines_78_5 = split /\n/msx, $output_78;
                    my @sort_sorted_78_5 = sort @sort_lines_78_5;
                    $output_78 = join "\n", @sort_sorted_78_5;
                                        if ($output_78 ne q{} && !($output_78 =~ m{\n\z}msx)) {
                                            $output_78 .= "\n";
                                        }
                    my @uniq_lines_78_6 = split /\n/msx, $output_78;
                    @uniq_lines_78_6 = grep { $_ ne q{} } @uniq_lines_78_6; # Filter out empty lines
                    my %uniq_seen_78_6;
                    my @uniq_result_78_6;
                    foreach my $line (@uniq_lines_78_6) {
                    if (!$uniq_seen_78_6{$line}++) { push @uniq_result_78_6, $line; }
                    }
                    $output_78 = join "\n", @uniq_result_78_6;
                                        if ($output_78 ne q{} && !($output_78 =~ m{\n\z}msx)) {
                                            $output_78 .= "\n";
                                        }
                    if ( !$pipeline_success_78 ) { $main_exit_code = 1; }
                    $output_78 =~ s/\n+\z//msx;
                    $output_78;
}; $_pipeline_result; };
                my $Dependentfiles;
                my @Dependentfiles;
                my %Dependentfiles;
                $Dependentfiles = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_79 = q{};
                    my $output_printed_79;
                    my $pipeline_success_79 = 1;
                    $output_79 .= $Dependentfilelist . "\n";
                    if ( !($output_79 =~ m{\n\z}msx) ) { $output_79 .= "\n"; }
                    $CHILD_ERROR = 0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_79 = 0; }
                    my @sed_lines_79 = split /\n/msx, $output_79;
                    my @sed_result_79;
                    foreach my $line (@sed_lines_79) {
                    chomp $line;
                    push @sed_result_79, $line;
                    }
                    $output_79 = join "\n", @sed_result_79;

                    if ( !$pipeline_success_79 ) { $main_exit_code = 1; }
                    $output_79 =~ s/\n+\z//msx;
                    $output_79;
}; $_pipeline_result; };
                # Original bash: echo "${Dependentfiles}" \
{
                    my $output_80 = q{};
                    my $output_printed_80;
                    my $pipeline_success_80 = 1;
                    $output_80 .= ${Dependentfiles} . "\n";
if ( !($output_80 =~ m{\n\z}msx) ) { $output_80 .= "\n"; }
$CHILD_ERROR = 0;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'Dependentfiles' ) {
                    print {$fh} $output_80;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'Dependentfiles': $ERRNO";
                    }
                    $output_80 = $output_80;
                    if ($output_80 ne q{} && !defined $output_printed_80) {
                        print $output_80;
                        if (!($output_80 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_80 ) { $main_exit_code = 1; }
                    }
                my $AllFiles;
                my @AllFiles;
                my %AllFiles;
                $AllFiles = ($Dependentfilelist);
                # Original bash: echo "${AllFiles}" \
{
                    my $output_81 = q{};
                    my $output_printed_81;
                    my $pipeline_success_81 = 1;
                    $output_81 .= ${AllFiles} . "\n";
if ( !($output_81 =~ m{\n\z}msx) ) { $output_81 .= "\n"; }
$CHILD_ERROR = 0;

                                        my @sort_lines_81_1 = split /\n/msx, $output_81;
                    my @sort_sorted_81_1 = sort @sort_lines_81_1;
                    my $output_81_1 = join "\n", @sort_sorted_81_1;
                    if ($output_81_1 ne q{} && !($output_81_1 =~ m{\n\z}msx)) {
                    $output_81_1 .= "\n";
                    }
                    $output_81 = $output_81_1;
                    $output_81 = $output_81_1;

                                        my @uniq_lines_81_2 = split /\n/msx, $output_81;
                    @uniq_lines_81_2 = grep { $_ ne q{} } @uniq_lines_81_2; # Filter out empty lines
                    my %uniq_seen_81_2;
                    my @uniq_result_81_2;
                    foreach my $line (@uniq_lines_81_2) {
                    if (!$uniq_seen_81_2{$line}++) { push @uniq_result_81_2, $line; }
                    }
                    my $output_81_2 = join "\n", @uniq_result_81_2;
                    if ($output_81_2 ne q{} && !($output_81_2 =~ m{\n\z}msx)) {
                    $output_81_2 .= "\n";
                    }
                    $output_81 = $output_81_2;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'AllFiles' ) {
                    print {$fh} $output_81;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'AllFiles': $ERRNO";
                    }
                    $output_81 = $output_81;
                    if ($output_81 ne q{} && !defined $output_printed_81) {
                        print $output_81;
                        if (!($output_81 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_81 ) { $main_exit_code = 1; }
                    }
                # Original bash: #!/bin/bash
{
                    my $output_82 = q{};
                    my $output_printed_82;
                    my $pipeline_success_82 = 1;
                                        $output_82 = q{};
                    my @output_82_items = (do { my $cat_chunk = q{}; if ( open my $fh, '<', 'AllFiles' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'AllFiles' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
                    for my $i (@output_82_items) {
                    $output_82 .= $i. "\n";
                    }

                                        my @sort_lines_82_1 = split /\n/msx, $output_82;
                    my @sort_sorted_82_1 = sort @sort_lines_82_1;
                    my $output_82_1 = join "\n", @sort_sorted_82_1;
                    if ($output_82_1 ne q{} && !($output_82_1 =~ m{\n\z}msx)) {
                    $output_82_1 .= "\n";
                    }
                    $output_82 = $output_82_1;
                    $output_82 = $output_82_1;

                                        my @uniq_lines_82_2 = split /\n/msx, $output_82;
                    @uniq_lines_82_2 = grep { $_ ne q{} } @uniq_lines_82_2; # Filter out empty lines
                    my %uniq_seen_82_2;
                    my @uniq_result_82_2;
                    foreach my $line (@uniq_lines_82_2) {
                    if (!$uniq_seen_82_2{$line}++) { push @uniq_result_82_2, $line; }
                    }
                    my $output_82_2 = join "\n", @uniq_result_82_2;
                    if ($output_82_2 ne q{} && !($output_82_2 =~ m{\n\z}msx)) {
                    $output_82_2 .= "\n";
                    }
                    $output_82 = $output_82_2;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>', 'AllFilesIAskFor' ) {
                    print {$fh} $output_82;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open 'AllFilesIAskFor': $ERRNO";
                    }
                    $output_82 = $output_82;
                    if ($output_82 ne q{} && !defined $output_printed_82) {
                        print $output_82;
                        if (!($output_82 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_82 ) { $main_exit_code = 1; }
                    }
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
                    chdir(${CWD2});
                    $CHILD_ERROR = 0;
                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
            }
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                chdir(${CWD1});
                $CHILD_ERROR = 0;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
    }
    return;
}

sub helpwithfetchallW32X86driverfiles {
    do {
    my $__echo_line = " \n\\\n################################################################################\n#\n#\t\t    About fetchallW32X86driverfiles()...\n#           \t    ------------------------------------\n#\n# PRECONDITIONS: 1) This function expects to have the \\'$nthost\\' variable set\n#\t\t    to the according value.\n#\t\t 2) This function expects to find files \"AllFiles\",\n#\t\t    \"AllFilesIAskFor\", and \"AllFilesIGot\" in the directories\n#\t\t    \\'${nthost}/<architecture>/<drivername>/<version>/\\'.\n#\n# WHAT IT DOES: These functions use \"smbclient\" to connect to the NT print\n#\t\tserver \"$nthost\" and download the printer driver files from\n#\t\tthere. To achieve that in an orderly fashion, the previously\n#\t\tcreated subdirectories (named like the drivers to fetch) are\n#\t\tvisited in turn and the related files are downloaded for each\n#\t\tdriver/directory.\n#\n# IF IT DOESN'T WORK: The function \"fetchenumdrivers3listfromNThost\" and\n#\t\t      consecutive ones may not have been run successfully. This\n#\t\t      is a precondition for the current function.\n#\n# HINT: The current values: 'nthost'=\"$nthost\n#\t\t\t    'ntprinteradmin'=$ntprinteradmin\"\n#\t\t\t    'ntadminpasswd'=<not shown here, check yourself!>\n#\n################################################################################";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}

sub fetchallW32X86driverfiles {
if (!(    stringinstring('help', "@ARGV"))) {
        helpwithfetchallW32X86driverfiles();
}
    else {
        print " \n";
        print " \n";
        print "--> Running now function fetchallW32X86driverfiles()....\n";
        print "========================================================\n";
        my $CURRENTWD;
        my @CURRENTWD;
        my %CURRENTWD;
        $CURRENTWD = $PWD;
        my $i;
        for my $i ($nthost, '/W32X86/*/*/') {
            chdir(${i});
            $CHILD_ERROR = 0;
            my $driverversion;
            my @driverversion;
            my %driverversion;
            $driverversion = (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename((do { my $_chomp_temp = ("$ENV{PWD}"); chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', 'driverversion'
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename((do { my $_chomp_temp = ("$ENV{PWD}"); chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            my $AllFiles;
            my @AllFiles;
            my %AllFiles;
            $AllFiles = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'AllFiles' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'AllFiles' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            if (!((-d 'TheFiles'))) {
                                use File::Path qw(make_path);
                my $err;
                if ( mkdir 'TheFiles' ) {
                    }
                else {
                    croak "mkdir: cannot create directory " . 'TheFiles' . ": File exists\n";
                }
            }
            chdir('TheFiles');
            $CHILD_ERROR = 0;
            print " \n";
            print "====================================================\n";
            do {
    my $__echo_line = "Downloading files now to " . ($ENV{PWD} // q{}) . "....";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print "====================================================\n";
            print " \n";
            $main_exit_code = system('smbclient', '-U', ($ENV{ntprinteradmin} // q{}) . "%" . ($ENV{ntadminpasswd} // q{}), '-d', q{2}, '//', $nthost, "/print\\$", '-c', "cd W32X86${driverversion};prompt;mget " . ${AllFiles}) >> 8;
            # Original bash: ls -1 \
{
                my $output_84 = q{};
                my $output_printed_84;
                my $pipeline_success_84 = 1;
                                $output_84 = do {
                my @ls_files_85 = ();
                if ( -f q{.} ) {
                push @ls_files_85, q{.};
                }
                elsif ( -d q{.} ) {
                if ( opendir my $dh, q{.} ) {
                while ( my $file = readdir $dh ) {
                next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                push @ls_files_85, $file;
                }
                closedir $dh;
                @ls_files_85 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_files_85;
                }
                }
                (@ls_files_85 ? join("\n", @ls_files_85) . "\n" : q{});
                };
                ;

                                my @sort_lines_84_1 = split /\n/msx, $output_84;
                my @sort_sorted_84_1 = sort @sort_lines_84_1;
                my $output_84_1 = join "\n", @sort_sorted_84_1;
                if ($output_84_1 ne q{} && !($output_84_1 =~ m{\n\z}msx)) {
                $output_84_1 .= "\n";
                }
                $output_84 = $output_84_1;
                $output_84 = $output_84_1;

                                my @uniq_lines_84_2 = split /\n/msx, $output_84;
                @uniq_lines_84_2 = grep { $_ ne q{} } @uniq_lines_84_2; # Filter out empty lines
                my %uniq_seen_84_2;
                my @uniq_result_84_2;
                foreach my $line (@uniq_lines_84_2) {
                if (!$uniq_seen_84_2{$line}++) { push @uniq_result_84_2, $line; }
                }
                my $output_84_2 = join "\n", @uniq_result_84_2;
                if ($output_84_2 ne q{} && !($output_84_2 =~ m{\n\z}msx)) {
                $output_84_2 .= "\n";
                }
                $output_84 = $output_84_2;

                                use Carp qw(carp croak);
                if ( open my $fh, '>', '../AllFilesIGot' ) {
                print {$fh} $output_84;
                close $fh or croak "Close failed: $ERRNO";
                }
                else {
                carp "tee: Cannot open '../AllFilesIGot': $ERRNO";
                }
                $output_84 = $output_84;
                if ($output_84 ne q{} && !defined $output_printed_84) {
                    print $output_84;
                    if (!($output_84 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_84 ) { $main_exit_code = 1; }
                }
            chdir($CURRENTWD);
            $CHILD_ERROR = 0;
        }
    }
    return;
}

sub helpwithuploadallW32X86drivers {
    # Original bash: echo -e " \n\
{
        my $output_87 = q{};
        my $output_printed_87;
        my $pipeline_success_87 = 1;
        $output_87 .= " \n\\\n################################################################################\n#\n#\t\t    About uploadallW32X86drivers()...\n#           \t    ---------------------------------\n#\n# PRECONDITIONS: 1) This function expects to have the '$nthost',\n#\t\t    '$ntprinteradmin' and '$ntadminpasswd' variables set to\n#\t\t    according values.\n#\t\t 2) This function expects to find the files \"AllFiles\",\n#\t\t    \"AllFilesIGot\" and \"AllFilesIAskFor\" in the\n#\t\t    \"${nthost}/W32X86<drivername>/<driverversion>/TheFiles\"\n#\t\t    subdirectory.\n#\n# WHAT IT DOES: This function uses " . q{ } . "smbclient" . q{ } . " to connect to the new Samba print\n#\t\tserver \t" . q{ } . "\\$nthost" . q{ } . " and upload the printer driver files into the\n#\t\t\"[print$]\" share there. To achieve that in orderly fashion,\n#\t\tthe previously created subdirectories (named like the drivers\n#\t\tfetched previously from $smbhost) are visited in turn and the\n#\t\trelated files are uploaded for each driver/directory. For this\n#\t\tto really succeed, the files \"AllFilesIGot\" and \"AllFilesIAskFor\"\n#\t\tare compared with the help of the \"sdiff\" utility to decide\n#\t\thow to re-name the mis-matching filenams, so that the used\n#\t\tdriver upload command's spelling convention is met....\n#\n# IF IT DOESN'T WORK: The function " . q{ } . "fetchenumdrivers3listfromNThost" . q{ } . " and\n#\t\t      consecutive ones may not have been run successfully. This\n#\t\t      is a precondition for the current function.\n#\n# HINT: The current values: 'nthost'=\"$nthost\n#\t\t\t    'ntprinteradmin'=$ntprinteradmin\"\n#\t\t\t    'ntadminpasswd'=<not shown here, check yourself!>\n#\n################################################################################\n#           ............PRESS \"q\" TO QUIT............" . "\n";
if ( !($output_87 =~ m{\n\z}msx) ) { $output_87 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_89 = 'less';
        my ($in_88, $out_88);
        my $pid_88 = open3($in_88, $out_88, '>&STDERR', $cmd_89, );
        print {$in_88} $output_87;
        close $in_88 or croak 'Close failed: $OS_ERROR';
        $output_87 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_88> };
        close $out_88 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_88, 0;
        if ($output_87 ne q{} && !defined $output_printed_87) {
            print $output_87;
            if (!($output_87 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_87 ) { $main_exit_code = 1; }
        }
    return;
}

sub uploadallW32X86drivers {
if (!(    stringinstring('help', "@ARGV"))) {
        helpwithuploadallW32X86drivers();
}
    else {
        print " \n";
        print " \n";
        print "--> Running now function uploadallW32X86drivers()....\n";
        print "=====================================================\n";
        my $i;
        for my $i ($nthost, '/W32X86/*/*/') {
            my $CURRENTWD;
            my @CURRENTWD;
            my %CURRENTWD;
            $CURRENTWD = $PWD;
            chdir(${i});
            $CHILD_ERROR = 0;
            my $driverversion;
            my @driverversion;
            my %driverversion;
            $driverversion = (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename((do { my $_chomp_temp = ("$ENV{PWD}"); chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', 'driverversion'
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename((do { my $_chomp_temp = ("$ENV{PWD}"); chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            chdir('TheFiles');
            $CHILD_ERROR = 0;
            print " \n";
            print "====================================================\n";
            do {
    my $__echo_line = "Uploading driverfiles now from " . ($ENV{PWD} // q{}) . "....";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print "====================================================\n";
            print " \n";
# set -x not implemented
            $main_exit_code = system('smbclient', '-U', ($ENV{smbprinteradmin} // q{}) . "%" . ($ENV{smbadminpasswd} // q{}), '-d', q{2}, '//', $smbhost, "/print\\$", '-c', "mkdir W32X86;cd W32X86;prompt;mput " . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', '../AllFilesIGot' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '../AllFilesIGot' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; })) >> 8;
            chdir('..');
            $CHILD_ERROR = 0;
            my $Drivername;
            my @Drivername;
            my %Drivername;
            $Drivername = (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Drivername' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Drivername' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; });
# set -x not implemented
            if (x"$( cat Dependentfiles)" =~ /^x""$/msx) {
                                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', 'Dependentfiles'
      or die "Cannot open file: $OS_ERROR\n";
                    print 'NULL' . "\n";
                    $CHILD_ERROR = 0;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            # Original bash: sdiff -s AllFilesIGot AllFilesIAskFor \
{
                my $output_90 = q{};
                my $output_printed_90;
                my $pipeline_success_90 = 1;
                                my ($in_91, $out_91);
                my $pid_91 = open3($in_91, $out_91, '>&STDERR', 'sdiff', '-s', 'AllFilesIGot', 'AllFilesIAskFor');
                close $in_91 or croak 'Close failed: $OS_ERROR';
                $output_90 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_91> };
                close $out_91 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_91, 0;

                                use Carp qw(carp croak);
                if ( open my $fh, '>', 'sdiff-of-Requested-and-Received.txt' ) {
                print {$fh} $output_90;
                close $fh or croak "Close failed: $ERRNO";
                }
                else {
                carp "tee: Cannot open 'sdiff-of-Requested-and-Received.txt': $ERRNO";
                }
                $output_90 = $output_90;
                if ($output_90 ne q{} && !defined $output_printed_90) {
                    print $output_90;
                    if (!($output_90 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_90 ) { $main_exit_code = 1; }
                }
            if (do {
if (!(((-s 'sdiff-of-Requested-and-Received.txt') > 0))) {
    if ( -e "sdiff-of-Requested-and-Received.txt" ) {
        if ( -d "sdiff-of-Requested-and-Received.txt" ) {
            carp "rm: carping: ", "sdiff-of-Requested-and-Received.txt",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "sdiff-of-Requested-and-Received.txt" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "sdiff-of-Requested-and-Received.txt",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}
                $CHILD_ERROR == 0
            }) {
                                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '../sdiff-of-Requested-and-Received.txt'
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', 'sdiff-of-Requested-and-Received.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'sdiff-of-Requested-and-Received.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
            }
            # Original bash: cat sdiff-of-Requested-and-Received.txt \
{
                my $output_93 = q{};
                my $output_printed_93;
                my $pipeline_success_93 = 1;
                                $output_93 = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'sdiff-of-Requested-and-Received.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'sdiff-of-Requested-and-Received.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };

                                my @sed_lines_93 = split /\n/msx, $output_93;
                my @sed_result_93;
                foreach my $line (@sed_lines_93) {
                chomp $line;
                push @sed_result_93, $line;
                }
                $output_93 = join "\n", @sed_result_93;

                                my @sed_lines_93 = split /\n/msx, $output_93;
                my @sed_result_93;
                foreach my $line (@sed_lines_93) {
                chomp $line;
                push @sed_result_93, $line;
                }
                $output_93 = join "\n", @sed_result_93;

                                use Carp qw(carp croak);
                if ( open my $fh, '>', 'rename-Received-to-Requested-case.txt' ) {
                print {$fh} $output_93;
                close $fh or croak "Close failed: $ERRNO";
                }
                else {
                carp "tee: Cannot open 'rename-Received-to-Requested-case.txt': $ERRNO";
                }
                $output_93 = $output_93;
                if ($output_93 ne q{} && !defined $output_printed_93) {
                    print $output_93;
                    if (!($output_93 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_93 ) { $main_exit_code = 1; }
                }
            $main_exit_code = system('sh', '-x', 'rename-Received-to-Requested-case.txt') >> 8;
            my $err;
            my $force = 0;
            if ( -e 'rename-Received-to-Requested-case.txt' ) {
                my $dest = 'done';
                if ( -e $dest && -d $dest ) {
                    my $source_name = 'rename-Received-to-Requested-case.txt';
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
                if ( File::Copy::move( 'rename-Received-to-Requested-case.txt', $dest ) ) {
                } else {
                    croak
  "mv: cannot move 'rename-Received-to-Requested-case.txt' to $dest: $ERRNO\n";
                }
            } else {
                croak "mv: 'rename-Received-to-Requested-case.txt': No such file or directory\n";
            }
            if ( -e 'rename-Received-to-Requested-case.' ) {
                my $dest = 'done';
                if ( -e $dest && -d $dest ) {
                    my $source_name = 'rename-Received-to-Requested-case.';
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
                if ( File::Copy::move( 'rename-Received-to-Requested-case.', $dest ) ) {
                } else {
                    croak
  "mv: cannot move 'rename-Received-to-Requested-case.' to $dest: $ERRNO\n";
                }
            } else {
                croak "mv: 'rename-Received-to-Requested-case.': No such file or directory\n";
            }
            print " ################ B E G I N  DEBUGGING STATEMENT ############\n";
            do {
    my $__echo_line = "rpcclient -U\"" . ($ENV{smbprinteradmin} // q{}) . "%" . ($ENV{smbadminpasswd} // q{}) . "\" -d 2 \
	-c \'adddriver \"Windows NT x86\" \"" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Drivername' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Drivername' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'DriverPath' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'DriverPath' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Datafile' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Datafile' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Configfile' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Configfile' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Helpfile' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Helpfile' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":NULL:RAW:" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Dependentfiles' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Dependentfiles' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . "\" " . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'driverversion' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'driverversion' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . q{ } . $smbhost . q{ } . "\\'";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print " ################ E N D  DEBUGGING STATEMENT ################\n";
            $main_exit_code = system('rpcclient', '-U', ($ENV{smbprinteradmin} // q{}) . "%" . ($ENV{smbadminpasswd} // q{}), '-d', q{2}, '-c', "adddriver \"Windows NT x86\" \"" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Drivername' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Drivername' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'DriverPath' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'DriverPath' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Datafile' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Datafile' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Configfile' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Configfile' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Helpfile' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Helpfile' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":NULL:RAW:" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Dependentfiles' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Dependentfiles' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . "\" " . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'driverversion' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'driverversion' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }), $smbhost) >> 8;
# set +x not implemented
            chdir($CURRENTWD);
            $CHILD_ERROR = 0;
        }
# set +x not implemented
    }
    return;
}

sub helpwithfetchallWIN40driverfiles {
    # Original bash: echo -e " \n\
{
        my $output_95 = q{};
        my $output_printed_95;
        my $pipeline_success_95 = 1;
        $output_95 .= " \n\\\n################################################################################\n#\n#\t\t    About fetchallWIN40driverfiles()...\n#           \t    -----------------------------------\n#\n# PRECONDITIONS: 1) This function expects to have the $nthost variable set to\n#\t\t    the according value.\n#\t\t 2) This function expects to find the \"AllFiles\" file in\n#\t\t    \"${nthost}/WIN40<drivername>/<driverversion>/TheFiles\".\n#\n# WHAT IT DOES: These functions use " . q{ } . "smbclient" . q{ } . " to connect to the NT print server\n#\t\t" . q{ } . "\\$nthost" . q{ } . " and download the printer driver files from there. To\n#\t\tachieve that in an orderly fashion, the previously created\n#\t\tsubdirectories (named like the drivers to fetch) are visited in\n#\t\tturn and the related files are downloaded for each\n#\t\tdriver/directory.\n#\n# IF IT DOESN'T WORK: The function " . q{ } . "fetchenumdrivers3listfromNThost" . q{ } . " and\n#\t\t      consecutive ones may not have been run successfully. This\n#\t\t      is a precondition for the current function.\n#\n# HINT: The current values: 'nthost'=\"$nthost\n#\t\t\t    'ntprinteradmin'=$ntprinteradmin\"\n#\t\t\t    'ntadminpasswd'=<not shown here, check yourself!>\n#\n################################################################################\n#           ............PRESS \"q\" TO QUIT............" . "\n";
if ( !($output_95 =~ m{\n\z}msx) ) { $output_95 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_97 = 'less';
        my ($in_96, $out_96);
        my $pid_96 = open3($in_96, $out_96, '>&STDERR', $cmd_97, );
        print {$in_96} $output_95;
        close $in_96 or croak 'Close failed: $OS_ERROR';
        $output_95 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_96> };
        close $out_96 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_96, 0;
        if ($output_95 ne q{} && !defined $output_printed_95) {
            print $output_95;
            if (!($output_95 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_95 ) { $main_exit_code = 1; }
        }
    return;
}

sub fetchallWIN40driverfiles {
if (!(    stringinstring('help', "@ARGV"))) {
        helpwithfetchallWIN40driverfiles();
}
    else {
        print " \n";
        print " \n";
        print "--> Running now function fetchallWIN40driverfiles()....\n";
        print "=======================================================\n";
        my $CURRENTWD;
        my @CURRENTWD;
        my %CURRENTWD;
        $CURRENTWD = $PWD;
        my $i;
        for my $i ($nthost, '/WIN40/*/*/') {
            chdir(${i});
            $CHILD_ERROR = 0;
            my $driverversion;
            my @driverversion;
            my %driverversion;
            $driverversion = (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename((do { my $_chomp_temp = ("$ENV{PWD}"); chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', 'driverversion'
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename((do { my $_chomp_temp = ("$ENV{PWD}"); chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            my $AllFiles;
            my @AllFiles;
            my %AllFiles;
            $AllFiles = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'AllFiles' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'AllFiles' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            if (!((-d 'TheFiles'))) {
                                use File::Path qw(make_path);
                my $err;
                if ( mkdir 'TheFiles' ) {
                    }
                else {
                    croak "mkdir: cannot create directory " . 'TheFiles' . ": File exists\n";
                }
            }
            chdir('TheFiles');
            $CHILD_ERROR = 0;
            print " \n";
            print "====================================================\n";
            do {
    my $__echo_line = "Downloading files now to " . ($ENV{PWD} // q{}) . "....";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print "====================================================\n";
            print " \n";
            $main_exit_code = system('smbclient', '-U', ($ENV{ntprinteradmin} // q{}) . "%" . ($ENV{ntadminpasswd} // q{}), '-d', q{2}, '//', $nthost, "/print\\$", '-c', "cd WIN40${driverversion};prompt;mget " . ${AllFiles}) >> 8;
            # Original bash: ls -1 \
{
                my $output_99 = q{};
                my $output_printed_99;
                my $pipeline_success_99 = 1;
                                $output_99 = do {
                my @ls_files_100 = ();
                if ( -f q{.} ) {
                push @ls_files_100, q{.};
                }
                elsif ( -d q{.} ) {
                if ( opendir my $dh, q{.} ) {
                while ( my $file = readdir $dh ) {
                next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                push @ls_files_100, $file;
                }
                closedir $dh;
                @ls_files_100 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_files_100;
                }
                }
                (@ls_files_100 ? join("\n", @ls_files_100) . "\n" : q{});
                };
                ;

                                my @sort_lines_99_1 = split /\n/msx, $output_99;
                my @sort_sorted_99_1 = sort @sort_lines_99_1;
                my $output_99_1 = join "\n", @sort_sorted_99_1;
                if ($output_99_1 ne q{} && !($output_99_1 =~ m{\n\z}msx)) {
                $output_99_1 .= "\n";
                }
                $output_99 = $output_99_1;
                $output_99 = $output_99_1;

                                my @uniq_lines_99_2 = split /\n/msx, $output_99;
                @uniq_lines_99_2 = grep { $_ ne q{} } @uniq_lines_99_2; # Filter out empty lines
                my %uniq_seen_99_2;
                my @uniq_result_99_2;
                foreach my $line (@uniq_lines_99_2) {
                if (!$uniq_seen_99_2{$line}++) { push @uniq_result_99_2, $line; }
                }
                my $output_99_2 = join "\n", @uniq_result_99_2;
                if ($output_99_2 ne q{} && !($output_99_2 =~ m{\n\z}msx)) {
                $output_99_2 .= "\n";
                }
                $output_99 = $output_99_2;

                                use Carp qw(carp croak);
                if ( open my $fh, '>', '../AllFilesIGot' ) {
                print {$fh} $output_99;
                close $fh or croak "Close failed: $ERRNO";
                }
                else {
                carp "tee: Cannot open '../AllFilesIGot': $ERRNO";
                }
                $output_99 = $output_99;
                if ($output_99 ne q{} && !defined $output_printed_99) {
                    print $output_99;
                    if (!($output_99 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_99 ) { $main_exit_code = 1; }
                }
            chdir($CURRENTWD);
            $CHILD_ERROR = 0;
        }
    }
    return;
}

sub helpwithuploadallWIN40drivers {
    # Original bash: echo -e " \n\
{
        my $output_102 = q{};
        my $output_printed_102;
        my $pipeline_success_102 = 1;
        $output_102 .= " \n\\\n################################################################################\n#\n#\t\t    About uploadallWIN40drivers()...\n#           \t    --------------------------------\n#\n# PRECONDITIONS: 1) This function expects to have '$smbhost', '$smbprinteradmin'\n#\t\t    and '$smbadminpasswd' variables set to according values.\n#\t\t 2) This function expects to find \"AllFiles\", \"AllFilesIGot\"\n#\t\t    and \"AllFilesIAskFor\" in the subdirectory\n#\t\t    \"${nthost}/WINI40/<drivername>/<driverversion>/TheFiles\".\n#\n# WHAT IT DOES: These function uses \"smbclient\" to connect to the new Samba\n#\t\tprint server " . q{ } . "\\$nthost" . q{ } . " and upload the printer driver files into\n#\t\tthe \"[print$]\" share there.\n#\t\tTo achieve that in an orderly fashion, the previously created\n#\t\tsubdirectories (named like the drivers fetched previously from\n#\t\t$smbhost) are visited in turn and the related files are\n#\t\tuploaded for each driver/directory.\n#\t\tFor this to really succeed, \"AllFilesIGot\" and \"AllFilesIAskFor\"\n#\t\tare compared with the help of the \"sdiff\" utility to decide\n#\t\thow to re-name the mis-matching filenams, so that the used\n#\t\tdriver upload command's spelling convention is met....\n#\n# IF IT DOESN'T WORK: The function \"fetchenumdrivers3listfromNThost\" and\n#\t\t      consecutive ones may not have been run successfully. This\n#\t\t      is a precondition for the current function.\n#\n# HINT: The current values: 'nthost'=\"$nthost\n#\t\t\t    'ntprinteradmin'=$ntprinteradmin\"\n#\t\t\t    'ntadminpasswd'=<not shown here, check yourself!>\n#\n################################################################################\n#           ............PRESS \"q\" TO QUIT............" . "\n";
if ( !($output_102 =~ m{\n\z}msx) ) { $output_102 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_104 = 'less';
        my ($in_103, $out_103);
        my $pid_103 = open3($in_103, $out_103, '>&STDERR', $cmd_104, );
        print {$in_103} $output_102;
        close $in_103 or croak 'Close failed: $OS_ERROR';
        $output_102 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_103> };
        close $out_103 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_103, 0;
        if ($output_102 ne q{} && !defined $output_printed_102) {
            print $output_102;
            if (!($output_102 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_102 ) { $main_exit_code = 1; }
        }
    return;
}

sub uploadallWIN40drivers {
if (!(    stringinstring('help', "@ARGV"))) {
        helpwithuploadallWIN40drivers();
}
    else {
        print " \n";
        print " \n";
        print "--> Running now function uploadallWIN40drivers()....\n";
        print "====================================================\n";
        my $i;
        for my $i ($nthost, '/WIN40/*/*/') {
            my $CURRENTWD;
            my @CURRENTWD;
            my %CURRENTWD;
            $CURRENTWD = $PWD;
            chdir(${i});
            $CHILD_ERROR = 0;
            my $driverversion;
            my @driverversion;
            my %driverversion;
            $driverversion = (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename((do { my $_chomp_temp = ("$ENV{PWD}"); chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', 'driverversion'
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename((do { my $_chomp_temp = ("$ENV{PWD}"); chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            chdir('TheFiles');
            $CHILD_ERROR = 0;
            print " \n";
            print "====================================================\n";
            do {
    my $__echo_line = "Uploading driverfiles now from " . ($ENV{PWD} // q{}) . "....";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print "====================================================\n";
            print " \n";
# set -x not implemented
            $main_exit_code = system('smbclient', '-U', ($ENV{smbprinteradmin} // q{}) . "%" . ($ENV{smbadminpasswd} // q{}), '-d', q{2}, '//', $smbhost, "/print\\$", '-c', "mkdir WIN40;cd WIN40;prompt;mput " . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', '../AllFilesIGot' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '../AllFilesIGot' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; })) >> 8;
            chdir('..');
            $CHILD_ERROR = 0;
            my $Drivername;
            my @Drivername;
            my %Drivername;
            $Drivername = (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Drivername' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Drivername' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; });
# set -x not implemented
            if (x"$( cat Dependentfiles)" =~ /^x""$/msx) {
                                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', 'Dependentfiles'
      or die "Cannot open file: $OS_ERROR\n";
                    print 'NULL' . "\n";
                    $CHILD_ERROR = 0;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            # Original bash: sdiff -s AllFilesIGot AllFilesIAskFor \
{
                my $output_105 = q{};
                my $output_printed_105;
                my $pipeline_success_105 = 1;
                                my ($in_106, $out_106);
                my $pid_106 = open3($in_106, $out_106, '>&STDERR', 'sdiff', '-s', 'AllFilesIGot', 'AllFilesIAskFor');
                close $in_106 or croak 'Close failed: $OS_ERROR';
                $output_105 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_106> };
                close $out_106 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_106, 0;

                                use Carp qw(carp croak);
                if ( open my $fh, '>', 'sdiff-of-Requested-and-Received.txt' ) {
                print {$fh} $output_105;
                close $fh or croak "Close failed: $ERRNO";
                }
                else {
                carp "tee: Cannot open 'sdiff-of-Requested-and-Received.txt': $ERRNO";
                }
                $output_105 = $output_105;
                if ($output_105 ne q{} && !defined $output_printed_105) {
                    print $output_105;
                    if (!($output_105 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_105 ) { $main_exit_code = 1; }
                }
            if (do {
if (!(((-s 'sdiff-of-Requested-and-Received.txt') > 0))) {
    if ( -e "sdiff-of-Requested-and-Received.txt" ) {
        if ( -d "sdiff-of-Requested-and-Received.txt" ) {
            carp "rm: carping: ", "sdiff-of-Requested-and-Received.txt",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "sdiff-of-Requested-and-Received.txt" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "sdiff-of-Requested-and-Received.txt",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}
                $CHILD_ERROR == 0
            }) {
                                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '../sdiff-of-Requested-and-Received.txt'
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', 'sdiff-of-Requested-and-Received.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'sdiff-of-Requested-and-Received.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
            }
            # Original bash: cat sdiff-of-Requested-and-Received.txt \
{
                my $output_108 = q{};
                my $output_printed_108;
                my $pipeline_success_108 = 1;
                                $output_108 = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'sdiff-of-Requested-and-Received.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'sdiff-of-Requested-and-Received.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };

                                my @sed_lines_108 = split /\n/msx, $output_108;
                my @sed_result_108;
                foreach my $line (@sed_lines_108) {
                chomp $line;
                push @sed_result_108, $line;
                }
                $output_108 = join "\n", @sed_result_108;

                                my @sed_lines_108 = split /\n/msx, $output_108;
                my @sed_result_108;
                foreach my $line (@sed_lines_108) {
                chomp $line;
                push @sed_result_108, $line;
                }
                $output_108 = join "\n", @sed_result_108;

                                use Carp qw(carp croak);
                if ( open my $fh, '>', 'rename-Received-to-Requested-case.txt' ) {
                print {$fh} $output_108;
                close $fh or croak "Close failed: $ERRNO";
                }
                else {
                carp "tee: Cannot open 'rename-Received-to-Requested-case.txt': $ERRNO";
                }
                $output_108 = $output_108;
                if ($output_108 ne q{} && !defined $output_printed_108) {
                    print $output_108;
                    if (!($output_108 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_108 ) { $main_exit_code = 1; }
                }
            $main_exit_code = system('sh', '-x', 'rename-Received-to-Requested-case.txt') >> 8;
            my $err;
            my $force = 0;
            if ( -e 'rename-Received-to-Requested-case.txt' ) {
                my $dest = 'done';
                if ( -e $dest && -d $dest ) {
                    my $source_name = 'rename-Received-to-Requested-case.txt';
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
                if ( File::Copy::move( 'rename-Received-to-Requested-case.txt', $dest ) ) {
                } else {
                    croak
  "mv: cannot move 'rename-Received-to-Requested-case.txt' to $dest: $ERRNO\n";
                }
            } else {
                croak "mv: 'rename-Received-to-Requested-case.txt': No such file or directory\n";
            }
            if ( -e 'rename-Received-to-Requested-case.' ) {
                my $dest = 'done';
                if ( -e $dest && -d $dest ) {
                    my $source_name = 'rename-Received-to-Requested-case.';
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
                if ( File::Copy::move( 'rename-Received-to-Requested-case.', $dest ) ) {
                } else {
                    croak
  "mv: cannot move 'rename-Received-to-Requested-case.' to $dest: $ERRNO\n";
                }
            } else {
                croak "mv: 'rename-Received-to-Requested-case.': No such file or directory\n";
            }
            print " ################ DEBUGGING STATEMENT \n";
            do {
    my $__echo_line = "rpcclient -U\"" . ($ENV{smbprinteradmin} // q{}) . "%" . ($ENV{smbadminpasswd} // q{}) . "\" -d 2 \
	-c \'adddriver \"Windows NT x86\" \"" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Drivername' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Drivername' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'DriverPath' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'DriverPath' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Datafile' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Datafile' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Configfile' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Configfile' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Helpfile' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Helpfile' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":NULL:RAW:" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Dependentfiles' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Dependentfiles' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . "\" " . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'driverversion' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'driverversion' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . q{ } . $smbhost . q{ } . "\\'";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print " ################ DEBUGGING STATEMENT \n";
            $main_exit_code = system('rpcclient', '-U', ($ENV{smbprinteradmin} // q{}) . "%" . ($ENV{smbadminpasswd} // q{}), '-d', q{2}, '-c', "adddriver \"Windows 4.0\" \"" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Drivername' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Drivername' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'DriverPath' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'DriverPath' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Datafile' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Datafile' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Configfile' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Configfile' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Helpfile' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Helpfile' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . ":NULL:RAW:" . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'Dependentfiles' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'Dependentfiles' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }) . "\" " . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'driverversion' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'driverversion' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }), $smbhost) >> 8;
# set +x not implemented
            chdir($CURRENTWD);
            $CHILD_ERROR = 0;
        }
    }
    return;
}
enumallfunctions();

exit $main_exit_code;
