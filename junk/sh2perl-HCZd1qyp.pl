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


sub get_dotnet_runtime_id {
if ("$(uname)" eq "Darwin") {
if ("$(uname -m)" eq "arm64") {
            my $__RuntimeID;
            my @__RuntimeID;
            my %__RuntimeID;
            $__RuntimeID = 'osx-arm64';
}
        else {
            $__RuntimeID = 'osx-x64';
        }
}
    else {
        if ("$(uname -m)" eq "x86_64") {
            $__RuntimeID = 'linux-x64';
if ((-e '/etc/os-release')) {
                $main_exit_code = system('.', '/etc/os-release') >> 8;
if ("$ID" eq "alpine") {
                    $__RuntimeID = 'linux-musl-x64';
                }
            }
}
        else {
            if ("$(uname -m)" eq "armv7l") {
                $__RuntimeID = 'linux-arm';
}
            else {
                if ("$(uname -m)" eq "aarch64") {
                    $__RuntimeID = 'linux-arm64';
if ((-e '/etc/os-release')) {
                        $main_exit_code = system('.', '/etc/os-release') >> 8;
if ("$ID" eq "alpine") {
                            $__RuntimeID = 'linux-musl-arm64';
                        }
                    }
                }
            }
        }
    }
    return;
}
get_dotnet_runtime_id();
my $VSDBGPATH;
my @VSDBGPATH;
my %VSDBGPATH;
$VSDBGPATH = '/remote_debugger/';
$CHILD_ERROR = 0;
$CHILD_ERROR = 0;

exit $main_exit_code;
