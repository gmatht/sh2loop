#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

$__set_e = 1;
if ("$_[0]" =~ /^install$/msx or "$_[0]" =~ /^upgrade$/msx) {
    if ((-e '/usr/share/doc/bash/completion-contrib')) {
if ( -e "/usr/share/doc/bash/completion-contrib" ) {
            if ( -d "/usr/share/doc/bash/completion-contrib" ) {
                my $err;
                require File::Path;
                File::Path::remove_tree("/usr/share/doc/bash/completion-contrib", {error => \$err});
                if (@{$err}) {
                    carp "rm: carping: could not remove ", "/usr/share/doc/bash/completion-contrib", ": $err->[0]\n";
                }
                else {
                                    }
            }
            else {
                if ( unlink "/usr/share/doc/bash/completion-contrib" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/usr/share/doc/bash/completion-contrib",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
        my $f;
    for my $f (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;

        my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'dpkg-query', '-W', '-f', q{=}, "${Conffiles}\\n", 'bash-completion');
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
        my $grep_result_0_1;
        my @grep_lines_0_1 = split /\n/msx, $output_0;
        my @grep_filtered_0_1 = grep { /bash_completion.d/msx } @grep_lines_0_1;
        $grep_result_0_1 = join "\n", @grep_filtered_0_1;
                if (!($grep_result_0_1 =~ m{\n\z}msx || $grep_result_0_1 eq q{})) {
                    $grep_result_0_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_0_1 > 0 ? 0 : 1;
        $output_0 = $grep_result_0_1;
        my @lines_2 = split /\n/msx, $output_0;
        my @result_2;
        foreach my $line (@lines_2) {
        chomp $line;
        my @fields = split /\\ \ /msx, $line;
        if (@fields > 1) {
            push @result_2, $fields[1];
        }
        }
        $output_0 = join "\n", @result_2;
        if ($output_0 ne q{} && !($output_0  =~ m{\n\z}msx)) { $output_0 .= "\n"; }

        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_0 =~ s/\n+\z//msx;
        $output_0;
}; $_pipeline_result; }) {
        $main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', $f, '1:1.3-1', '--', "@ARGV") >> 8;
    }
    if ((((!(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt-nl', '1:2.0-1') >> 8) && !(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'ge', '1:1.99-2') >> 8)) && (-l '/etc/bash_completion')) && "$(readlink /etc/bash_completion)" eq /usr/share/bash-completion/bash_completion)) {
if ( -e "/etc/bash_completion" ) {
            if ( -d "/etc/bash_completion" ) {
                carp "rm: carping: ", "/etc/bash_completion",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "/etc/bash_completion" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/etc/bash_completion",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
} elsif ("$_[0]" =~ /^abort-upgrade$/msx) {
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "preinst called with unknown argument \\" . chr(96) . "$_[0]'";
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
