#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';


my $DEBIAN_FRONTEND;
my $hook;
my $localsite;

$__set_e = 1;
if ("$_[0]" =~ /^remove$/msx) {
    if ("$DEBIAN_FRONTEND" ne noninteractive) {
        say "Unlinking and removing bytecode for runtime python3.12";
    }
        for my $hook ('/usr/share/python3/runtime.d/*.rtremove') {
        if (!((-x $hook))) {
            next;        }
                $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) {
            next;        }
;
    }
    if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'update-binfmts') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };)) {
        $main_exit_code = system('update-binfmts', '--package', 'python3.12', '--remove', 'python3.12', '/usr/bin/python3.12') >> 8;
    }
        $localsite = '/usr/local/lib/python3.12/dist-packages';
            if ((-d $localsite)) {
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
rmdir ($localsite) or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        };
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
        1;
    }
            if ((-d $(dirname $localsite))) {
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
rmdir (do { use File::Basename qw(dirname); my $dirname_output = dirname($localsite); $CHILD_ERROR = 0; $dirname_output; }) or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        };
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
        1;
    }
} elsif ("$_[0]" =~ /^upgrade$/msx) {
} elsif ("$_[0]" =~ /^deconfigure$/msx) {
} elsif ("$_[0]" =~ /^failed-upgrade$/msx) {
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        say "prerm called with unknown argument \\" . chr(96) . "$_[0]'";
    };
    exit 1;
}
