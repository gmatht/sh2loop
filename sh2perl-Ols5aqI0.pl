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

print q{WARNING: git-remote-hg is now maintained independently.
WARNING: For more information visit https://github.com/felipec/git-remote-hg
WARNING:
WARNING: You can pick a directory on your $PATH and download it, e.g.:
WARNING:   $ wget -O $HOME/bin/git-remote-hg \
WARNING:     https://raw.github.com/felipec/git-remote-hg/master/git-remote-hg
WARNING:   $ chmod +x $HOME/bin/git-remote-hg
};

exit $main_exit_code;
