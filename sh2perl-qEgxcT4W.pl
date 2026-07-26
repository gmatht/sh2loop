#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $PERL;
my @PERL;
my %PERL;
$PERL = '/usr/bin/perl';
my $OPTIONS_KEEPDASHDASH;
my @OPTIONS_KEEPDASHDASH;
my %OPTIONS_KEEPDASHDASH;
$OPTIONS_KEEPDASHDASH = q{};
my $OPTIONS_STUCKLONG;
my @OPTIONS_STUCKLONG;
my %OPTIONS_STUCKLONG;
$OPTIONS_STUCKLONG = q{};
my $OPTIONS_SPEC;
my @OPTIONS_SPEC;
my %OPTIONS_SPEC;
$OPTIONS_SPEC = "\
git instaweb [options] (--start | --stop | --restart)
--
l,local        only bind on 127.0.0.1
p,port=        the port to bind to
d,httpd=       the command to launch
b,browser=     the browser to launch
m,module-path= the module path (only needed for apache2)
 Action
stop           stop the web server
start          start the web server
restart        restart the web server
";
my $SUBDIRECTORY_OK;
my @SUBDIRECTORY_OK;
my %SUBDIRECTORY_OK;
$SUBDIRECTORY_OK = 'Yes';
$main_exit_code = system('.', 'git-sh-setup') >> 8;
my $fqgitdir;
my @fqgitdir;
my %fqgitdir;
$fqgitdir = "$ENV{GIT_DIR}";
my $local;
my @local;
my %local;
$local = (do { my $_chomp_temp = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'git', 'config', '--bool', '--get', 'instaweb.local');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; chomp $_chomp_temp; $_chomp_temp; });
my $httpd;
my @httpd;
my %httpd;
$httpd = (do { my $_chomp_temp = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'git', 'config', '--get', 'instaweb.httpd');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
}; chomp $_chomp_temp; $_chomp_temp; });
my $root;
my @root;
my %root;
$root = (do { my $_chomp_temp = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'git', 'config', '--get', 'instaweb.gitwebdir');
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
}; chomp $_chomp_temp; $_chomp_temp; });
my $port;
my @port;
my %port;
$port = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'git', 'config', '--get', 'instaweb.port');
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
};
my $module_path;
my @module_path;
my %module_path;
$module_path = (do { my $_chomp_temp = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'git', 'config', '--get', 'instaweb.modulepath');
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
}; chomp $_chomp_temp; $_chomp_temp; });
my $action;
my @action;
my %action;
$action = "browse";
my $conf;
my @conf;
my %conf;
$conf = "$ENV{GIT_DIR}/gitweb/httpd.conf";
if (do {
$main_exit_code = system('test', '-z', "$httpd") >> 8;
    $CHILD_ERROR == 0
}) {
        $httpd = 'lighttpd -f';
}
if (do {
$main_exit_code = system('test', '-z', "$root") >> 8;
    $CHILD_ERROR == 0
}) {
        $root = '/usr/share/gitweb';
}
if (do {
$main_exit_code = system('test', '-z', "$port") >> 8;
    $CHILD_ERROR == 0
}) {
        $port = '1234';
}

sub resolve_full_httpd {
if ("$httpd" =~ /^.*apache2.*$/msx or "$httpd" =~ /^.*lighttpd.*$/msx or "$httpd" =~ /^.*httpd.*$/msx) {
        if (!(!(# Original bash: echo "$httpd" | grep -- '-f *$' >/dev/null 2>&1
{
            my $output_5 = q{};
            my $output_printed_5;
            my $pipeline_success_5 = 1;
            $output_5 .= $httpd . "\n";
if ( !($output_5 =~ m{\n\z}msx) ) { $output_5 .= "\n"; }
$CHILD_ERROR = 0;

                        carp "grep: no pattern specified";
            exit 1;
            $output_5 = $grep_result_5_1;
            if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
            }))) {
            $httpd = "$httpd -f";
        }
    } elsif ("$httpd" =~ /^.*plackup.*$/msx) {
                my $full_httpd;
        my @full_httpd;
        my %full_httpd;
        $full_httpd = "$fqgitdir/gitweb/gitweb.psgi";
                my $httpd_only;
        my @httpd_only;
        my %httpd_only;
        $httpd_only = (${httpd} =~ s/ .*$//sr =~ s/ .*$//sr);
        return;    } elsif ("$httpd" =~ /^.*webrick.*$/msx) {
                $full_httpd = "$fqgitdir/gitweb/webrick.rb";
                $httpd_only = (${httpd} =~ s/ .*$//sr =~ s/ .*$//sr);
        return;    } elsif ("$httpd" =~ /^.*python.*$/msx) {
                $full_httpd = "$fqgitdir/gitweb/gitweb.py";
                $httpd_only = (${httpd} =~ s/ .*$//sr =~ s/ .*$//sr);
        return;    }
    $httpd_only = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_6 = q{};
        my $output_printed_6;
        my $pipeline_success_6 = 1;
        $output_6 .= $httpd . "\n";
        if ( !($output_6 =~ m{\n\z}msx) ) { $output_6 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_6 = 0; }
        my @lines_7 = split /\n/msx, $output_6;
        my @result_7;
        foreach my $line (@lines_7) {
        chomp $line;
        my @fields = split /\ /msx, $line;
        if (@fields > 0) {
            push @result_7, $fields[0];
        }
        }
        $output_6 = join "\n", @result_7;
        if ($output_6 ne q{} && !($output_6  =~ m{\n\z}msx)) { $output_6 .= "\n"; }

        if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
        $output_6 =~ s/\n+\z//msx;
        $output_6;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
if (!(if ("$httpd_only" =~ /^/.*$/msx) {
                $main_exit_code = system('bash', ':') >> 8;
    } elsif (1) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = $httpd_only;
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    })) {
        $full_httpd = $httpd;
}
    else {
        my $i;
        for my $i ('/usr/local/sbin', '/usr/sbin', "$root", "$fqgitdir/gitweb") {
if ((-x 'StringInterpolation(StringInterpolation { parts: [Variable("i"), Literal("/"), Variable("httpd_only")] }, None)')) {
                $full_httpd = $i;
                $main_exit_code = system('/', $httpd) >> 8;
return;
            }
        }
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
        };
        $CHILD_ERROR = 0;
exit 1;
    }
    return;
}

sub start_httpd {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("fqgitdir"), Literal("/pid")] }, None)')) {
        print "Instance already running. Restarting...\n";
        $main_exit_code = system('bash', 'stop_httpd') >> 8;
    }
    resolve_full_httpd();
    use File::Path qw(make_path);
    my $err;
    if ( !-d "$fqgitdir/gitweb/$ENV{httpd_only}" ) {
        make_path( "$fqgitdir/gitweb/$ENV{httpd_only}", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . "$fqgitdir/gitweb/$ENV{httpd_only}" . ": $err->[0]\n";
        }
    }
    $conf = "$fqgitdir/gitweb/$ENV{httpd_only}.conf";
        $main_exit_code = system('test', '-f', "$conf") >> 8;
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('bash', 'configure_httpd') >> 8;
    }
        $main_exit_code = system('test', '-f', "$fqgitdir/gitweb/gitweb_config.perl") >> 8;
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('bash', 'gitweb_conf') >> 8;
    }
if ("$httpd" =~ /^.*mongoose.*$/msx or "$httpd" =~ /^.*plackup.*$/msx or "$httpd" =~ /^.*python.*$/msx) {
                if (my $pid = fork()) {
            # Parent process continues
        } elsif (defined $pid) {
            # Child process executes the background command
            $CHILD_ERROR = 0;
            exit(0);
        } else {
            die "Cannot fork: $ERRNO\n";
        }
                my $pid;
        my @pid;
        my %pid;
        $pid = $!;
        if ((!Variable("?", false, None) eq 0)) {
            do {
    my $__echo_line = "Could not execute http daemon $httpd.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
exit 1;
        }
        open my $fh_cat, '>', "\"$fqgitdir/pid\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "$pid
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    } elsif (1) {
                $CHILD_ERROR = 0;
        if ((!Variable("?", false, None) eq 0)) {
            do {
    my $__echo_line = "Could not execute http daemon $httpd.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
exit 1;
        }
    }
    return;
}

sub stop_httpd {
    if (do {
$main_exit_code = system('test', '-f', "$fqgitdir/pid") >> 8;
        $CHILD_ERROR == 0
    }) {
        my $signal = 'TERM';
my @pids = (do { my $cat_chunk = q{}; if ( open my $fh, '<', "$fqgitdir/pid" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$fqgitdir/pid" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
foreach my $pid (@pids) {
if ($pid =~ /^\\d+$/msx) {
my $result = kill $signal, $pid;
if ($result) {
print "Sent signal $signal to process $pid\n";
} else {
print {*STDERR} "kill: ($pid) - No such process\n";
}
} else {
print {*STDERR} "kill: invalid process id: $pid\n";
}
}
    }
if ( -e "$fqgitdir/pid" ) {
        if ( -d "$fqgitdir/pid" ) {
            carp "rm: carping: ", "$fqgitdir/pid",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$fqgitdir/pid" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$fqgitdir/pid",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}

sub httpd_is_ready {
    $CHILD_ERROR = 0;
    return;
}
my $# = 0;
while ( (!Variable("#", false, None) eq 0) ) {
if ("$_[0]" =~ /^--stop$/msx or "$_[0]" =~ /^stop$/msx) {
                $action = "stop";
    } elsif ("$_[0]" =~ /^--start$/msx or "$_[0]" =~ /^start$/msx) {
                $action = "start";
    } elsif ("$_[0]" =~ /^--restart$/msx or "$_[0]" =~ /^restart$/msx) {
                $action = "restart";
    } elsif ("$_[0]" =~ /^-l$/msx or "$_[0]" =~ /^--local$/msx) {
                $local = 'true';
    } elsif ("$_[0]" =~ /^-d$/msx or "$_[0]" =~ /^--httpd$/msx) {
        # Builtin command 'shift' not implemented
                $httpd = "$_[0]";
    } elsif ("$_[0]" =~ /^-b$/msx or "$_[0]" =~ /^--browser$/msx) {
        # Builtin command 'shift' not implemented
                my $browser;
        my @browser;
        my %browser;
        $browser = "$_[0]";
    } elsif ("$_[0]" =~ /^-p$/msx or "$_[0]" =~ /^--port$/msx) {
        # Builtin command 'shift' not implemented
                $port = "$_[0]";
    } elsif ("$_[0]" =~ /^-m$/msx or "$_[0]" =~ /^--module-path$/msx) {
        # Builtin command 'shift' not implemented
                $module_path = "$_[0]";
    } elsif ("$_[0]" =~ /^--$/msx) {
    } elsif (1) {
                $main_exit_code = system('bash', 'usage') >> 8;
    }
# Builtin command 'shift' not implemented
}
use File::Path qw(make_path);
my $err;
if ( !-d "$ENV{GIT_DIR}/gitweb/tmp" ) {
    make_path( "$ENV{GIT_DIR}/gitweb/tmp", { error => \$err } );
    if ( @{$err} ) {
        croak "mkdir: cannot create directory " . "$ENV{GIT_DIR}/gitweb/tmp" . ": $err->[0]\n";
    }
}
my $GIT_EXEC_PATH;
my @GIT_EXEC_PATH;
my %GIT_EXEC_PATH;
$GIT_EXEC_PATH = (do { my $_chomp_temp = do {
    my ($in_12, $out_12);
    my $pid_12 = open3($in_12, $out_12, '>&STDERR', 'git', '--exec-path');
    close $in_12 or croak 'Close failed: $OS_ERROR';
    my $result_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
    close $out_12 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_12, 0;
    $result_12
}; chomp $_chomp_temp; $_chomp_temp; });
my $GIT_DIR;
my @GIT_DIR;
my %GIT_DIR;
$GIT_DIR = "$fqgitdir";
my $GITWEB_CONFIG;
my @GITWEB_CONFIG;
my %GITWEB_CONFIG;
$GITWEB_CONFIG = "$fqgitdir/gitweb/gitweb_config.perl";
$ENV{GIT_EXEC_PATH} = $GIT_EXEC_PATH;
$ENV{GIT_DIR} = $GIT_DIR;
$ENV{GITWEB_CONFIG} = $GITWEB_CONFIG;

sub webrick_conf {
    my $wrapper;
    my @wrapper;
    my %wrapper;
    $wrapper = "$fqgitdir/gitweb/$httpd/wrapper.sh";
open my $fh_cat, '>', "\"$wrapper\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "#!/bin/sh
# we use this shell script wrapper around the real gitweb.cgi since
# there appears to be no other way to pass arbitrary environment variables
# into the CGI process
GIT_EXEC_PATH=$GIT_EXEC_PATH GIT_DIR=$GIT_DIR GITWEB_CONFIG=$GITWEB_CONFIG
export GIT_EXEC_PATH GIT_DIR GITWEB_CONFIG
exec $root/gitweb.cgi
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
chmod(oct('+x'), ("$wrapper")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
open my $fh_cat, '>', "\"$fqgitdir/gitweb/$httpd.rb\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "#!/usr/bin/env ruby
require 'webrick'
require 'logger'
options = {
  :Port => $port,
  :DocumentRoot => \"$root\",
  :Logger => Logger.new('$fqgitdir/gitweb/error.log'),
  :AccessLog => [
    [ Logger.new('$fqgitdir/gitweb/access.log'),
      WEBrick::AccessLog::COMBINED_LOG_FORMAT ]
  ],
  :DirectoryIndex => [\"gitweb.cgi\"],
  :CGIInterpreter => \"$wrapper\",
  :StartCallback => lambda do
    File.open(\"$fqgitdir/pid\", \"w\") { |f| f.puts Process.pid }
  end,
  :ServerType => WEBrick::Daemon,
}
options[:BindAddress] = '127.0.0.1' if \"$local\" == \"true\"
server = WEBrick::HTTPServer.new(options)
['INT', 'TERM'].each do |signal|
  trap(signal) {server.shutdown}
end
server.start
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
chmod(oct('+x'), ("$fqgitdir/gitweb/$httpd.rb")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
if ( -e "$conf" ) {
        if ( -d "$conf" ) {
            carp "rm: carping: ", "$conf",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$conf" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$conf",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}

sub lighttpd_conf {
open my $fh_cat, '>', "\"$conf\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "server.document-root = \"$root\"
server.port = $port
server.modules = ( \"mod_setenv\", \"mod_cgi\" )
server.indexfiles = ( \"gitweb.cgi\" )
server.pid-file = \"$fqgitdir/pid\"
server.errorlog = \"$fqgitdir/gitweb/$httpd_only/error.log\"

# to enable, add \"mod_access\", \"mod_accesslog\" to server.modules
# variable above and uncomment this
#accesslog.filename = \"$fqgitdir/gitweb/$httpd_only/access.log\"

setenv.add-environment = ( \"PATH\" => env.PATH, \"GITWEB_CONFIG\" => env.GITWEB_CONFIG )

cgi.assign = ( \".cgi\" => \"\" )

# mimetype mapping
mimetype.assign             = (
  \".pdf\"          =>      \"application/pdf\",
  \".sig\"          =>      \"application/pgp-signature\",
  \".spl\"          =>      \"application/futuresplash\",
  \".class\"        =>      \"application/octet-stream\",
  \".ps\"           =>      \"application/postscript\",
  \".torrent\"      =>      \"application/x-bittorrent\",
  \".dvi\"          =>      \"application/x-dvi\",
  \".gz\"           =>      \"application/x-gzip\",
  \".pac\"          =>      \"application/x-ns-proxy-autoconfig\",
  \".swf\"          =>      \"application/x-shockwave-flash\",
  \".tar.gz\"       =>      \"application/x-tgz\",
  \".tgz\"          =>      \"application/x-tgz\",
  \".tar\"          =>      \"application/x-tar\",
  \".zip\"          =>      \"application/zip\",
  \".mp3\"          =>      \"audio/mpeg\",
  \".m3u\"          =>      \"audio/x-mpegurl\",
  \".wma\"          =>      \"audio/x-ms-wma\",
  \".wax\"          =>      \"audio/x-ms-wax\",
  \".ogg\"          =>      \"application/ogg\",
  \".wav\"          =>      \"audio/x-wav\",
  \".gif\"          =>      \"image/gif\",
  \".jpg\"          =>      \"image/jpeg\",
  \".jpeg\"         =>      \"image/jpeg\",
  \".png\"          =>      \"image/png\",
  \".xbm\"          =>      \"image/x-xbitmap\",
  \".xpm\"          =>      \"image/x-xpixmap\",
  \".xwd\"          =>      \"image/x-xwindowdump\",
  \".css\"          =>      \"text/css\",
  \".html\"         =>      \"text/html\",
  \".htm\"          =>      \"text/html\",
  \".js\"           =>      \"text/javascript\",
  \".asc\"          =>      \"text/plain\",
  \".c\"            =>      \"text/plain\",
  \".cpp\"          =>      \"text/plain\",
  \".log\"          =>      \"text/plain\",
  \".conf\"         =>      \"text/plain\",
  \".text\"         =>      \"text/plain\",
  \".txt\"          =>      \"text/plain\",
  \".dtd\"          =>      \"text/xml\",
  \".xml\"          =>      \"text/xml\",
  \".mpeg\"         =>      \"video/mpeg\",
  \".mpg\"          =>      \"video/mpeg\",
  \".mov\"          =>      \"video/quicktime\",
  \".qt\"           =>      \"video/quicktime\",
  \".avi\"          =>      \"video/x-msvideo\",
  \".asf\"          =>      \"video/x-ms-asf\",
  \".asx\"          =>      \"video/x-ms-asf\",
  \".wmv\"          =>      \"video/x-ms-wmv\",
  \".bz2\"          =>      \"application/x-bzip\",
  \".tbz\"          =>      \"application/x-bzip-compressed-tar\",
  \".tar.bz2\"      =>      \"application/x-bzip-compressed-tar\",
  \"\"              =>      \"text/plain\"
 )
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    if (do {
$main_exit_code = system('test', q{x}, "$local", q{=}, 'xtrue') >> 8;
        $CHILD_ERROR == 0
    }) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$conf"
      or die "Cannot open file: $OS_ERROR\n";
            print "server.bind = \"127.0.0.1\"\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    return;
}

sub apache2_conf {
    my $candidate;
    for my $candidate ('/etc/httpd', '/usr/lib/apache2', '/usr/lib/httpd') {
if ((-d 'StringInterpolation(StringInterpolation { parts: [Variable("candidate"), Literal("/modules")] }, None)')) {
            $module_path = "$candidate/modules";
last;
        }
    }
    my $bind;
    my @bind;
    my %bind;
    $bind = q{};
    if (do {
$main_exit_code = system('test', q{x}, "$local", q{=}, 'xtrue') >> 8;
        $CHILD_ERROR == 0
    }) {
                $bind = '127.0.0.1:';
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$fqgitdir/mime.types"
      or die "Cannot open file: $OS_ERROR\n";
        print 'text/css css' . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
open my $fh_cat, '>', "\"$conf\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "ServerName \"git-instaweb\"
ServerRoot \"$root\"
DocumentRoot \"$root\"
ErrorLog \"$fqgitdir/gitweb/$httpd_only/error.log\"
CustomLog \"$fqgitdir/gitweb/$httpd_only/access.log\" combined
PidFile \"$fqgitdir/pid\"
Listen $bind$port
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    my $mod;
    for my $mod ('mpm_event', 'mpm_prefork', 'mpm_worker') {
if ((-e 'Variable("module_path", false, None) /mod_ Variable("mod", true, None) .so')) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$conf"
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "LoadModule " . ${mod} . "_module " . q{ } . "$module_path/mod_" . ${mod} . ".so";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
last;
        }
    }
    for my $mod ('mime', 'dir', 'env', 'log_config', 'authz_core', 'unixd') {
if ((-e 'Variable("module_path", false, None) /mod_ Variable("mod", true, None) .so')) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$conf"
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "LoadModule " . ${mod} . "_module " . q{ } . "$module_path/mod_" . ${mod} . ".so";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
    }
open my $fh_cat, '>', "\"$conf\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "TypesConfig \"$fqgitdir/mime.types\"
DirectoryIndex gitweb.cgi
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("module_path"), Literal("/mod_perl.so")] }, None)')) {
open my $fh_cat, '>', "\"$conf\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "LoadModule perl_module $module_path/mod_perl.so
PerlPassEnv GIT_DIR
PerlPassEnv GIT_EXEC_PATH
PerlPassEnv GITWEB_CONFIG
<Location /gitweb.cgi>
\tSetHandler perl-script
\tPerlResponseHandler ModPerl::Registry
\tPerlOptions +ParseHeaders
\tOptions +ExecCGI
</Location>
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
}
    else {
        resolve_full_httpd();
        my $list_mods;
        my @list_mods;
        my %list_mods;
        $list_mods = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_15 = q{};
            my $output_printed_15;
            my $pipeline_success_15 = 1;
            $output_15 .= $full_httpd . "\n";
            if ( !($output_15 =~ m{\n\z}msx) ) { $output_15 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_15 = 0; }
            my @sed_lines_15 = split /\n/msx, $output_15;
            my @sed_result_15;
            foreach my $line (@sed_lines_15) {
            chomp $line;
            $line =~ s/-f$/-l/gmsx;
            push @sed_result_15, $line;
            }
            $output_15 = join "\n", @sed_result_15;

            if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
            $output_15 =~ s/\n+\z//msx;
            $output_15;
}; $_pipeline_result; };
        {
            my $output_16 = q{};
            my $output_printed_16;
            my $pipeline_success_16 = 1;
                        my ($in_17, $out_17);
            my $pid_17 = open3($in_17, $out_17, '>&STDERR', 'unknown_command', );
            close $in_17 or croak 'Close failed: $OS_ERROR';
            $output_16 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> };
            close $out_17 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_17, 0;

                        my $grep_result_16_1;
            my @grep_lines_16_1 = split /\n/msx, $output_16;
            my @grep_filtered_16_1 = grep { /mod_cgi[.]c/msx } @grep_lines_16_1;
            $grep_result_16_1 = join "\n", @grep_filtered_16_1;
            if (!($grep_result_16_1 =~ m{\n\z}msx || $grep_result_16_1 eq q{})) {
            $grep_result_16_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_16_1 > 0 ? 0 : 1;
            $output_16 = $grep_result_16_1;
            if ( !$pipeline_success_16 ) { $main_exit_code = 1; }
            }
        if ($CHILD_ERROR != 0) {
            if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("module_path"), Literal("/mod_cgi.so")] }, None)')) {
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', "$conf"
      or die "Cannot open file: $OS_ERROR\n";
                    do {
    my $__echo_line = "LoadModule cgi_module $module_path/mod_cgi.so";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
}
            else {
                {
                    my $output_18 = q{};
                    my $output_printed_18;
                    my $pipeline_success_18 = 1;
                                        my ($in_19, $out_19);
                    my $pid_19 = open3($in_19, $out_19, '>&STDERR', 'unknown_command', );
                    close $in_19 or croak 'Close failed: $OS_ERROR';
                    $output_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19> };
                    close $out_19 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_19, 0;

                                        my $grep_result_18_1;
                    my @grep_lines_18_1 = split /\n/msx, $output_18;
                    my @grep_filtered_18_1 = grep { /mod_cgid[.]c/msx } @grep_lines_18_1;
                    $grep_result_18_1 = join "\n", @grep_filtered_18_1;
                    if (!($grep_result_18_1 =~ m{\n\z}msx || $grep_result_18_1 eq q{})) {
                    $grep_result_18_1 .= "\n";
                    }
                    $CHILD_ERROR = scalar @grep_filtered_18_1 > 0 ? 0 : 1;
                    $output_18 = $grep_result_18_1;
                    if ( !$pipeline_success_18 ) { $main_exit_code = 1; }
                    }
                if ($CHILD_ERROR != 0) {
                    if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("module_path"), Literal("/mod_cgid.so")] }, None)')) {
                        do {
                            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                            open STDOUT, '>>', "$conf"
      or die "Cannot open file: $OS_ERROR\n";
                            do {
    my $__echo_line = "LoadModule cgid_module $module_path/mod_cgid.so";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                            $CHILD_ERROR = 0;
                            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                        };
}
                    else {
                        print "You have no CGI support!\n";
exit 2;
                    }
                }
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', "$conf"
      or die "Cannot open file: $OS_ERROR\n";
                    print "ScriptSock logs/gitweb.sock\n";
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
            }
        }
open my $fh_cat, '>', "\"$conf\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "PassEnv GIT_DIR
PassEnv GIT_EXEC_PATH
PassEnv GITWEB_CONFIG
AddHandler cgi-script .cgi
<Location /gitweb.cgi>
\tOptions +ExecCGI
</Location>
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    }
    return;
}

sub mongoose_conf {
open my $fh_cat, '>', "\"$conf\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "# Mongoose web server configuration file.
# Lines starting with '#' and empty lines are ignored.
# For detailed description of every option, visit
# http://code.google.com/p/mongoose/wiki/MongooseManual

root\t\t$root
ports\t\t$port
index_files\tgitweb.cgi
#ssl_cert\t$fqgitdir/gitweb/ssl_cert.pem
error_log\t$fqgitdir/gitweb/$httpd_only/error.log
access_log\t$fqgitdir/gitweb/$httpd_only/access.log

#cgi setup
cgi_env\t\tPATH=$PATH,GIT_DIR=$GIT_DIR,GIT_EXEC_PATH=$GIT_EXEC_PATH,GITWEB_CONFIG=$GITWEB_CONFIG
cgi_interp\t$PERL
cgi_ext\t\tcgi,pl

# mimetype mapping
mime_types\t.gz=application/x-gzip,.tar.gz=application/x-tgz,.tgz=application/x-tgz,.tar=application/x-tar,.zip=application/zip,.gif=image/gif,.jpg=image/jpeg,.jpeg=image/jpeg,.png=image/png,.css=text/css,.html=text/html,.htm=text/html,.js=text/javascript,.c=text/plain,.cpp=text/plain,.log=text/plain,.conf=text/plain,.text=text/plain,.txt=text/plain,.dtd=text/xml,.bz2=application/x-bzip,.tbz=application/x-bzip-compressed-tar,.tar.bz2=application/x-bzip-compressed-tar
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub plackup_conf {
open my $fh_cat, '>', "\"$fqgitdir/gitweb/gitweb.psgi\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "#!$PERL

# gitweb - simple web interface to track changes in git repositories
#          PSGI wrapper and server starter (see http://plackperl.org)

use strict;

use IO::Handle;
use Plack::MIME;
use Plack::Builder;
use Plack::App::WrapCGI;
use CGI::Emulate::PSGI 0.07; # minimum version required to work with gitweb

# mimetype mapping (from lighttpd_conf)
Plack::MIME->add_type(
\t\".pdf\"          =>      \"application/pdf\",
\t\".sig\"          =>      \"application/pgp-signature\",
\t\".spl\"          =>      \"application/futuresplash\",
\t\".class\"        =>      \"application/octet-stream\",
\t\".ps\"           =>      \"application/postscript\",
\t\".torrent\"      =>      \"application/x-bittorrent\",
\t\".dvi\"          =>      \"application/x-dvi\",
\t\".gz\"           =>      \"application/x-gzip\",
\t\".pac\"          =>      \"application/x-ns-proxy-autoconfig\",
\t\".swf\"          =>      \"application/x-shockwave-flash\",
\t\".tar.gz\"       =>      \"application/x-tgz\",
\t\".tgz\"          =>      \"application/x-tgz\",
\t\".tar\"          =>      \"application/x-tar\",
\t\".zip\"          =>      \"application/zip\",
\t\".mp3\"          =>      \"audio/mpeg\",
\t\".m3u\"          =>      \"audio/x-mpegurl\",
\t\".wma\"          =>      \"audio/x-ms-wma\",
\t\".wax\"          =>      \"audio/x-ms-wax\",
\t\".ogg\"          =>      \"application/ogg\",
\t\".wav\"          =>      \"audio/x-wav\",
\t\".gif\"          =>      \"image/gif\",
\t\".jpg\"          =>      \"image/jpeg\",
\t\".jpeg\"         =>      \"image/jpeg\",
\t\".png\"          =>      \"image/png\",
\t\".xbm\"          =>      \"image/x-xbitmap\",
\t\".xpm\"          =>      \"image/x-xpixmap\",
\t\".xwd\"          =>      \"image/x-xwindowdump\",
\t\".css\"          =>      \"text/css\",
\t\".html\"         =>      \"text/html\",
\t\".htm\"          =>      \"text/html\",
\t\".js\"           =>      \"text/javascript\",
\t\".asc\"          =>      \"text/plain\",
\t\".c\"            =>      \"text/plain\",
\t\".cpp\"          =>      \"text/plain\",
\t\".log\"          =>      \"text/plain\",
\t\".conf\"         =>      \"text/plain\",
\t\".text\"         =>      \"text/plain\",
\t\".txt\"          =>      \"text/plain\",
\t\".dtd\"          =>      \"text/xml\",
\t\".xml\"          =>      \"text/xml\",
\t\".mpeg\"         =>      \"video/mpeg\",
\t\".mpg\"          =>      \"video/mpeg\",
\t\".mov\"          =>      \"video/quicktime\",
\t\".qt\"           =>      \"video/quicktime\",
\t\".avi\"          =>      \"video/x-msvideo\",
\t\".asf\"          =>      \"video/x-ms-asf\",
\t\".asx\"          =>      \"video/x-ms-asf\",
\t\".wmv\"          =>      \"video/x-ms-wmv\",
\t\".bz2\"          =>      \"application/x-bzip\",
\t\".tbz\"          =>      \"application/x-bzip-compressed-tar\",
\t\".tar.bz2\"      =>      \"application/x-bzip-compressed-tar\",
\t\"\"              =>      \"text/plain\"
);

my \\$app = builder {
\t# to be able to override \\$SIG{__WARN__} to log build time warnings
\tuse CGI::Carp; # it sets \\$SIG{__WARN__} itself

\tmy \\$logdir = \"$fqgitdir/gitweb/$httpd_only\";
\topen my \\$access_log_fh, '>>', \"\\$logdir/access.log\"
\t\tor die \"Couldn't open access log '\\$logdir/access.log': \\$!\";
\topen my \\$error_log_fh,  '>>', \"\\$logdir/error.log\"
\t\tor die \"Couldn't open error log '\\$logdir/error.log': \\$!\";

\t\\$access_log_fh->autoflush(1);
\t\\$error_log_fh->autoflush(1);

\t# redirect build time warnings to error.log
\t\\$SIG{'__WARN__'} = sub {
\t\tmy \\$msg = shift;
\t\t# timestamp warning like in CGI::Carp::warn
\t\tmy \\$stamp = CGI::Carp::stamp();
\t\t\\$msg =~ s/^/\\$stamp/gm;
\t\tprint \\$error_log_fh \\$msg;
\t};

\t# write errors to error.log, access to access.log
\tenable 'AccessLog',
\t\tformat => \"combined\",
\t\tlogger => sub { print \\$access_log_fh @_; };
\tenable sub {
\t\tmy \\$app = shift;
\t\tsub {
\t\t\tmy \\$env = shift;
\t\t\t\\$env->{'psgi.errors'} = \\$error_log_fh;
\t\t\t\\$app->(\\$env);
\t\t}
\t};
\t# gitweb currently doesn't work with $SIG{CHLD} set to 'IGNORE',
\t# because it uses 'close $fd or die...' on piped filehandle $fh
\t# (which causes the parent process to wait for child to finish).
\tenable_if { \\$SIG{'CHLD'} eq 'IGNORE' } sub {
\t\tmy \\$app = shift;
\t\tsub {
\t\t\tmy \\$env = shift;
\t\t\tlocal \\$SIG{'CHLD'} = 'DEFAULT';
\t\t\tlocal \\$SIG{'CLD'}  = 'DEFAULT';
\t\t\t\\$app->(\\$env);
\t\t}
\t};
\t# serve static files, i.e. stylesheet, images, script
\tenable 'Static',
\t\tpath => sub { m!\\.(js|css|png)\\$! && s!^/gitweb/!! },
\t\troot => \"$root/\",
\t\tencoding => 'utf-8'; # encoding for 'text/plain' files
\t# convert CGI application to PSGI app
\tPlack::App::WrapCGI->new(script => \"$root/gitweb.cgi\")->to_app;
};

# make it runnable as standalone app,
# like it would be run via 'plackup' utility
if (caller) {
\treturn \\$app;
} else {
\trequire Plack::Runner;

\tmy \\$runner = Plack::Runner->new();
\t\\$runner->parse_options(qw(--env deployment --port $port),
\t\t\t\t\"$local\" ? qw(--host 127.0.0.1) : ());
\t\\$runner->run(\\$app);
}
__END__
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
chmod(oct('a+x'), ("$fqgitdir/gitweb/gitweb.psgi")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
if ( -e "$conf" ) {
        if ( -d "$conf" ) {
            carp "rm: carping: ", "$conf",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$conf" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$conf",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}

sub python_conf {
    use File::Path qw(make_path);
    if ( !-d "$fqgitdir/gitweb/$ENV{httpd_only}/cgi-bin" ) {
        make_path( "$fqgitdir/gitweb/$ENV{httpd_only}/cgi-bin", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . "$fqgitdir/gitweb/$ENV{httpd_only}/cgi-bin" . ": $err->[0]\n";
        }
    }
symlink q{f}, "$fqgitdir/gitweb/$ENV{httpd_only}/cgi-bin/gitweb.cgi" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink q{f}, "$fqgitdir/gitweb/$ENV{httpd_only}/" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
open my $fh_cat, '>', "\"$fqgitdir/gitweb/gitweb.py\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "#!/usr/bin/env python
import os
import sys

# Open log file in line buffering mode
accesslogfile = open(\"$fqgitdir/gitweb/access.log\", 'a', buffering=1)
errorlogfile = open(\"$fqgitdir/gitweb/error.log\", 'a', buffering=1)

# and replace our stdout and stderr with log files
# also do a lowlevel duplicate of the logfile file descriptors so that
# our CGI child process writes any stderr warning also to the log file
_orig_stdout_fd = sys.stdout.fileno()
sys.stdout.close()
os.dup2(accesslogfile.fileno(), _orig_stdout_fd)
sys.stdout = accesslogfile

_orig_stderr_fd = sys.stderr.fileno()
sys.stderr.close()
os.dup2(errorlogfile.fileno(), _orig_stderr_fd)
sys.stderr = errorlogfile

from functools import partial

if sys.version_info < (3, 0):  # Python 2
\tfrom CGIHTTPServer import CGIHTTPRequestHandler
\tfrom BaseHTTPServer import HTTPServer as ServerClass
else:  # Python 3
\tfrom http.server import CGIHTTPRequestHandler
\tfrom http.server import HTTPServer as ServerClass


# Those environment variables will be passed to the cgi script
os.environ.update({
\t\"GIT_EXEC_PATH\": \"$GIT_EXEC_PATH\",
\t\"GIT_DIR\": \"$GIT_DIR\",
\t\"GITWEB_CONFIG\": \"$GITWEB_CONFIG\"
})


class GitWebRequestHandler(CGIHTTPRequestHandler):

\tdef log_message(self, format, *args):
\t\t# Write access logs to stdout
\t\tsys.stdout.write(\"%s - - [%s] %s\\n\" %
\t\t\t\t(self.address_string(),
\t\t\t\tself.log_date_time_string(),
\t\t\t\tformat%args))

\tdef do_HEAD(self):
\t\tself.redirect_path()
\t\tCGIHTTPRequestHandler.do_HEAD(self)

\tdef do_GET(self):
\t\tif self.path == \"/\":
\t\t\tself.send_response(303, \"See Other\")
\t\t\tself.send_header(\"Location\", \"/cgi-bin/gitweb.cgi\")
\t\t\tself.end_headers()
\t\t\treturn
\t\tself.redirect_path()
\t\tCGIHTTPRequestHandler.do_GET(self)

\tdef do_POST(self):
\t\tself.redirect_path()
\t\tCGIHTTPRequestHandler.do_POST(self)

\t# rewrite path of every request that is not gitweb.cgi to out of cgi-bin
\tdef redirect_path(self):
\t\tif not self.path.startswith(\"/cgi-bin/gitweb.cgi\"):
\t\t\tself.path = self.path.replace(\"/cgi-bin/\", \"/\")

\t# gitweb.cgi is the only thing that is ever going to be run here.
\t# Ignore everything else
\tdef is_cgi(self):
\t\tresult = False
\t\tif self.path.startswith('/cgi-bin/gitweb.cgi'):
\t\t\tresult = CGIHTTPRequestHandler.is_cgi(self)
\t\treturn result


bind = \"127.0.0.1\"
if \"$local\" == \"true\":
\tbind = \"0.0.0.0\"

# Set our http root directory
# This is a work around for a missing directory argument in older Python versions
# as this was added to SimpleHTTPRequestHandler in Python 3.7
os.chdir(\"$fqgitdir/gitweb/$httpd_only/\")

GitWebRequestHandler.protocol_version = \"HTTP/1.0\"
httpd = ServerClass((bind, $port), GitWebRequestHandler)

sa = httpd.socket.getsockname()
print(\"Serving HTTP on\", sa[0], \"port\", sa[1], \"...\")
httpd.serve_forever()
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
chmod(oct('a+x'), ("$fqgitdir/gitweb/gitweb.py")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    return;
}

sub gitweb_conf {
open my $fh_cat, '>', "\"$fqgitdir/gitweb/gitweb_config.perl\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "#!/usr/bin/perl
our \\$projectroot = \"$(dirname \"$fqgitdir\")\";
our \\$git_temp = \"$fqgitdir/gitweb/tmp\";
our \\$projects_list = \\$projectroot;

\\$feature{'remote_heads'}{'default'} = [1];
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    return;
}

sub configure_httpd {
if ("$httpd" =~ /^.*lighttpd.*$/msx) {
                lighttpd_conf();
    } elsif ("$httpd" =~ /^.*apache2.*$/msx or "$httpd" =~ /^.*httpd.*$/msx) {
                apache2_conf();
    } elsif ("$httpd" =~ /^webrick$/msx) {
                webrick_conf();
    } elsif ("$httpd" =~ /^.*mongoose.*$/msx) {
                mongoose_conf();
    } elsif ("$httpd" =~ /^.*plackup.*$/msx) {
                plackup_conf();
    } elsif ("$httpd" =~ /^.*python.*$/msx) {
                python_conf();
    } elsif (1) {
                do {
    my $__echo_line = "Unknown httpd specified: $httpd";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        exit 1;
    }
    return;
}
if ("$action" =~ /^stop$/msx) {
        stop_httpd();
    exit 0;
} elsif ("$action" =~ /^start$/msx) {
        start_httpd();
    exit 0;
} elsif ("$action" =~ /^restart$/msx) {
        stop_httpd();
        start_httpd();
    exit 0;
}
gitweb_conf();
resolve_full_httpd();
use File::Path qw(make_path);
if ( !-d "$fqgitdir/gitweb/$ENV{httpd_only}" ) {
    make_path( "$fqgitdir/gitweb/$ENV{httpd_only}", { error => \$err } );
    if ( @{$err} ) {
        croak "mkdir: cannot create directory " . "$fqgitdir/gitweb/$ENV{httpd_only}" . ": $err->[0]\n";
    }
}
$conf = "$fqgitdir/gitweb/$ENV{httpd_only}.conf";
configure_httpd();
start_httpd();
my $url;
my @url;
my %url;
$url = 'http://127.0.0.1:';
if (StringInterpolation(StringInterpolation { parts: [Variable("browser")] }, None) ne q{}) {
        if (do {
httpd_is_ready();
        $CHILD_ERROR == 0
    }) {
                $main_exit_code = system('git', 'web--browse', '-b', "$browser", $url) >> 8;
    }
    if ($CHILD_ERROR != 0) {
                print $url;
if ( !( ($url) =~ m{\n\z}msx ) ) { print "\n"; }
    }
}
else {
        if (do {
httpd_is_ready();
        $CHILD_ERROR == 0
    }) {
                $main_exit_code = system('git', 'web--browse', '-c', "instaweb.browser", $url) >> 8;
    }
    if ($CHILD_ERROR != 0) {
                print $url;
if ( !( ($url) =~ m{\n\z}msx ) ) { print "\n"; }
    }
}

exit $main_exit_code;
