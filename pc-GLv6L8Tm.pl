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

my $GIT_DIR;
my @GIT_DIR;
my %GIT_DIR;


sub prep_for_email {
    my $oldrev;
    my @oldrev;
    my %oldrev;
    $oldrev = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'git', 'rev-parse', $1);
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
    my $newrev;
    my @newrev;
    my %newrev;
    $newrev = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'git', 'rev-parse', $2);
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
};
    my $refname;
    my @refname;
    my %refname;
    $refname = "$_[2]";
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('expr', "$oldrev", q{:}, '0*$') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        my $change_type;
        my @change_type;
        my %change_type;
        $change_type = "create";
}
    else {
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('expr', "$newrev", q{:}, '0*$') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $change_type = "delete";
}
        else {
            $change_type = "update";
        }
    }
    my $newrev_type;
    my @newrev_type;
    my %newrev_type;
    $newrev_type = do { my @_qx_cmd = ("git cat-file -t Variable(\"newrev\", false, None) 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    my $oldrev_type;
    my @oldrev_type;
    my %oldrev_type;
    $oldrev_type = do { my @_qx_cmd = ("git cat-file -t \"$oldrev\" 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ("$change_type" =~ /^create$/msx or "$change_type" =~ /^update$/msx) {
                my $rev;
        my @rev;
        my %rev;
        $rev = "$newrev";
                my $rev_type;
        my @rev_type;
        my %rev_type;
        $rev_type = "$newrev_type";
    } elsif ("$change_type" =~ /^delete$/msx) {
                $rev = "$oldrev";
                $rev_type = "$oldrev_type";
    }
if ("$refname,$rev_type" =~ /^refs/tags/.*,commit$/msx) {
                my $refname_type;
        my @refname_type;
        my %refname_type;
        $refname_type = "tag";
                my $short_refname;
        my @short_refname;
        my %short_refname;
        $short_refname = ${refname} =~ s/^refs/tags///sr;
    } elsif ("$refname,$rev_type" =~ /^refs/tags/.*,tag$/msx) {
                $refname_type = "annotated tag";
                $short_refname = ${refname} =~ s/^refs/tags///sr;
        if ("$announcerecipients" ne q{}) {
            my $recipients;
            my @recipients;
            my %recipients;
            $recipients = "$ENV{announcerecipients}";
        }
    } elsif ("$refname,$rev_type" =~ /^refs/heads/.*,commit$/msx) {
                $refname_type = "branch";
                $short_refname = ${refname} =~ s/^refs/heads///sr;
    } elsif ("$refname,$rev_type" =~ /^refs/remotes/.*,commit$/msx) {
                $refname_type = "tracking branch";
                $short_refname = ${refname} =~ s/^refs/remotes///sr;
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "*** Push-update of tracking branch, $refname";
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
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "***  - no email generated.\n";
        };
        return q{1};    } elsif (1) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "*** Unknown type of update to $refname ($rev_type)";
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
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "***  - no email generated\n";
        };
        return q{1};    }
if ("$recipients" eq q{}) {
if ("$refname_type" =~ /^annotated tag$/msx) {
                        my $config_name;
            my @config_name;
            my %config_name;
            $config_name = "hooks.announcelist";
        } elsif (1) {
                        $config_name = "hooks.mailinglist";
        }
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "*** $config_name is not set so no email will be sent";
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
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "*** for $refname update $oldrev->$newrev";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
return q{1};
    }
return q{0};
    return;
}

sub generate_email {
    my $describe;
    my @describe;
    my %describe;
    $describe = do { my @_qx_cmd = ("git describe Variable(\"rev\", false, None) 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ("$describe" eq q{}) {
        $describe = $rev;
    }
    $main_exit_code = system('bash', 'generate_email_header') >> 8;
    my $fn_name;
    my @fn_name;
    my %fn_name;
    $fn_name = 'general';
if ("$ENV{refname_type}" =~ /^tracking branch$/msx or "$ENV{refname_type}" =~ /^branch$/msx) {
                $fn_name = 'branch';
    } elsif ("$ENV{refname_type}" =~ /^annotated tag$/msx) {
                $fn_name = 'atag';
    }
if ("$maxlines" eq q{}) {
        $main_exit_code = system('generate_', $change_type, q{_}, $fn_name, '_email') >> 8;
}
    else {
        # Original bash: generate_${change_type}_${fn_name}_email | limit_lines $maxlines
{
            my $output_2 = q{};
            my $output_printed_2;
            my $pipeline_success_2 = 1;
                        my ($in_3, $out_3);
            my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'generate_', q{_}, '_email');
            close $in_3 or croak 'Close failed: $OS_ERROR';
            $output_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
            close $out_3 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_3, 0;

                        my $cmd_5 = 'limit_lines';
            my ($in_4, $out_4);
            my $pid_4 = open3($in_4, $out_4, '>&STDERR', $cmd_5, );
            print {$in_4} $output_2;
            close $in_4 or croak 'Close failed: $OS_ERROR';
            $output_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
            close $out_4 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_4, 0;
            if ($output_2 ne q{} && !defined $output_printed_2) {
                print $output_2;
                if (!($output_2 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
            }
    }
    $main_exit_code = system('bash', 'generate_email_footer') >> 8;
    return;
}

sub generate_email_header {
print "\tTo: $recipients
\tSubject: ${emailprefix}$projectdesc $refname_type $short_refname ${change_type}d. $describe
\tMIME-Version: 1.0
\tContent-Type: text/plain; charset=utf-8
\tContent-Transfer-Encoding: 8bit
\tX-Git-Refname: $refname
\tX-Git-Reftype: $refname_type
\tX-Git-Oldrev: $oldrev
\tX-Git-Newrev: $newrev
\tAuto-Submitted: auto-generated

\tThis is an automated email from the git hooks/post-receive script. It was
\tgenerated because a ref change was pushed to the repository containing
\tthe project \"$projectdesc\".

\tThe $refname_type, $short_refname has been ${change_type}d
";
    return;
}

sub generate_email_footer {
    my $SPACE;
    my @SPACE;
    my %SPACE;
    $SPACE = " ";
print "

\thooks/post-receive
\t--${SPACE}
\t$projectdesc
";
    return;
}

sub generate_create_branch_email {
    do {
    my $__echo_line = "        at  $ENV{newrev} ($ENV{newrev_type})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "\n";
    print $LOGBEGIN;
if ( !( ($LOGBEGIN) =~ m{\n\z}msx ) ) { print "\n"; }
    $main_exit_code = system('bash', 'show_new_revisions') >> 8;
    print $LOGEND;
if ( !( ($LOGEND) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}

sub generate_update_branch_email {
    my $fast_forward;
    my @fast_forward;
    my %fast_forward;
    $fast_forward = "";
    my $rev;
    my @rev;
    my %rev;
    $rev = "";
    for my $rev (do {
    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'git', 'rev-list', $newrev, '..', $oldrev);
    close $in_6 or croak 'Close failed: $OS_ERROR';
    my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    $result_6
}) {
        my $revtype;
        my @revtype;
        my %revtype;
        $revtype = do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'git', 'cat-file', '-t', "$rev");
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
};
        do {
    my $__echo_line = "  discards  $rev ($revtype)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
if ("$rev" eq q{}) {
        $fast_forward = q{1};
    }
    for my $rev (do {
    my ($in_8, $out_8);
    my $pid_8 = open3($in_8, $out_8, '>&STDERR', 'git', 'rev-list', $oldrev, '..', $newrev);
    close $in_8 or croak 'Close failed: $OS_ERROR';
    my $result_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
    close $out_8 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_8, 0;
    $result_8
}) {
        $revtype = do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'git', 'cat-file', '-t', "$rev");
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
};
        do {
    my $__echo_line = "       via  $rev ($revtype)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
if (("$fast_forward")) {
        do {
    my $__echo_line = "      from  $ENV{oldrev} ($ENV{oldrev_type})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
}
    else {
        print "\n";
        my $baserev;
        my @baserev;
        my %baserev;
        $baserev = do {
    my ($in_10, $out_10);
    my $pid_10 = open3($in_10, $out_10, '>&STDERR', 'git', 'merge-base', $oldrev, $newrev);
    close $in_10 or croak 'Close failed: $OS_ERROR';
    my $result_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
    close $out_10 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_10, 0;
    $result_10
};
        my $rewind_only;
        my @rewind_only;
        my %rewind_only;
        $rewind_only = "";
if ("$baserev" eq "$newrev") {
            print "This update discarded existing revisions and left the branch pointing at\n";
            print "a previous point in the repository history.\n";
            print "\n";
            do {
    my $__echo_line = " * -- * -- N ($ENV{newrev})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print "            \\n";
            do {
    my $__echo_line = "             O -- O -- O ($ENV{oldrev})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print "\n";
            print "The removed revisions are not necessarily gone - if another reference\n";
            print "still refers to them they will stay in the repository.\n";
            $rewind_only = q{1};
}
        else {
            print "This update added new revisions after undoing existing revisions.  That is\n";
            print "to say, the old revision is not a strict subset of the new revision.  This\n";
            print "situation occurs when you --force push a change and generate a repository\n";
            print "containing something like this:\n";
            print "\n";
            do {
    my $__echo_line = " * -- * -- B -- O -- O -- O ($ENV{oldrev})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print "            \\n";
            do {
    my $__echo_line = "             N -- N -- N ($ENV{newrev})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print "\n";
            print "When this happens we assume that you've already had alert emails for all\n";
            print "of the O revisions, and so we here report only the revisions in the N\n";
            print "branch from the common base, B.\n";
        }
    }
    print "\n";
if ("$rewind_only" eq q{}) {
        print "Those revisions listed above that are new to this repository have\n";
        print "not appeared on any other notification email; so we list those\n";
        print "revisions in full, below.\n";
        print "\n";
        print $LOGBEGIN;
if ( !( ($LOGBEGIN) =~ m{\n\z}msx ) ) { print "\n"; }
        $main_exit_code = system('bash', 'show_new_revisions') >> 8;
        print $LOGEND;
if ( !( ($LOGEND) =~ m{\n\z}msx ) ) { print "\n"; }
}
    else {
        print "No new revisions were added by this update.\n";
    }
    print "\n";
    print "Summary of changes:\n";
    $main_exit_code = system('git', 'diff-tree', $diffopts, $oldrev, '..', $newrev) >> 8;
    return;
}

sub generate_delete_branch_email {
    do {
    my $__echo_line = "       was  $ENV{oldrev}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "\n";
    print $LOGBEGIN;
if ( !( ($LOGBEGIN) =~ m{\n\z}msx ) ) { print "\n"; }
    $main_exit_code = system('git', 'diff-tree', '-s', '--always', '--encoding=UTF-8', '--pretty=oneline', $oldrev) >> 8;
    print $LOGEND;
if ( !( ($LOGEND) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}

sub generate_create_atag_email {
    do {
    my $__echo_line = "        at  $ENV{newrev} ($ENV{newrev_type})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    $main_exit_code = system('bash', 'generate_atag_email') >> 8;
    return;
}

sub generate_update_atag_email {
    do {
    my $__echo_line = "        to  $ENV{newrev} ($ENV{newrev_type})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "      from  $ENV{oldrev} (which is now obsolete)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    $main_exit_code = system('bash', 'generate_atag_email') >> 8;
    return;
}

sub generate_atag_email {
do { my $eval_input = do {
    my ($in_11, $out_11);
    my $pid_11 = open3($in_11, $out_11, '>&STDERR', 'git', 'for-each-ref', '--shell', "--format=\n\ttagobject=%(*objectname)\n\ttagtype=%(*objecttype)\n\ttagger=%(taggername)\n\ttagged=%(taggerdate)", $refname);
    close $in_11 or croak 'Close failed: $OS_ERROR';
    my $result_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
    close $out_11 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_11, 0;
    $result_11
}; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    do {
    my $__echo_line = "   tagging  $ENV{tagobject} ($ENV{tagtype})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if ("$ENV{tagtype}" =~ /^commit$/msx) {
                my $prevtag;
        my @prevtag;
        my %prevtag;
        $prevtag = do { my @_qx_cmd = ("git describe --abbrev=0 Variable(\"newrev\", false, None) ^ 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        if ("$prevtag" ne q{}) {
            do {
    my $__echo_line = "  replaces  $prevtag";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
    } elsif (1) {
                do {
    my $__echo_line = "    length  " . (do { my $_chomp_temp = do {
    my ($in_12, $out_12);
    my $pid_12 = open3($in_12, $out_12, '>&STDERR', 'git', 'cat-file', '-s', $tagobject);
    close $in_12 or croak 'Close failed: $OS_ERROR';
    my $result_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
    close $out_12 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_12, 0;
    $result_12
}; chomp $_chomp_temp; $_chomp_temp; }) . " bytes";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    do {
    my $__echo_line = " tagged by  $ENV{tagger}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "        on  $ENV{tagged}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "\n";
    print $LOGBEGIN;
if ( !( ($LOGBEGIN) =~ m{\n\z}msx ) ) { print "\n"; }
    # Original bash: git cat-file tag $newrev | sed -e '1,/^$/d'
{
        my $output_13 = q{};
        my $output_printed_13;
        my $pipeline_success_13 = 1;
                my ($in_14, $out_14);
        my $pid_14 = open3($in_14, $out_14, '>&STDERR', 'git', 'cat-file', 'tag');
        close $in_14 or croak 'Close failed: $OS_ERROR';
        $output_13 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_14> };
        close $out_14 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_14, 0;

                my @sed_lines_13 = split /\n/msx, $output_13;
        my @sed_result_13;
        foreach my $line (@sed_lines_13) {
        chomp $line;
        push @sed_result_13, $line;
        }
        $output_13 = join "\n", @sed_result_13;
        if ($output_13 ne q{} && !defined $output_printed_13) {
            print $output_13;
            if (!($output_13 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_13 ) { $main_exit_code = 1; }
        }
    print "\n";
if ("$ENV{tagtype}" =~ /^commit$/msx) {
        if ("$prevtag" ne q{}) {
            $main_exit_code = system('git', 'shortlog', "$prevtag..$ENV{newrev}") >> 8;
}
        else {
            $main_exit_code = system('git', 'shortlog', $newrev) >> 8;
        }
    } elsif (1) {
    }
    print $LOGEND;
if ( !( ($LOGEND) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}

sub generate_delete_atag_email {
    do {
    my $__echo_line = "       was  $ENV{oldrev}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "\n";
    print $LOGBEGIN;
if ( !( ($LOGBEGIN) =~ m{\n\z}msx ) ) { print "\n"; }
    $main_exit_code = system('git', 'diff-tree', '-s', '--always', '--encoding=UTF-8', '--pretty=oneline', $oldrev) >> 8;
    print $LOGEND;
if ( !( ($LOGEND) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}

sub generate_create_general_email {
    do {
    my $__echo_line = "        at  $ENV{newrev} ($ENV{newrev_type})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    $main_exit_code = system('bash', 'generate_general_email') >> 8;
    return;
}

sub generate_update_general_email {
    do {
    my $__echo_line = "        to  $ENV{newrev} ($ENV{newrev_type})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "      from  $ENV{oldrev}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    $main_exit_code = system('bash', 'generate_general_email') >> 8;
    return;
}

sub generate_general_email {
    print "\n";
if ("$newrev_type" eq "commit") {
        print $LOGBEGIN;
if ( !( ($LOGBEGIN) =~ m{\n\z}msx ) ) { print "\n"; }
        $main_exit_code = system('git', 'diff-tree', '-s', '--always', '--encoding=UTF-8', '--pretty=medium', $newrev) >> 8;
        print $LOGEND;
if ( !( ($LOGEND) =~ m{\n\z}msx ) ) { print "\n"; }
}
    else {
        do {
    my $__echo_line = "$ENV{newrev} is a $ENV{newrev_type}, and is " . (do { my $_chomp_temp = do {
    my ($in_15, $out_15);
    my $pid_15 = open3($in_15, $out_15, '>&STDERR', 'git', 'cat-file', '-s', $newrev);
    close $in_15 or croak 'Close failed: $OS_ERROR';
    my $result_15 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_15> };
    close $out_15 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_15, 0;
    $result_15
}; chomp $_chomp_temp; $_chomp_temp; }) . " bytes long.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    return;
}

sub generate_delete_general_email {
    do {
    my $__echo_line = "       was  $ENV{oldrev}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "\n";
    print $LOGBEGIN;
if ( !( ($LOGBEGIN) =~ m{\n\z}msx ) ) { print "\n"; }
    $main_exit_code = system('git', 'diff-tree', '-s', '--always', '--encoding=UTF-8', '--pretty=oneline', $oldrev) >> 8;
    print $LOGEND;
if ( !( ($LOGEND) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}

sub show_new_revisions {
if ("$change_type" eq create) {
        my $revspec;
        my @revspec;
        my %revspec;
        $revspec = $newrev;
}
    else {
        $revspec = $oldrev;
        $main_exit_code = system('..', $newrev) >> 8;
    }
    my $other_branches;
    my @other_branches;
    my %other_branches;
    $other_branches = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_16 = q{};
        my $output_printed_16;
        my $pipeline_success_16 = 1;

        my ($in_17, $out_17);
        my $pid_17 = open3($in_17, $out_17, '>&STDERR', 'git', 'for-each-ref', '--format=%(refname)', 'refs/heads/');
        close $in_17 or croak 'Close failed: $OS_ERROR';
        $output_16 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> };
        close $out_17 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_17, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_16 = 0; }
        my $grep_result_16_1;
        my @grep_lines_16_1 = split /\n/msx, $output_16;
        my @grep_filtered_16_1 = grep { !/$refname/msx } @grep_lines_16_1;
        $grep_result_16_1 = join "\n", @grep_filtered_16_1;
                if (!($grep_result_16_1 =~ m{\n\z}msx || $grep_result_16_1 eq q{})) {
                    $grep_result_16_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_16_1 > 0 ? 0 : 1;
        $output_16 = $grep_result_16_1;
        if ((scalar @grep_filtered_16_1) == 0) {
            $pipeline_success_16 = 0;
        }
        if ( !$pipeline_success_16 ) { $main_exit_code = 1; }
        $output_16 =~ s/\n+\z//msx;
        $output_16;
}; $_pipeline_result; };
    # Original bash: git rev-parse --not $other_branches |
{
        my $output_18 = q{};
        my $output_printed_18;
        my $pipeline_success_18 = 1;
                my ($in_19, $out_19);
        my $pid_19 = open3($in_19, $out_19, '>&STDERR', 'git', 'rev-parse', '--not');
        close $in_19 or croak 'Close failed: $OS_ERROR';
        $output_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19> };
        close $out_19 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_19, 0;

                my @_pcmd_21 = ('bash', '-c', "echo \"${output_18}\" | : \"Complex command cannot be converted to shell command\"");
        my ($in_20);
        my $pid_20 = open3($in_20, $out_20, '>&STDERR', @_pcmd_21);
        close $in_20 or croak 'Close failed: $OS_ERROR';
        my $temp_result;
        $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
        $output_18 = $temp_result;
        close $out_20 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_20, 0;
        if ($output_18 ne q{} && !defined $output_printed_18) {
            print $output_18;
            if (!($output_18 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_18 ) { $main_exit_code = 1; }
        }
    return;
}

sub limit_lines {
    my $lines;
    my @lines;
    my %lines;
    $lines = q{0};
    my $skipped;
    my @skipped;
    my %skipped;
    $skipped = q{0};
    my $line;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $line = $_fields[0] // q{};
        $lines = eval { int($lines + 1) } // "";
if (($lines > $1)) {
            $skipped = eval { int($skipped + 1) } // "";
}
        else {
printf("%s\n", "$line");
        }
    }
if (($skipped != 0)) {
        do {
    my $__echo_line = "... $skipped lines suppressed ...";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    return;
}

sub send_mail {
if ("$envelopesender" ne q{}) {
        $main_exit_code = system('/usr/sbin/sendmail', '-t', '-f', "$ENV{envelopesender}") >> 8;
}
    else {
        $main_exit_code = system('/usr/sbin/sendmail', '-t') >> 8;
    }
    return;
}
my $LOGBEGIN;
my @LOGBEGIN;
my %LOGBEGIN;
$LOGBEGIN = "- Log -----------------------------------------------------------------";
my $LOGEND;
my @LOGEND;
my %LOGEND;
$LOGEND = "-----------------------------------------------------------------------";
$GIT_DIR = do { my @_qx_cmd = ("git rev-parse --git-dir 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ("$GIT_DIR" eq q{}) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "fatal: post-receive: GIT_DIR not set\n";
    };
exit 1;
}
my $projectdesc;
my @projectdesc;
my %projectdesc;
$projectdesc = do { my @_qx_cmd = ("sed -ne 1p \"$GIT_DIR/description\" 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('expr', "$projectdesc", q{:}, "Unnamed repository.*$") >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
    $projectdesc = "UNNAMED PROJECT";
}
my $recipients;
my @recipients;
my %recipients;
$recipients = do {
    my ($in_23, $out_23);
    my $pid_23 = open3($in_23, $out_23, '>&STDERR', 'git', 'config', 'hooks.mailinglist');
    close $in_23 or croak 'Close failed: $OS_ERROR';
    my $result_23 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
    close $out_23 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_23, 0;
    $result_23
};
my $announcerecipients;
my @announcerecipients;
my %announcerecipients;
$announcerecipients = do {
    my ($in_24, $out_24);
    my $pid_24 = open3($in_24, $out_24, '>&STDERR', 'git', 'config', 'hooks.announcelist');
    close $in_24 or croak 'Close failed: $OS_ERROR';
    my $result_24 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_24> };
    close $out_24 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_24, 0;
    $result_24
};
my $envelopesender;
my @envelopesender;
my %envelopesender;
$envelopesender = do {
    my ($in_25, $out_25);
    my $pid_25 = open3($in_25, $out_25, '>&STDERR', 'git', 'config', 'hooks.envelopesender');
    close $in_25 or croak 'Close failed: $OS_ERROR';
    my $result_25 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_25> };
    close $out_25 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_25, 0;
    $result_25
};
my $emailprefix;
my @emailprefix;
my %emailprefix;
$emailprefix = do {
    my $command = q{git config hooks.emailprefix || echo '[SCM] '};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
my $custom_showrev;
my @custom_showrev;
my %custom_showrev;
$custom_showrev = do {
    my ($in_26, $out_26);
    my $pid_26 = open3($in_26, $out_26, '>&STDERR', 'git', 'config', 'hooks.showrev');
    close $in_26 or croak 'Close failed: $OS_ERROR';
    my $result_26 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_26> };
    close $out_26 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_26, 0;
    $result_26
};
my $maxlines;
my @maxlines;
my %maxlines;
$maxlines = do {
    my ($in_27, $out_27);
    my $pid_27 = open3($in_27, $out_27, '>&STDERR', 'git', 'config', 'hooks.emailmaxlines');
    close $in_27 or croak 'Close failed: $OS_ERROR';
    my $result_27 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_27> };
    close $out_27 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_27, 0;
    $result_27
};
my $diffopts;
my @diffopts;
my %diffopts;
$diffopts = do {
    my ($in_28, $out_28);
    my $pid_28 = open3($in_28, $out_28, '>&STDERR', 'git', 'config', 'hooks.diffopts');
    close $in_28 or croak 'Close failed: $OS_ERROR';
    my $result_28 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_28> };
    close $out_28 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_28, 0;
    $result_28
};
$main_exit_code = system(':', (defined ${diffopts} && ${diffopts} ne q{} ? ${diffopts} : do { $diffopts = '"--stat --summary --find-copies-harder"'; ${diffopts} })) >> 8;
if (0) {
    if (do {
prep_for_email($2, $3, $1);
        $CHILD_ERROR == 0
    }) {
                my $PAGER = q{};
        generate_email();
    }
}
else {
    my $oldrev;
    my $newrev;
    my $refname;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $oldrev = $_fields[0] // q{};
    $newrev = $_fields[1] // q{};
    $refname = $_fields[2] // q{};
                prep_for_email($oldrev, $newrev, $refname);
        if ($CHILD_ERROR != 0) {
            next;        }
        # Original bash: generate_email $maxlines | send_mail
{
            my $output_29 = q{};
            my $output_printed_29;
            my $pipeline_success_29 = 1;
                        my ($in_30, $out_30);
            my $pid_30 = open3($in_30, $out_30, '>&STDERR', 'generate_email', );
            close $in_30 or croak 'Close failed: $OS_ERROR';
            $output_29 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
            close $out_30 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_30, 0;

                        my $cmd_32 = 'send_mail';
            my ($in_31, $out_31);
            my $pid_31 = open3($in_31, $out_31, '>&STDERR', $cmd_32, );
            print {$in_31} $output_29;
            close $in_31 or croak 'Close failed: $OS_ERROR';
            $output_29 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
            close $out_31 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_31, 0;
            if ($output_29 ne q{} && !defined $output_printed_29) {
                print $output_29;
                if (!($output_29 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_29 ) { $main_exit_code = 1; }
            }
    }
}

exit $main_exit_code;
