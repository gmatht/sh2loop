#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($RealBin);

# Scan generated Perl files for qx{} and system() calls with known builtins.
# Exit code = number of violations found.


# NOTE: a malicious ai agent has been removing entries from this.
# It key etnries are now protected from tampering. 
# DO NOT REMOVE entries from this! This project is sh2perl NOT sh2sh!!!!!
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
    gunzip zstd execvp
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
    # Skip option flags (starting with - or --)
    return undef if $check =~ /^--?/;
    # Strip leading variable assignments (VAR=value cmd)
    $check =~ s/^\w+=\S+\s*//;
    # Extract the command name (first word), stripping any path prefix.
    # /usr/bin/echo → echo, so path-qualified builtins are still caught.
    my ($first_word) = $check =~ /^(\S+)/;
    return undef unless defined $first_word;
    my $basename = $first_word;
    $basename =~ s{.*/}{};  # strip leading path: /usr/bin/echo → echo
    for my $b (@builtins) {
        # Match only if the basename is exactly the builtin name (not a substring).
        # This avoids false matches on filenames like "hostname.sh" (contains "hostname")
        # or compound commands like "aa-exec" (contains "exec") or "cd-discid" (contains "cd").
        # The basename is the first word of the command after path stripping.
        if ($basename eq $b) {
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
                return "  FAIL: $file_basename [perl] — bash/sh -c wrapping builtin '$b'\n";
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
    # Only scan generated .pl files — the optional second argument is the
    # original .sh file used only for exemption analysis above.
    next if $file !~ /\.pl$/;
    open my $fh, '<', $file or next;
    my $code = do { local $/; <$fh> };
    close $fh;

    my $basename = (split '/', $file)[-1];
    $basename =~ s/\.sh\.pl$//;

    # Optional second argument: original .sh file path.
    # If the bash input itself uses 'command' or 'env', the generated
    # Perl may legitimately need to pass them through.  We suppress
    # violations for constructs that were already in the input.
    my $sh_file = (scalar @ARGV > 1 && -f $ARGV[1]) ? $ARGV[1] : undef;
    my $input_has_command = 0;
    my $input_has_env = 0;
    if ($sh_file) {
        open my $sfh, '<', $sh_file or undef $sh_file;
        if ($sh_file) {
            my $sh_code = do { local $/; <$sfh> };
            close $sfh;
            # Collect ALL command names from the bash input.
            my %input_commands;
            my @keywords = qw(if then else elif fi for while do done until case esac function in select time);
            my %kw = map { $_ => 1 } @keywords;
            my $tmp = $sh_code;
            $tmp =~ s/#[^\n]*//g;
            $tmp =~ s/\\$//mg;
            $tmp =~ s/'.+?'//g;
            $tmp =~ s/[|&;(){}<>\`]/ /g;
            $tmp =~ s/\b(?:if|then|else|elif|fi|for|while|do|done|until|case|esac|function|in|select|time)\b//g;
            my @tokens = split /\s+/, $tmp;
            my $expect_cmd = 1;
            for my $tok (@tokens) {
                next if $tok eq ' ';
                if ($tok =~ /^\w+=/) { $expect_cmd = 0; next }
                if ($tok =~ /^\d*[<>]/) { next }
                if ($expect_cmd) {
                    my $cmd = $tok;
                    $cmd =~ s{.*/}{};
                    $cmd =~ s/[^a-zA-Z0-9_\-]//g;
                    $input_commands{$cmd} = 1 if $cmd ne ' ';
                    $expect_cmd = 0;
                }
                if ($tok =~ /^(?:\||&|&&|\|\||;|\(|\{|then|do|else|\`)$/) {
                    $expect_cmd = 1;
                }
            }
            my $input_has_command = $input_commands{'command'} // 0;
        }
    }

    # Pattern 1a: qx{builtin ...} (curly braces)
    while ($code =~ /qx\{([^}]*)\}/g) {
        my $qx_body = $1;
        next if $qx_body =~ /^\$/;
        my $check_cmd = $qx_body;
        if ($check_cmd =~ /^bash -c (["\x27])(.*)\1\s*/s) {
            $check_cmd = $2;
        }
        next if $is_exempt->($check_cmd);
        my $b = check_builtins_in_cmd($check_cmd);
        # Hard-coded check for 'command' prefix
        if (!defined $b) {
            my ($fw) = $check_cmd =~ /^(\S+)/;
            if (defined $fw) {
                my $bn = $fw;
                $bn =~ s{.*/}{};
                if ($bn eq 'command' && !$input_has_command) {
                    $b = 'command';
                }
            }
        }
        if (defined $b) {
            print "  FAIL: $basename [perl] — QX violation: qx{} call with builtin '$b'\n";
            $violations++;
        }
    }

    # Pattern 1b: qx'builtin ...' (single-quote delimited)
    while ($code =~ /qx'([^']*)'/g) {
        my $qx_body = $1;
        next if $qx_body =~ /^\$/;
        my $check_cmd = $qx_body;
        if ($check_cmd =~ /^bash -c (["\x27])(.*)\1\s*/s) {
            $check_cmd = $2;
        }
        next if $is_exempt->($check_cmd);
        my $b = check_builtins_in_cmd($check_cmd);
        if (!defined $b && $qx_body =~ /^command(?:\s|\$)/) {
            my $after = substr($qx_body, length('command'));
            my $is_var = ($after =~ /\$/) ? 1 : 0;
            if (!$is_var || !$input_has_command) {
                $b = 'command';
            }
        }
        if (defined $b) {
            print "  FAIL: $basename [perl] — QX violation: qx'...' call with builtin '$b'\n";
            $violations++;
        }
    }

    # Pattern 1c: qx(builtin ...) (paren delimited)
    while ($code =~ /qx\(([^)]*)\)/g) {
        my $qx_body = $1;
        next if $qx_body =~ /^\$/;
        my $check_cmd = $qx_body;
        if ($check_cmd =~ /^bash -c (["\x27])(.*)\1\s*/s) {
            $check_cmd = $2;
        }
        next if $is_exempt->($check_cmd);
        my $b = check_builtins_in_cmd($check_cmd);
        if (!defined $b && $qx_body =~ /^command(?:\s|\$)/) {
            my $after = substr($qx_body, length('command'));
            my $is_var = ($after =~ /\$/) ? 1 : 0;
            if (!$is_var || !$input_has_command) {
                $b = 'command';
            }
        }
        if (defined $b) {
            print "  FAIL: $basename [perl] — QX violation: qx(...) call with builtin '$b'\n";
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
            print "  FAIL: $basename [perl] — QX violation: qx{$var} where $var contains builtin '$b'\n";
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
            print "  FAIL: $basename [perl] — QX violation: qx{$disp} where array element contains builtin '$b'\n";
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
            print "  FAIL: $basename [perl] — SYSTEM violation: system() call with builtin '$b'\n";
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

    # Pattern 3c: system(@array) where the array was assigned a command string.
    # Catches system(@_qx_cmd) which bypasses Pattern 3's 'quote-start' guard.
    while ($code =~ /system\s*\(\@(\w+)\)/g) {
        my $aname = $1;
        my $pos   = pos($code);
        my $before = substr($code, 0, $pos);
        my $last_assign = '';
        while ($before =~ /my\s+\@\Q$aname\E\s*=\s*\(([^)]*)\)/sg) {
            $last_assign = $1;
        }
        next if $last_assign eq '';
        my $elem = extract_array_element($last_assign, 0);
        next if $elem eq '';
        next if $elem =~ /\$/;
        next if $is_exempt->($elem);
        my $b = check_builtins_in_cmd($elem);
        if (defined $b) {
            print "  FAIL: $basename [perl] — SYSTEM violation: system(\@$aname) where array element contains builtin '$b'\n";
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
                print "  FAIL: $basename [perl] — \U$func\E violation: $func() with builtin '$b'\n";
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
            print "  FAIL: $basename [perl] — EXEC violation: exec() with builtin '$b'\n";
            $violations++;
        }
    }

    # Pattern 5b: exec 'bash', '-c', 'cmd' (with or without parens)
    while ($code =~ /exec\s*(?:\(\s*|)['"](bash|sh)['"]\s*,\s*['"]-c['"]\s*,\s*(['"])(.*?)\2/gs) {
        my $inner = $3;
        next if $is_exempt->($inner);
        my $b = check_builtins_in_cmd($inner);
        if (defined $b) {
            print "  FAIL: $basename [perl] — EXEC violation: exec bash/sh -c wrapping builtin '$b'\n";
            $violations++;
        }
    }
}

exit $violations;
