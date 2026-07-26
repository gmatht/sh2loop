#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);
use POSIX qw(time);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $expkey;
my @expkey;
my %expkey;
my $equal;
my @equal;
my %equal;
my $tool;
my @tool;
my %tool;
my $url_asc;
my @url_asc;
my %url_asc;
my $rc;
my @rc;
my %rc;
my $newver;
my @newver;
my %newver;
my $trunk;
my @trunk;
my %trunk;
my $url;
my @url;
my %url;
my $force;
my @force;
my %force;
my $drivedb;
my @drivedb;
my %drivedb;
my $oldver;
my @oldver;
my %oldver;
my $no_verify;
my @no_verify;
my %no_verify;
my $file;
my @file;
my %file;
my $smartctl;
my @smartctl;
my %smartctl;
my $file_asc;
my @file_asc;
my %file_asc;

my $MAGIC_700 = 700;
my $MAGIC_644 = 644;
my $MAGIC_10  = 10;

$__set_e = 1;
$ENV{PATH} = '';
my $PACKAGE;
my @PACKAGE;
my %PACKAGE;
$PACKAGE = "smartmontools";
my $VERSION;
my @VERSION;
my %VERSION;
$VERSION = "7.4";
my $prefix;
my @prefix;
my %prefix;
$prefix = "/usr";
my $exec_prefix;
my @exec_prefix;
my %exec_prefix;
$exec_prefix = ${prefix};
my $sbindir;
my @sbindir;
my %sbindir;
$sbindir = ${exec_prefix} . "/sbin";
my $datarootdir;
my @datarootdir;
my %datarootdir;
$datarootdir = ${prefix} . "/share";
my $datadir;
my @datadir;
my %datadir;
$datadir = ${datarootdir};
my $localstatedir;
my @localstatedir;
my %localstatedir;
$localstatedir = "/var";
my $drivedbinstdir;
my @drivedbinstdir;
my %drivedbinstdir;
$drivedbinstdir = "/usr/share/smartmontools";
my $drivedbdir;
my @drivedbdir;
my %drivedbdir;
$drivedbdir = "/var/lib/smartmontools/drivedb";
my $os_dltools;
my @os_dltools;
my %os_dltools;
$os_dltools = "curl wget lynx svn";
my $default_branch;
my @default_branch;
my %default_branch;
$default_branch = "RELEASE_7_3_DRIVEDB";
my $default_drivedb;
my @default_drivedb;
my %default_drivedb;
$default_drivedb = "$drivedbdir/drivedb.h";
my $gpg;
my @gpg;
my %gpg;
$gpg = "gpg";
my $default_smartctl;
my @default_smartctl;
my %default_smartctl;
$default_smartctl = "$sbindir/smartctl";
my $pathinfo;
my @pathinfo;
my %pathinfo;
$pathinfo = "'$ENV{PATH}'";
my $myname;
my @myname;
my %myname;
$myname = $PROGRAM_NAME;

sub print_help {
    $pathinfo = "
                     $pathinfo";
print "smartmontools $VERSION drive database update script

Usage: $myname [OPTIONS] [DESTFILE]

  -s, --smartctl SMARTCTL
                    Use SMARTCTL for syntax check ('-s -' to disable)
                    [default: $default_smartctl]
  -t, --tool [DIR/]TOOL
                    Use TOOL for download: $os_dltools
                    [default: first one found in $pathinfo]
  -u, --url-of LOCATION
                    Use URL of LOCATION for download:
                      github (GitHub mirror of SVN repository)
                      sf (Sourceforge code browser)
                      svn (SVN repository) [default]
                      svni (SVN repository via HTTP instead of HTTPS)
                      trac (Trac code browser)
  --url URL         Download from URL
  --file FILE       Copy from local FILE
";
        $main_exit_code = system('test', "$drivedbinstdir", q{=}, "$drivedbdir") >> 8;
    if ($CHILD_ERROR != 0) {
        print "  --install         Copy from originally installed drive database file
                    This is the same as:
                    '--no-verify --file $drivedbinstdir/drivedb.h'
";
    }
print "  --trunk           Download from SVN trunk (requires '--no-verify')
  --branch X.Y      Download from branches/RELEASE_X_Y_DRIVEDB
  --cacert FILE     Use CA certificates from FILE to verify the peer
  --capath DIR      Use CA certificate files from DIR to verify the peer
  --insecure        Don't abort download if certificate verification fails
  --no-verify       Don't verify signature
  --force           Allow downgrades
  --export-key      Print the OpenPGP/GPG public key block
  --dryrun          Print download commands only
  -q, --quiet       Suppress info messages
  -v, --verbose     Verbose output
  -h, --help        Print this help text

Updates $default_drivedb
or DESTFILE from branches/$default_branch of smartmontools
SVN repository.
";
    return;
}

sub error {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "$myname: @ARGV";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
        $main_exit_code = system('test', '-z', "$ENV{usageerr}") >> 8;
    if ($CHILD_ERROR != 0) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Try '$myname -h' for help";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
    }
exit 1;
    return;
}

sub err_notfound {
    my ($file) = @_;
if ($arg1 =~ /^.*/.*$/msx) {
                error("$_[0]: not found $_[1]");
    } elsif (1) {
                error("$_[0]: not found in $pathinfo $_[1]");
    }
    return;
}

sub check_optarg {
        $main_exit_code = system('test', scalar(@ARGV), '-gt', q{1}) >> 8;
    if ($CHILD_ERROR != 0) {
                error("option '$_[0]' requires an argument");
    }
    return;
}

sub warning {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "$myname: (Warning) @ARGV";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    return;
}

sub selecturl {
    my ($file) = @_;
if ($arg1 =~ /^github$/msx) {
                $url = 'https://raw.githubusercontent.com/smartmontools/smartmontools/master/smartmontools/drivedb.h';
    } elsif ($arg1 =~ /^sf$/msx) {
                $url = 'https://sourceforge.net/p/smartmontools/code/HEAD/tree/trunk/smartmontools/drivedb.h?format=raw';
    } elsif ($arg1 =~ /^svn$/msx) {
                $url = 'https://svn.code.sf.net/p/smartmontools/code/trunk/smartmontools/drivedb.h';
    } elsif ($arg1 =~ /^svni$/msx) {
                $url = 'http://svn.code.sf.net/p/smartmontools/code/trunk/smartmontools/drivedb.h';
    } elsif ($arg1 =~ /^trac$/msx) {
                $url = 'https://www.smartmontools.org/export/HEAD/trunk/smartmontools/drivedb.h';
    } elsif (1) {
                error("$_[0]: is none of 'github sf svn svni trac'");
    }
    return;
}

sub inpath {
    my $d;
    my $rc;
    my $save;
    $rc = q{1};
    $save = $IFS;
    my $IFS;
    my @IFS;
    my %IFS;
    $IFS = q{:};
    for my $d ($PATH) {
                $main_exit_code = system('test', '-f', "$d/$_[0]") >> 8;
        if ($CHILD_ERROR != 0) {
            next;        }
                $main_exit_code = system('test', '-x', "$d/$_[0]") >> 8;
        if ($CHILD_ERROR != 0) {
            next;        }
        $rc = q{0};
last;
    }
    $IFS = $save;
return $rc;
    return;
}

sub iecho {
        $main_exit_code = system('test', '-n', "$ENV{quiet}") >> 8;
    if ($CHILD_ERROR != 0) {
                print $*;
if ( !( ($*) =~ m{\n\z}msx ) ) { print "\n"; }
    }
    return;
}

sub vecho {
        $main_exit_code = system('test', '-n', "$ENV{q}") >> 8;
    if ($CHILD_ERROR != 0) {
                print $*;
if ( !( ($*) =~ m{\n\z}msx ) ) { print "\n"; }
    }
    return;
}

sub vrun {
if ("$dryrun" ne q{}) {
        print $*;
if ( !( ($*) =~ m{\n\z}msx ) ) { print "\n"; }
}
    else {
        if ("$q" ne q{}) {
            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                $CHILD_ERROR = 0;
            };
}
        else {
            print $*;
if ( !( ($*) =~ m{\n\z}msx ) ) { print "\n"; }
            $CHILD_ERROR = 0;
        }
    }
    return;
}

sub vrun2 {
    my $f;
    my $err;
    my $rc;
    $f = $1;
# Builtin command 'shift' not implemented
    $rc = q{0};
if ("$dryrun" ne q{}) {
        do {
    my $__echo_line = "@ARGV > $f";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
}
    else {
        vecho("@ARGV > $f");
                $err = do { my @_qx_cmd = ("\"$@\" 2>&1 > Variable(\"f\", false, None)"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        if ($CHILD_ERROR != 0) {
                        $rc = $?;
        }
if ("$err" ne q{}) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                vecho("$err");
            };
                        $main_exit_code = system('test', $rc, q{!}, q{=}, q{0}) >> 8;
            if ($CHILD_ERROR != 0) {
                                $rc = '42';
            }
        }
    }
return $rc;
    return;
}

sub download {
    my $f;
    my $u;
    my $rc;
    $u = $1;
    $f = $2;
    $rc = q{0};
if (basename(${tool}) =~ /^curl.*$/msx) {
                        vrun("$tool", (defined ($ENV{q} // q{}) && ($ENV{q} // q{}) ne q{} ? ($ENV{q} // q{}) : '-s'), '-f', '--max-redirs', q{0}, '-H', "Accept-Encoding: identity", (defined ($ENV{cacert} // q{}) && ($ENV{cacert} // q{}) ne q{} ? ($ENV{cacert} // q{}) : '--cacert "$cacert"'), (defined ($ENV{capath} // q{}) && ($ENV{capath} // q{}) ne q{} ? ($ENV{capath} // q{}) : '--capath "$capath"'), (defined ($ENV{insecure} // q{}) && ($ENV{insecure} // q{}) ne q{} ? ($ENV{insecure} // q{}) : '--insecure'), '-o', "$f", "$u");
        if ($CHILD_ERROR != 0) {
                        $rc = $?;
        }
    } elsif (basename(${tool}) =~ /^wget.*$/msx) {
                        vrun("$tool", $q, '--max-redirect=0', (defined ($ENV{cacert} // q{}) && ($ENV{cacert} // q{}) ne q{} ? ($ENV{cacert} // q{}) : '--ca-certificate="$cacert"'), (defined ($ENV{capath} // q{}) && ($ENV{capath} // q{}) ne q{} ? ($ENV{capath} // q{}) : '--ca-directory="$capath"'), (defined ($ENV{insecure} // q{}) && ($ENV{insecure} // q{}) ne q{} ? ($ENV{insecure} // q{}) : '--no-check-certificate'), '-O', "$f", "$u");
        if ($CHILD_ERROR != 0) {
                        $rc = $?;
        }
    } elsif (basename(${tool}) =~ /^lynx.*$/msx) {
                        $main_exit_code = system('test', '-z', "$ENV{cacert}") >> 8;
        if ($CHILD_ERROR != 0) {
                        vrun('export', 'SSL_CERT_FILE', q{=}, "$ENV{cacert}");
        }
                        $main_exit_code = system('test', '-z', "$ENV{capath}") >> 8;
        if ($CHILD_ERROR != 0) {
                        vrun('export', 'SSL_CERT_DIR', q{=}, "$ENV{capath}");
        }
                        vrun2("$f", "$tool", '-s', 'tderr', '-n', 'oredir', '-s', 'ource', "$u");
        if ($CHILD_ERROR != 0) {
                        $rc = $?;
        }
    } elsif (basename(${tool}) =~ /^svn.*$/msx) {
                        vrun("$tool", $q, 'export', '--non-interactive', '--no-auth-cache', (defined ($ENV{cacert} // q{}) && ($ENV{cacert} // q{}) ne q{} ? ($ENV{cacert} // q{}) : '--config-option "servers:global:ssl-trust-default-ca=no"'), (defined ($ENV{cacert} // q{}) && ($ENV{cacert} // q{}) ne q{} ? ($ENV{cacert} // q{}) : '--config-option "servers:global:ssl-authority-files=$cacert"'), (defined ($ENV{insecure} // q{}) && ($ENV{insecure} // q{}) ne q{} ? ($ENV{insecure} // q{}) : '--trust-server-cert'), "$u", "$f");
        if ($CHILD_ERROR != 0) {
                        $rc = $?;
        }
    } elsif (basename(${tool}) =~ /^fetch.*$/msx) {
                        vrun("$tool", $q, '--no-redirect', (defined ($ENV{cacert} // q{}) && ($ENV{cacert} // q{}) ne q{} ? ($ENV{cacert} // q{}) : '--ca-cert "$cacert"'), (defined ($ENV{capath} // q{}) && ($ENV{capath} // q{}) ne q{} ? ($ENV{capath} // q{}) : '--ca-path "$capath"'), (defined ($ENV{insecure} // q{}) && ($ENV{insecure} // q{}) ne q{} ? ($ENV{insecure} // q{}) : '--no-verify-hostname'), '-o', "$f", "$u");
        if ($CHILD_ERROR != 0) {
                        $rc = $?;
        }
    } elsif (basename(${tool}) =~ /^ftp.*$/msx) {
                        vrun("$tool", (defined ($ENV{cacert} // q{}) && ($ENV{cacert} // q{}) ne q{} ? ($ENV{cacert} // q{}) : '-S cafile="$cacert"'), (defined ($ENV{capath} // q{}) && ($ENV{capath} // q{}) ne q{} ? ($ENV{capath} // q{}) : '-S capath="$capath"'), (defined ($ENV{insecure} // q{}) && ($ENV{insecure} // q{}) ne q{} ? ($ENV{insecure} // q{}) : '-S dont'), '-o', "$f", "$u");
        if ($CHILD_ERROR != 0) {
                        $rc = $?;
        }
    } elsif (1) {
                error("$tool: unknown (internal error)");
    }
return $rc;
    return;
}

sub check_file {
    my $firstchar;
    my $f;
    my $maxsize;
    my $minsize;
    my $size;
    $f = $1;
    $firstchar = $2;
    $minsize = $3;
    $maxsize = $4;
if (do { my @_qx_cmd = ("dd if = \"$f\" bs = 1 count = 1 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^$firstchar$/msx) {
    } elsif (do { my @_qx_cmd = ("dd if = \"$f\" bs = 1 count = 1 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^\<$/msx) {
                print "HTML error message\n";
        return q{1};    } elsif (1) {
                print "unknown file contents\n";
        return q{1};    }
    $size = do {
    my $wc_file = "$f";
    my $wc_file_opened = 0;
    my $content = do {
        my $result = q{};
        if (open my $fh, '<', $wc_file) {
            $wc_file_opened = 1;
            local $INPUT_RECORD_SEPARATOR = undef;
            $result = <$fh>;
            close $fh or warn "Close failed: $OS_ERROR\n";
        } else {
            warn "Cannot open $wc_file: $OS_ERROR\n";
        }
        $result;
    };
    $wc_file_opened ? do {
        my $wc_bytes = length($content);
        $wc_bytes;
    } : q{};
};
if ((StringInterpolation(StringInterpolation { parts: [Variable("size")] }, None) < Variable("minsize", false, None))) {
        do {
    my $__echo_line = "too small file size $size bytes";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
return q{1};
    }
if ((StringInterpolation(StringInterpolation { parts: [Variable("size")] }, None) > Variable("maxsize", false, None))) {
        do {
    my $__echo_line = "too large file size $size bytes";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
return q{1};
    }
return q{0};
    return;
}

sub unexpand_svn_id {
my @sed_lines_0 = split /\n/msx, $;
my @sed_result_0;
foreach my $line (@sed_lines_0) {
chomp $line;
push @sed_result_0, $line;
}
$ = join "\n", @sed_result_0;

    return;
}

sub selectkey {
    my ($file) = @_;
if ($arg1 =~ /^RELEASE_5_4\[0-3\]_DRIVEDB$/msx or $arg1 =~ /^RELEASE_6_\[0-6\]_DRIVEDB$/msx) {
                my $public_key;
        my @public_key;
        my %public_key;
        $public_key = "\
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQENBFgOYoEBCAC93841SlFmpp6640hKUvZ8PbZR6OGnZnMXD6QRVzpibXGZXUDB
f6unujun5Ql4ObAWt6QuRqz5Gk2gF8tcOfN6edR/uK5gyX2rlWVLoZKOV91a3aDI
iIDh018tLWOpHg3VxgHL6f0iMcFogUYnD5zhC5Z2GVhFb/cVpj+ocZWcxQLQGPVv
uZPUQWrvdpFEzcnxPMtJJDqXEChzhrdFTXGm69ERxULOro7yDmG1Y5xWmhdGnPPM
cuCXVVlADz/Gh1w+ay7RqFnzPjqjQmHAuggns467TJEcS0yiX4LJnEoKLyPGen9L
FH6z38xHCNt4Da05/OeRgXwVLH9M95lu8d6TABEBAAG0U1NtYXJ0bW9udG9vbHMg
U2lnbmluZyBLZXkgKGV4dC4gdG8gMjAyNCkgPHNtYXJ0bW9udG9vbHMtZGF0YWJh
c2VAbGlzdGkuanBiZXJsaW4uZGU+iQFBBBMBAgArAhsDBQkPZe4NBgsJCAcDAgYV
CAIJCgsEFgIDAQIeAQIXgAUCXheK5gIZAQAKCRDzh2PO39IlWdUTCAC8v9Oa7umW
+/tXBiEtElDW/U2rEOC3OHWSzPvqE4iGjWc5fbvrAKS7bfccZM8Aq0a1t2pSbIlB
MvRrsNTGdQSPsOdhxPD8pEJW0uH9Z5VyPzoO9VIaoqi1irRdWnXCfhBJX9PLySAb
9BPQZXXQypmACieRDv31E4hiB+vYet/SpVuRyfL57XU3jmwFREip9OiFOp+61X2+
oIlgvNU60JZy2vXpTo6PNbDGetEycfH6Y8vfCXniihMkSfeOnNqWI/hycBDprFB5
CB5ShIH71vhCOPnVGwtYY30wlJ1+Ybg2ZAIi6JN8E38Dpx382IzeT2LydnZydiC6
PcLCr7mbsX3hiQEcBBMBAgAGBQJeF4sWAAoJEC/N7AvTrxqr7ZAH/jB4xFtBTo1x
w8CGwslZCJ+/BeEZ5XpV+8zLdeRV2tXegUFjGZ9FI6UpzBeVyK2R1qGbcdSf2S45
KutcM2gjKETW+ZwW76qHJD52mYihPPLXu2pRAG2WyH5GDnqNMj5iQ1inoPdZOTpi
evBMTv1YHJML6SiF6t/HoKorl5ffvHBE/1onBfUzLwQ/ct14sZ2UXHzyxdHo73vm
XWgcjQ1TQhCSdLqucQbwR78EyUa9tYxk/NWBqfc5YHt7t+KTVTLlp7Buk1wscLkj
NTlxl+IjAxRwsWc6PWnyRdAgXxtt2q6llYgFahWM21OyJVLVjbMGVF+oBtFumqq3
lQy6H6tp/1uJAhwEEwECAAYFAl4XiyMACgkQvwsznGS8qosSiw//QjbWDldB2gHf
3Tfs+LaFdzkDbioWdnj96DiCynTSwZF8d5ISqwA+QTL/43Y0msU26WBMvIRBg2Xm
+r4TMMfWF4a1Yjq6cisKEaUsbjV9ztzH/XB2ydo8HgnxZuVKQoIuh1sSrE7p6mpQ
YUrV5eWRpqc79AI9ZzRBM5nhbBejqLVw2F8dyz6c3lfGM9IOenp+Y8N43SdNpBcp
DuHnzbQIMtkyoX7tTKDDv5gnoRNCsdBsCduTyNWYOIEdhRiCfo5Ce7kufIoo4ZqV
BM8dzwm1RrcYa0kMKPZAucJDRjwevEYDbOg7vmEYsuGPRbVmOFdx4uMx4gX8vF5+
AG3rTSA805zkwD+WQXyYQohVZxNjeK7P/ukr6NCZx226gwAiw1ms7PYOo8snjK8e
nRlMTLKiGiMIH7xJu55JliVlcEvn3G7WO0n4qQOJj3Msh+xflBSfZmzBDAzPgxwC
m/RSmonGV0uZVJFDHCpqus35E6bzFF6yO3yXvpngAMTBrpX6Nzgea1SzlK2Iquls
te1GYAx/IXaY7cVYo4iEv/m346SINzLGHpXZkbbcenSgljBfHLCz7vF33IotfEWh
C7Kb4iKbEjERa+zzqR+vK+nDj6YG9Mvguj1EqnM47oDwgMaqWY6oPfefLCD8Tg51
rlAAGFdcWb9g034vgtK8l+ooUtn63PKJAhwEEwECAAYFAl4XiywACgkQ6nSrJXIQ
QsUuTRAAsSMmQ7jsvmljExwrmIu6Oyh+1J5D/GPBRYhSyip/bnxCscCBnpjEk8+7
VG9JtGTCa0zVY14Y3Cl4obND25QN9LhiE/y8olnIgJ2adtmpi6+zFpdGWVYUpDgZ
IMePUVKyZenTjezFwRlLsYsxbSb9wIR1iofP1l/dQF8DwhwFL9AGRmHTcWM1ZYoc
fv80A5SAposnspnkKKcuC3q2+pMsUtbHT9t/+iusVXBDERh+FPlvtYh+Khze3c8z
g4M9RsQLCanMp4jZhzgSakjeg9tCr33SIJIEKpn6MUftX9QC82S75UNwxXgC38EA
s2t+BjPLUaXENSdOe3l+KKY5ozbmRpRmQIHw7jlT3+9C0RUHGTPQYCidsx8OdYA0
4wDRWcjCQcXWxTaUoeaoMJcE1iv5IIf/X0MXYMlCPG8OKAlDE2Kkrx0A8agPp7JH
0UAOaqpAA74kZnpuvJ6BqrX2hMbNbyVg1rWu1BQA3qESa41rKiWyEtjiLdQ/NtNu
6BsPhDGvaQqGbu4t0GfJ1PhbFnHrVkLW8v1NzYZRpLXAFJGZdD6Ue/L6bHFOJ6SJ
JwAHjH26nxSMuDV779AUrnOcmoXIkj6sdAwDZ5Z2ri7b2MgkrJzeapKd0SItnWUQ
TMe7YUl8B+kUATj01YWMLtHsX9yciFP0iDagW14/rFJHtchOBcu0U1NtYXJ0bW9u
dG9vbHMgU2lnbmluZyBLZXkgKHRocm91Z2ggMjAxOCkgPHNtYXJ0bW9udG9vbHMt
ZGF0YWJhc2VAbGlzdGkuanBiZXJsaW4uZGU+iQE+BBMBAgAoAhsDBgsJCAcDAgYV
CAIJCgsEFgIDAQIeAQIXgAUJD2XuDQUCXheK5gAKCRDzh2PO39IlWTDxCACtkOGn
vUs/m/uE7IHoSM6wj/6OXXo+TEM1rgnl40oySVoMgyonx7PSwi9rSoDC8AfRhN2q
bFLEQcrGI8V7PxLpjsz5Z0m/ZnZJAP7TB5WhLRJdu3w2cssjekhIRc+I2B00gcRl
H//okXyvGte3kr1JdgaownbslwcZRxyNdvWigQH/Vnz91lKAujGULJyl7hv6Kl02
HYynYmxGmES3pd5VEOpA/DR7n54T2J+Vubh99RT+RH2v46e7LnPhZhN2uxvIiJKE
8Lp67l1aeMXfgZv6dQ7Dl+pu5lUUyyMQ+nUMBGKZBWftyqhekZrvYcVnTJYU93kU
41QULaRVIwg888kUiQEcBBMBAgAGBQJZ7kylAAoJEC/N7AvTrxqroQQH/jrZAGT5
t8uyzRTzJCf3Bco8FqwKcfw8hhpF1Uaypa+quxkpYz9PtP+3e9lGxl0XSEzOwHjf
gGWXISUOM1ufVxo2hSLG87yO7naFAtylL8l0Zny8Fb6kmT9f3vMktbHdXHUTDNrC
UkoElEwwDK3qaur8IPUaIKeSTC3C8E/DVnasLs9cpOs2LPIKr3ishbqbHNeWOgGy
HbA4KCtvQzBhun9drmtQJW6OyCC9FcIoqPSFM/bs2KHf7qATNu9kSMg/YWw7WLAD
4GPqH9us1GigQ0h6Y4KG5EgmkFvuQFPLHvT4rtqv51zzs1iwFh4+GIagFp+HJ2jn
lp+GcZcySlwfnemJAT4EEwECACgFAlnuSe4CGwMFCQQcDQAGCwkIBwMCBhUIAgkK
CwQWAgMBAh4BAheAAAoJEPOHY87f0iVZVMQIAK5wPezq0ROsxiCYPLcR9dF/Qdp2
1pLfodi6wsC9FAlTVJ3fk2vkNQDb5rMkNvZ/MHf2EWoVIFHvPZcJ6paBjZlapvGF
qDNrU6hDbakO0PIej5yy+qVeIYcSQpNZeHchAhOOJcnN0o8H6SzZik38b4Hb8H5X
do78LsZJwU0jsKG6LH3gjiWJtrC+WCXCMYzEGjAJXev2npU2DMVVwxsfYLfdZWq7
FJJINv8R9EUjtSQQIynJAwb2lFvZB+jC6u8Vv9N1Wid6wh5lF5ejMt6KXqWOvNn+
YreopmQfbn2XJZxpyn9d7Ev91epYW11E5qG4xNI3m3AmtEGjMTGjfMUstNK0V1Nt
YXJ0bW9udG9vbHMgU2lnbmluZyBLZXkgKHRocm91Z2ggMjAxOCkgPHNtYXJ0bW9u
dG9vbHMtZGF0YWJhc2VAbGlzdHMuc291cmNlZm9yZ2UubmV0PokBPgQTAQIAKAIb
AwYLCQgHAwIGFQgCCQoLBBYCAwECHgECF4AFAl4XiZMFCQ9l7g0ACgkQ84djzt/S
JVnl5Qf+PVRoLmEpDIqQ+58DMIwz98+yajCJ1vQvEOKjMcgeePOn475eV5Phkvsp
KtW6TedWhN9l/NcDZzEPCpkhrz24WJDLFV+o16B4MZwSkGTl4/3qijERKsd8M+MS
tiLr3+eUCFi4dAp0uhPytETvUmtj3ByA0R2luoOK+kEutq6i2x9BPr8Qc55Lqdwt
SK8pPU05WSaCu1m2oThJhkELVklOQ2cj+D8MrQdJGd3plEb9j5oUbhj7LW/y0i4M
lqk1rQCQKnY3vTFQBpj1o7T6kLiGqQCOLTX0B6RQ8vt+PEzXPHi0lIdwOrQk5l7h
utnjwXmWaWEpRjlsuQ5PBrFDsD9N+IkBHAQTAQIABgUCWA5kYwAKCRDfDxpJxKSQ
Op+/CADTlsgisoXI6b+0oohRaD4ZVl5eBtkvTrxNQf6EF7Z1uPkVOqi1OLWFGyAm
beLcRmN6c4/DVcaa6GAG7GA+KQwVPRCyC+9Ibsn/+uG6ZFXAez+0eG9NxOfkCnYH
8ZP8o2VH+9uKJlGGujh9o5r1SNGVifoLGTc8NkWCW+MAKj8dw8WW+wDc80YrdCRr
SyLrRU9NLTSE4pIJWKcHLwG63xkXHQPPR1lsJgzdAalfEv1TQdIF3sM+GXp4lZ6b
uahFDiILBh1vj+5C9TdpWZAlqHDYFICa7Rv/MvQa4O9UUl3SlN3sed8zwAmL3Heo
XE5tBu8iatMaS9e3BmSsVYlhd/q+iQEcBBMBAgAGBQJYDmSWAAoJEC/N7AvTrxqr
8HsH+QGQuhHYt9Syccd8AF36psyT03mqgbGLMZL8H9ngoa9ZqVMq7O8Aqz23SGTt
uNuw6EyrcHo7Dy1311GftshI6arsFNJxE2ZNGIfGocRxu9m3Ez+AysWT9sxz/haH
E+d58NTg+/7R8YWS1q+Tk6m8dA0Xyf3tMBsIJfj0zJvuGMbCLmd93Yw4nk76qtSn
9UHbnf76UJN5SctAd8+gK3uO6O4XDcZqC06xkWKl193lzcC8sZJBdI15NszC3y/e
pnILDDMBUNQMBm/XlCYQUetyrJnAVzFGXurtjEXQ/DDnbfy2Z8efoG8rtq7v3fxS
1TC5jSVOIEqOE4TwzRz1Y/dfqSU=
=3Lcg
-----END PGP PUBLIC KEY BLOCK-----
";
    } elsif ($arg1 =~ /^RELEASE_7_\[023\]_DRIVEDB$/msx) {
                $public_key = "\
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
90iSgZdt5cZgoH04weXCMwDugn/+Q3rzKvRUTrEfSOivJYg65D/mhbz6HoUTs4JD
SstTYa9qNCwKQGRSeis4PAgu0hCpnDAhZuN3Ja5AFC2Wi2szQ7R+Zx/JucIBm5S4
U30W66MtsyUHeulSJ3AV3HrbFfnqu6zfQM4XLw7MpAtQUNJceS/lWfGIquAp3tY/
IjZIHwgZqKB3czWDhM83wBzCWgAmxyzIrpb4MBYJ5PGuCyC7R/YTdtPJXxsPQl2l
znsX/9ssa4kBHAQTAQIABgUCX+CfSAAKCRDzh2PO39IlWVcuB/9UkLaPtGY4sDDV
/A7qjSvSy93mv8gkaIj9dhqoZw+r7cLiEtX04Cz9PqocOFgCYJXKrufHNNkHke2A
jE9EJfRKiPU/bkeWmrACvtrOd/DZbdmXfxTOekOr516D2ip/U8GBPw6zxfCQVot6
htpBpB6zzMDtzMOeLnkOxoxR4EMu5K6eJ48bHvG/lbGBByyfRzhtqPh6AAA9G1CC
IdhNkaA5W1qums3N1mCXrTBnWyjaFhdnttGQfrMdHvTQ77HeL0c2axT2y5PYfrXY
2ZfZowYLEtFXRSTpDaJfgG+qem3N+pMv6SMOG/4CvlH4/3Hq0aCNvKcY5KUXfIgT
xmc3/n/wtFNTbWFydG1vbnRvb2xzIFNpZ25pbmcgS2V5ICh0aHJvdWdoIDIwMjAp
IDxzbWFydG1vbnRvb2xzLWRhdGFiYXNlQGxpc3RpLmpwYmVybGluLmRlPokCPgQT
AQIAKAIbAwYLCQgHAwIGFQgCCQoLBBYCAwECHgECF4AFAl/gnzAFCQ0umpsACgkQ
6nSrJXIQQsVK7RAAqbZfT3wZEfJkw8MK2JlvgGWH76fHKn5ZoH5i0mA4AvN4QLbU
5Q20HmqHnO9mfAZQ6u4Tn/aFcYT7nlSsEsEmFX+s5QU2y6m2Tx9ThDbZ03ezREOS
0wNf0FOQunV9ZVPT/7cKIgWJa5mZy+LClor9OHllyGUfs9tKNzwxaHh1zBrCNJow
Fi/1bkWy3iMc7vZhWHASwPSp64KHjB4UdMz2hV4pROiUhWi7BY0exIHyZrkcANMP
Hhl9lP32ZvNbOy8osBdPUgXyK3HePD+ftcwJMkoc4mFQXYi9UY7NQpk7STRO10cx
Kq/CgDDvYxbnViRjQoJ0sfwKCaOfsnY/gea7I0aCx8uNISYpHO9iMidd/tJ7+lgx
NiKZTI0EppHYvkyMY15/NGb0gTJbYjuVYdbqDS9mnLuLQAjAX43+n9ND2NjX1o0q
Z9bBqV2VFioNmnxKqGphhRFX9jEzTklieOjhpRrd8v9ljprT6vLFNpYpeLkel8om
VFXrHxrfzKtVFcto5wqHVOcyZyE2zm1QmsS8qvWOTrNfY6p2q9MA2rysqdfgfvN7
pNDaXutK6ooQi6YlyyTA2ANnHFKa0ncRH+dg+5OF9rhNvM7RyaBXgxF7+5gnU5Gb
VQRKbJ+LOtSKkj0pApR5AKSwyGslZ2bNVlKsADWhk5xj8QlHVlNWiht+i/6JARwE
EwECAAYFAlwmhpwACgkQL83sC9OvGqsVOggAqLB5eQrUv8E9ikD6kJCito827bzD
WF29yD7PvfhjXaz5in54jOVpwg3o9CsqIjjRW0/1bBVswC8ZL0sAdZ+GDSDMw5F2
IpkD77gjnFY79M/e6C9xYyxYzHC7emDPSz9IroOvdkkEgrB+OABKkaOCcS18P4Lk
3WNHaPw5c7aI0z1iJP52EmSfvB8r86mtUFJB+f15eD/4vaRfkZLFjF9FQ3kgEK1U
+rV4s1O2bCFfP3WPDcc83NgwRUvtXmcSOSOIoXnemJzyJr+JnqCWVET4XWF6i20m
RFXVEpWtf5AkJYgR3z/jW0djELbBWA/35bAnpXy5pDHv9NbZsTkBZxK/kokBHAQT
AQIABgUCXCaGnQAKCRAY7NpGy/a6xn4lB/90tXTnZsgmoftol9uivfQrPdR88WmO
ZLYmUeQAd1rqSFMxe+KzO/qLuU8s6OF4nznwL2cPfbGZxezM4PiYmAmbbEU/3gTO
NwjVBBA0Gfimy/fITEezFtCigo1thkaJ195g/dqY+zE3Vt4rzC03j1vx8mUHRPU6
kkvKj8cP0j+XHX2xQDsTXTstfnom29wBmGnvSZ9HgcdL71e1VXJXwikmnO3P4J/1
C2LeCOlWrGqWZ2c0WBLKdJnsYUx7Dm/OvkkB4lF+zWp98zS8jS/5h+1apVgEzrdT
MvT8ydTkUr7ObKGkIhK+L+Xo5BD+V9Qf6xKGYPwhhdj/E5/kyjULrm10iQEcBBMB
AgAGBQJcJoadAAoJEPOHY87f0iVZfiUH/3yKS5wGvTeRInse8+W1WzKuto3XzqXL
ngb9QXWw7nCwqmNS7PbzDnufQi2ThKrMfcK14WgNYABNZPU75I+6bcb0oCB5tloo
IUEV/2Ut/5Hl/83zFFoNA/kQKVz8kIDqgRcxC+zY2VJ4eTKHyQDvXygVk8wnKTBa
e3gX+CIZqJHPXiiygHlbl31Mi3G1Iaxu57dP6ocV0vX1dytKSwd4Rbviwwb4L76o
/tVT9t3GwFM15uK1SqtnAaiaktEdMi3XI4d01H3VUVz/iR0XQbf13RZoEM6CJWms
Q/qvYlwkbKOdlahjoHrFlkhADSBaO9N1OZp3OYDjziIujMdt2IPKnmM=
=7MQk
-----END PGP PUBLIC KEY BLOCK-----
";
    } elsif (1) {
                error("No known public key for branches/$_[0]");
    }
    return;
}

sub gpg_verify {
    my $gnupgtmp;
    my $i;
    my $out;
    my $rc;
    $gnupgtmp = "$ENV{tmpdir}/.gnupg.$ENV{$}.tmp";
if ( -e "$gnupgtmp" ) {
        if ( -d "$gnupgtmp" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$gnupgtmp", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "$gnupgtmp", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$gnupgtmp" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$gnupgtmp",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
        use File::Path qw(make_path);
    my $err;
    if ( mkdir "$gnupgtmp" ) {
        }
    else {
        croak "mkdir: cannot create directory " . "$gnupgtmp" . ": File exists\n";
    }
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
chmod(oct('0700'), ("$gnupgtmp")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
if (!(!($out = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_3 = q{};
        my $output_printed_3;
        my $pipeline_success_3 = 1;
        $output_3 .= $public_key . "\n";
        if ( !($output_3 =~ m{\n\z}msx) ) { $output_3 .= "\n"; }
        $CHILD_ERROR = 0;
        my $cmd_5 = 'unknown_command';
        my ($in_4, $out_4);
        my $pid_4 = open3($in_4, $out_4, '>&STDERR', $cmd_5, '--batch', '--no-tty', '--homedir=$gnupgtmp', '--import');
        print {$in_4} $output_3;
        close $in_4 or croak 'Close failed: $OS_ERROR';
        $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
        close $out_4 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_4, 0;
        if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
        $output_3 =~ s/\n+\z//msx;
        $output_3;
}; $_pipeline_result; };))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print $out;
if ( !( ($out) =~ m{\n\z}msx ) ) { print "\n"; }
        };
exit 1;
    }
    vecho("$out");
    $rc = q{0};
        $out = do { my @_qx_cmd = ("$gpg --batch --no-tty --homedir=$gnupgtmp --verify \"$1\" \"$2\" < /dev/null 2>&1"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    if ($CHILD_ERROR != 0) {
                $rc = q{1};
    }
if ($rc eq 0) {
        vecho("$out");
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print $out;
if ( !( ($out) =~ m{\n\z}msx ) ) { print "\n"; }
        };
    }
if ("$gpgconf" ne q{}) {
                $out = do { my @_qx_cmd = ("$gpgconf --homedir=$gnupgtmp --kill gpg-agent < /dev/null 2>&1"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        if ($CHILD_ERROR != 0) {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print $out;
if ( !( ($out) =~ m{\n\z}msx ) ) { print "\n"; }
            };
        }
    }
    $i = q{0};
while ( !($out = do { my @_qx_cmd = ("rm -f -r \"$gnupgtmp\" 2>&1"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };) ) {
        $i = eval { int($i+1) } // "";
if (($i >= $MAGIC_10)) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print $out;
if ( !( ($out) =~ m{\n\z}msx ) ) { print "\n"; }
            };
last;
        }
        vecho("$out");
require Time::HiRes; Time::HiRes::sleep(q{1});
    }
return $rc;
    return;
}

sub get_db_version {
    my $r;
    my $v;
    my $x;
        $x = do { my @_qx_cmd = (q<sed -n "/^[ {]*\"VERSION: *[^\"]*\"/{
       s,^[ {]*\"VERSION: \\([1-9][./0-9]* [^\"]*\\)\".*\$,\\1,p
       q
     }" "$1">); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    if ($CHILD_ERROR != 0) {
        return q{1};    }
    $v = ${x} =~ s/ .*$//sr;
        $main_exit_code = system('test', '-n', "$v") >> 8;
    if ($CHILD_ERROR != 0) {
        return q{0};    }
if ("${v%/*}" eq "$v") {
        $r = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_7 = q{};
            my $output_printed_7;
            my $pipeline_success_7 = 1;
            $output_7 .= $x . "\n";
            if ( !($output_7 =~ m{\n\z}msx) ) { $output_7 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_7 = 0; }
            my @sed_lines_7 = split /\n/msx, $output_7;
            my @sed_result_7;
            foreach my $line (@sed_lines_7) {
            chomp $line;
            push @sed_result_7, $line;
            }
            $output_7 = join "\n", @sed_result_7;

            if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_7 =~ s/\n+\z//msx;
            $output_7;
}; $_pipeline_result; };
                $main_exit_code = system('test', '-n', "$r") >> 8;
        if ($CHILD_ERROR != 0) {
                        $r = "?";
        }
        $v = "$v/$r";
    }
    print $v;
if ( !( ($v) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}

sub mv_all {
    if (do {
if (do {
my $err;
my $force = 1;
if ( -e "$_[0] . $_[1]" ) {
    my $dest = $_[0] . $_[2];
    if ( -e $dest && -d $dest ) {
        my $source_name = "$_[0] . $_[1]";
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
    if ( File::Copy::move( "$_[0] . $_[1]", $dest ) ) {
    } else {
        croak
  "mv: cannot move "$_[0] . $_[1]" to $dest: $ERRNO\n";
    }
} else {
    croak "mv: "$_[0] . $_[1]": No such file or directory\n";
}
    $CHILD_ERROR == 0
}) {
        if ( -e "$_[0] . $_[1] . ".raw"" ) {
        my $dest = $_[0] . $_[2] . ".raw";
        if ( -e $dest && -d $dest ) {
            my $source_name = "$_[0] . $_[1] . ".raw"";
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
        if ( File::Copy::move( "$_[0] . $_[1] . ".raw"", $dest ) ) {
        } else {
            croak
  "mv: cannot move "$_[0] . $_[1] . ".raw"" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "$_[0] . $_[1] . ".raw"": No such file or directory\n";
    }
}
        $CHILD_ERROR == 0
    }) {
        if ((-f "${1}${2}.raw.asc")) {
            if ( -e "$_[0] . $_[1] . ".raw.asc"" ) {
                my $dest = $_[0] . $_[2] . ".raw.asc";
                if ( -e $dest && -d $dest ) {
                    my $source_name = "$_[0] . $_[1] . ".raw.asc"";
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
                if ( File::Copy::move( "$_[0] . $_[1] . ".raw.asc"", $dest ) ) {
                } else {
                    croak
  "mv: cannot move "$_[0] . $_[1] . ".raw.asc"" to $dest: $ERRNO\n";
                }
            } else {
                croak "mv: "$_[0] . $_[1] . ".raw.asc"": No such file or directory\n";
            }
}
        else {
if ( -e "$_[0] . $_[2] . ".raw.asc"" ) {
                if ( -d "$_[0] . $_[2] . ".raw.asc"" ) {
                    carp "rm: carping: ", $_[0] . $_[2] . ".raw.asc",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$_[0] . $_[2] . ".raw.asc"" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", $_[0] . $_[2] . ".raw.asc",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
    }
    return;
}
$smartctl = $default_smartctl;
$tool = q{};
my $url_of;
my @url_of;
my %url_of;
$url_of = q{};
$url = q{};
$file = q{};
my $quiet;
my @quiet;
my %quiet;
$quiet = q{};
my $q;
my @q;
my %q;
$q = "-q";
my $dryrun;
my @dryrun;
my %dryrun;
$dryrun = q{};
$trunk = q{};
my $branch;
my @branch;
my %branch;
$branch = $default_branch;
my $cacert;
my @cacert;
my %cacert;
$cacert = q{};
my $capath;
my @capath;
my %capath;
$capath = q{};
my $insecure;
my @insecure;
my %insecure;
$insecure = q{};
$no_verify = q{};
$force = q{};
$expkey = q{};
my $usageerr;
my @usageerr;
my %usageerr;
$usageerr = q{t};
while ( 1 ) {
if ($arg1 =~ /^-s$/msx or $arg1 =~ /^--smartctl$/msx) {
                check_optarg("@ARGV");
        # Builtin command 'shift' not implemented
                $smartctl = $1;
    } elsif ($arg1 =~ /^-t$/msx or $arg1 =~ /^--tool$/msx) {
                check_optarg("@ARGV");
        # Builtin command 'shift' not implemented
                $tool = $1;
    } elsif ($arg1 =~ /^-u$/msx or $arg1 =~ /^--url-of$/msx) {
                check_optarg("@ARGV");
        # Builtin command 'shift' not implemented
                $url_of = $1;
    } elsif ($arg1 =~ /^-q$/msx or $arg1 =~ /^--quiet$/msx) {
                $quiet = q{t};
    } elsif ($arg1 =~ /^-v$/msx or $arg1 =~ /^--verbose$/msx) {
                $q = q{};
    } elsif ($arg1 =~ /^--url$/msx) {
                check_optarg("@ARGV");
        # Builtin command 'shift' not implemented
                $url = $1;
    } elsif ($arg1 =~ /^--file$/msx) {
                check_optarg("@ARGV");
        # Builtin command 'shift' not implemented
                $file = $1;
    } elsif ($arg1 =~ /^--install$/msx) {
                        $main_exit_code = system('test', "$drivedbinstdir", q{!}, q{=}, "$drivedbdir") >> 8;
        if ($CHILD_ERROR != 0) {
                        error("'$_[0]' is not supported in this configuration");
        }
                $file = "$drivedbinstdir/drivedb.h";
                $no_verify = q{t};
    } elsif ($arg1 =~ /^--dryrun$/msx) {
                $dryrun = q{t};
    } elsif ($arg1 =~ /^--trunk$/msx) {
                $trunk = q{t};
    } elsif ($arg1 =~ /^--branch$/msx) {
                check_optarg("@ARGV");
        # Builtin command 'shift' not implemented
                $branch = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_12 = q{};
            my $output_printed_12;
            my $pipeline_success_12 = 1;
            $output_12 .= $1 . "\n";
            if ( !($output_12 =~ m{\n\z}msx) ) { $output_12 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_12 = 0; }
            my @sed_lines_12 = split /\n/msx, $output_12;
            my @sed_result_12;
            foreach my $line (@sed_lines_12) {
            chomp $line;
            push @sed_result_12, $line;
            }
            $output_12 = join "\n", @sed_result_12;

            if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_12 =~ s/\n+\z//msx;
            $output_12;
}; $_pipeline_result; };
                        $main_exit_code = system('test', '-n', "$branch") >> 8;
        if ($CHILD_ERROR != 0) {
                        error("invalid branch version '$_[0]'");
        }
    } elsif ($arg1 =~ /^--cacert$/msx) {
                check_optarg("@ARGV");
        # Builtin command 'shift' not implemented
                $cacert = $1;
    } elsif ($arg1 =~ /^--capath$/msx) {
                check_optarg("@ARGV");
        # Builtin command 'shift' not implemented
                $capath = $1;
    } elsif ($arg1 =~ /^--insecure$/msx) {
                $insecure = q{t};
    } elsif ($arg1 =~ /^--no-verify$/msx) {
                $no_verify = q{t};
    } elsif ($arg1 =~ /^--force$/msx) {
                $force = q{t};
    } elsif ($arg1 =~ /^--export-key$/msx) {
                $expkey = q{t};
    } elsif ($arg1 =~ /^-h$/msx or $arg1 =~ /^--help$/msx) {
                print_help();
        exit 0;
    } elsif ($arg1 =~ /^-.*$/msx) {
                error("unknown option '$_[0]'");
    } elsif (1) {
        last;    }
# Builtin command 'shift' not implemented
}
if ("$expkey" ne q{}) {
    selectkey("$branch");
print "$public_key
";
exit 0;
}
if (scalar(@ARGV) =~ /^0$/msx) {
        $drivedb = $default_drivedb;
} elsif (scalar(@ARGV) =~ /^1$/msx) {
        $drivedb = $1;
} elsif (1) {
        error("only one DESTFILE argument is allowed");
}
if ((defined (defined ${url_of} && ${url_of} ne q{} ? ${url_of} : 'url_of') && (defined ${url_of} && ${url_of} ne q{} ? ${url_of} : 'url_of') ne q{} ? (defined ${url_of} && ${url_of} ne q{} ? ${url_of} : 'url_of') : 'url_of') . (defined (defined ${url} && ${url} ne q{} ? ${url} : 'url') && (defined ${url} && ${url} ne q{} ? ${url} : 'url') ne q{} ? (defined ${url} && ${url} ne q{} ? ${url} : 'url') : 'url') . (defined (defined ${file} && ${file} ne q{} ? ${file} : 'file') && (defined ${file} && ${file} ne q{} ? ${file} : 'file') ne q{} ? (defined ${file} && ${file} ne q{} ? ${file} : 'file') : 'file') =~ /^$/msx or (defined (defined ${url_of} && ${url_of} ne q{} ? ${url_of} : 'url_of') && (defined ${url_of} && ${url_of} ne q{} ? ${url_of} : 'url_of') ne q{} ? (defined ${url_of} && ${url_of} ne q{} ? ${url_of} : 'url_of') : 'url_of') . (defined (defined ${url} && ${url} ne q{} ? ${url} : 'url') && (defined ${url} && ${url} ne q{} ? ${url} : 'url') ne q{} ? (defined ${url} && ${url} ne q{} ? ${url} : 'url') : 'url') . (defined (defined ${file} && ${file} ne q{} ? ${file} : 'file') && (defined ${file} && ${file} ne q{} ? ${file} : 'file') ne q{} ? (defined ${file} && ${file} ne q{} ? ${file} : 'file') : 'file') =~ /^url_of$/msx) {
            $main_exit_code = system('test', '-n', "$url_of") >> 8;
    if ($CHILD_ERROR != 0) {
                $url_of = 'svn';
    }
        selecturl("$url_of");
    if ("$trunk" eq q{}) {
        $url = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_13 = q{};
            my $output_printed_13;
            my $pipeline_success_13 = 1;
            $output_13 .= $url . "\n";
            if ( !($output_13 =~ m{\n\z}msx) ) { $output_13 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_13 = 0; }
            my @sed_lines_13 = split /\n/msx, $output_13;
            my @sed_result_13;
            foreach my $line (@sed_lines_13) {
            chomp $line;
            push @sed_result_13, $line;
            }
            $output_13 = join "\n", @sed_result_13;

            if ( !$pipeline_success_13 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_13 =~ s/\n+\z//msx;
            $output_13;
}; $_pipeline_result; };
}
    else {
        if ("$no_verify" eq q{}) {
            error("'--trunk' requires '--no-verify'");
        }
    }
} elsif ((defined (defined ${url_of} && ${url_of} ne q{} ? ${url_of} : 'url_of') && (defined ${url_of} && ${url_of} ne q{} ? ${url_of} : 'url_of') ne q{} ? (defined ${url_of} && ${url_of} ne q{} ? ${url_of} : 'url_of') : 'url_of') . (defined (defined ${url} && ${url} ne q{} ? ${url} : 'url') && (defined ${url} && ${url} ne q{} ? ${url} : 'url') ne q{} ? (defined ${url} && ${url} ne q{} ? ${url} : 'url') : 'url') . (defined (defined ${file} && ${file} ne q{} ? ${file} : 'file') && (defined ${file} && ${file} ne q{} ? ${file} : 'file') ne q{} ? (defined ${file} && ${file} ne q{} ? ${file} : 'file') : 'file') =~ /^url$/msx) {
            $main_exit_code = system('test', '-z', (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_14 = q{};
        my $output_printed_14;
        my $pipeline_success_14 = 1;
        $output_14 .= $url . "\n";
        if ( !($output_14 =~ m{\n\z}msx) ) { $output_14 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_14 = 0; }
        my @sed_lines_14 = split /\n/msx, $output_14;
        my @sed_result_14;
        foreach my $line (@sed_lines_14) {
        chomp $line;
        push @sed_result_14, $line;
        }
        $output_14 = join "\n", @sed_result_14;

        if ( !$pipeline_success_14 ) { $main_exit_code = 1; }
        $output_14 =~ s/\n+\z//msx;
        $output_14;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; })) >> 8;
    if ($CHILD_ERROR != 0) {
                error("$url: Invalid URL");
    }
} elsif ((defined (defined ${url_of} && ${url_of} ne q{} ? ${url_of} : 'url_of') && (defined ${url_of} && ${url_of} ne q{} ? ${url_of} : 'url_of') ne q{} ? (defined ${url_of} && ${url_of} ne q{} ? ${url_of} : 'url_of') : 'url_of') . (defined (defined ${url} && ${url} ne q{} ? ${url} : 'url') && (defined ${url} && ${url} ne q{} ? ${url} : 'url') ne q{} ? (defined ${url} && ${url} ne q{} ? ${url} : 'url') : 'url') . (defined (defined ${file} && ${file} ne q{} ? ${file} : 'file') && (defined ${file} && ${file} ne q{} ? ${file} : 'file') ne q{} ? (defined ${file} && ${file} ne q{} ? ${file} : 'file') : 'file') =~ /^file$/msx) {
} elsif (1) {
        error("only one of '-u', '--url', '--file' is allowed");
}
$file_asc = q{};
$url_asc = q{};
if ("$no_verify" eq q{}) {
if ($url =~ /^$/msx) {
                $file_asc = "$file.raw.asc";
    } elsif ($url =~ /^.*\..*$/msx) {
                $url_asc = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_15 = q{};
            my $output_printed_15;
            my $pipeline_success_15 = 1;
            $output_15 .= $url . "\n";
            if ( !($output_15 =~ m{\n\z}msx) ) { $output_15 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_15 = 0; }
            my @sed_lines_15 = split /\n/msx, $output_15;
            my @sed_result_15;
            foreach my $line (@sed_lines_15) {
            chomp $line;
            push @sed_result_15, $line;
            }
            $output_15 = join "\n", @sed_result_15;

            if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_15 =~ s/\n+\z//msx;
            $output_15;
}; $_pipeline_result; };
    } elsif (1) {
                $url_asc = "$url.raw.asc";
    }
}
if ("$file" eq q{}) {
if ("$tool" eq q{}) {
        my $t;
        for my $t ($os_dltools) {
if (!(            inpath("$t"))) {
                $tool = $t;
last;
            }
        }
                $main_exit_code = system('test', '-n', "$tool") >> 8;
        if ($CHILD_ERROR != 0) {
                        error("found none of '$os_dltools' in $pathinfo");
        }
}
    else {
        my $found;
        my @found;
        my %found;
        $found = q{};
        for my $t ($os_dltools) {
if (basename(${tool}) =~ /^$t.*$/msx) {
                                $found = q{t};
                last;            }
        }
                $main_exit_code = system('test', '-n', "$found") >> 8;
        if ($CHILD_ERROR != 0) {
                        error("$tool: is none of '$os_dltools'");
        }
    }
}
if ("$tool:$url_of" =~ /^svn:svn.*$/msx) {
} elsif ("$tool:$url_of" =~ /^svn:.*$/msx) {
        error("'-t svn' requires '-u svn' or '-u svni'");
}
if ("$tool:" . (defined (defined ${capath} && ${capath} ne q{} ? ${capath} : 'set') && (defined ${capath} && ${capath} ne q{} ? ${capath} : 'set') ne q{} ? (defined ${capath} && ${capath} ne q{} ? ${capath} : 'set') : 'set') =~ /^svn:set$/msx) {
        warning("'--capath' is ignored if '-t svn' is used");
}
if ("$url_of:$insecure" =~ /^svni:t$/msx) {
        $insecure = q{};
} elsif ("$url_of:$insecure" =~ /^svni:.*$/msx) {
        error("'-u svni' requires '--insecure'");
}
if ("$tool:$insecure" =~ /^lynx:t$/msx) {
        warning("'--insecure' is ignored if '-t lynx' is used");
}
if ("$smartctl" ne "-") {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $CHILD_ERROR = 0;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
                err_notfound("$smartctl", "('-s -' to ignore)");
    }
}
my $gpgconf;
my @gpgconf;
my %gpgconf;
$gpgconf = q{};
if ("$no_verify" eq q{}) {
        $main_exit_code = system('test', '-n', "$gpg") >> 8;
    if ($CHILD_ERROR != 0) {
                error("GnuPG is not available ('--no-verify' to ignore)");
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $CHILD_ERROR = 0;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
                err_notfound("$gpg", "('--no-verify' to ignore)");
    }
    selectkey("$branch");
if ($gpg =~ /^.*/.*$/msx) {
                $gpgconf = ( ( dirname(${gpg}) ) =~ s|/[^/]*$||sr ) . "/gpgconf";
    } elsif (1) {
                $gpgconf = "gpgconf";
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $CHILD_ERROR = 0;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
                $gpgconf = q{};
    }
}
$usageerr = q{};
my $tmpdir;
my @tmpdir;
my %tmpdir;
$tmpdir = do { use File::Basename qw(dirname); my $dirname_output = dirname("$drivedb"); $CHILD_ERROR = 0; $dirname_output; };
$main_exit_code = system('test', '-n', "$dryrun") >> 8;
if ($CHILD_ERROR != 0) {
    if ( -e "$drivedb.new" ) {
        if ( -d "$drivedb.new" ) {
            carp "rm: carping: ", "$drivedb.new",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$drivedb.new" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$drivedb.new",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "$drivedb.new.raw" ) {
        if ( -d "$drivedb.new.raw" ) {
            carp "rm: carping: ", "$drivedb.new.raw",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$drivedb.new.raw" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$drivedb.new.raw",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "$drivedb.new.raw.asc" ) {
        if ( -d "$drivedb.new.raw.asc" ) {
            carp "rm: carping: ", "$drivedb.new.raw.asc",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$drivedb.new.raw.asc" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$drivedb.new.raw.asc",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}
if ($CHILD_ERROR != 0) {
    exit 1;
}
if ("$url" ne q{}) {
    vecho("Download drivedb.h with $tool");
    $rc = q{0};
        download("$url", "$drivedb.new");
    if ($CHILD_ERROR != 0) {
                $rc = $?;
    }
if ($rc ne 0) {
if ( -e "$drivedb.new" ) {
            if ( -d "$drivedb.new" ) {
                carp "rm: carping: ", "$drivedb.new",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$drivedb.new" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$drivedb.new",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
        error("drivedb.h: download failed ($tool: exit $rc)");
    }
if ("$url_asc" ne q{}) {
        vecho("Download drivedb.h.raw.asc with $tool");
        $rc = q{0};
                download("$url_asc", "$drivedb.new.raw.asc");
        if ($CHILD_ERROR != 0) {
                        $rc = $?;
        }
if ($rc ne 0) {
if ( -e "$drivedb.new" ) {
                if ( -d "$drivedb.new" ) {
                    carp "rm: carping: ", "$drivedb.new",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$drivedb.new" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$drivedb.new",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
if ( -e "$drivedb.new.raw.asc" ) {
                if ( -d "$drivedb.new.raw.asc" ) {
                    carp "rm: carping: ", "$drivedb.new.raw.asc",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$drivedb.new.raw.asc" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$drivedb.new.raw.asc",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
            error("drivedb.h.raw.asc: download failed ($tool: exit $rc) ('--no-verify' to ignore)");
        }
    }
}
else {
if ((!-f "$file")) {
        error("$file: file not found");
    }
if (("$file_asc" ne q{} && (!-f "$file_asc"))) {
        error("$file_asc: file not found ('--no-verify' to ignore)");
    }
if (!(!(vrun('cp', "$file", "$drivedb.new");))) {
        error("$file: copy failed");
    }
if ("$file_asc" ne q{}) {
if (!(!(vrun('cp', "$file_asc", "$drivedb.new.raw.asc");))) {
if ( -e "$drivedb.new" ) {
                if ( -d "$drivedb.new" ) {
                    carp "rm: carping: ", "$drivedb.new",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$drivedb.new" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$drivedb.new",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
            error("$file_asc: copy failed");
        }
    }
}
$main_exit_code = system('test', '-z', "$dryrun") >> 8;
if ($CHILD_ERROR != 0) {
    exit 0;
}
if (!(!(my $errmsg;
my @errmsg;
my %errmsg;
$errmsg = do {
    my ($in_16, $out_16);
    my $pid_16 = open3($in_16, $out_16, '>&STDERR', 'check_file', "$drivedb.new", q{/}, '10000', '1000000');
    close $in_16 or croak 'Close failed: $OS_ERROR';
    my $result_16 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_16> };
    close $out_16 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_16, 0;
    $result_16
};))) {
if ( -e "$drivedb.new.raw.asc" ) {
        if ( -d "$drivedb.new.raw.asc" ) {
            carp "rm: carping: ", "$drivedb.new.raw.asc",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$drivedb.new.raw.asc" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$drivedb.new.raw.asc",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    my $err;
    my $force = 1;
    if ( -e "$drivedb.new" ) {
        my $dest = "$drivedb.error";
        if ( -e $dest && -d $dest ) {
            my $source_name = "$drivedb.new";
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
        if ( File::Copy::move( "$drivedb.new", $dest ) ) {
        } else {
            croak
  "mv: cannot move "$drivedb.new" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "$drivedb.new": No such file or directory\n";
    }
    error("$drivedb.error: $errmsg");
}
if ( -e "$drivedb.new" ) {
    my $current_time = time;
    utime $current_time, $current_time, "$drivedb.new";
}
else {
    if ( open my $fh, '>', "$drivedb.new" ) {
        close $fh or croak "Close failed: $ERRNO";
    }
    else {
        croak "touch: cannot create ", "$drivedb.new",
          ": $ERRNO\n";
    }
}
chmod(oct('0644'), ("$drivedb.new")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
if ((-f "$drivedb.new.raw.asc")) {
if (!(!($errmsg = do {
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', 'check_file', "$drivedb.new.raw.asc", q{-}, '200', '2000');
    close $in_20 or croak 'Close failed: $OS_ERROR';
    my $result_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    $result_20
};))) {
if ( -e "$drivedb.new" ) {
            if ( -d "$drivedb.new" ) {
                carp "rm: carping: ", "$drivedb.new",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$drivedb.new" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$drivedb.new",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
        if ( -e "$drivedb.new.raw.asc" ) {
            my $dest = "$drivedb.error.raw.asc";
            if ( -e $dest && -d $dest ) {
                my $source_name = "$drivedb.new.raw.asc";
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
            if ( File::Copy::move( "$drivedb.new.raw.asc", $dest ) ) {
            } else {
                croak
  "mv: cannot move "$drivedb.new.raw.asc" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "$drivedb.new.raw.asc": No such file or directory\n";
        }
        error("$drivedb.error.raw.asc: $errmsg");
    }
    if ( -e "$drivedb.new.raw.asc" ) {
        my $current_time = time;
        utime $current_time, $current_time, "$drivedb.new.raw.asc";
    }
    else {
        if ( open my $fh, '>', "$drivedb.new.raw.asc" ) {
            close $fh or croak "Close failed: $ERRNO";
        }
        else {
            croak "touch: cannot create ", "$drivedb.new.raw.asc",
              ": $ERRNO\n";
        }
    }
chmod(oct('0644'), ("$drivedb.new.raw.asc")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
open STDIN, '<', "$drivedb.new" or croak "Cannot open file: $OS_ERROR\n";
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', "$drivedb.new.raw"
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    unexpand_svn_id();
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
chmod(oct('0644'), ("$drivedb.new.raw")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
$equal = q{};
if ((-f "$drivedb")) {
if ((!-f "$drivedb.raw")) {
open STDIN, '<', "$drivedb" or croak "Cannot open file: $OS_ERROR\n";
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$drivedb.raw"
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            unexpand_svn_id();
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
chmod(oct('0644'), ("$drivedb.raw")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
if ((!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('cmp', "$drivedb.raw", "$drivedb.new.raw") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }) && !(                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('cmp', "$drivedb", "$drivedb.new") >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ($CHILD_ERROR != 0) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('cmp', "$drivedb.raw", "$drivedb.new") >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }))) {
        $equal = q{t};
    }
}
if ("$no_verify" eq q{}) {
if (!(!(gpg_verify("$drivedb.new.raw.asc", "$drivedb.new.raw");))) {
        mv_all("$drivedb", ".new", ".error");
                $main_exit_code = system('test', '-z', "$equal") >> 8;
        if ($CHILD_ERROR != 0) {
                        warning("$drivedb: *** installed file is identical to broken new file ***");
        }
        error("$drivedb.error.raw: *** BAD signature or outdated key ***");
    }
}
$newver = do {
    my ($in_26, $out_26);
    my $pid_26 = open3($in_26, $out_26, '>&STDERR', 'get_db_version', "$drivedb.new");
    close $in_26 or croak 'Close failed: $OS_ERROR';
    my $result_26 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_26> };
    close $out_26 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_26, 0;
    $result_26
};
if ("$newver" eq q{}) {
if ("$force" eq q{}) {
        mv_all("$drivedb", ".new", ".error");
        error("$drivedb.error: no VERSION information found ('--force' to ignore)");
    }
    $newver = "?/?";
}
else {
    if ("${newver##*/}" eq "?") {
if ("$trunk" eq q{}) {
            mv_all("$drivedb", ".new", ".error");
            error("$drivedb.error: VERSION information is incomplete ('--trunk' to ignore)");
        }
    }
}
if ("$smartctl" ne "-") {
if (!(!(do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $CHILD_ERROR = 0;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };))) {
        mv_all("$drivedb", ".new", ".error");
        error("$drivedb.error: rejected by $smartctl, probably no longer compatible");
    }
    vecho("$smartctl: syntax OK");
}
if ( -e "$drivedb.lastcheck" ) {
    if ( -d "$drivedb.lastcheck" ) {
        carp "rm: carping: ", "$drivedb.lastcheck",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "$drivedb.lastcheck" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "$drivedb.lastcheck",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
if ((!-f "$drivedb")) {
    mv_all("$drivedb", ".new", "");
    iecho("$drivedb $newver newly installed" . (defined (defined ${no_verify} && ${no_verify} ne q{} ? ${no_verify} : ' (NOT VERIFIED)') && (defined ${no_verify} && ${no_verify} ne q{} ? ${no_verify} : ' (NOT VERIFIED)') ne q{} ? (defined ${no_verify} && ${no_verify} ne q{} ? ${no_verify} : ' (NOT VERIFIED)') : ' (NOT VERIFIED)'));
exit 0;
}
if ("$equal" ne q{}) {
if (((-f "$drivedb.new.raw.asc") && !(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
!($main_exit_code = system('cmp', "$drivedb.new.raw.asc", "$drivedb.raw.asc") >> 8;)
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }))) {
        if ( -e "$drivedb.new.raw.asc" ) {
            my $dest = "$drivedb.raw.asc";
            if ( -e $dest && -d $dest ) {
                my $source_name = "$drivedb.new.raw.asc";
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
            if ( File::Copy::move( "$drivedb.new.raw.asc", $dest ) ) {
            } else {
                croak
  "mv: cannot move "$drivedb.new.raw.asc" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "$drivedb.new.raw.asc": No such file or directory\n";
        }
        iecho("$drivedb.raw.asc $newver updated");
    }
if ( -e "$drivedb.new" ) {
        if ( -d "$drivedb.new" ) {
            carp "rm: carping: ", "$drivedb.new",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$drivedb.new" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$drivedb.new",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "$drivedb.new.raw" ) {
        if ( -d "$drivedb.new.raw" ) {
            carp "rm: carping: ", "$drivedb.new.raw",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$drivedb.new.raw" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$drivedb.new.raw",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "$drivedb.new.raw.asc" ) {
        if ( -d "$drivedb.new.raw.asc" ) {
            carp "rm: carping: ", "$drivedb.new.raw.asc",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$drivedb.new.raw.asc" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$drivedb.new.raw.asc",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if ( -e "$drivedb.lastcheck" ) {
        my $current_time = time;
        utime $current_time, $current_time, "$drivedb.lastcheck";
    }
    else {
        if ( open my $fh, '>', "$drivedb.lastcheck" ) {
            close $fh or croak "Close failed: $ERRNO";
        }
        else {
            croak "touch: cannot create ", "$drivedb.lastcheck",
              ": $ERRNO\n";
        }
    }
    iecho("$drivedb $newver is already up to date" . (defined (defined ${no_verify} && ${no_verify} ne q{} ? ${no_verify} : ' (NOT VERIFIED)') && (defined ${no_verify} && ${no_verify} ne q{} ? ${no_verify} : ' (NOT VERIFIED)') ne q{} ? (defined ${no_verify} && ${no_verify} ne q{} ? ${no_verify} : ' (NOT VERIFIED)') : ' (NOT VERIFIED)'));
exit 0;
}
$oldver = do {
    my ($in_29, $out_29);
    my $pid_29 = open3($in_29, $out_29, '>&STDERR', 'get_db_version', "$drivedb");
    close $in_29 or croak 'Close failed: $OS_ERROR';
    my $result_29 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_29> };
    close $out_29 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_29, 0;
    $result_29
};
$main_exit_code = system('test', '-n', "$oldver") >> 8;
if ($CHILD_ERROR != 0) {
        $oldver = "?/?";
}
if ((("${newver##*/}" eq "?" || "${oldver##*/}" eq "?") || "${newver%/*}" ne "${oldver%/*}")) {
    my $updmsg;
    my @updmsg;
    my %updmsg;
    $updmsg = "replaced with";
}
else {
    if ((${newver##*/} < ${oldver##*/})) {
if ("$force" eq q{}) {
if ( -e "$drivedb.new" ) {
                if ( -d "$drivedb.new" ) {
                    carp "rm: carping: ", "$drivedb.new",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$drivedb.new" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$drivedb.new",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
if ( -e "$drivedb.new.raw" ) {
                if ( -d "$drivedb.new.raw" ) {
                    carp "rm: carping: ", "$drivedb.new.raw",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$drivedb.new.raw" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$drivedb.new.raw",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
if ( -e "$drivedb.new.raw.asc" ) {
                if ( -d "$drivedb.new.raw.asc" ) {
                    carp "rm: carping: ", "$drivedb.new.raw.asc",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$drivedb.new.raw.asc" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$drivedb.new.raw.asc",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
            iecho("$drivedb $oldver not downgraded to $newver ('--force' to override)");
exit 0;
        }
        $updmsg = "downgraded to";
}
    else {
        $updmsg = "updated to";
    }
}
mv_all("$drivedb", "", ".old");
mv_all("$drivedb", ".new", "");
iecho("$drivedb $oldver $updmsg $newver" . (defined (defined ${no_verify} && ${no_verify} ne q{} ? ${no_verify} : ' (NOT VERIFIED)') && (defined ${no_verify} && ${no_verify} ne q{} ? ${no_verify} : ' (NOT VERIFIED)') ne q{} ? (defined ${no_verify} && ${no_verify} ne q{} ? ${no_verify} : ' (NOT VERIFIED)') : ' (NOT VERIFIED)'));

exit $main_exit_code;
