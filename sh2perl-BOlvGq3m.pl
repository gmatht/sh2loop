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

my $MC_XDG_OPEN;
my @MC_XDG_OPEN;
my %MC_XDG_OPEN;

my $action;
my @action;
my %action;
$action = $1;
my $filetype;
my @filetype;
my %filetype;
$filetype = $2;
my $pager;
my @pager;
my %pager;
$pager = $3;
if (!("${MC_XDG_OPEN}" ne q{})) {
        $MC_XDG_OPEN = "xdg-open";
}

sub get_unpacker {
    $filetype = $1;
if (${filetype} =~ /^man.gz$/msx) {
                my $unpacker;
        my @unpacker;
        my %unpacker;
        $unpacker = "gzip -dc";
    } elsif (${filetype} =~ /^man.bz$/msx) {
                $unpacker = "bzip -dc";
    } elsif (${filetype} =~ /^man.bz2$/msx) {
                $unpacker = "bzip2 -dc";
    } elsif (${filetype} =~ /^man.lz$/msx) {
                $unpacker = "lzip -dc";
    } elsif (${filetype} =~ /^man.lz4$/msx) {
                $unpacker = "lz4 -dc";
    } elsif (${filetype} =~ /^man.lzma$/msx) {
                $unpacker = "lzma -dc";
    } elsif (${filetype} =~ /^man.xz$/msx) {
                $unpacker = "xz -dc";
    } elsif (${filetype} =~ /^man.zst$/msx) {
                $unpacker = "zstd -dc";
    }
    print $unpacker;
if ( !( ($unpacker) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}

sub do_view_action {
    $filetype = $1;
    my $unpacker;
    my @unpacker;
    my %unpacker;
    $unpacker = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'get_unpacker', $filetype);
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
if (${filetype} =~ /^man$/msx) {
        if (($ENV{MC_EXT_FILENAME} // q{}) =~ /^.*/log/.*$/msx or ($ENV{MC_EXT_FILENAME} // q{}) =~ /^.*/logs/.*$/msx) {
            print do { my $cat_chunk = q{}; if ( open my $fh, '<', ($ENV{MC_EXT_FILENAME} // q{}) ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . ($ENV{MC_EXT_FILENAME} // q{}) . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        } elsif (1) {
                        my $MANROFFOPT;
            my @MANROFFOPT;
            my %MANROFFOPT;
            $MANROFFOPT = '-c';
                        my $MAN_KEEP_FORMATTING = q{1};
            $main_exit_code = system('man', '-P', 'cat', ($ENV{MC_EXT_FILENAME} // q{})) >> 8;
        }
    } elsif (${filetype} =~ /^pod$/msx) {
                # Original bash: pod2man "${MC_EXT_FILENAME}" | nroff -c -Tlatin1 -mandoc
{
            my $output_2 = q{};
            my $output_printed_2;
            my $pipeline_success_2 = 1;
                        my ($in_3, $out_3);
            my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'pod2man', );
            close $in_3 or croak 'Close failed: $OS_ERROR';
            $output_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
            close $out_3 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_3, 0;

                        my $cmd_5 = 'nroff';
            my ($in_4, $out_4);
            my $pid_4 = open3($in_4, $out_4, '>&STDERR', $cmd_5, '-c', '-Tlatin1', '-mandoc');
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
    } elsif (${filetype} =~ /^nroff.me$/msx) {
                $main_exit_code = system('nroff', '-c', '-Tlatin1', '-me', ($ENV{MC_EXT_FILENAME} // q{})) >> 8;
    } elsif (${filetype} =~ /^nroff.ms$/msx) {
                $main_exit_code = system('nroff', '-c', '-Tlatin1', '-ms', ($ENV{MC_EXT_FILENAME} // q{})) >> 8;
    } elsif (${filetype} =~ /^man.gz$/msx or ${filetype} =~ /^man.bz$/msx or ${filetype} =~ /^man.bz2$/msx or ${filetype} =~ /^man.lz$/msx or ${filetype} =~ /^man.lz4$/msx or ${filetype} =~ /^man.lzma$/msx or ${filetype} =~ /^man.xz$/msx or ${filetype} =~ /^man.zst$/msx) {
        if (($ENV{MC_EXT_FILENAME} // q{}) =~ /^.*/log/.*$/msx or ($ENV{MC_EXT_FILENAME} // q{}) =~ /^.*/logs/.*$/msx) {
                        $CHILD_ERROR = 0;
        } elsif (1) {
                        $MANROFFOPT = '-c';
                        $MAN_KEEP_FORMATTING = q{1};
            $main_exit_code = system('man', '-P', 'cat', ($ENV{MC_EXT_FILENAME} // q{})) >> 8;
        }
    } elsif (1) {
    }
    return;
}

sub do_open_action {
    $filetype = $1;
    $pager = $2;
    my $unpacker;
    my @unpacker;
    my %unpacker;
    $unpacker = do {
    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'get_unpacker', $filetype);
    close $in_6 or croak 'Close failed: $OS_ERROR';
    my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    $result_6
};
if (${filetype} =~ /^info$/msx) {
                $main_exit_code = system('info', '-f', ($ENV{MC_EXT_FILENAME} // q{})) >> 8;
    } elsif (${filetype} =~ /^man$/msx) {
                # Original bash: #!/bin/sh
{
            my $output_7 = q{};
            my $output_printed_7;
            my $pipeline_success_7 = 1;
                        my @_pcmd_9 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
            my ($in_8);
            my $pid_8 = open3($in_8, $out_8, '>&STDERR', @_pcmd_9);
            close $in_8 or croak 'Close failed: $OS_ERROR';
            my $temp_result;
            $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
            $output_7 = $temp_result;
            close $out_8 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_8, 0;

                        my $cmd_11 = 'unknown_command';
            my ($in_10, $out_10);
            my $pid_10 = open3($in_10, $out_10, '>&STDERR', $cmd_11, );
            print {$in_10} $output_7;
            close $in_10 or croak 'Close failed: $OS_ERROR';
            $output_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
            close $out_10 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_10, 0;
            if ($output_7 ne q{} && !defined $output_printed_7) {
                print $output_7;
                if (!($output_7 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
            }
    } elsif (${filetype} =~ /^pod$/msx) {
                # Original bash: pod2man "${MC_EXT_FILENAME}" | nroff -c -Tlatin1 -mandoc | ${pager}
{
            my $output_12 = q{};
            my $output_printed_12;
            my $pipeline_success_12 = 1;
                        my ($in_13, $out_13);
            my $pid_13 = open3($in_13, $out_13, '>&STDERR', 'pod2man', );
            close $in_13 or croak 'Close failed: $OS_ERROR';
            $output_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
            close $out_13 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_13, 0;

                        my $cmd_15 = 'nroff';
            my ($in_14, $out_14);
            my $pid_14 = open3($in_14, $out_14, '>&STDERR', $cmd_15, '-c', '-Tlatin1', '-mandoc');
            print {$in_14} $output_12;
            close $in_14 or croak 'Close failed: $OS_ERROR';
            $output_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_14> };
            close $out_14 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_14, 0;

                        my $cmd_17 = 'unknown_command';
            my ($in_16, $out_16);
            my $pid_16 = open3($in_16, $out_16, '>&STDERR', $cmd_17, );
            print {$in_16} $output_12;
            close $in_16 or croak 'Close failed: $OS_ERROR';
            $output_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_16> };
            close $out_16 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_16, 0;
            if ($output_12 ne q{} && !defined $output_printed_12) {
                print $output_12;
                if (!($output_12 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
            }
    } elsif (${filetype} =~ /^nroff.me$/msx) {
                # Original bash: nroff -c -Tlatin1 -me "${MC_EXT_FILENAME}" | ${pager}
{
            my $output_18 = q{};
            my $output_printed_18;
            my $pipeline_success_18 = 1;
                        my ($in_19, $out_19);
            my $pid_19 = open3($in_19, $out_19, '>&STDERR', 'nroff', '-c', '-Tlatin1', '-me');
            close $in_19 or croak 'Close failed: $OS_ERROR';
            $output_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19> };
            close $out_19 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_19, 0;

                        my $cmd_21 = 'unknown_command';
            my ($in_20, $out_20);
            my $pid_20 = open3($in_20, $out_20, '>&STDERR', $cmd_21, );
            print {$in_20} $output_18;
            close $in_20 or croak 'Close failed: $OS_ERROR';
            $output_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
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
    } elsif (${filetype} =~ /^nroff.ms$/msx) {
                # Original bash: nroff -c -Tlatin1 -ms "${MC_EXT_FILENAME}" | ${pager}
{
            my $output_22 = q{};
            my $output_printed_22;
            my $pipeline_success_22 = 1;
                        my ($in_23, $out_23);
            my $pid_23 = open3($in_23, $out_23, '>&STDERR', 'nroff', '-c', '-Tlatin1', '-ms');
            close $in_23 or croak 'Close failed: $OS_ERROR';
            $output_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
            close $out_23 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_23, 0;

                        my $cmd_25 = 'unknown_command';
            my ($in_24, $out_24);
            my $pid_24 = open3($in_24, $out_24, '>&STDERR', $cmd_25, );
            print {$in_24} $output_22;
            close $in_24 or croak 'Close failed: $OS_ERROR';
            $output_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_24> };
            close $out_24 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_24, 0;
            if ($output_22 ne q{} && !defined $output_printed_22) {
                print $output_22;
                if (!($output_22 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_22 ) { $main_exit_code = 1; }
            }
    } elsif (${filetype} =~ /^man.gz$/msx or ${filetype} =~ /^man.bz$/msx or ${filetype} =~ /^man.bz2$/msx or ${filetype} =~ /^man.lz$/msx or ${filetype} =~ /^man.lz4$/msx or ${filetype} =~ /^man.lzma$/msx or ${filetype} =~ /^man.xz$/msx or ${filetype} =~ /^man.zst$/msx) {
                # Original bash: #!/bin/sh
{
            my $output_26 = q{};
            my $output_printed_26;
            my $pipeline_success_26 = 1;
                        my @_pcmd_28 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
            my ($in_27);
            my $pid_27 = open3($in_27, $out_27, '>&STDERR', @_pcmd_28);
            close $in_27 or croak 'Close failed: $OS_ERROR';
            my $temp_result;
            $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_27> };
            $output_26 = $temp_result;
            close $out_27 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_27, 0;

                        my $cmd_30 = 'unknown_command';
            my ($in_29, $out_29);
            my $pid_29 = open3($in_29, $out_29, '>&STDERR', $cmd_30, );
            print {$in_29} $output_26;
            close $in_29 or croak 'Close failed: $OS_ERROR';
            $output_26 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_29> };
            close $out_29 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_29, 0;
            if ($output_26 ne q{} && !defined $output_printed_26) {
                print $output_26;
                if (!($output_26 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_26 ) { $main_exit_code = 1; }
            }
    } elsif (${filetype} =~ /^chm$/msx) {
        if ("$DISPLAY" ne q{}) {
                        if (do {
                                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'kchmviewer';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
            } == 0) {
                                do {
                    local %ENV = %ENV;
                    my $action = $action;
                    my $pager = $pager;
                    my $unpacker = $unpacker;
                    my $filetype = $filetype;
                    if (my $pid = fork()) {
                        # Parent process continues
                    } elsif (defined $pid) {
                        # Child process executes the background command
                        $main_exit_code = system('kchmviewer', ($ENV{MC_EXT_FILENAME} // q{})) >> 8;
                        exit(0);
                    } else {
                        die "Cannot fork: $ERRNO\n";
                    }
                    q{};
                };
            }
            if ($CHILD_ERROR != 0) {
                                do {
                    local %ENV = %ENV;
                    my $action = $action;
                    my $pager = $pager;
                    my $unpacker = $unpacker;
                    my $filetype = $filetype;
                    if (my $pid = fork()) {
                        # Parent process continues
                    } elsif (defined $pid) {
                        # Child process executes the background command
                        $main_exit_code = system('xchm', ($ENV{MC_EXT_FILENAME} // q{})) >> 8;
                        exit(0);
                    } else {
                        die "Cannot fork: $ERRNO\n";
                    }
                    q{};
                };
            }
}
        else {
            if (my $pid = fork()) {
                # Parent process continues
            } elsif (defined $pid) {
                # Child process executes the background command
                $main_exit_code = system('chm_http', ($ENV{MC_EXT_FILENAME} // q{})) >> 8;
                exit(0);
            } else {
                die "Cannot fork: $ERRNO\n";
            }
            $main_exit_code = system('elinks', 'http://localhost:8080/index.html') >> 8;
my $signal = 'INT';
my @pids = ('%1');
foreach my $pid (@pids) {
if ($pid =~ /^\\d+$/msx) {
my $result = kill $signal, $pid;
if ($result) {
print "Sent signal $signal to process $pid\n";
} else {
print {*STDERR} "kill: ($pid) - No such process\n";
}
} else {
print {*STDERR} "kill: invalid process id: $pid\n";
}
}
        }
    } elsif (1) {
    }
    return;
}
if (${action} =~ /^view$/msx) {
        do_view_action(${filetype});
} elsif (${action} =~ /^open$/msx) {
            do {
        local %ENV = %ENV;
        my $pager = $pager;
        my $action = $action;
        my $filetype = $filetype;
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        q{};
    };
    if ($CHILD_ERROR != 0) {
                do_open_action(${filetype}, ${pager});
    }
} elsif (1) {
}

exit $main_exit_code;
