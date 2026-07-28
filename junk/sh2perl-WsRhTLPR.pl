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

$main_exit_code = system('.', './setup-vars') >> 8;
$main_exit_code = system('.', './setup-edit') >> 8;
open my $fh_cat, '>', '$input' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "Hi, this is an edit box. It can be used to edit text from a file.

It's like a simple text editor, with these keys implemented:

PGDN\t- Move down one page
PGUP\t- Move up one page
DOWN\t- Move down one line
UP\t- Move up one line
DELETE\t- Delete the current character
BACKSPC\t- Delete the previous character

Unlike Xdialog, it does not do these:

CTRL C\t- Copy text
CTRL V\t- Paste text

Because dialog normally uses TAB for moving between fields,
this editbox uses CTRL/V as a literal-next character.  You
can enter TAB characters by first pressing CTRL/V.  This
example contains a few tab characters.

It supports the mouse - but only for positioning in the editbox,
or for clicking on buttons.  Your terminal (emulator) may support
cut/paste.

Try to input some text below:

";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
do {
local *STDERR;
open STDERR, '>', $output or croak "Cannot open file: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
my $returncode;
my @returncode;
my %returncode;
$returncode = $?;
$main_exit_code = system('.', './report-edit') >> 8;

exit $main_exit_code;
