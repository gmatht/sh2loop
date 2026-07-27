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

my $NAME;
my @NAME;
my %NAME;

$__set_e = 1;
# set u not implemented

sub usage {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "Usage: $PROGRAM_NAME [--root=path] enable|disable|is-enabled <sysv script name>";
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
    return;
}
my $ROOT;
my @ROOT;
my %ROOT;
$ROOT = q{};
do { my $eval_input = "set" . "--" . q{}; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
while ( 1 ) {
if ("$_[0]" =~ /^-r$/msx or "$_[0]" =~ /^--root$/msx) {
                $ROOT = "$_[1]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--$/msx) {
        # Builtin command 'shift' not implemented
        last;    } elsif (1) {
                usage();
    }
}
$NAME = (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : '') && (defined $_[1] && $_[1] ne q{} ? $_[1] : '') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : '') : '');

sub run {
if (("$ROOT" ne q{} && "$ROOT" ne "/")) {
        my $_SKIP_SYSTEMD_NATIVE = q{1};
        $main_exit_code = system('chroot', "$ROOT", '/usr/sbin/update-rc.d', "@ARGV") >> 8;
}
    else {
        $_SKIP_SYSTEMD_NATIVE = q{1};
        $main_exit_code = system('/usr/sbin/update-rc.d', "@ARGV") >> 8;
    }
    return;
}
if (!("$NAME" ne q{})) {
        usage();
}
if ("$_[0]" =~ /^enable$/msx) {
        run("$NAME", 'defaults');
        run("$NAME", 'enable');
} elsif ("$_[0]" =~ /^disable$/msx) {
        run("$NAME", 'defaults');
        run("$NAME", 'disable');
} elsif ("$_[0]" =~ /^is-enabled$/msx) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my @ls_files_1 = ();
        my $ls_all_found_2 = 1;
        my @ls_inputs_3 = ();
        my @ls_glob_ls_inputs_3_0 = glob('/etc/rc[S5].d/S??');
        if ( !@ls_glob_ls_inputs_3_0 ) {
            push @ls_inputs_3, '/etc/rc[S5].d/S??';
            $ls_all_found_2 = 0;
        } else {
            push @ls_inputs_3, @ls_glob_ls_inputs_3_0;
        }
        my @ls_files_4 = ();
        my @ls_dirs_5 = ();
        my $ls_show_headers_6 = scalar(@ls_inputs_3) > 1;
        for my $ls_item_7 (@ls_inputs_3) {
            if ( -f $ls_item_7 ) {
                push @ls_files_4, $ls_item_7;
            }
            elsif ( -d $ls_item_7 ) {
                push @ls_dirs_5, $ls_item_7;
            }
            else {
                $ls_all_found_2 = 0;
            }
        }
        @ls_files_4 = sort { $a cmp $b } @ls_files_4;
        @ls_dirs_5 = sort { $a cmp $b } @ls_dirs_5;
        if (@ls_files_4) {
            push @ls_files_1, join("\n", @ls_files_4);
        }
        for my $ls_dir_8 (@ls_dirs_5) {
            my @ls_dir_entries_9 = ();
            if ( opendir my $dh, $ls_dir_8 ) {
                while ( my $file = readdir $dh ) {
                    next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                    push @ls_dir_entries_9, $file;
                }
                closedir $dh;
                @ls_dir_entries_9 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_9;
                if ( $ls_show_headers_6 ) {
                    if ( @ls_dir_entries_9 ) {
                        push @ls_files_1, $ls_dir_8 . ":\n" . join("\n", @ls_dir_entries_9);
                    } else {
                        push @ls_files_1, $ls_dir_8 . ':';
                    }
                }
                elsif ( @ls_dir_entries_9 ) {
                    push @ls_files_1, join("\n", @ls_dir_entries_9);
                }
            }
            else {
                $ls_all_found_2 = 0;
            }
        }
        if (@ls_files_1) {
            print join "\n", @ls_files_1;
            print "\n";
        }
        if ( $ls_all_found_2 ) {
            local $CHILD_ERROR = 0;
            $ls_success = 1;
        }
        else {
            local $CHILD_ERROR = 2;
            $ls_success = 0;
            $main_exit_code = $CHILD_ERROR;
        }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
} elsif (1) {
        usage();
}

exit $main_exit_code;
