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

my $package_name;
my @package_name;
my %package_name;

$__set_e = 1;
$package_name = 'ucf';
if ("$package_name" eq q{}) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        $main_exit_code = system('print', "Internal Error. Please report a bug.") >> 8;
    };
exit 1;
}
if ("$_[0]" =~ /^remove$/msx) {
        $main_exit_code = system('bash', ':') >> 8;
} elsif ("$_[0]" =~ /^purge$/msx) {
    if ( -e "/var/lib/ucf/hashfile" ) {
        if ( -d "/var/lib/ucf/hashfile" ) {
            carp "rm: carping: ", "/var/lib/ucf/hashfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/var/lib/ucf/hashfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/lib/ucf/hashfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    my @files_to_remove = glob("/var/lib/ucf/hashfile.*");
foreach my $file_to_remove (@files_to_remove) {
        if ( -e $file_to_remove ) {
            if ( -d $file_to_remove ) {
                carp "rm: carping: ", $file_to_remove,
    " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink $file_to_remove ) {
                }
                else {
                    local $CHILD_ERROR = 1;
                    carp "rm: carping: could not remove ", $file_to_remove,
    ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    if ( -e "/var/lib/ucf/registry" ) {
        if ( -d "/var/lib/ucf/registry" ) {
            carp "rm: carping: ", "/var/lib/ucf/registry",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/var/lib/ucf/registry" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/lib/ucf/registry",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    my @files_to_remove = glob("/var/lib/ucf/registry.*");
foreach my $file_to_remove (@files_to_remove) {
        if ( -e $file_to_remove ) {
            if ( -d $file_to_remove ) {
                carp "rm: carping: ", $file_to_remove,
    " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink $file_to_remove ) {
                }
                else {
                    local $CHILD_ERROR = 1;
                    carp "rm: carping: could not remove ", $file_to_remove,
    ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    if ((-d '/var/lib/ucf/cache')) {
        # Original bash: find /var/lib/ucf/cache -type f -print0 | xargs -0r /bin/rm -f
{
            my $output_0 = q{};
            my $output_printed_0;
            my $pipeline_success_0 = 1;
                        $output_0 = do {
            require File::Find;
            my @find_results;
            File::Find::find(sub { if (-f $_) { push @find_results, $File::Find::name; } }, '/var/lib/ucf/cache');
            my $result = join "\n", @find_results;
            if ($result ne q{}) { $result .= "\n"; }
            $CHILD_ERROR = 0;
            $result;
            };

                        my @xargs_input_0_1 = grep { $_ ne q{} } split /\s+/msx, $output_0;
            my @xargs_output_0_1;
            for my $i (0..scalar @xargs_input_0_1-1) {
            my @xargs_args_0_1;
            for my $j (0..1-1) {
            push @xargs_args_0_1, $xargs_input_0_1[$i + $j];
            }
            my ($in_0_1, $out_0_1, $err_0_1);
            my $cmd_xargs_0_1 = '/bin/rm';
            my $pid_0_1 = open3($in_0_1, $out_0_1, $err_0_1, $cmd_xargs_0_1, '-f', @xargs_args_0_1);
            close $in_0_1 or croak 'Close failed: $OS_ERROR';
            my $xargs_result_0_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0_1> };
            close $out_0_1 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_0_1, 0;
            chomp $xargs_result_0_1;
            push @xargs_output_0_1, $xargs_result_0_1;
            }
            my $xargs_result_0_1 = join "\n", @xargs_output_0_1;
            if ($xargs_result_0_1 ne q{} && !( $xargs_result_0_1 =~ m{\n\z}msx )) { $xargs_result_0_1 .= "\n"; }
            $output_0 = $xargs_result_0_1;
            $output_0 = $xargs_result_0_1;
            if ($output_0 ne q{} && !defined $output_printed_0) {
                print $output_0;
                if (!($output_0 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
rmdir ('/var/lib/ucf/cache') or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
    if ((-e '/usr/share/debconf/confmodule')) {
        $main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;
        $main_exit_code = system('bash', 'db_purge') >> 8;
    }
} elsif ("$_[0]" =~ /^disappear$/msx) {
    if ((!StringInterpolation(StringInterpolation { parts: [Variable("2")] }, None) eq overwriter)) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$PROGRAM_NAME: undocumented call to \\" . chr(96) . "postrm @ARGV'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
exit 0;
    }
        $main_exit_code = system('bash', ':') >> 8;
} elsif ("$_[0]" =~ /^upgrade$/msx) {
        $main_exit_code = system('bash', ':') >> 8;
} elsif ("$_[0]" =~ /^failed-upgrade$/msx) {
        $main_exit_code = system('bash', ':') >> 8;
} elsif ("$_[0]" =~ /^abort-install$/msx) {
        $main_exit_code = system('bash', ':') >> 8;
    if (StringInterpolation(StringInterpolation { parts: [ParameterExpansion(ParameterExpansion { variable: "2+set", operator: None, is_mutable: true })] }, None) eq set) {
        $main_exit_code = system('bash', ':') >> 8;
}
    else {
        $main_exit_code = system('bash', ':') >> 8;
    }
} elsif ("$_[0]" =~ /^abort-upgrade$/msx) {
        $main_exit_code = system('bash', ':') >> 8;
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "$PROGRAM_NAME: didn't understand being called with \\" . chr(96) . "$_[0]'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    exit 0;
}
if (("$1" eq purge && (-e '/usr/share/debconf/confmodule'))) {
    $main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;
    $main_exit_code = system('bash', 'db_purge') >> 8;
}
exit 0;

exit $main_exit_code;
