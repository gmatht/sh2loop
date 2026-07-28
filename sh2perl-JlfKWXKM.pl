#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

my $output         = q{};
our $CHILD_ERROR;

my $i;
my $j;

for my $i ( 1 .. $MAX_LOOP_5 ) {
    say "Number: $i";
}
$i = 5;
for my $i ( 1 .. $MAX_LOOP_3 ) {
    $j = eval { int($j+1) } // "";
}
$i = 3;
say $j;
while ( $i < 10 ) {
    say "Counter: $i";
    $i = eval { int($i + 1) } // "";
}
