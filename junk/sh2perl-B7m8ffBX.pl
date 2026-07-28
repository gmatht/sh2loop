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

my $old_dkms_file;
my @old_dkms_file;
my %old_dkms_file;

$__set_e = 1;
my $mvverbose;
my @mvverbose;
my %mvverbose;
$mvverbose = '-v';

sub ensure_package_owns_file {
    my $PACKAGE = "$_[0]";
    my $FILE = "$_[1]";
    # Original bash: dpkg-query -L "$PACKAGE" | grep -F -q -x "$FILE"
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
                my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'dpkg-query', '-L');
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;

                my $grep_result_0_1;
        my @grep_lines_0_1 = split /\n/msx, $output_0;
        my @grep_filtered_0_1 = grep { /$FILE/msx } @grep_lines_0_1;
        $grep_result_0_1 = join "\n", @grep_filtered_0_1;
        if (!($grep_result_0_1 =~ m{\n\z}msx || $grep_result_0_1 eq q{})) {
        $grep_result_0_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_0_1 > 0 ? 0 : 1;
        $grep_result_0_1 = q{};
        $output_0 = q{};
        if ((scalar @grep_filtered_0_1) == 0) {
            $pipeline_success_0 = 0;
        }
        if ($output_0 ne q{} && !defined $output_printed_0) {
            print $output_0;
            if (!($output_0 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
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
if ((("$1" eq configure && "$2" ne q{}) && !($main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', '0.123', q{~}) >> 8))) {
    finish_mv_conffile('/etc/initramfs-tools/initramfs.conf', 'initramfs-tools-core');
}
if ("$1" ne triggered) {
    $main_exit_code = system('update-initramfs', '-u') >> 8;
}
else {
    my $DPKG_MAINTSCRIPT_PACKAGE = q{};
    $main_exit_code = system('update-initramfs', '-u') >> 8;
}
if ((("$1" eq configure && "$2" ne q{}) && !($main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt', "0.131ubuntu11") >> 8))) {
    for my $old_dkms_file ('/boot/initrd-*.img.old-dkms', '/boot/initramfs-*.img.old-dkms', '/boot/initrd.img-*.old-dkms', '/boot/initrd-*.old-dkms') {
if ((!-e "${old_dkms_file%%.old-dkms}")) {
if ( -e "v" ) {
                if ( -d "v" ) {
                    carp "rm: carping: ", "v",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "v" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "v",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
if ( -e "${old_dkms_file}" ) {
                if ( -d "${old_dkms_file}" ) {
                    carp "rm: carping: ", ${old_dkms_file},
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "${old_dkms_file}" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", ${old_dkms_file},
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
    }
    $old_dkms_file = '/boot/initrd-*.old-dkms';
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/bash_completion.d/initramfs-tools', "0.126\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/kernel/signed_postinst.d/initramfs-tools', "0.126\\~", '--', "@ARGV") >> 8;

exit $main_exit_code;
