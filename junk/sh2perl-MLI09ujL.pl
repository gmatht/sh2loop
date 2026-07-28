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

my $TESTEE;
my @TESTEE;
my %TESTEE;
my $RET;
my @RET;
my %RET;

if ((qx'id -u' != 0)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $main_exit_code = system('bash', 'ERR: root needed') >> 8;
exit 1;
}
use strict;
$__set_e = 1;
my $DIR;
my @DIR;
my %DIR;
$DIR = (do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; }) . "/workdir";
my $PKGDIR;
my @PKGDIR;
my %PKGDIR;
$PKGDIR = "$DIR/pkg";
my $LOCDIR;
my @LOCDIR;
my %LOCDIR;
$LOCDIR = "$DIR/loc";
my $PKGNAME;
my @PKGNAME;
my %PKGNAME;
$PKGNAME = "pkgname";
my $PKGF;
my @PKGF;
my %PKGF;
$PKGF = "$PKGDIR/conffile";
my $LOCF;
my @LOCF;
my %LOCF;
$LOCF = "$LOCDIR/conffile";
my $PKGRF;
my @PKGRF;
my %PKGRF;
$PKGRF = "$PKGDIR/renamedconffile";
my $LOCRF;
my @LOCRF;
my %LOCRF;
$LOCRF = "$LOCDIR/renamedconffile";
my $REFDIR;
my @REFDIR;
my %REFDIR;
$REFDIR = "reference";
my $PKGREF;
my @PKGREF;
my %PKGREF;
$PKGREF = "$REFDIR/pkg";
my $LOCREF;
my @LOCREF;
my %LOCREF;
$LOCREF = "$REFDIR/loc";
my $PKGRREF;
my @PKGRREF;
my %PKGRREF;
$PKGRREF = "$REFDIR/renamedpkg";
my $LOCRREF;
my @LOCRREF;
my %LOCRREF;
$LOCRREF = "$REFDIR/renamedloc";
my $LOCNEWF;
my @LOCNEWF;
my %LOCNEWF;
$LOCNEWF = "$DIR/localnewfile";
$TESTEE = "ucf-helper-functions.sh";
if ((-x "./$TESTEE")) {
    $main_exit_code = system('.', './', $TESTEE) >> 8;
}
chdir('tests');
$CHILD_ERROR = 0;

sub cleanup {
    my $fn;
    for my $fn ($LOCF, $LOCNEWF, $LOCRF) {
        $main_exit_code = system('ucf', '--purge', $fn) >> 8;
        $main_exit_code = system('ucfr', '--purge', $PKGNAME, $fn) >> 8;
    }
if ( -e "$DIR" ) {
        if ( -d "$DIR" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$DIR", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", $DIR, ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$DIR" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $DIR,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "$PKGDIR" ) {
        if ( -d "$PKGDIR" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$PKGDIR", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", $PKGDIR, ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$PKGDIR" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $PKGDIR,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "$LOCDIR" ) {
        if ( -d "$LOCDIR" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$LOCDIR", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", $LOCDIR, ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$LOCDIR" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $LOCDIR,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "$REFDIR" ) {
        if ( -d "$REFDIR" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$REFDIR", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", $REFDIR, ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$REFDIR" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $REFDIR,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "result" ) {
        if ( -d "result" ) {
            carp "rm: carping: ", "result",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "result" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "result",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}

sub prepare {
    cleanup();
    use File::Path qw(make_path);
    my $err;
    if ( mkdir $DIR ) {
        }
    else {
        croak "mkdir: cannot create directory " . $DIR . ": File exists\n";
    }
    if ( mkdir $PKGDIR ) {
        }
    else {
        croak "mkdir: cannot create directory " . $PKGDIR . ": File exists\n";
    }
    if ( mkdir $LOCDIR ) {
        }
    else {
        croak "mkdir: cannot create directory " . $LOCDIR . ": File exists\n";
    }
    if ( mkdir $REFDIR ) {
        }
    else {
        croak "mkdir: cannot create directory " . $REFDIR . ": File exists\n";
    }
    use File::Copy qw(copy);
    if ( -e 'package-orig' ) {
        if ( -d $PKGF ) {
            require File::Copy; File::Copy::copy('package-orig', $PKGF . '/' . ('package-orig' =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy('package-orig', $PKGF);
        }
    } else {
        croak "cp: cannot stat 'package-orig': No such file or directory\n";
    }
    return;
}

sub take_ref {
if ((-e "$PKGF")) {
        use File::Copy qw(copy);
        if ( -e $PKGF ) {
            if ( -d $PKGREF ) {
                require File::Copy; File::Copy::copy($PKGF, $PKGREF . '/' . ($PKGF =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy($PKGF, $PKGREF);
            }
        } else {
            croak "cp: cannot stat '$PKGF': No such file or directory\n";
        }
}
    else {
do { my $touch_cmd_str = 'touch Variable("PKGREF", false, None) -deleted'; system $touch_cmd_str; };
    }
if ((-e "$LOCF")) {
        use File::Copy qw(copy);
        if ( -e $LOCF ) {
            if ( -d $LOCREF ) {
                require File::Copy; File::Copy::copy($LOCF, $LOCREF . '/' . ($LOCF =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy($LOCF, $LOCREF);
            }
        } else {
            croak "cp: cannot stat '$LOCF': No such file or directory\n";
        }
}
    else {
do { my $touch_cmd_str = 'touch Variable("LOCREF", false, None) -deleted'; system $touch_cmd_str; };
    }
if ((-e "$PKGRF")) {
        use File::Copy qw(copy);
        if ( -e $PKGRF ) {
            if ( -d $PKGRREF ) {
                require File::Copy; File::Copy::copy($PKGRF, $PKGRREF . '/' . ($PKGRF =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy($PKGRF, $PKGRREF);
            }
        } else {
            croak "cp: cannot stat '$PKGRF': No such file or directory\n";
        }
}
    else {
do { my $touch_cmd_str = 'touch Variable("PKGRREF", false, None) -deleted'; system $touch_cmd_str; };
    }
if ((-e "$LOCRF")) {
        use File::Copy qw(copy);
        if ( -e $LOCRF ) {
            if ( -d $LOCRREF ) {
                require File::Copy; File::Copy::copy($LOCRF, $LOCRREF . '/' . ($LOCRF =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy($LOCRF, $LOCRREF);
            }
        } else {
            croak "cp: cannot stat '$LOCRF': No such file or directory\n";
        }
}
    else {
do { my $touch_cmd_str = 'touch Variable("LOCRREF", false, None) -deleted'; system $touch_cmd_str; };
    }
    return;
}

sub check_ucfq_number {
    my $EXPECTED;
    my @EXPECTED;
    my %EXPECTED;
    $EXPECTED = "$_[0]";
if ($(ucfq --with-colons $PKGNAME | wc -l) ne "$EXPECTED") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
        };
        $CHILD_ERROR = 0;
        # Original bash: ucfq --with-colons $PKGNAME | wc -l
{
            my $output_10 = q{};
            my $output_printed_10;
            my $pipeline_success_10 = 1;
                        my ($in_11, $out_11);
            my $pid_11 = open3($in_11, $out_11, '>&STDERR', 'ucfq', '--with-colons');
            close $in_11 or croak 'Close failed: $OS_ERROR';
            $output_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
            close $out_11 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_11, 0;

                        my $output_10_1 = do {
            my $_wc_data = $output_10;
            my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
            my $_wc_result = q{};
            $_wc_result .= sprintf q{%d}, $_wc_lines;
            $_wc_result .= "\n";
            $_wc_result;
            };
            $output_10 = $output_10_1;
            if ($output_10 ne q{} && !defined $output_printed_10) {
                print $output_10;
                if (!($output_10 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_10 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
        $main_exit_code = system('ucfq', $PKGNAME) >> 8;
return q{1};
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
        };
        $CHILD_ERROR = 0;
return q{0};
    }
    return;
}

sub is_package {
    my $LOCF;
    my $REFF;
    $LOCF = $1;
    $REFF = (defined $_[1] && $_[1] ne q{} ? $_[1] : '$PKGREF');
if (!(!($main_exit_code = system('cmp', $LOCF, $REFF) >> 8;))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
        };
        $CHILD_ERROR = 0;
return q{1};
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
        };
        $CHILD_ERROR = 0;
return q{0};
    }
    return;
}

sub is_local {
    my $LOCF;
    my $REFF;
    $LOCF = $1;
    $REFF = (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : '$LOCREF') && (defined $_[1] && $_[1] ne q{} ? $_[1] : '$LOCREF') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : '$LOCREF') : '$LOCREF');
if (!(!($main_exit_code = system('cmp', $LOCF, $REFF) >> 8;))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
        };
        $CHILD_ERROR = 0;
return q{1};
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
        };
        $CHILD_ERROR = 0;
return q{0};
    }
    return;
}

sub is_deleted {
    $RET = q{0};
    my $FN;
    my @FN;
    my %FN;
    $FN = "$_[0]";
if ((-e "$FN")) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
        };
        $CHILD_ERROR = 0;
        $RET = q{1};
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
        };
        $CHILD_ERROR = 0;
    }
return $RET;
    return;
}

sub print_state {
printf('--', "------- %s\n", (defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '') : ''));
    do {
    my $__echo_line = "ls -alR $DIR";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    my @ls_files_13 = ();
    if ( -f q{.} ) {
        push @ls_files_13, q{.};
    }
    elsif ( -d q{.} ) {
        if ( opendir my $dh, q{.} ) {
            while ( my $file = readdir $dh ) {
                push @ls_files_13, $file;
            }
            closedir $dh;
            @ls_files_13 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_files_13;
        }
    }
    @ls_files_13 = map { my $isdir = (-d $_ || -d ( q{.} . q{/} . $_ )); ($isdir ? 'd ' : '- ') . $_ } @ls_files_13;
    if (@ls_files_13) {
        print join "\n", @ls_files_13;
        print "\n";
    }
    local $CHILD_ERROR = 0;
    $ls_success = 1;
do { my $__head_count = 0; while (<STDIN>) { print $_; last if --$__head_count <= 0; } };
printf("ucfq  knows about %d files\n", (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_17 = q{};
        my $output_printed_17;
        my $pipeline_success_17 = 1;

        my ($in_18, $out_18);
        my $pid_18 = open3($in_18, $out_18, '>&STDERR', 'ucfq', '--with-colons');
        close $in_18 or croak 'Close failed: $OS_ERROR';
        $output_17 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_18> };
        close $out_18 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_18, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_17 = 0; }
        $output_17 = do {
                    my $_wc_data = $output_17;
                    my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
                    my $_wc_result = q{};
                    $_wc_result .= sprintf q{%d}, $_wc_lines;
                    $_wc_result .= "\n";
                    $_wc_result;
                };
        if ( !$pipeline_success_17 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_17 =~ s/\n+\z//msx;
        $output_17;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; }));
    $main_exit_code = system('ucfq', '--with-colons', "$PKGNAME") >> 8;
    return;
}
my $DEBIAN_FRONTEND;
my @DEBIAN_FRONTEND;
my %DEBIAN_FRONTEND;
$DEBIAN_FRONTEND = 'readline';
my $GLOB;
my @GLOB;
my %GLOB;
$GLOB = (defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '*') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '*') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '*') : '*');
my $test;
for my $test ('./test_', $GLOB) {
    prepare();
    $RET = q{0};
delete $ENV{UCF_FORCE_CONFFOLD};
$ENV{-n} = $-n;
$ENV{UCF_FORCE_CONFFOLOLD} = $UCF_FORCE_CONFFOLOLD;
delete $ENV{UCF_FORCE_CONFFNEW};
$ENV{-n} = $-n;
$ENV{UCF_FORCE_CONFFNEW} = $UCF_FORCE_CONFFNEW;
        $main_exit_code = system('.', $test) >> 8;
    if ($CHILD_ERROR != 0) {
                $RET = $?;
    }
if (($RET != 0)) {
        do {
    my $__echo_line = "$test failed";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print_state("$test failed");
        cleanup();
exit 1;
}
    else {
        do {
    my $__echo_line = "$test passed";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    cleanup();
}

exit $main_exit_code;
