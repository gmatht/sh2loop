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

my $DOMAINS;
my @DOMAINS;
my %DOMAINS;
my $interface;
my @interface;
my %interface;
my $DNS6;
my @DNS6;
my %DNS6;
my $DNS;
my @DNS;
my %DNS;
my $resolvectl_failed;
my @resolvectl_failed;
my %resolvectl_failed;
my $NEW_DEFAULT_ROUTE;
my @NEW_DEFAULT_ROUTE;
my %NEW_DEFAULT_ROUTE;
my $ifindex;
my @ifindex;
my %ifindex;
my $mystatedir;
my @mystatedir;
my %mystatedir;
my $NEW_DNS;
my @NEW_DNS;
my %NEW_DNS;
my $DEFAULT_ROUTE;
my @DEFAULT_ROUTE;
my %DEFAULT_ROUTE;
my $DOMAINS6;
my @DOMAINS6;
my %DOMAINS6;
my $ADDRFAM;
my @ADDRFAM;
my %ADDRFAM;
my $NEW_DOMAINS;
my @NEW_DOMAINS;
my %NEW_DOMAINS;

if ("$ADDRFAM" =~ /^inet$/msx or "$ADDRFAM" =~ /^inet6$/msx) {
        $main_exit_code = system('bash', ':') >> 8;
} elsif (1) {
    exit 0;
}
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('systemctl', 'is-enabled', "sys" . "tem" . "d-resolved") >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
    $interface = $IFACE;
if ((!"$interface")) {
return;
    }
if ("$interface" eq "lo") {
return;
    }
    $ifindex = do { my $cat_chunk = q{}; if ( open my $fh, '<', "/sys/class/net/$interface/ifindex" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "/sys/class/net/$interface/ifindex" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
if ((!"$ifindex")) {
return;
    }
    $mystatedir = '/run/network';
    use File::Path qw(make_path);
    my $err;
    if ( !-d $mystatedir ) {
        make_path( $mystatedir, { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . $mystatedir . ": $err->[0]\n";
        }
    }
    my $statedir;
    my @statedir;
    my %statedir;
    $statedir = "/run/" . "sys" . "tem" . "d/resolve/netif";
    use File::Path qw(make_path);
    if ( !-d $statedir ) {
        make_path( $statedir, { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . $statedir . ": $err->[0]\n";
        }
    }
do {
    my ($owner, $group) = split /:/, "sys" . "tem" . "d-resolve:" . "sys" . "tem" . "d-resolve", 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ($statedir) or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
    my $oldstate;
    my @oldstate;
    my %oldstate;
    $oldstate = (do { my $_chomp_temp = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'mktemp');
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
}; chomp $_chomp_temp; $_chomp_temp; });
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$oldstate"
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('md5sum', "$mystatedir/isc-dhcp-v4-$interface", "$mystatedir/isc-dhcp-v6-$interface", "$mystatedir/ifupdown-inet-$interface", "$mystatedir/ifupdown-inet6-$interface") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
    $NEW_DEFAULT_ROUTE = $IF_DNS_DEFAULT_ROUTE;
    $NEW_DNS = ($IF_DNS_NAMESERVERS . q{ } . $IF_DNS_NAMESERVER);
    $NEW_DOMAINS = ($IF_DNS_DOMAIN . q{ } . $IF_DNS_SEARCH);
    $DNS = 'DNS';
    $DOMAINS = 'DOMAINS';
if ("$ADDRFAM" eq "inet6") {
        $DNS = 'DNS6';
        $DOMAINS = 'DOMAINS6';
    }
if ("$NEW_DNS" ne q{}) {
open my $fh_cat, '>', "\"$mystatedir/ifupdown-\" . ${ADDRFAM} . \"-$interface\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "$DNS=\"$NEW_DNS\"
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
if ("$NEW_DOMAINS" ne q{}) {
open my $fh_cat, '>', "\"$mystatedir/ifupdown-\" . ${ADDRFAM} . \"-$interface\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "$DOMAINS=\"$NEW_DOMAINS\"
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
        }
    }
if ("$NEW_DEFAULT_ROUTE" =~ /^1$/msx or "$NEW_DEFAULT_ROUTE" =~ /^yes$/msx or "$NEW_DEFAULT_ROUTE" =~ /^true$/msx or "$NEW_DEFAULT_ROUTE" =~ /^on$/msx) {
                $NEW_DEFAULT_ROUTE = 'yes';
    } elsif ("$NEW_DEFAULT_ROUTE" =~ /^0$/msx or "$NEW_DEFAULT_ROUTE" =~ /^no$/msx or "$NEW_DEFAULT_ROUTE" =~ /^false$/msx or "$NEW_DEFAULT_ROUTE" =~ /^off$/msx) {
                $NEW_DEFAULT_ROUTE = 'no';
    } elsif (1) {
                $NEW_DEFAULT_ROUTE = q{};
    }
if ("$NEW_DEFAULT_ROUTE" ne q{}) {
open my $fh_cat, '>', "\"$mystatedir/ifupdown-\" . ${ADDRFAM} . \"-$interface\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "DEFAULT_ROUTE=\"$NEW_DEFAULT_ROUTE\"
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    }
    my $newstate;
    my @newstate;
    my %newstate;
    $newstate = (do { my $_chomp_temp = do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'mktemp');
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
}; chomp $_chomp_temp; $_chomp_temp; });
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$newstate"
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('md5sum', "$mystatedir/isc-dhcp-v4-$interface", "$mystatedir/isc-dhcp-v6-$interface", "$mystatedir/ifupdown-inet-$interface", "$mystatedir/ifupdown-inet6-$interface") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
if (!(!(do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        $main_exit_code = system('cmp', '--silent', "$oldstate", "$newstate") >> 8;
    };))) {
delete $ENV{DNS};
delete $ENV{DNS6};
delete $ENV{DOMAINS};
delete $ENV{DOMAINS6};
delete $ENV{DEFAULT_ROUTE};
if ((-e "$mystatedir/isc-dhcp-v4-$interface")) {
            $main_exit_code = system('.', "$mystatedir/isc-dhcp-v4-$interface") >> 8;
        }
if ((-e "$mystatedir/ifupdown-inet-$interface")) {
            $main_exit_code = system('.', "$mystatedir/ifupdown-inet-$interface") >> 8;
        }
if ((-e "$mystatedir/isc-dhcp-v6-$interface")) {
            $main_exit_code = system('.', "$mystatedir/isc-dhcp-v6-$interface") >> 8;
        }
if ((-e "$mystatedir/ifupdown-inet6-$interface")) {
            $main_exit_code = system('.', "$mystatedir/ifupdown-inet6-$interface") >> 8;
        }
        $resolvectl_failed = q{};
if ((("$DNS") || ("$DNS6"))) {
open my $fh_cat, '>', "\"$statedir/$ifindex\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "# This is private data. Do not parse.
LLMNR=yes
MDNS=no
SERVERS=$(echo $DNS6 $DNS)
DOMAINS=$(echo $DOMAINS6 $DOMAINS)
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
if ("$DEFAULT_ROUTE" ne q{}) {
open my $fh_cat, '>', "\"$statedir/$ifindex\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "DEFAULT_ROUTE=$DEFAULT_ROUTE
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
            }
do {
    my ($owner, $group) = split /:/, "sys" . "tem" . "d-resolve:" . "sys" . "tem" . "d-resolve", 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ("$statedir/$ifindex") or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
if (!(            $main_exit_code = system('systemctl', '--quiet', 'is-active', "sys" . "tem" . "d-resolved") >> 8)) {
                                $main_exit_code = system('resolvectl', 'llmnr', "$ifindex", 'yes') >> 8;
                if ($CHILD_ERROR != 0) {
                                        $resolvectl_failed = $?;
                }
                                $main_exit_code = system('resolvectl', 'mdns', "$ifindex", 'no') >> 8;
                if ($CHILD_ERROR != 0) {
                                        $resolvectl_failed = $?;
                }
if ((("$DOMAINS6") || ("$DOMAINS"))) {
                                        $main_exit_code = system('resolvectl', 'domain', "$ifindex", $DOMAINS6, $DOMAINS) >> 8;
                    if ($CHILD_ERROR != 0) {
                                                $resolvectl_failed = $?;
                    }
}
                else {
                                        $main_exit_code = system('resolvectl', 'domain', "$ifindex", "") >> 8;
                    if ($CHILD_ERROR != 0) {
                                                $resolvectl_failed = $?;
                    }
                }
                                $main_exit_code = system('resolvectl', 'dns', "$ifindex", $DNS6, $DNS) >> 8;
                if ($CHILD_ERROR != 0) {
                                        $resolvectl_failed = $?;
                }
if (("$DEFAULT_ROUTE")) {
                                        $main_exit_code = system('resolvectl', 'default-route', "$ifindex", $DEFAULT_ROUTE) >> 8;
                    if ($CHILD_ERROR != 0) {
                                                $resolvectl_failed = $?;
                    }
                }
            }
}
        else {
if ( -e "$statedir/$ifindex" ) {
                if ( -d "$statedir/$ifindex" ) {
                    carp "rm: carping: ", "$statedir/$ifindex",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$statedir/$ifindex" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$statedir/$ifindex",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
if (!(            $main_exit_code = system('systemctl', '--quiet', 'is-active', "sys" . "tem" . "d-resolved") >> 8)) {
                                $main_exit_code = system('resolvectl', 'revert', "$ifindex") >> 8;
                if ($CHILD_ERROR != 0) {
                                        $resolvectl_failed = $?;
                }
            }
        }
if (("$resolvectl_failed")) {
            $main_exit_code = system('systemctl', 'try-restart', "sys" . "tem" . "d-resolved") >> 8;
        }
    }
if ( -e "$oldstate" ) {
        if ( -d "$oldstate" ) {
            carp "rm: carping: ", "$oldstate",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$oldstate" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$oldstate",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "$newstate" ) {
        if ( -d "$newstate" ) {
            carp "rm: carping: ", "$newstate",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$newstate" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$newstate",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}

exit $main_exit_code;
