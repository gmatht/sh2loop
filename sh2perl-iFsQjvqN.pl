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

$__set_e = 1;

sub run_update_cracklib {
if ((-r '/etc/cracklib/cracklib.conf')) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('bash', 'update-cracklib') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    return;
}
if ("$1" eq "triggered") {
    run_update_cracklib();
exit 0;
}
if (!("$1" eq "configure")) {
    exit 0;
}
run_update_cracklib();
if (!($main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'le', "2.7-17") >> 8)) {
if ((-e '/etc/cron.daily/cracklib')) {
if ( -e "/etc/cron.daily/cracklib-runtime" ) {
            if ( -d "/etc/cron.daily/cracklib-runtime" ) {
                carp "rm: carping: ", "/etc/cron.daily/cracklib-runtime",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "/etc/cron.daily/cracklib-runtime" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/etc/cron.daily/cracklib-runtime",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
        my $err;
        my $force = 0;
        if ( -e '/etc/cron.daily/cracklib' ) {
            my $dest = '/etc/cron.daily/cracklib-runtime';
            if ( -e $dest && -d $dest ) {
                my $source_name = '/etc/cron.daily/cracklib';
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
            if ( File::Copy::move( '/etc/cron.daily/cracklib', $dest ) ) {
            } else {
                croak
  "mv: cannot move '/etc/cron.daily/cracklib' to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: '/etc/cron.daily/cracklib': No such file or directory\n";
        }
    }
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/cron.daily/cracklib-runtime', "2.9.6-5\\", q{~}, 'cracklib-runtime', '--', "@ARGV") >> 8;
exit 0;

exit $main_exit_code;
