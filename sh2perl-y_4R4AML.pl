#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

my $output         = q{};
our $CHILD_ERROR;

my $name = "John Doe";
say "Hello " . $name =~ s/ /_/grs;
say "Length: " . length($name);
say "First: " . substr($name, 0, 4);
say "Last: " . substr($name, -3);
