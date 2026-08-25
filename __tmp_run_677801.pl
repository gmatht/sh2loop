#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);
my $main_exit_code = 0;
my $ls_success = 0;
my $output = '';
our $CHILD_ERROR = 0;
my $d = do { open(my $__fh, '-|', 'bash', '-c', 'mktemp -d') or die "cmd failed: $!\n"; my $_r = do { local $/; <$__fh> }; close $__fh; chomp $_r; $CHILD_ERROR = $? >> 8; $_r; };
$CHILD_ERROR = chdir("${d}") ? 0 : 1;
if ($CHILD_ERROR != 0) {
    exit q{1};
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', 'file.txt'
      or die "Cannot access file: $OS_ERROR\n";
printf("apple\napple\n");
$CHILD_ERROR = 0;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', 'note.txt'
      or die "Cannot access file: $OS_ERROR\n";
printf("hello.txt\n");
$CHILD_ERROR = 0;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', 's.sh'
      or die "Cannot access file: $OS_ERROR\n";
printf("function f() { echo hi; }\n");
$CHILD_ERROR = 0;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
# Original bash: ls | grep "\.txt$" | wc -l
my $output_3 = do { open(my $__fh, '-|', 'bash', '-c', 'ls | grep "\\\\.txt\\$" | wc -l') or die "cmd failed: $!\n"; my $_r = do { local $/; <$__fh> }; close $__fh; chomp $_r; $CHILD_ERROR = $? >> 8; $_r; };
if ($output_3 ne q{}) { print $output_3, "\n"; }
print "\n";
$CHILD_ERROR = 0;
# Original bash: cat file.txt | sort | uniq -c | sort -nr
my $output_4 = do { open(my $__fh, '-|', 'bash', '-c', 'cat file.txt | sort | uniq -c | sort -n -r') or die "cmd failed: $!\n"; my $_r = do { local $/; <$__fh> }; close $__fh; chomp $_r; $CHILD_ERROR = $? >> 8; $_r; };
if ($output_4 ne q{}) { print $output_4, "\n"; }
print "\n";
$CHILD_ERROR = 0;
# Original bash: find . -name "*.sh" | xargs grep -l "function" | tr -d "\\\\/"
my $output_5 = do { open(my $__fh, '-|', 'bash', '-c', q{find . -name '*.sh' | xargs grep -l function | tr -d "\\\\/"}) or die "cmd failed: $!\n"; my $_r = do { local $/; <$__fh> }; close $__fh; chomp $_r; $CHILD_ERROR = $? >> 8; $_r; };
if ($output_5 ne q{}) { print $output_5, "\n"; }
print "\n";
$CHILD_ERROR = 0;
# Original bash: cat file.txt | tr 'a' 'b' | grep 'hello'
my $output_6 = do { open(my $__fh, '-|', 'bash', '-c', 'cat file.txt | tr a b | grep hello') or die "cmd failed: $!\n"; my $_r = do { local $/; <$__fh> }; close $__fh; chomp $_r; $CHILD_ERROR = $? >> 8; $_r; };
if ($output_6 ne q{}) { print $output_6, "\n"; }
print "\n";
$CHILD_ERROR = 0;
# Original bash: cat file.txt | sort | grep 'hello'
my $output_7 = do { open(my $__fh, '-|', 'bash', '-c', 'cat file.txt | sort | grep hello') or die "cmd failed: $!\n"; my $_r = do { local $/; <$__fh> }; close $__fh; chomp $_r; $CHILD_ERROR = $? >> 8; $_r; };
if ($output_7 ne q{}) { print $output_7, "\n"; }
$CHILD_ERROR = chdir(q{/}) ? 0 : 1;
if ( -e "${d}" ) {
    if ( -d "${d}" ) {
        my $err;
        require File::Path;
        File::Path::remove_tree("${d}", {error => \$err});
        if (@{$err}) {
            carp "rm: carping: could not remove ", "${d}", ": $err->[0]\n";
        }
        else {
                    }
    }
    else {
        if ( unlink "${d}" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "${d}",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}

exit ($main_exit_code || $CHILD_ERROR);
