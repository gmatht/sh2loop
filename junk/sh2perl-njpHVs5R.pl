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

my $ca;
my @ca;
my %ca;

my $MAGIC_20111025 = 20_111_025;

$__set_e = 1;

sub each_value {
    my ($file) = @_;
    # Original bash: echo "$1" |tr ',' '\n' | sed -e 's/^[[:space:]]*//'
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
        $output_0 .= $1 . "\n";
if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
$CHILD_ERROR = 0;

                my $set1_1 = q{,};
        my $set2_1 = "\\n";
        my $input_1 = $output_0;
        # Expand character ranges for tr command
        my $expanded_set1_1 = $set1_1;
        my $expanded_set2_1 = $set2_1;
        # Handle a-z range in set1
        if ($expanded_set1_1 =~ /a-z/msx) {
        $expanded_set1_1 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_1 =~ /A-Z/msx) {
        $expanded_set1_1 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_1 =~ /\[:upper:\]/msx) {
        $expanded_set1_1 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_1 =~ /\[:lower:\]/msx) {
        $expanded_set1_1 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_1 =~ /a-z/msx) {
        $expanded_set2_1 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_1 =~ /A-Z/msx) {
        $expanded_set2_1 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_1 =~ /\[:upper:\]/msx) {
        $expanded_set2_1 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_1 =~ /\[:lower:\]/msx) {
        $expanded_set2_1 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_0_1 = q{};
        for my $char ( split //msx, $input_1 ) {
        my $pos_1 = index $expanded_set1_1, $char;
        if ( $pos_1 >= 0 && $pos_1 < length $expanded_set2_1 ) {
        $tr_result_0_1 .= substr $expanded_set2_1, $pos_1, 1;
        } else {
        $tr_result_0_1 .= $char;
        }
        }
        if (!($tr_result_0_1 =~ m{\n\z}msx || $tr_result_0_1 eq q{})) {
        $tr_result_0_1 .= "\n";
        }
        $output_0 = $tr_result_0_1;
        $output_0 = $tr_result_0_1;

                my @sed_lines_0 = split /\n/msx, $output_0;
        my @sed_result_0;
        foreach my $line (@sed_lines_0) {
        chomp $line;
        push @sed_result_0, $line;
        }
        $output_0 = join "\n", @sed_result_0;
        if ($output_0 ne q{} && !defined $output_printed_0) {
            print $output_0;
            if (!($output_0 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
    return;
}

sub memberp {
    my $m;
    my @m;
    my %m;
    $m = "$_[0]";
    my $l;
    my @l;
    my %l;
    $l = "$_[1]";
    # Original bash: each_value "$l" | grep -q "^$m\$"
{
        my $output_2 = q{};
        my $output_printed_2;
        my $pipeline_success_2 = 1;
                my ($in_3, $out_3);
        my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'each_value', );
        close $in_3 or croak 'Close failed: $OS_ERROR';
        $output_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
        close $out_3 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_3, 0;

                my $grep_result_2_1;
        my @grep_lines_2_1 = split /\n/msx, $output_2;
        my @grep_filtered_2_1 = grep { /^$m$/msx } @grep_lines_2_1;
        $grep_result_2_1 = join "\n", @grep_filtered_2_1;
        if (!($grep_result_2_1 =~ m{\n\z}msx || $grep_result_2_1 eq q{})) {
        $grep_result_2_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_2_1 > 0 ? 0 : 1;
        $grep_result_2_1 = q{};
        $output_2 = q{};
        if ((scalar @grep_filtered_2_1) == 0) {
            $pipeline_success_2 = 0;
        }
        if ($output_2 ne q{} && !defined $output_printed_2) {
            print $output_2;
            if (!($output_2 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
    return;
}

sub delca {
    my $m;
    my @m;
    my %m;
    $m = "$_[0]";
    my $l;
    my @l;
    my %l;
    $l = "$_[1]";
    # Original bash: echo "$l" |sed -e 's|'"$m"', ||' -e 's|'"$m"'$||' -e 's/,[[:space:]]*,/, /' -e 's/^[[:space:]]*//' -e 's/,[[:space:]]*$//'
{
        my $output_4 = q{};
        my $output_printed_4;
        my $pipeline_success_4 = 1;
        $output_4 .= $l . "\n";
if ( !($output_4 =~ m{\n\z}msx) ) { $output_4 .= "\n"; }
$CHILD_ERROR = 0;

                my @sed_lines_4 = split /\n/msx, $output_4;
        my @sed_result_4;
        foreach my $line (@sed_lines_4) {
        chomp $line;
        push @sed_result_4, $line;
        }
        $output_4 = join "\n", @sed_result_4;
        if ($output_4 ne q{} && !defined $output_printed_4) {
            print $output_4;
            if (!($output_4 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
    return;
}
if ("$_[0]" =~ /^configure$/msx) {
    if ((!-e /usr/local/share/ca-certificates)) {
if (!(        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            use File::Path qw(make_path);
            my $err;
            if ( mkdir do { my ($in_6, $out_6); my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'stat', ''-L'', ''-c'', ''%a'', ''/usr/local''); close $in_6 or croak 'Close failed: $OS_ERROR'; my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> }; close $out_6 or croak 'Close failed: $OS_ERROR'; waitpid $pid_6, 0; $result_6 } ) {
                }
            else {
                croak "mkdir: cannot create directory " . do { my ($in_6, $out_6); my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'stat', ''-L'', ''-c'', ''%a'', ''/usr/local''); close $in_6 or croak 'Close failed: $OS_ERROR'; my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> }; close $out_6 or croak 'Close failed: $OS_ERROR'; waitpid $pid_6, 0; $result_6 } . ": File exists\n";
            }
            if ( mkdir '/usr/local/share/ca-certificates' ) {
                }
            else {
                croak "mkdir: cannot create directory " . '/usr/local/share/ca-certificates' . ": File exists\n";
            }
        })) {
            $main_exit_code = system('chgrp', do { my ($in_7, $out_7); my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'stat', ''-L'', ''-c'', ''%g'', ''/usr/local''); close $in_7 or croak 'Close failed: $OS_ERROR'; my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> }; close $out_7 or croak 'Close failed: $OS_ERROR'; waitpid $pid_7, 0; $result_7 }, '/usr/local/share/ca-certificates') >> 8;
        }
}
    else {
        if (!(!(do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('dpkg-statoverride', '--list', '/usr/local/share/ca-certificates') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };))) {
            chmod(oct(do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'stat', '-L', '-c', '%a', '/usr/local');
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
}), ('/usr/local/share/ca-certificates')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) {
                1;
            }
            do {
    my ($owner, $group) = split /:/, do {
    my ($in_12, $out_12);
    my $pid_12 = open3($in_12, $out_12, '>&STDERR', 'stat', '-L', '-c', '%u', '/usr/local');
    close $in_12 or croak 'Close failed: $OS_ERROR';
    my $result_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
    close $out_12 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_12, 0;
    $result_12
}, 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, (q{:}, do {
    my ($in_13, $out_13);
    my $pid_13 = open3($in_13, $out_13, '>&STDERR', 'stat', '-L', '-c', '%g', '/usr/local');
    close $in_13 or croak 'Close failed: $OS_ERROR';
    my $result_13 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
    close $out_13 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_13, 0;
    $result_13
}, '/usr/local/share/ca-certificates') or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
            if ($CHILD_ERROR != 0) {
                1;
            }
        }
    }
        $main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;
        $main_exit_code = system('db_version', '2.0') >> 8;
        $main_exit_code = system('db_capb', 'multiselect') >> 8;
        $main_exit_code = system('db_metaget', 'ca-certificates/enable_crts', 'choices') >> 8;
        my $CERTS_AVAILABLE;
    my @CERTS_AVAILABLE;
    my %CERTS_AVAILABLE;
    $CERTS_AVAILABLE = "$ENV{RET}";
        $main_exit_code = system('db_get', 'ca-certificates/enable_crts') >> 8;
        my $CERTS_ENABLED;
    my @CERTS_ENABLED;
    my %CERTS_ENABLED;
    $CERTS_ENABLED = "$ENV{RET}";
        $main_exit_code = system('db_fset', 'ca-certificates/new_crts', 'seen', 'false') >> 8;
            $main_exit_code = system('bash', 'db_stop') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
    if ((-f '/etc/ca-certificates.conf')) {
open STDIN, '<', '/etc/ca-certificates.conf' or croak "Cannot open file: $OS_ERROR\n";
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/etc/ca-certificates.conf.dpkg-new'
      or die "Cannot open file: $OS_ERROR\n";
            my $line;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $line = $_fields[0] // q{};
if (!(                # Original bash: echo "$line" | grep -q '^#';
{
                    my $output_16 = q{};
                    my $output_printed_16;
                    my $pipeline_success_16 = 1;
                    $output_16 .= $line . "\n";
if ( !($output_16 =~ m{\n\z}msx) ) { $output_16 .= "\n"; }
$CHILD_ERROR = 0;

                                        my $grep_result_16_1;
                    my @grep_lines_16_1 = split /\n/msx, $output_16;
                    my @grep_filtered_16_1 = grep { /^\#/msx } @grep_lines_16_1;
                    $grep_result_16_1 = join "\n", @grep_filtered_16_1;
                    if (!($grep_result_16_1 =~ m{\n\z}msx || $grep_result_16_1 eq q{})) {
                    $grep_result_16_1 .= "\n";
                    }
                    $CHILD_ERROR = scalar @grep_filtered_16_1 > 0 ? 0 : 1;
                    $grep_result_16_1 = q{};
                    $output_16 = q{};
                    if ((scalar @grep_filtered_16_1) == 0) {
                        $pipeline_success_16 = 0;
                    }
                    if ($output_16 ne q{} && !defined $output_printed_16) {
                        print $output_16;
                        if (!($output_16 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_16 ) { $main_exit_code = 1; }
                    })) {
                    print $line;
if ( !( ($line) =~ m{\n\z}msx ) ) { print "\n"; }
}
                else {
if ("$line" =~ /^!.*$/msx) {
                                                $ca = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                            my $output_17 = q{};
                            my $output_printed_17;
                            my $pipeline_success_17 = 1;
                            $output_17 .= $line . "\n";
                            if ( !($output_17 =~ m{\n\z}msx) ) { $output_17 .= "\n"; }
                            $CHILD_ERROR = 0;
                            if ($CHILD_ERROR != 0) { $pipeline_success_17 = 0; }
                            my @sed_lines_17 = split /\n/msx, $output_17;
                            my @sed_result_17;
                            foreach my $line (@sed_lines_17) {
                            chomp $line;
                            push @sed_result_17, $line;
                            }
                            $output_17 = join "\n", @sed_result_17;

                            if ( !$pipeline_success_17 ) { $main_exit_code = 1; }
                            exit $main_exit_code if $__set_e && $main_exit_code != 0;
                            $output_17 =~ s/\n+\z//msx;
                            $output_17;
}; $_pipeline_result; };
                    } elsif (1) {
                                                $ca = "$line";
                    }
if (!(                    memberp("$ca", "$CERTS_ENABLED"))) {
                        print $ca;
if ( !( ($ca) =~ m{\n\z}msx ) ) { print "\n"; }
}
                    else {
                        if ((!(                        memberp("$ca", "$CERTS_AVAILABLE")) || !({
                            my $output_18 = q{};
                            my $output_printed_18;
                            my $pipeline_success_18 = 1;
                            $output_18 .= $line . "\n";
if ( !($output_18 =~ m{\n\z}msx) ) { $output_18 .= "\n"; }
$CHILD_ERROR = 0;

                                                        my $grep_result_18_1;
                            my @grep_lines_18_1 = split /\n/msx, $output_18;
                            my @grep_filtered_18_1 = grep { /^!/msx } @grep_lines_18_1;
                            $grep_result_18_1 = join "\n", @grep_filtered_18_1;
                            if (!($grep_result_18_1 =~ m{\n\z}msx || $grep_result_18_1 eq q{})) {
                            $grep_result_18_1 .= "\n";
                            }
                            $CHILD_ERROR = scalar @grep_filtered_18_1 > 0 ? 0 : 1;
                            $grep_result_18_1 = q{};
                            $output_18 = q{};
                            if ((scalar @grep_filtered_18_1) == 0) {
                                $pipeline_success_18 = 0;
                            }
                            if ($output_18 ne q{} && !defined $output_printed_18) {
                                print $output_18;
                                if (!($output_18 =~ m{\n\z}msx)) {
                                    print "\n";
                                }
                            }
                            if ( !$pipeline_success_18 ) { $main_exit_code = 1; }
                            }))) {
                            do {
    my $__echo_line = "!$ca";
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
                            if (((-f '/usr/share/ca-certificates/"$ca"') || (-f '/usr/local/share/ca-certificates/"$ca"'))) {
                                print $ca;
if ( !( ($ca) =~ m{\n\z}msx ) ) { print "\n"; }
}
                            else {
                                do {
    my $__echo_line = "!$ca";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                                $CHILD_ERROR = 0;
                            }
                        }
                    }
                }
            }
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
if (!(        # Original bash: echo "$CERTS_ENABLED" | egrep -q "^([[:space:]]*,)*[[:space:]]*$";
{
            my $output_19 = q{};
            my $output_printed_19;
            my $pipeline_success_19 = 1;
            $output_19 .= $CERTS_ENABLED . "\n";
if ( !($output_19 =~ m{\n\z}msx) ) { $output_19 .= "\n"; }
$CHILD_ERROR = 0;

                        my $cmd_21 = 'egrep';
            my ($in_20, $out_20);
            my $pid_20 = open3($in_20, $out_20, '>&STDERR', $cmd_21, '-q');
            print {$in_20} $output_19;
            close $in_20 or croak 'Close failed: $OS_ERROR';
            $output_19 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
            close $out_20 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_20, 0;
            if ($output_19 ne q{} && !defined $output_printed_19) {
                print $output_19;
                if (!($output_19 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_19 ) { $main_exit_code = 1; }
            })) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
            # Original bash: each_value "$CERTS_ENABLED" | while read ca
{
                my $output_22 = q{};
                my $output_printed_22;
                my $pipeline_success_22 = 1;
                                my ($in_23, $out_23);
                my $pid_23 = open3($in_23, $out_23, '>&STDERR', 'each_value', );
                close $in_23 or croak 'Close failed: $OS_ERROR';
                $output_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
                close $out_23 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_23, 0;

                                my @lines = split /\n/msx, $output_22;
                my $result_22_1 = q{};
                for my $line (@lines) {
                chomp $line;
                my $L = $line;
                if (!(my $grep_result_24;
                my @grep_lines_24 = ();
                my @grep_filenames_24 = ();
                if (-e "/etc/ca-certificates.conf.dpkg-new") {
                open my $fh, '<', "/etc/ca-certificates.conf.dpkg-new" or croak "Cannot open file: $ERRNO";
                while (my $line = <$fh>) {
                chomp $line;
                push @grep_lines_24, $line;
                push @grep_filenames_24, "/etc/ca-certificates.conf.dpkg-new";
                }
                close $fh
                or croak "Close failed: $OS_ERROR";
                }
                else { print {*STDERR} "grep: /etc/ca-certificates.conf.dpkg-new: No such file or directory\n"; }
                my @grep_filtered_24 = grep { /^$ca/msx } @grep_lines_24;
                $grep_result_24 = join "\n", @grep_filtered_24;
                if (!($grep_result_24 =~ m{\n\z}msx || $grep_result_24 eq q{})) {
                $grep_result_24 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_24 > 0 ? 0 : 1;
                $grep_result_24 = q{})) {
                $main_exit_code = system('bash', ':') >> 8;
                }
                else {
                do {
                open my $original_stdout, '>&', STDOUT
                or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', '/etc/ca-certificates.conf.dpkg-new'
                or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                my $tmp_redirect_25 = q{};
                $tmp_redirect_25 .= $ca . "\n";
                if ( !($tmp_redirect_25 =~ m{\n\z}msx) ) { $tmp_redirect_25 .= "\n"; }
                $CHILD_ERROR = 0;
                $tmp_redirect_25;
                };
                print $tmp;
                if ($tmp eq q{}) { print $output_22; }
                $output_printed_22 = 1;
                open STDOUT, '>&', $original_stdout
                or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
                or die "Close failed: $OS_ERROR\n";
                };
                }
                }
                $output_22 = $result_22_1;
                if ($output_22 ne q{} && !defined $output_printed_22) {
                    print $output_22;
                    if (!($output_22 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_22 ) { $main_exit_code = 1; }
                exit $main_exit_code if $__set_e && $main_exit_code != 0;
                }
        }
        # Original bash: each_value "$CERTS_AVAILABLE" | while read ca
{
            my $output_27 = q{};
            my $output_printed_27;
            my $pipeline_success_27 = 1;
                        my ($in_28, $out_28);
            my $pid_28 = open3($in_28, $out_28, '>&STDERR', 'each_value', );
            close $in_28 or croak 'Close failed: $OS_ERROR';
            $output_27 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_28> };
            close $out_28 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_28, 0;

                        my @lines = split /\n/msx, $output_27;
            my $result_27_1 = q{};
            for my $line (@lines) {
            chomp $line;
            my $L = $line;
            if (!(            memberp("$ca", "$CERTS_ENABLED"))) {
            $main_exit_code = system('bash', ':') >> 8;
            }
            else {
            if (!(my $grep_result_29;
            my @grep_lines_29 = ();
            my @grep_filenames_29 = ();
            if (-e "/etc/ca-certificates.conf.dpkg-new") {
            open my $fh, '<', "/etc/ca-certificates.conf.dpkg-new" or croak "Cannot open file: $ERRNO";
            while (my $line = <$fh>) {
            chomp $line;
            push @grep_lines_29, $line;
            push @grep_filenames_29, "/etc/ca-certificates.conf.dpkg-new";
            }
            close $fh
            or croak "Close failed: $OS_ERROR";
            }
            else { print {*STDERR} "grep: /etc/ca-certificates.conf.dpkg-new: No such file or directory\n"; }
            my @grep_filtered_29 = grep { /^!$ca/msx } @grep_lines_29;
            $grep_result_29 = join "\n", @grep_filtered_29;
            if (!($grep_result_29 =~ m{\n\z}msx || $grep_result_29 eq q{})) {
            $grep_result_29 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_29 > 0 ? 0 : 1;
            $grep_result_29 = q{})) {
            $main_exit_code = system('bash', ':') >> 8;
            }
            else {
            do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', '/etc/ca-certificates.conf.dpkg-new'
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_30 = q{};
            $tmp_redirect_30 .= "!$ca\n";
            if ( !($tmp_redirect_30 =~ m{\n\z}msx) ) { $tmp_redirect_30 .= "\n"; }
            $CHILD_ERROR = 0;
            $tmp_redirect_30;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_27; }
            $output_printed_27 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            }
            }
            }
            $output_27 = $result_27_1;
            if ($output_27 ne q{} && !defined $output_printed_27) {
                print $output_27;
                if (!($output_27 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_27 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
if (!(        $main_exit_code = system('cmp', '-s', '/etc/ca-certificates.conf', '/etc/ca-certificates.conf.dpkg-new') >> 8)) {
if ( -e "/etc/ca-certificates.conf.dpkg-new" ) {
                if ( -d "/etc/ca-certificates.conf.dpkg-new" ) {
                    carp "rm: carping: ", "/etc/ca-certificates.conf.dpkg-new",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "/etc/ca-certificates.conf.dpkg-new" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "/etc/ca-certificates.conf.dpkg-new",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
}
        else {
            my $force = 1;
            if ( -e '/etc/ca-certificates.conf' ) {
                my $dest = '/etc/ca-certificates.conf.dpkg-old';
                if ( -e $dest && -d $dest ) {
                    my $source_name = '/etc/ca-certificates.conf';
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
                if ( File::Copy::move( '/etc/ca-certificates.conf', $dest ) ) {
                } else {
                    croak
  "mv: cannot move '/etc/ca-certificates.conf' to $dest: $ERRNO\n";
                }
            } else {
                croak "mv: '/etc/ca-certificates.conf': No such file or directory\n";
            }
            if ( -e '/etc/ca-certificates.conf.dpkg-new' ) {
                my $dest = '/etc/ca-certificates.conf';
                if ( -e $dest && -d $dest ) {
                    my $source_name = '/etc/ca-certificates.conf.dpkg-new';
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
                if ( File::Copy::move( '/etc/ca-certificates.conf.dpkg-new', $dest ) ) {
                } else {
                    croak
  "mv: cannot move '/etc/ca-certificates.conf.dpkg-new' to $dest: $ERRNO\n";
                }
            } else {
                croak "mv: '/etc/ca-certificates.conf.dpkg-new': No such file or directory\n";
            }
        }
}
    else {
open my $fh_cat, '>', '/etc/ca-certificates.conf' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "# This file lists certificates that you wish to use or to ignore to be
# installed in /etc/ssl/certs.
# update-ca-certificates(8) will update /etc/ssl/certs by reading this file.
#
# This is autogenerated by dpkg-reconfigure ca-certificates.
# Certificates should be installed under /usr/share/ca-certificates
# and files with extension '.crt' is recognized as available certs.
#
# line begins with # is comment.
# line begins with ! is certificate filename to be deselected.
#
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
        # Original bash: #! /bin/sh
{
            my $output_34 = q{};
            my $output_printed_34;
            my $pipeline_success_34 = 1;
                        $output_34 = q{};
            my @_pcmd_36 = ('sh', '-c', 'echo Variable("CERTS_ENABLED", false, None) | tr , "\\\\n"');
            my ($in_35, $out_35);
            my $pid_35 = open3($in_35, $out_35, '>&STDERR', @_pcmd_36);
            close $in_35 or croak 'Close failed: $OS_ERROR';
            $output_34 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_35> };
            close $out_35 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_35, 0;
            my @_pcmd_38 = ('sh', '-c', 'echo Variable("CERTS_AVAILABLE", false, None) | tr , "\\\\n"');
            my ($in_37, $out_37);
            my $pid_37 = open3($in_37, $out_37, '>&STDERR', @_pcmd_38);
            close $in_37 or croak 'Close failed: $OS_ERROR';
            $output_34 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_37> };
            close $out_37 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_37, 0;

                        my @sed_lines_34 = split /\n/msx, $output_34;
            my @sed_result_34;
            foreach my $line (@sed_lines_34) {
            chomp $line;
            push @sed_result_34, $line;
            }
            $output_34 = join "\n", @sed_result_34;

                        my @sort_lines_34_2 = split /\n/msx, $output_34;
            my @sort_sorted_34_2 = sort @sort_lines_34_2;
            my $output_34_2 = join "\n", @sort_sorted_34_2;
            if ($output_34_2 ne q{} && !($output_34_2 =~ m{\n\z}msx)) {
            $output_34_2 .= "\n";
            }
            $output_34 = $output_34_2;
            $output_34 = $output_34_2;

                        my @uniq_lines_34_3 = split /\n/msx, $output_34;
            @uniq_lines_34_3 = grep { $_ ne q{} } @uniq_lines_34_3; # Filter out empty lines
            my %uniq_counts_34_3;
            my @uniq_order_34_3;
            foreach my $line (@uniq_lines_34_3) {
            if (!exists $uniq_counts_34_3{$line}) { push @uniq_order_34_3, $line; }
            $uniq_counts_34_3{$line}++;
            }
            my @uniq_result_34_3;
            foreach my $line (@uniq_order_34_3) {
            push @uniq_result_34_3, sprintf "%7d %s", $uniq_counts_34_3{$line}, $line;
            }
            my $output_34_3 = join "\n", @uniq_result_34_3;
            if ($output_34_3 ne q{} && !($output_34_3 =~ m{\n\z}msx)) {
            $output_34_3 .= "\n";
            }
            $output_34 = $output_34_3;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', '/etc/ca-certificates.conf'
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_39 = q{};
            my @sed_lines_40 = split /\n/msx, $output_34;
            my @sed_result_40;
            foreach my $line (@sed_lines_40) {
            chomp $line;
            push @sed_result_40, $line;
            }
            $output_34 = join "\n", @sed_result_40;
            $tmp_redirect_39;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_34; }
            $output_printed_34 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_34 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
    }
    if (!(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt-nl', '20111025') >> 8)) {
        $main_exit_code = system('update-ca-certificates', '--hooksdir', "", '--fresh') >> 8;
}
    else {
        $main_exit_code = system('update-ca-certificates', '--hooksdir', "") >> 8;
    }
        $main_exit_code = system('dpkg-trigger', '--no-await', 'update-ca-certificates') >> 8;
} elsif ("$_[0]" =~ /^triggered$/msx) {
        my $trigger;
    for my $trigger ($2) {
if ("$trigger" =~ /^update-ca-certificates$/msx) {
                        $main_exit_code = system('bash', 'update-ca-certificates') >> 8;
        } elsif ("$trigger" =~ /^update-ca-certificates-fresh$/msx) {
                        $main_exit_code = system('update-ca-certificates', '--fresh') >> 8;
        } elsif (1) {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "postinst called with unknown trigger \\" . chr(96) . "$_[1]'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
            exit 1;
        }
    }
} elsif ("$_[0]" =~ /^abort-upgrade$/msx or "$_[0]" =~ /^abort-remove$/msx or "$_[0]" =~ /^abort-deconfigure$/msx) {
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "postinst called with unknown argument \\" . chr(96) . "$_[0]'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    exit 1;
}
exit 0;

exit $main_exit_code;
