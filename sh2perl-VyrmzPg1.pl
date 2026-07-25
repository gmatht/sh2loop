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

$__set_e = 1;
if ((!-e /etc/initramfs-tools/modules)) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/etc/initramfs-tools/modules'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
my @sed_lines_0 = split /\n/msx, $;
my @sed_result_0;
foreach my $line (@sed_lines_0) {
chomp $line;
push @sed_result_0, $line;
}
$ = join "\n", @sed_result_0;

        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
my $mvverbose;
my @mvverbose;
my %mvverbose;
$mvverbose = '-v';

sub ensure_package_owns_file {
    my $PACKAGE = "$_[0]";
    my $FILE = "$_[1]";
    # Original bash: dpkg-query -L "$PACKAGE" | grep -F -q -x "$FILE"
{
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
                my ($in_2, $out_2);
        my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'dpkg-query', '-L');
        close $in_2 or croak 'Close failed: $OS_ERROR';
        $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
        close $out_2 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_2, 0;

                my $grep_result_1_1;
        my @grep_lines_1_1 = split /\n/msx, $output_1;
        my @grep_filtered_1_1 = grep { /$FILE/msx } @grep_lines_1_1;
        $grep_result_1_1 = join "\n", @grep_filtered_1_1;
        if (!($grep_result_1_1 =~ m{\n\z}msx || $grep_result_1_1 eq q{})) {
        $grep_result_1_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_1_1 > 0 ? 0 : 1;
        $grep_result_1_1 = q{};
        $output_1 = q{};
        if ((scalar @grep_filtered_1_1) == 0) {
            $pipeline_success_1 = 0;
        }
        if ($output_1 ne q{} && !defined $output_printed_1) {
            print $output_1;
            if (!($output_1 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
    return;
}

sub finish_mv_conffile {
    my $CONFFILE = "$_[0]";
    my $PACKAGE = "$_[1]";
if ( -e "$mvverbose" ) {
        if ( -d "$mvverbose" ) {
            carp "rm: carping: ", $mvverbose,
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$mvverbose" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $mvverbose,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "$CONFFILE.dpkg-remove" ) {
        if ( -d "$CONFFILE.dpkg-remove" ) {
            carp "rm: carping: ", "$CONFFILE.dpkg-remove",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$CONFFILE.dpkg-remove" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$CONFFILE.dpkg-remove",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if (!((-e "$CONFFILE.dpkg-backup"))) {
        return q{0};    }
        ensure_package_owns_file("$PACKAGE", "$CONFFILE");
    if ($CHILD_ERROR != 0) {
        return q{0};    }
    do {
    my $__echo_line = "Preserving user changes to $CONFFILE (now owned by $PACKAGE)...";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if ((-e "$CONFFILE")) {
        my $err;
        my $force = 1;
        if ( -e "$mvverbose" ) {
            my $dest = "$CONFFILE.dpkg-new";
            if ( -e $dest && -d $dest ) {
                my $source_name = "$mvverbose";
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
            if ( File::Copy::move( "$mvverbose", $dest ) ) {
            } else {
                croak
  "mv: cannot move "$mvverbose" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "$mvverbose": No such file or directory\n";
        }
        if ( -e "$CONFFILE" ) {
            my $dest = "$CONFFILE.dpkg-new";
            if ( -e $dest && -d $dest ) {
                my $source_name = "$CONFFILE";
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
            if ( File::Copy::move( "$CONFFILE", $dest ) ) {
            } else {
                croak
  "mv: cannot move "$CONFFILE" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "$CONFFILE": No such file or directory\n";
        }
    }
    if ( -e "$mvverbose" ) {
        my $dest = "$CONFFILE";
        if ( -e $dest && -d $dest ) {
            my $source_name = "$mvverbose";
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
        if ( File::Copy::move( "$mvverbose", $dest ) ) {
        } else {
            croak
  "mv: cannot move "$mvverbose" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "$mvverbose": No such file or directory\n";
    }
    if ( -e "$CONFFILE.dpkg-backup" ) {
        my $dest = "$CONFFILE";
        if ( -e $dest && -d $dest ) {
            my $source_name = "$CONFFILE.dpkg-backup";
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
        if ( File::Copy::move( "$CONFFILE.dpkg-backup", $dest ) ) {
        } else {
            croak
  "mv: cannot move "$CONFFILE.dpkg-backup" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "$CONFFILE.dpkg-backup": No such file or directory\n";
    }
    return;
}
if (("$1" eq configure && !($main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', '0.123', q{~}) >> 8))) {
    finish_mv_conffile('/etc/initramfs-tools/initramfs.conf', 'initramfs-tools-core');
}
if (("$1" eq configure && !($main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', '0.138', q{~}) >> 8))) {
if ( -e "/var/lib/initramfs-tools" ) {
        if ( -d "/var/lib/initramfs-tools" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("/var/lib/initramfs-tools", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "/var/lib/initramfs-tools", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "/var/lib/initramfs-tools" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/lib/initramfs-tools",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}

exit $main_exit_code;
