#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

$__set_e = 1;
$main_exit_code = system('dpkg-maintscript-helper', 'symlink_to_dir', '/usr/share/doc/zsh', 'zsh-common', '5.0.7-3', '--', "\@ARGV") >> 8;
my $temp_content = '/usr/local/share/zsh/site-functions
/usr/local/share/zsh
';
use File::Path qw(make_path);
if (!-d q{/tmp}) { make_path(q{/tmp}); }
open my $fh_1, '>', q{/tmp} . '/heredoc_temp' or croak "Cannot create temp file: $OS_ERROR\n";
print $fh_1 $temp_content;
close $fh_1 or croak "Close failed: $OS_ERROR\n";
open STDIN, '<', q{/tmp} . '/heredoc_temp' or croak "Cannot open temp file: $OS_ERROR\n";
do {
    local %ENV = %ENV;
    my $dir;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $dir = $_fields[0] // q{};
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
rmdir ("$dir") or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
;
    }
    q{};
};
