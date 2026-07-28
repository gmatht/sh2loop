#!/bin/sh
# Verify that embedded Perl code (perl -e) has two-argument opens
# converted to three-argument opens to avoid Perl::Critic violations.
perl -e '
open F, ">/tmp/test.txt" or die;
print F "hello\n";
close F or die;
'
