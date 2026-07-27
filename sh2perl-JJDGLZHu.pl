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

if ("$1" eq q{}) {
    do {
    my $__echo_line = "Usage: $PROGRAM_NAME <language code> <class> [<version>]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
exit 0;
}

sub normalize_locale {
    my $this_locale;
    my @this_locale;
    my %this_locale;
    $this_locale = q{x};
    $CHILD_ERROR = 0;
    my $charset;
    my @charset;
    my %charset;
    $charset = q{};
if (!(    # Original bash: echo $this_locale | LC_ALL=C grep '\.' > /dev/null 2>&1;
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
        $output_0 .= $this_locale . "\n";
if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
$CHILD_ERROR = 0;

                my $grep_result_0_1;
        my @grep_lines_0_1 = split /\n/msx, $output_0;
        my @grep_filtered_0_1 = grep { /[.]/msx } @grep_lines_0_1;
        $grep_result_0_1 = join "\n", @grep_filtered_0_1;
        if (!($grep_result_0_1 =~ m{\n\z}msx || $grep_result_0_1 eq q{})) {
        $grep_result_0_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_0_1 > 0 ? 0 : 1;
        $output_0 = $grep_result_0_1;
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        })) {
        $charset = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_1 = q{};
            my $output_printed_1;
            my $pipeline_success_1 = 1;
            $output_1 .= $this_locale . "\n";
            if ( !($output_1 =~ m{\n\z}msx) ) { $output_1 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
            my @sed_lines_1 = split /\n/msx, $output_1;
            my @sed_result_1;
            foreach my $line (@sed_lines_1) {
            chomp $line;
            push @sed_result_1, $line;
            }
            $output_1 = join "\n", @sed_result_1;

            my $set1_2 = '[A-Z]';
            my $set2_2 = '[a-z]';
            my $input_2 = $output_1;
            # Expand character ranges for tr command
            my $expanded_set1_2 = $set1_2;
            my $expanded_set2_2 = $set2_2;
            # Handle a-z range in set1
            if ($expanded_set1_2 =~ /a-z/msx) {
                $expanded_set1_2 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle A-Z range in set1
            if ($expanded_set1_2 =~ /A-Z/msx) {
                $expanded_set1_2 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:upper:] POSIX class in set1
            if ($expanded_set1_2 =~ /\[:upper:\]/msx) {
                $expanded_set1_2 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:lower:] POSIX class in set1
            if ($expanded_set1_2 =~ /\[:lower:\]/msx) {
                $expanded_set1_2 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle a-z range in set2
            if ($expanded_set2_2 =~ /a-z/msx) {
                $expanded_set2_2 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle A-Z range in set2
            if ($expanded_set2_2 =~ /A-Z/msx) {
                $expanded_set2_2 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:upper:] POSIX class in set2
            if ($expanded_set2_2 =~ /\[:upper:\]/msx) {
                $expanded_set2_2 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:lower:] POSIX class in set2
            if ($expanded_set2_2 =~ /\[:lower:\]/msx) {
                $expanded_set2_2 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
            }
            my $tr_result_1_2 = q{};
            for my $char ( split //msx, $input_2 ) {
                my $pos_2 = index $expanded_set1_2, $char;
                if ( $pos_2 >= 0 && $pos_2 < length $expanded_set2_2 ) {
                    $tr_result_1_2 .= substr $expanded_set2_2, $pos_2, 1;
                } else {
                    $tr_result_1_2 .= $char;
                }
            }
                        if (!($tr_result_1_2 =~ m{\n\z}msx || $tr_result_1_2 eq q{})) {
                            $tr_result_1_2 .= "\n";
                        }
                        $output_1 = $tr_result_1_2;
            my @sed_lines_1 = split /\n/msx, $output_1;
            my @sed_result_1;
            foreach my $line (@sed_lines_1) {
            chomp $line;
            push @sed_result_1, $line;
            }
            $output_1 = join "\n", @sed_result_1;

            if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
            $output_1 =~ s/\n+\z//msx;
            $output_1;
}; $_pipeline_result; };
    }
    my $modifier;
    my @modifier;
    my %modifier;
    $modifier = q{};
if (!(    # Original bash: echo $this_locale | LC_ALL=C grep '@' > /dev/null 2>&1;
{
        my $output_3 = q{};
        my $output_printed_3;
        my $pipeline_success_3 = 1;
        $output_3 .= $this_locale . "\n";
if ( !($output_3 =~ m{\n\z}msx) ) { $output_3 .= "\n"; }
$CHILD_ERROR = 0;

                my $grep_result_3_1;
        my @grep_lines_3_1 = split /\n/msx, $output_3;
        my @grep_filtered_3_1 = grep { /@/msx } @grep_lines_3_1;
        $grep_result_3_1 = join "\n", @grep_filtered_3_1;
        if (!($grep_result_3_1 =~ m{\n\z}msx || $grep_result_3_1 eq q{})) {
        $grep_result_3_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_3_1 > 0 ? 0 : 1;
        $output_3 = $grep_result_3_1;
        if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
        })) {
        $modifier = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_4 = q{};
            my $output_printed_4;
            my $pipeline_success_4 = 1;
            $output_4 .= $this_locale . "\n";
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
    }
    my $main;
    my @main;
    my %main;
    $main = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_5 = q{};
        my $output_printed_5;
        my $pipeline_success_5 = 1;
        $output_5 .= $this_locale . "\n";
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
    do {
    my $__echo_line = $main . q{ } . $charset . q{ } . $modifier;
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

sub get_supported_local_normalized {
    if (!((-e '/etc/locale.gen'))) {
        return q{0};    }
    # Original bash: sort -u /etc/locale.gen | while read locale charset; do
{
        my $output_6 = q{};
        my $output_printed_6;
        my $pipeline_success_6 = 1;
                my @sort_lines_6_0 = split /\n/msx, $;
        my @sort_sorted_6_0 = sort @sort_lines_6_0;
        $output_6 = join "\n", @sort_sorted_6_0;
        if ($output_6 ne q{} && !($output_6 =~ m{\n\z}msx)) {
        $output_6 .= "\n";
        }
        $ = $output_6;

                my @lines = split /\n/msx, $output_6;
        my $result_6_1 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        if ($locale =~ /^\#.*$/msx) {
        next;        } elsif ($locale =~ /^$/msx) {
        next;        }
        normalize_locale("$ENV{locale}");
        }
        $output_6 = $result_6_1;
        if ($output_6 ne q{} && !defined $output_printed_6) {
            print $output_6;
            if (!($output_6 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
        }
    return;
}

sub remove_locale {
    my $this_locale;
    my @this_locale;
    my %this_locale;
    $this_locale = do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'normalize_locale', "$_[0]");
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
};
if (!(!(# Original bash: echo "$supported_local_normalized" | fgrep -qx "$this_locale";
{
        my $output_8 = q{};
        my $output_printed_8;
        my $pipeline_success_8 = 1;
        $output_8 .= $supported_local_normalized . "\n";
if ( !($output_8 =~ m{\n\z}msx) ) { $output_8 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_10 = 'fgrep';
        my ($in_9, $out_9);
        my $pid_9 = open3($in_9, $out_9, '>&STDERR', $cmd_10, '-qx');
        print {$in_9} $output_8;
        close $in_9 or croak 'Close failed: $OS_ERROR';
        $output_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
        close $out_9 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_9, 0;
        if ($output_8 ne q{} && !defined $output_printed_8) {
            print $output_8;
            if (!($output_8 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
        }))) {
if ((-e '/usr/lib/locale/locale-archive')) {
            $main_exit_code = system('localedef', '--delete-from-archive', "$this_locale") >> 8;
        }
    }
    return;
}
if ("$2" eq q{}) {
if ((!-e /var/lib/locales/supported.d/$1)) {
        my $supported_local_normalized;
        my @supported_local_normalized;
        my %supported_local_normalized;
        $supported_local_normalized = (do { my $_chomp_temp = do {
    my ($in_11, $out_11);
    my $pid_11 = open3($in_11, $out_11, '>&STDERR', 'get_supported_local_normalized');
    close $in_11 or croak 'Close failed: $OS_ERROR';
    my $result_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
    close $out_11 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_11, 0;
    $result_11
}; chomp $_chomp_temp; $_chomp_temp; });
if ("$1" eq 'zh-hans') {
            remove_locale('zh_CN.utf8');
            remove_locale('zh_SG.utf8');
}
        else {
            if ("$1" eq 'zh-hant') {
                remove_locale('zh_HK.utf8');
                remove_locale('zh_TW.utf8');
}
            else {
if ((-e '/usr/lib/locale/locale-archive')) {
                    my $l;
                    for my $l (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                        my $output_12 = q{};
                        my $output_printed_12;
                        my $pipeline_success_12 = 1;

                        my ($in_13, $out_13);
                        my $pid_13 = open3($in_13, $out_13, '>&STDERR', 'localedef', '--list-archive');
                        close $in_13 or croak 'Close failed: $OS_ERROR';
                        $output_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
                        close $out_13 or croak 'Close failed: $OS_ERROR';
                        waitpid $pid_13, 0;
                        if ($CHILD_ERROR != 0) { $pipeline_success_12 = 0; }
                        my $grep_result_12_1;
                        my @grep_lines_12_1 = split /\n/msx, $output_12;
                        my @grep_filtered_12_1 = grep { /^$_[0][._@]/msx } @grep_lines_12_1;
                        $grep_result_12_1 = join "\n", @grep_filtered_12_1;
                                                if (!($grep_result_12_1 =~ m{\n\z}msx || $grep_result_12_1 eq q{})) {
                                                    $grep_result_12_1 .= "\n";
                                                }
                        $CHILD_ERROR = scalar @grep_filtered_12_1 > 0 ? 0 : 1;
                        $output_12 = $grep_result_12_1;
                        if ((scalar @grep_filtered_12_1) == 0) {
                            $pipeline_success_12 = 0;
                        }
                        if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
                        $output_12 =~ s/\n+\z//msx;
                        $output_12;
}; $_pipeline_result; }) {
                        remove_locale("$l");
                    }
                }
            }
        }
    }
}
$main_exit_code = system('dpkg-trigger', 'gmenucache') >> 8;
if ($CHILD_ERROR != 0) {
    1;
}

exit $main_exit_code;
