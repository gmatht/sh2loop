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

my $UCF;
my @UCF;
my %UCF;
$UCF = "ucf --three-way --debconf-ok";

sub rename_ucf_file {
    my $oldname;
    my $newname;
    my $UCF_FORCE_CONFFNEW;
    $oldname = "$_[0]";
    $newname = "$_[1]";
if ((!-e "$newname")) {
if ((-e "$oldname")) {
            my $err;
            my $force = 0;
            if ( -e "$oldname" ) {
                my $dest = "$newname";
                if ( -e $dest && -d $dest ) {
                    my $source_name = "$oldname";
                    $source_name =~ s{^.*[\/]}{};
                    $dest = "$dest/$source_name";
                }
                if ( -e $dest && !$force ) {
                    croak "mv: $dest: File exists (use -f to force overwrite)\n";
                }
                my $dest_dir = $dest;
                $dest_dir =~ s/\/[^\/]*$//msx;
                if ( $dest_dir eq $dest ) {
                    $dest_dir = q{};
                }
                if ( $dest_dir ne q{} && !-d $dest_dir ) {
                    my $err;
                    make_path( $dest_dir, { error => \$err } );
                    if ( @{$err} ) {
                        croak "mv: cannot create directory $dest_dir: $err->[0]\n";
                    }
                }
                require File::Copy;
                if ( File::Copy::move( "$oldname", $dest ) ) {
                } else {
                    croak
  "mv: cannot move "$oldname" to $dest: $ERRNO\n";
                }
            } else {
                croak "mv: "$oldname": No such file or directory\n";
            }
        }
my @sed_lines_1 = split /\n/msx, $;
my @sed_result_1;
foreach my $line (@sed_lines_1) {
chomp $line;
push @sed_result_1, $line;
}
$ = join "\n", @sed_result_1;

        $main_exit_code = system('ucfr', '--purge', "$ENV{PKGNAME}", "$oldname") >> 8;
        $main_exit_code = system('ucfr', "$ENV{PKGNAME}", "$newname") >> 8;
    }
    $main_exit_code = system('ucfr', "$ENV{PKGNAME}", "$newname") >> 8;
    return;
}

sub generate_directory_structure {
    my $pkgdir;
    my $locdir;
    $pkgdir = "$_[0]";
    $locdir = "$_[1]";
    # Original bash: #!/bin/sh
{
        my $output_2 = q{};
        my $output_printed_2;
        my $pipeline_success_2 = 1;
                $output_2 = q{};
        my @_pcmd_4 = ('sh', '-c', ': "Complex command cannot be converted to shell command"');
        my ($in_3, $out_3);
        my $pid_3 = open3($in_3, $out_3, '>&STDERR', @_pcmd_4);
        close $in_3 or croak 'Close failed: $OS_ERROR';
        $output_2 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
        close $out_3 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_3, 0;

                $output_2 = q{};
        my @_pcmd_6 = ('sh', '-c', ': "Complex command cannot be converted to shell command"');
        my ($in_5, $out_5);
        my $pid_5 = open3($in_5, $out_5, '>&STDERR', @_pcmd_6);
        close $in_5 or croak 'Close failed: $OS_ERROR';
        $output_2 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
        close $out_5 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_5, 0;
        if ($output_2 ne q{} && !defined $output_printed_2) {
            print $output_2;
            if (!($output_2 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
        }
    return;
}

sub handle_single_ucf_file {
    my $pkgfile;
    my $locfile;
if ("${UCF_HELPER_FUNCTIONS_DEBUG:-}" ne q{}) {
# set -x not implemented
    }
    $pkgfile = "$_[0]";
    $locfile = "$_[1]";
$ENV{DEBIAN_FRONTEND} = $DEBIAN_FRONTEND;
    my $PKG;
    my @PKG;
    my %PKG;
    $PKG = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_7 = q{};
        my $output_printed_7;
        my $pipeline_success_7 = 1;

        my ($in_8, $out_8);
        my $pid_8 = open3($in_8, $out_8, '>&STDERR', 'ucfq', '--with-colons');
        close $in_8 or croak 'Close failed: $OS_ERROR';
        $output_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
        close $out_8 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_8, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_7 = 0; }
        my $num_lines       = 1;
        my $head_line_count = 0;
        my $result          = q{};
        my $input           = $output_7;
        my $pos             = 0;

        while ( $pos < length $input && $head_line_count < $num_lines ) {
            my $line_end = index $input, "\n", $pos;
            if ( $line_end == -1 ) {
                $line_end = length $input;
            }
            my $head_line = substr $input, $pos, $line_end - $pos;
            $result .= $head_line . "\n";
            $pos = $line_end + 1;
            ++$head_line_count;
        }
        $output_7 = $result;

        my @lines_9 = split /\n/msx, $output_7;
        my @result_9;
        foreach my $line (@lines_9) {
        chomp $line;
        my @fields = split /\t/msx, $line;
        if (@fields > 0) {
            push @result_9, $fields[0];
        }
        }
        $output_7 = join "\n", @result_9;
        if ($output_7 ne q{} && !($output_7  =~ m{\n\z}msx)) { $output_7 .= "\n"; }

        if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
        $output_7 =~ s/\n+\z//msx;
        $output_7;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
if (("$PKG" eq q{} || "$PKG" eq "$PKGNAME")) {
        $CHILD_ERROR = 0;
        $main_exit_code = system('ucfr', "$ENV{PKGNAME}", "$ENV{locdir}/$ENV{file}") >> 8;
    }
# set +x not implemented
    return;
}

sub handle_deleted_ucf_file {
    my $locfile;
    my $locdir;
    my $pkgdir;
if ("${UCF_HELPER_FUNCTIONS_DEBUG:-}" ne q{}) {
# set -x not implemented
    }
    $locfile = "$_[0]";
    $pkgdir = "$_[1]";
    $locdir = "$_[2]";
    my $reffile;
    my @reffile;
    my %reffile;
    $reffile = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_10 = q{};
        my $output_printed_10;
        my $pipeline_success_10 = 1;
        $output_10 .= $locfile . "\n";
        if ( !($output_10 =~ m{\n\z}msx) ) { $output_10 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_10 = 0; }
        my @sed_lines_10 = split /\n/msx, $output_10;
        my @sed_result_10;
        foreach my $line (@sed_lines_10) {
        chomp $line;
        push @sed_result_10, $line;
        }
        $output_10 = join "\n", @sed_result_10;

        if ( !$pipeline_success_10 ) { $main_exit_code = 1; }
        $output_10 =~ s/\n+\z//msx;
        $output_10;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
if (!(!((-e "$reffile")))) {
        $CHILD_ERROR = 0;
if (((-s "$locfile") > 0)) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
            my $ext;
            for my $ext (q{}, q{~}, q{%}, '.bak', '.dpkg-tmp', '.dpkg-new', '.dpkg-old', '.dpkg-dist', '.ucf-new', '.ucf-old', '.ucf-dist') {
if ( -e "${locfile} . "$ext"" ) {
                    if ( -d "${locfile} . "$ext"" ) {
                        carp "rm: carping: ", ${locfile} . "$ext",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "${locfile} . "$ext"" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", ${locfile} . "$ext",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
            }
        }
        $main_exit_code = system('ucf', '--purge', ${locfile}) >> 8;
        $main_exit_code = system('ucfr', '--purge', "$ENV{PKGNAME}", ${locfile}) >> 8;
    }
# set +x not implemented
    return;
}

sub handle_all_ucf_files {
    my $pkgdir;
    my $locdir;
    $pkgdir = "$_[0]";
    $locdir = "$_[1]";
    generate_directory_structure("$pkgdir", "$locdir");
    my $file;
    for my $file (do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { if (-f $_) { push @find_results, $File::Find::name; } }, 'rintf');
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
}) {
        handle_single_ucf_file("$pkgdir/$file", "$locdir/$file");
    }
    my $locfile;
    for my $locfile (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_11 = q{};
        my $output_printed_11;
        my $pipeline_success_11 = 1;

        my ($in_12, $out_12);
        my $pid_12 = open3($in_12, $out_12, '>&STDERR', 'ucfq', '--with-colons');
        close $in_12 or croak 'Close failed: $OS_ERROR';
        $output_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
        close $out_12 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_12, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_11 = 0; }
        my @lines_13 = split /\n/msx, $output_11;
        my @result_13;
        foreach my $line (@lines_13) {
        chomp $line;
        my @fields = split /\t/msx, $line;
        if (@fields > 0) {
            push @result_13, $fields[0];
        }
        }
        $output_11 = join "\n", @result_13;
        if ($output_11 ne q{} && !($output_11  =~ m{\n\z}msx)) { $output_11 .= "\n"; }

        if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
        $output_11 =~ s/\n+\z//msx;
        $output_11;
}; $_pipeline_result; }) {
        handle_deleted_ucf_file("$locfile", "$pkgdir", "$locdir");
    }
    return;
}

exit $main_exit_code;
