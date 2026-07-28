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

my $MAGIC_28    = 28;
my $MAGIC_12    = 12;
my $MAGIC_100   = 100;
my $MAGIC_12345 = 12_345;

print "=== Number Factorization Examples ===\n";

sub factorize {
    my $n = $_[0];
    my $divisor = "2";
    my $factors = "";
    print "Factors of $n: ";
while ( $n > 1 ) {
while ( (eval { int($n % $divisor) } // "") == 0 ) {
if ("$factors" eq q{}) {
                $factors = "$divisor";
}
            else {
                $factors = "$factors * $divisor";
            }
            $n = eval { int($n / $divisor) } // "";
        }
        $divisor = eval { int($divisor + 1) } // "";
if (((eval { int($divisor * $divisor) } // "") > $n)) {
if (($n > 1)) {
if ("$factors" eq q{}) {
                    $factors = "$n";
}
                else {
                    $factors = "$factors * $n";
                }
            }
last;
        }
    }
    print $factors;
if ( !( ($factors) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}
factorize('12');
factorize('28');
factorize('100');
factorize('12345');
print "Factorization complete!\n";

exit $main_exit_code;
