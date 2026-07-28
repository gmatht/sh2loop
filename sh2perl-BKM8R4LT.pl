#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';


my $python;
my $files;

$__set_e = 1;
my $versions = "3.12";
if ("$_[0]" =~ /^configure$/msx) {
        my $v;
    for my $v ($versions) {
        $python = 'python';
        $CHILD_ERROR = 0;
        if (!((-x '/usr/bin/$python'))) {
            next;
        }
        $files = do {
    do { do {
            my $output_0 = q{};
            my $output_printed_0;
            my $pipeline_success_0 = 1;

            my ($in_1, $out_1);
            my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'dpkg', '-L', 'python3-lib2to3');
            close $in_1 or croak 'Close failed: $OS_ERROR';
            $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
            close $out_1 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_1, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
            my @sed_lines_0 = split /\n/, $output_0;
            my @sed_result_0;
            foreach my $line (@sed_lines_0) {
            chomp $line;
            push @sed_result_0, $line;
            }
            $output_0 = join "\n", @sed_result_0;

            if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_0 =~ s/\n+\z//msx;
            $output_0;
}; };
};
if ("$files" ne q{}) {
            $main_exit_code = system('/usr/bin/', $python, '-E', '-S', '/usr/lib/', $python, '/py_compile.py', $files) >> 8;
if (!(my $grep_result_2;
my @grep_lines_2 = ();
my @grep_filenames_2 = ();
my @glob_files_2 = glob('^byte-compile[^#]*optimize');
for my $glob_file (@glob_files_2) {
    if (-f $glob_file) {
        open my $fh, '<', $glob_file or die "Cannot open $glob_file: $ERRNO";
        while (my $line = <$fh>) {
            chomp $line;
            push @grep_lines_2, $line;
            push @grep_filenames_2, $glob_file;
        }
        close $fh
            or croak "Close failed: $OS_ERROR";
    }
}
if (-e "/etc/python/debian_config") {
    open my $fh, '<', "/etc/python/debian_config" or croak "Cannot access file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_2, $line;
        push @grep_filenames_2, "/etc/python/debian_config";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/python/debian_config: No such file or directory\n"; }
my @grep_filtered_2 = grep { /q/msx } @grep_lines_2;
$grep_result_2 = join "\n", @grep_filtered_2;
            if (!($grep_result_2 =~ m{\n\z} || $grep_result_2 eq q{})) {
                $grep_result_2 .= "\n";
            }
print $grep_result_2;
$CHILD_ERROR = scalar @grep_filtered_2 > 0 ? 0 : 1)) {
                $main_exit_code = system('/usr/bin/', $python, '-E', '-S', '-O', '/usr/lib/', $python, '/py_compile.py', $files) >> 8;
            }
}
        else {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                say "$python: can't get files for byte-compilation";
            };
        }
    }
    if (("$2" ne q{} && !(system('dpkg', '--compare-versions', $2, 'lt', '3.7.2-3', q{~}) >> 8))) {
        # Original bash: find /usr/lib/python3.6/lib2to3 -name __pycache__ | xargs -r rm -rf
do {
            my $output_3 = q{};
            my $output_printed_3;
            my $pipeline_success_3 = 1;
                        $output_3 = do {
            require File::Find;
            my @find_results;
            File::Find::find(sub { if ($_ =~ /^__pycache__$/) { push @find_results, $File::Find::name; } }, '/usr/lib/python3.6/lib2to3');
            my $result = join "\n", @find_results;
            if ($result ne q{}) { $result .= "\n"; }
            $CHILD_ERROR = 0;
            $result;
            };

                        my @xargs_input_3_1 = grep { $_ ne q{} } split /\s+/, $output_3;
            my @xargs_output_3_1;
            for my $i (0..scalar @xargs_input_3_1-1) {
            my @xargs_args_3_1;
            for my $j (0..1-1) {
            push @xargs_args_3_1, $xargs_input_3_1[$i + $j];
            }
            my ($in_3_1, $out_3_1, $err_3_1);
            my $cmd_xargs_3_1 = 'rm';
            my $pid_3_1 = open3($in_3_1, $out_3_1, $err_3_1, $cmd_xargs_3_1, '-r', 'f', @xargs_args_3_1);
            close $in_3_1 or croak 'Close failed: $OS_ERROR';
            my $xargs_result_3_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3_1> };
            close $out_3_1 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_3_1, 0;
            chomp $xargs_result_3_1;
            push @xargs_output_3_1, $xargs_result_3_1;
            }
            my $xargs_result_3_1 = join "\n", @xargs_output_3_1;
            if ($xargs_result_3_1 ne q{} && !( $xargs_result_3_1 =~ m{\n\z} )) { $xargs_result_3_1 .= "\n"; }
            $output_3 = $xargs_result_3_1;
            $output_3 = $xargs_result_3_1;
            if ($output_3 ne q{} && !defined $output_printed_3) {
                print $output_3;
                if (!($output_3 =~ m{\n\z})) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
;
                require File::Find;
        File::Find::find(sub {     next unless -d $_;     print "$File::Find::name\n"; }, '/usr/lib/python3.6/lib2to3');
        if ($CHILD_ERROR != 0) {
            1;
        }
;
                require File::Find;
        File::Find::find(sub {     next unless -d $_;     my $depth = ($File::Find::dir =~ tr/\///) + 1; next if $depth > 0;     print "$File::Find::name\n"; }, '/usr/lib/python3.6');
        if ($CHILD_ERROR != 0) {
            1;
        }
;
    }
    if (("$2" ne q{} && !(system('dpkg', '--compare-versions', $2, 'lt', '3.8.3-2', q{~}) >> 8))) {
        # Original bash: find /usr/lib/python3.7/lib2to3 -name __pycache__ | xargs -r rm -rf
do {
            my $output_6 = q{};
            my $output_printed_6;
            my $pipeline_success_6 = 1;
                        $output_6 = do {
            require File::Find;
            my @find_results;
            File::Find::find(sub { if ($_ =~ /^__pycache__$/) { push @find_results, $File::Find::name; } }, '/usr/lib/python3.7/lib2to3');
            my $result = join "\n", @find_results;
            if ($result ne q{}) { $result .= "\n"; }
            $CHILD_ERROR = 0;
            $result;
            };

                        my @xargs_input_6_1 = grep { $_ ne q{} } split /\s+/, $output_6;
            my @xargs_output_6_1;
            for my $i (0..scalar @xargs_input_6_1-1) {
            my @xargs_args_6_1;
            for my $j (0..1-1) {
            push @xargs_args_6_1, $xargs_input_6_1[$i + $j];
            }
            my ($in_6_1, $out_6_1, $err_6_1);
            my $cmd_xargs_6_1 = 'rm';
            my $pid_6_1 = open3($in_6_1, $out_6_1, $err_6_1, $cmd_xargs_6_1, '-r', 'f', @xargs_args_6_1);
            close $in_6_1 or croak 'Close failed: $OS_ERROR';
            my $xargs_result_6_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6_1> };
            close $out_6_1 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_6_1, 0;
            chomp $xargs_result_6_1;
            push @xargs_output_6_1, $xargs_result_6_1;
            }
            my $xargs_result_6_1 = join "\n", @xargs_output_6_1;
            if ($xargs_result_6_1 ne q{} && !( $xargs_result_6_1 =~ m{\n\z} )) { $xargs_result_6_1 .= "\n"; }
            $output_6 = $xargs_result_6_1;
            $output_6 = $xargs_result_6_1;
            if ($output_6 ne q{} && !defined $output_printed_6) {
                print $output_6;
                if (!($output_6 =~ m{\n\z})) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
;
                require File::Find;
        File::Find::find(sub {     next unless -d $_;     print "$File::Find::name\n"; }, '/usr/lib/python3.7/lib2to3');
        if ($CHILD_ERROR != 0) {
            1;
        }
;
                require File::Find;
        File::Find::find(sub {     next unless -d $_;     my $depth = ($File::Find::dir =~ tr/\///) + 1; next if $depth > 0;     print "$File::Find::name\n"; }, '/usr/lib/python3.7');
        if ($CHILD_ERROR != 0) {
            1;
        }
;
    }
    if (("$2" ne q{} && !(system('dpkg', '--compare-versions', $2, 'lt', '3.9.1-2', q{~}) >> 8))) {
        # Original bash: find /usr/lib/python3.8/lib2to3 -name __pycache__ 2>/dev/null | xargs -r rm -rf
do {
            my $output_9 = q{};
            my $output_printed_9;
            my $pipeline_success_9 = 1;
                        $output = q{};
                        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
my $tmp_redirect_10 = q{};
$tmp_redirect_10 = do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { if ($_ =~ /^__pycache__$/) { push @find_results, $File::Find::name; } }, '/usr/lib/python3.8/lib2to3');
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
};
$tmp_redirect_10;
            };
            $output_9 = $output;

                        my @xargs_input_9_1 = grep { $_ ne q{} } split /\s+/, $output_9;
            my @xargs_output_9_1;
            for my $i (0..scalar @xargs_input_9_1-1) {
            my @xargs_args_9_1;
            for my $j (0..1-1) {
            push @xargs_args_9_1, $xargs_input_9_1[$i + $j];
            }
            my ($in_9_1, $out_9_1, $err_9_1);
            my $cmd_xargs_9_1 = 'rm';
            my $pid_9_1 = open3($in_9_1, $out_9_1, $err_9_1, $cmd_xargs_9_1, '-r', 'f', @xargs_args_9_1);
            close $in_9_1 or croak 'Close failed: $OS_ERROR';
            my $xargs_result_9_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9_1> };
            close $out_9_1 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_9_1, 0;
            chomp $xargs_result_9_1;
            push @xargs_output_9_1, $xargs_result_9_1;
            }
            my $xargs_result_9_1 = join "\n", @xargs_output_9_1;
            if ($xargs_result_9_1 ne q{} && !( $xargs_result_9_1 =~ m{\n\z} )) { $xargs_result_9_1 .= "\n"; }
            $output_9 = $xargs_result_9_1;
            $output_9 = $xargs_result_9_1;
            if ($output_9 ne q{} && !defined $output_printed_9) {
                print $output_9;
                if (!($output_9 =~ m{\n\z})) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
;
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
            require File::Find;
            File::Find::find(sub {     next unless -d $_;     print "$File::Find::name\n"; }, '/usr/lib/python3.8/lib2to3');
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
;
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
            require File::Find;
            File::Find::find(sub {     next unless -d $_;     my $depth = ($File::Find::dir =~ tr/\///) + 1; next if $depth > 0;     print "$File::Find::name\n"; }, '/usr/lib/python3.8');
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
;
    }
    if (("$2" ne q{} && !(system('dpkg', '--compare-versions', $2, 'lt', '3.10.8-1', q{~}) >> 8))) {
        # Original bash: find /usr/lib/python3.9/lib2to3 -name __pycache__ 2>/dev/null | xargs -r rm -rf
do {
            my $output_14 = q{};
            my $output_printed_14;
            my $pipeline_success_14 = 1;
                        $output = q{};
                        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
my $tmp_redirect_15 = q{};
$tmp_redirect_15 = do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { if ($_ =~ /^__pycache__$/) { push @find_results, $File::Find::name; } }, '/usr/lib/python3.9/lib2to3');
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
};
$tmp_redirect_15;
            };
            $output_14 = $output;

                        my @xargs_input_14_1 = grep { $_ ne q{} } split /\s+/, $output_14;
            my @xargs_output_14_1;
            for my $i (0..scalar @xargs_input_14_1-1) {
            my @xargs_args_14_1;
            for my $j (0..1-1) {
            push @xargs_args_14_1, $xargs_input_14_1[$i + $j];
            }
            my ($in_14_1, $out_14_1, $err_14_1);
            my $cmd_xargs_14_1 = 'rm';
            my $pid_14_1 = open3($in_14_1, $out_14_1, $err_14_1, $cmd_xargs_14_1, '-r', 'f', @xargs_args_14_1);
            close $in_14_1 or croak 'Close failed: $OS_ERROR';
            my $xargs_result_14_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_14_1> };
            close $out_14_1 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_14_1, 0;
            chomp $xargs_result_14_1;
            push @xargs_output_14_1, $xargs_result_14_1;
            }
            my $xargs_result_14_1 = join "\n", @xargs_output_14_1;
            if ($xargs_result_14_1 ne q{} && !( $xargs_result_14_1 =~ m{\n\z} )) { $xargs_result_14_1 .= "\n"; }
            $output_14 = $xargs_result_14_1;
            $output_14 = $xargs_result_14_1;
            if ($output_14 ne q{} && !defined $output_printed_14) {
                print $output_14;
                if (!($output_14 =~ m{\n\z})) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_14 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
;
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
            require File::Find;
            File::Find::find(sub {     next unless -d $_;     print "$File::Find::name\n"; }, '/usr/lib/python3.9/lib2to3');
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
;
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
            require File::Find;
            File::Find::find(sub {     next unless -d $_;     my $depth = ($File::Find::dir =~ tr/\///) + 1; next if $depth > 0;     print "$File::Find::name\n"; }, '/usr/lib/python3.9');
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
;
    }
}
exit 0;
