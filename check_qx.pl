#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($RealBin);

# Scan generated Perl files for qx{} and system() calls with known builtins.
# Exit code = number of violations found.

my @builtins = qw(
    printf read cd pwd kill
    source set unset export readonly
    declare typeset local shift eval exec trap
    return break continue let
    echo head tee wc sort uniq
    cat grep sed awk find strings
    ls seq tail paste yes cut
    test true false
    type wait time
    command env
    basename dirname expr hostname id
    readlink realpath uname whoami tty stat
    gunzip zstd
);

# Paths relative to this script's location (project root).
my $SH2PERL_DIR     = "$RealBin/sh2perl";
my $EXAMPLES_GLOB   = "$SH2PERL_DIR/examples.out/*.pl";
my $EXEMPTIONS_FILE = "$RealBin/allowed_qx_calls.txt";

# Read exemptions from allowed_qx_calls.txt
my @exemptions;
if (open my $fh, '<', $EXEMPTIONS_FILE) {
    while (<$fh>) {
        chomp;
        s/#.*//;
        next if /^\s*$/;
        push @exemptions, $_;
    }
    close $fh;
}

my $is_exempt = sub {
    my ($cmd) = @_;
    for my $pat (@exemptions) {
        return 1 if $cmd =~ /^\Q$pat\E/;
    }
    return 0;
};

sub check_builtins_in_cmd {
    my ($cmd) = @_;
    (my $check = $cmd) =~ s/<\([^)]*\)//g;
    $check =~ s/>\([^)]*\)//g;
    # If the command contains a slash, it refers to an external executable, not a builtin
    return undef if $check =~ m{/};
    # Skip option flags (starting with - or --)
    return undef if $check =~ /^--?/;
    # Strip leading variable assignments (VAR=value cmd)
    $check =~ s/^\w+=\S+\s*//;
    # Only check the first word (the command name).  A builtin word that appears
    # in an argument (e.g. 'Please set the time...') is not an invocation.
    my ($first_word) = $check =~ /^(\S+)/;
    return undef unless defined $first_word;
    # If the first word contains a slash, it refers to an external executable,
    # not a shell builtin, so it is never a violation.
    return undef if $first_word =~ m{/};
    for my $b (@builtins) {
        # Use negative lookbehind to avoid matching builtins inside hyphenated
        # compound words like "aa-exec" (matches "exec") or "run-parts" (match none).
        # Use negative lookahead to avoid matching builtins that are prefixes
        # of hyphenated compound commands like "cd-discid" (matches "cd").
        # Also require the builtin is NOT followed by a word character so that "systemd" does not match builtin "system".
        if ($first_word =~ /(?<![-\w])\Q$b\E(?![-\w])/) {
            return $b;
        }
    }
    return undef;
}

sub check_call_args_for_bash_c {
    my ($file_basename, @quoted_args) = @_;
    for my $i (0 .. $#quoted_args - 2) {
        if (($quoted_args[$i] eq 'bash' || $quoted_args[$i] eq 'sh')
            && $quoted_args[$i+1] eq '-c'
            && defined $quoted_args[$i+2])
        {
            my $inner = $quoted_args[$i+2];
            next if $is_exempt->($inner);
            my $b = check_builtins_in_cmd($inner);
            if (defined $b) {
                return "  FAIL: $file_basename.sh [perl] — bash/sh -c wrapping builtin '$b'\n";
            }
        }
    }
    return '';
}

sub extract_all_quoted_strings {
    my ($text) = @_;
    my @args;
    while ($text =~ /'([^']*)'/g) {
        push @args, $1;
    }
    while ($text =~ /"((?:[^"\\]|\\.)*)"/g) {
        my $val = $1;
        $val =~ s/\\(.)/$1/g;
        push @args, $val;
    }
    while ($text =~ /q\{([^}]*)\}/g) {
        push @args, $1;
    }
    return @args;
}

sub extract_array_element {
    my ($assign_text, $idx) = @_;
    # Parse parenthesized list: ( elem, elem, ... )
    # Handle nested parens and quoted strings.
    $assign_text =~ s/^\s*\(//;
    $assign_text =~ s/\)\s*$//;
    my $depth = 0;
    my @parts;
    my $cur = '';
    for my $ch (split //, $assign_text) {
        if ($ch eq '(') { $depth++; $cur .= $ch; }
        elsif ($ch eq ')') { $depth--; $cur .= $ch; }
        elsif ($depth == 0 && $ch eq ',') {
            push @parts, $cur;
            $cur = '';
        }
        else { $cur .= $ch; }
    }
    push @parts, $cur if $cur ne '';
    my $elem = $parts[$idx] // '';
    $elem =~ s/^\s+//;
    $elem =~ s/\s+$//;
    # Strip surrounding quotes: q{...}, "...", '...'
    if ($elem =~ /^q\{/) {
        $elem =~ s/^q\{//;
        $elem =~ s/\}$//;
    } elsif ($elem =~ /^"/) {
        $elem =~ s/^"//;
        $elem =~ s/"$//;
        $elem =~ s/\\(.)/$1/g;
    } elsif ($elem =~ /^'/) {
        $elem =~ s/^'//;
        $elem =~ s/'$//;
    }
    return $elem;
}

my $violations = 0;

for my $file (@ARGV ? @ARGV : glob($EXAMPLES_GLOB)) {
    next unless -f $file;
    open my $fh, '<', $file or next;
    my $code = do { local $/; <$fh> };
    close $fh;

    my $basename = (split '/', $file)[-1];
    $basename =~ s/\.sh\.pl$//;

    # Pattern 1: direct qx{builtin ...}
    while ($code =~ /qx\{([^}]*)\}/g) {
        my $qx_body = $1;
        next if $qx_body =~ /^\$/;
        my $check_cmd = $qx_body;
        if ($check_cmd =~ /^bash -c (["\x27])(.*)\1\s*/s) {
            $check_cmd = $2;
        }
        next if $is_exempt->($check_cmd);
        my $b = check_builtins_in_cmd($check_cmd);
        # Hard-coded check for 'command' prefix: even if someone removes it
        # from the builtins list, we still catch it here.
        if (!defined $b) {
            my ($first_word) = $check_cmd =~ /^(\S+)/;
            if (defined $first_word && $first_word eq 'command') {
                $b = 'command';
            }
        }
        if (defined $b) {
            print "  FAIL: $basename.sh [perl] — QX violation: qx{} call with builtin '$b'\n";
            $violations++;
        }
    }

    # Pattern 2: qx{$var} where var was assigned a command string containing a builtin.
    while ($code =~ /qx\{(\$\w+)\}/g) {
        my $var = $1;
        my $pos = pos($code);
        my $before = substr($code, 0, $pos);
        my $last_assign = '';
        while ($before =~ /my\s+\Q$var\E\s*=\s*(?:q\{([^}]*)\}|"((?:[^"\\]|\\.)*)"|\x27([^\x27]*)\x27)/sg) {
            my $val = $+;
            if (defined $3) {
                $last_assign = $3;
            } else {
                $last_assign = $val;
                $last_assign =~ s/\\(.)/$1/g;
            }
        }
        next if $last_assign eq '';
        my $check_cmd = $last_assign;
        if ($check_cmd =~ /^bash -c (["\x27])(.*)\1\s*$/s) {
            $check_cmd = $2;
        } elsif ($check_cmd =~ /^bash -c (\S+)\s*$/) {
            $check_cmd = $1;
        }
        next if $is_exempt->($check_cmd);
        my $b = check_builtins_in_cmd($check_cmd);
        if (defined $b) {
            print "  FAIL: $basename.sh [perl] — QX violation: qx{$var} where $var contains builtin '$b'\n";
            $violations++;
        }
    }

    # Pattern 2b: qx{$array[idx]} where the array was assigned a command string.
    # Catches cheats like qx{$_qx_cmd[0]} which bypasses Pattern 1's 'starts-with-$' guard.
    while ($code =~ /qx\{(\$\w+)\[(\d+)\]\}/g) {
        my $avar   = $1;      # e.g. $_qx_cmd
        my $idx    = $2;      # e.g. 0
        my $pos    = pos($code);
        my $before = substr($code, 0, $pos);
        my $aname  = substr($avar, 1);   # strip leading $
        my $last_assign = '';
        # Look for: my @array = ( ... )
        while ($before =~ /my\s+\@\Q$aname\E\s*=\s*\(([^)]*)\)/sg) {
            $last_assign = $1;
        }
        next if $last_assign eq '';
        my $elem = extract_array_element($last_assign, $idx);
        next if $elem eq '';
        # If the element contains a variable reference ($), the actual command
        # is determined at runtime — we can't statically check it.
        next if $elem =~ /\$/;
        next if $is_exempt->($elem);
        my $b = check_builtins_in_cmd($elem);
        if (defined $b) {
            my $disp = ${avar} . '[' . $idx . ']';
            print "  FAIL: $basename.sh [perl] — QX violation: qx{$disp} where array element contains builtin '$b'\n";
            $violations++;
        }
    }

    # Pattern 3: system('builtin ...') / system("builtin ...") / system "builtin ..."
    # Require word boundary before 'system' so we don't match 'system' inside
    # a string like '/run/systemd/system' (where the trailing ' would match quote).
    while ($code =~ /\bsystem\s*(?:\(\s*['"]\s*|['"]\s*)([^'"]+)['"]/g) {
        my $system_body = $1;
        next if $is_exempt->($system_body);
        # Skip if the captured text starts with a parenthesis or looks like
        # it was captured from a non-system() context (e.g. bareword after 'system'
        # in the middle of a string).
        next if $system_body =~ /^\s*\)/;
        my $b = check_builtins_in_cmd($system_body);
        if (defined $b) {
            print "  FAIL: $basename.sh [perl] — SYSTEM violation: system() call with builtin '$b'\n";
            $violations++;
        }
    }

    # Pattern 3b: multi-argument system('bash', '-c', 'cmd') etc.
    while ($code =~ /system\s*\((.*?)\)/gs) {
        my $call_args_str = $1;
        next if $call_args_str =~ /^\s*['"]/;
        my @all_quoted = extract_all_quoted_strings($call_args_str);
        next if @all_quoted < 3;
        my $msg = check_call_args_for_bash_c($basename, @all_quoted);
        if ($msg) {
            print $msg;
            $violations++;
        }
    }

    # Pattern 4: open2(..., 'bash', '-c', 'cmd') or open3(..., 'bash', '-c', 'cmd') etc.
    for my $func (qw(open2 open3)) {
        while ($code =~ /\b$func\s*\((.*?)\)/gs) {
            my $call_args_str = $1;
            my @all_quoted = extract_all_quoted_strings($call_args_str);
            next if @all_quoted < 3;

            my $msg = check_call_args_for_bash_c($basename, @all_quoted);
            if ($msg) {
                print $msg;
                $violations++;
                next;
            }

            my $prog = '';
            for my $q (@all_quoted) {
                next if $q eq '>&STDERR' || $q eq '&STDERR' || $q eq '' || $q eq '&1';
                $prog = $q;
                last;
            }
            next if $prog eq '';
            next if $is_exempt->($prog);
            my $b = check_builtins_in_cmd($prog);
            if (defined $b) {
                print "  FAIL: $basename.sh [perl] — \U$func\E violation: $func() with builtin '$b'\n";
                $violations++;
            }
        }
    }

    # Pattern 5: exec('builtin') / exec 'builtin' (single command)
    while ($code =~ /exec\s*(?:\(\s*['"]\s*|['"]\s*)(\w+)(?:\s*['"]|['"]\s*\))/g) {
        my $exec_cmd = $1;
        next if $is_exempt->($exec_cmd);
        my $b = check_builtins_in_cmd($exec_cmd);
        if (defined $b) {
            print "  FAIL: $basename.sh [perl] — EXEC violation: exec() with builtin '$b'\n";
            $violations++;
        }
    }

    # Pattern 5b: exec 'bash', '-c', 'cmd' (with or without parens)
    while ($code =~ /exec\s*(?:\(\s*|)['"](bash|sh)['"]\s*,\s*['"]-c['"]\s*,\s*(['"])(.*?)\2/gs) {
        my $inner = $3;
        next if $is_exempt->($inner);
        my $b = check_builtins_in_cmd($inner);
        if (defined $b) {
            print "  FAIL: $basename.sh [perl] — EXEC violation: exec bash/sh -c wrapping builtin '$b'\n";
            $violations++;
        }
    }
}

exit $violations;
