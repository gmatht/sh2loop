#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $LANG = q{C};
$ENV{LANG} = $LANG;
my $LC_TIME = q{C};
$ENV{LC_TIME} = $LC_TIME;

sub found_git_dir {
    my ($work_dir) = @_;
while ( "$work_dir" ne q{} && "$work_dir" ne "/" ) {
        if ((-d "${work_dir}/.git")) {
                            say ${work_dir} . "/.git/";
return;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        $work_dir = do { use File::Basename qw(dirname); my $dirname_output = dirname("$work_dir"); $CHILD_ERROR = 0; $dirname_output; };
    }

    return;
}

sub changesetfs_list_git {
    my ($DATE) = @_;
    my $WORK_DIR = $_[0];
# Builtin command 'shift' not implemented
    my $fname = $_[0];
# Builtin command 'shift' not implemented
    my $USER = $_[0];
# Builtin command 'shift' not implemented
# Builtin command 'shift' not implemented
    my $GIT_DIR = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'found_git_dir', "$WORK_DIR");
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
    if ("$GIT_DIR" eq q{}) {
                $GIT_DIR = $WORK_DIR;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $curr_year = do {
require POSIX; POSIX::strftime('', localtime())
};
    # Original bash: git --git-dir="$GIT_DIR" log --abbrev=7 --pretty="format:%at %h %an" -- "$fname" | while read TIMESTAMP chset author
do {
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
                my ($in_2, $out_2);
        my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'git', '--git-dir=$GIT_DIR', 'log', '--abbrev=7', '--pretty=format:%at %h %an', '--');
        close $in_2 or croak 'Close failed: $OS_ERROR';
        $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
        close $out_2 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_2, 0;

                my @lines = split /\n/msx, $output_1;
        my $result_1_1 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        my $year = do {
        my $date_source = q{@};
        require POSIX;
        if ($date_source =~ /^@([0-9]+)$/) {
        my $date_epoch = $_[0];
        POSIX::strftime('%a %b %e %H:%M:%S %Z %Y', localtime($date_epoch))
        }
        else {
        select((select(STDOUT), $| = 1)[0]);
        print {*STDERR} "date: option requires an argument -- 'd'\nTry 'date --help' for more information.\n";
        q{};
        }
        };
        if ("$year" eq "$curr_year") {
        $DATE = do {
        my $date_source = q{@};
        require POSIX;
        if ($date_source =~ /^@([0-9]+)$/) {
        my $date_epoch = $_[0];
        POSIX::strftime('%a %b %e %H:%M:%S %Z %Y', localtime($date_epoch))
        }
        else {
        select((select(STDOUT), $| = 1)[0]);
        print {*STDERR} "date: option requires an argument -- 'd'\nTry 'date --help' for more information.\n";
        q{};
        }
        };
        $CHILD_ERROR = 0;
        } else {
        $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
        $DATE = do {
        my $date_source = q{@};
        require POSIX;
        if ($date_source =~ /^@([0-9]+)$/) {
        my $date_epoch = $_[0];
        POSIX::strftime('%a %b %e %H:%M:%S %Z %Y', localtime($date_epoch))
        }
        else {
        select((select(STDOUT), $| = 1)[0]);
        print {*STDERR} "date: option requires an argument -- 'd'\nTry 'date --help' for more information.\n";
        q{};
        }
        };
        }
        my $NAME = "$ENV{chset} $ENV{author}";
        $output .= "-rw-rw-rw-   1 $USER    0 0 $DATE  $NAME " . (do { use File::Basename qw(basename); my $basename_output = basename($fname); $CHILD_ERROR = 0; $basename_output; }) . "\n";
        }
        $output_1 = $result_1_1;
        if ($output_1 ne q{} && !defined $output_printed_1) {
            print $output_1;
            if (!($output_1 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        }
;
    return;
}

sub changesetfs_copyout_git {
    my ($output_fname) = @_;
    my $WORK_DIR = $_[0];
# Builtin command 'shift' not implemented
    my $fname = $_[0];
# Builtin command 'shift' not implemented
    my $orig_fname = $_[0];
# Builtin command 'shift' not implemented
# Builtin command 'shift' not implemented
    my $chset = do {
    do { do {
        my $output_3 = q{};
        my $output_printed_3;
        my $pipeline_success_3 = 1;
        $output_3 .= $orig_fname . "\n";
        if ( !($output_3 =~ m{\n\z}) ) { $output_3 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_3 = 0; }
        my @lines_4 = split /\n/, $output_3;
        my @result_4;
        foreach my $line (@lines_4) {
        chomp $line;
        my @fields = split /\ /msx, $line;
        if (@fields > 0) {
            push @result_4, $fields[0];
        }
        }
        $output_3 = join "\n", @result_4;
        if ($output_3 ne q{} && !($output_3  =~ m{\n\z})) { $output_3 .= "\n"; }

        if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
        $output_3 =~ s/\n+\z//msx;
        $output_3;
}; };
};
    my $GIT_DIR = do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'found_git_dir', "$WORK_DIR");
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
};
    if ("$GIT_DIR" eq q{}) {
                $GIT_DIR = $WORK_DIR;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $filecommit = do {
    do { do {
        my $output_6 = q{};
        my $output_printed_6;
        my $pipeline_success_6 = 1;

        my ($in_7, $out_7);
        my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'git', '--git-dir=$GIT_DIR', 'show', '--raw', '--pretty=tformat:%h', '--');
        close $in_7 or croak 'Close failed: $OS_ERROR';
        $output_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
        close $out_7 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_7, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_6 = 0; }
        my @lines = split /\n/, $output_6;
        my $num_lines = 1;
        if ($num_lines > scalar @lines) {
        $num_lines = scalar @lines;
        }
        my $start_index = scalar @lines - $num_lines;
        if ($start_index < 0) { $start_index = 0; }
        my @result = @lines[$start_index..$;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$output_fname"
      or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('git', '--git-dir=$GIT_DIR', 'show', "$filecommit") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    }
    }
    }
    return;
}

sub changesetfs_list {
    my ($fname) = @_;
    my $VCS_type = $_[0];
# Builtin command 'shift' not implemented
    my $WORK_DIR = $_[0];
# Builtin command 'shift' not implemented
# Builtin command 'shift' not implemented
    my $DATE = do {
require POSIX; POSIX::strftime('', localtime())
};
    my $USER = do { my $whoami_user = (getpwuid($<))[0]; $whoami_user . "\n"; };
if ("$VCS_type" =~ /^git$/msx) {
                changesetfs_list_git(DATE => "$WORK_DIR", "$fname", "$USER", "$DATE");
    }
    return;
}

sub changesetfs_copyout {
    my ($fname) = @_;
    my $VCS_type = $_[0];
# Builtin command 'shift' not implemented
    my $WORK_DIR = $_[0];
# Builtin command 'shift' not implemented
# Builtin command 'shift' not implemented
if ("$VCS_type" =~ /^git$/msx) {
                changesetfs_copyout_git(output_fname => "$WORK_DIR", "$fname", "\@ARGV");
    }
    return;
}
my $command = $1;
# Builtin command 'shift' not implemented
my $tmp_file = $1;
# Builtin command 'shift' not implemented
my $WORK_DIR = do { my @_qx_cmd = ('head -n 1 $tmp_file'); qx{$_qx_cmd[0]}; };
my $fname = do {
    do { my $output_9 = q{};
my $output_printed_9;
my $head_line_count = 0;
my @tail_lines = ();
my $output_10 = q{};
while (my $line = <>) {
    chomp $line;;
my $VCS_type = do { my @_qx_cmd = ('tail -n 1 $tmp_file'); qx{$_qx_cmd[0]}; };
if ("$command" =~ /^list$/msx) {
        changesetfs_list(fname => "$VCS_type", "$WORK_DIR", "$fname");
} elsif ("$command" =~ /^copyout$/msx) {
        changesetfs_copyout(fname => "$VCS_type", "$WORK_DIR", "$fname", "\@ARGV");
} elsif (1) {
    exit 1;
}
exit 0;
}
}
}
