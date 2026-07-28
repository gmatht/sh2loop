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


sub spotify {
    my ($file) = @_;
    my $USER_CONFIG_DEFAULTS;
    my @USER_CONFIG_DEFAULTS;
    my %USER_CONFIG_DEFAULTS;
    $USER_CONFIG_DEFAULTS = "CLIENT_ID=\"\"\nCLIENT_SECRET=\"\"";
    my $USER_CONFIG_FILE;
    my @USER_CONFIG_FILE;
    my %USER_CONFIG_FILE;
    $USER_CONFIG_FILE = ($ENV{HOME} // q{}) . "/.shpotify.cfg";
if (!(!((-f "${USER_CONFIG_FILE}")))) {
        if ( -e "${USER_CONFIG_FILE}" ) {
            my $current_time = time;
            utime $current_time, $current_time, "${USER_CONFIG_FILE}";
        }
        else {
            if ( open my $fh, '>', "${USER_CONFIG_FILE}" ) {
                close $fh or croak "Close failed: $ERRNO";
            }
            else {
                croak "touch: cannot create ", "${USER_CONFIG_FILE}",
                  ": $ERRNO\n";
            }
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', ${USER_CONFIG_FILE}
      or die "Cannot open file: $OS_ERROR\n";
            print ${USER_CONFIG_DEFAULTS};
if ( !( (${USER_CONFIG_DEFAULTS}) =~ m{\n\z}msx ) ) { print "\n"; }
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
# Builtin command 'source' not implemented
    my $VOL_INCREMENT;
    my @VOL_INCREMENT;
    my %VOL_INCREMENT;
    $VOL_INCREMENT = '10';

sub showAPIHelp {
        print "\n";
        $CHILD_ERROR = 0;
        print "Connecting to Spotify's API:\n";
        print "\n";
        $CHILD_ERROR = 0;
        print "  This command line application needs to connect to Spotify's API in order to\n";
        print "  find music by name. It is very likely you want this feature!\n";
        print "\n";
        $CHILD_ERROR = 0;
        print "  To get this to work, you need to sign up (or in) and create an 'Application' at:\n";
        print "  https://developer.spotify.com/dashboard/create\n";
        print "\n";
        $CHILD_ERROR = 0;
        print "  Once you've created an application, find the 'Client ID' and 'Client Secret'\n";
        do {
    my $__echo_line = "  values, and enter them into your shpotify config file at '" . ${USER_CONFIG_FILE} . "'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print "\n";
        $CHILD_ERROR = 0;
        print "  Be sure to quote your values and don't add any extra spaces!\n";
        print "  When done, it should look like this (but with your own values):\n";
        print "  CLIENT_ID=\"abc01de2fghijk345lmnop\"\n";
        print "  CLIENT_SECRET=\"qr6stu789vwxyz\"\n";
        return;
}

sub showHelp {
        print "Usage:\n";
        print "\n";
        $CHILD_ERROR = 0;
        do {
    my $__echo_line = "  " . (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($PROGRAM_NAME); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; }) . " <command>";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print "\n";
        $CHILD_ERROR = 0;
        print "Commands:\n";
        print "\n";
        $CHILD_ERROR = 0;
        print "  play                         # Resumes playback where Spotify last left off.\n";
        print "  play <song name>             # Finds a song by name and plays it.\n";
        print "  play album <album name>      # Finds an album by name and plays it.\n";
        print "  play artist <artist name>    # Finds an artist by name and plays it.\n";
        print "  play list <playlist name>    # Finds a playlist by name and plays it.\n";
        print "  play uri <uri>               # Play songs from specific uri.\n";
        print "\n";
        $CHILD_ERROR = 0;
        print "  next                         # Skips to the next song in a playlist.\n";
        print "  prev                         # Returns to the previous song in a playlist.\n";
        print "  replay                       # Replays the current track from the beginning.\n";
        print "  pos <time>                   # Jumps to a time (in secs) in the current song.\n";
        print "  pause                        # Pauses (or resumes) Spotify playback.\n";
        print "  stop                         # Stops playback.\n";
        print "  quit                         # Stops playback and quits Spotify.\n";
        print "\n";
        $CHILD_ERROR = 0;
        print "  vol up                       # Increases the volume by 10%.\n";
        print "  vol down                     # Decreases the volume by 10%.\n";
        print "  vol <amount>                 # Sets the volume to an amount between 0 and 100.\n";
        print "  vol [show]                   # Shows the current Spotify volume.\n";
        print "\n";
        $CHILD_ERROR = 0;
        print "  status                       # Shows the current player status.\n";
        print "  status artist                # Shows the currently playing artist.\n";
        print "  status album                 # Shows the currently playing album.\n";
        print "  status track                 # Shows the currently playing track.\n";
        print "\n";
        $CHILD_ERROR = 0;
        print "  share                        # Displays the current song's Spotify URL and URI.\n";
        print "  share url                    # Displays the current song's Spotify URL and copies it to the clipboard.\n";
        print "  share uri                    # Displays the current song's Spotify URI and copies it to the clipboard.\n";
        print "\n";
        $CHILD_ERROR = 0;
        print "  toggle shuffle               # Toggles shuffle playback mode.\n";
        print "  toggle repeat                # Toggles repeat playback mode.\n";
        showAPIHelp();
        return;
}

sub cecho {
        my ($file) = @_;
        my $bold;
        my @bold;
        my %bold;
        $bold = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'tput', 'bold');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
};
        my $green;
        my @green;
        my %green;
        $green = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'tput', 'setaf', q{2});
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
        my $reset;
        my @reset;
        my %reset;
        $reset = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'tput', 'sgr0');
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
};
        do {
    my $__echo_line = $bold . q{ } . $green . q{ } . $1 . q{ } . $reset;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        return;
}

sub showArtist {
        print join(" ", grep { length } split /\s+/msx, do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'osascript', '-e', "tell application \"Spotify\" to artist of current track as string");
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
});
        return;
}

sub showAlbum {
        print join(" ", grep { length } split /\s+/msx, do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'osascript', '-e', "tell application \"Spotify\" to album of current track as string");
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
});
        return;
}

sub showTrack {
        print join(" ", grep { length } split /\s+/msx, do {
    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'osascript', '-e', "tell application \"Spotify\" to name of current track as string");
    close $in_6 or croak 'Close failed: $OS_ERROR';
    my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    $result_6
});
        return;
}

sub showStatus {
        my $state;
        my @state;
        my %state;
        $state = do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'osascript', '-e', "tell application \"Spotify\" to player state as string");
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
};
        cecho("Spotify is currently $state.");
        my $duration;
        my @duration;
        my %duration;
        $duration = do {
    my ($in_8, $out_8);
    my $pid_8 = open3($in_8, $out_8, '>&STDERR', 'osascript', '-e', "tell application \"Spotify\"\n            set durSec to (duration of current track / 1000) as text\n            set tM to (round (durSec / 60) rounding down) as text\n            if length of ((durSec mod 60 div 1) as text) is greater than 1 then\n                set tS to (durSec mod 60 div 1) as text\n            else\n                set tS to (\"0\" & (durSec mod 60 div 1)) as text\n            end if\n            set myTime to tM as text & \":\" & tS as text\n            end tell\n            return myTime");
    close $in_8 or croak 'Close failed: $OS_ERROR';
    my $result_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
    close $out_8 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_8, 0;
    $result_8
};
        my $position;
        my @position;
        my %position;
        $position = do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'osascript', '-e', "tell application \"Spotify\"\n            set pos to player position\n            set nM to (round (pos / 60) rounding down) as text\n            if length of ((round (pos mod 60) rounding down) as text) is greater than 1 then\n                set nS to (round (pos mod 60) rounding down) as text\n            else\n                set nS to (\"0\" & (round (pos mod 60) rounding down)) as text\n            end if\n            set nowAt to nM as text & \":\" & nS as text\n            end tell\n            return nowAt");
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
};
        do {
    my $__echo_line = $reset . q{ } . "Artist: do {\n    my ($in_10, $out_10);\n    my $pid_10 = open3($in_10, $out_10, '>&STDERR', 'showArtist');\n    close $in_10 or croak 'Close failed: $OS_ERROR';\n    my $result_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };\n    close $out_10 or croak 'Close failed: $OS_ERROR';\n    waitpid $pid_10, 0;\n    $result_10\n}\nAlbum: do {\n    my ($in_11, $out_11);\n    my $pid_11 = open3($in_11, $out_11, '>&STDERR', 'showAlbum');\n    close $in_11 or croak 'Close failed: $OS_ERROR';\n    my $result_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };\n    close $out_11 or croak 'Close failed: $OS_ERROR';\n    waitpid $pid_11, 0;\n    $result_11\n}\nTrack: do {\n    my ($in_12, $out_12);\n    my $pid_12 = open3($in_12, $out_12, '>&STDERR', 'showTrack');\n    close $in_12 or croak 'Close failed: $OS_ERROR';\n    my $result_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };\n    close $out_12 or croak 'Close failed: $OS_ERROR';\n    waitpid $pid_12, 0;\n    $result_12\n} \nPosition: $position / $duration";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        return;
}
if ($# eq 0) {
        showHelp();
}
    else {
if (((!-d /Applications/Spotify.app) && (!-d $HOME/Applications/Spotify.app))) {
            print "The Spotify application must be installed.\n";
return q{1};
        }
if ($(osascript -e 'application "Spotify" is running') eq "false") {
                        $main_exit_code = system('osascript', '-e', "tell application \"Spotify\" to activate") >> 8;
            if ($CHILD_ERROR != 0) {
                return q{1};            }
require Time::HiRes; Time::HiRes::sleep(q{2});
        }
    }
while ( scalar(@ARGV) > 0 ) {
        my $arg;
        my @arg;
        my %arg;
        $arg = $1;
if ($arg =~ /^play$/msx) {
            if ($# ne 1) {
                my $array;
                my @array = ('$@');
                my %array;
                my $len;
                my @len;
                my %len;
                $len = scalar(@array);
                my $SPOTIFY_SEARCH_API;
                my @SPOTIFY_SEARCH_API;
                my %SPOTIFY_SEARCH_API;
                $SPOTIFY_SEARCH_API = "https://api.spotify.com/v1/search";
                my $SPOTIFY_TOKEN_URI;
                my @SPOTIFY_TOKEN_URI;
                my %SPOTIFY_TOKEN_URI;
                $SPOTIFY_TOKEN_URI = "https://accounts.spotify.com/api/token";
if ("${CLIENT_ID}" eq q{}) {
                    cecho("Invalid Client ID, please update " . ${USER_CONFIG_FILE});
                    showAPIHelp();
return q{1};
                }
if ("${CLIENT_SECRET}" eq q{}) {
                    cecho("Invalid Client Secret, please update " . ${USER_CONFIG_FILE});
                    showAPIHelp();
return q{1};
                }
                my $SHPOTIFY_CREDENTIALS;
                my @SHPOTIFY_CREDENTIALS;
                my %SHPOTIFY_CREDENTIALS;
                $SHPOTIFY_CREDENTIALS = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_14 = q{};
                    my $output_printed_14;
                    my $pipeline_success_14 = 1;
                    my $output_14;
                    {
                        local *STDOUT;
                        open STDOUT, '>', \$output_14 or die "Cannot redirect STDOUT";
                        printf(q{:});
                    }
                    if ($CHILD_ERROR != 0) { $pipeline_success_14 = 0; }

                    my $cmd_16 = 'base64';
                    my ($in_15, $out_15);
                    my $pid_15 = open3($in_15, $out_15, '>&STDERR', $cmd_16, );
                    print {$in_15} $output_14;
                    close $in_15 or croak 'Close failed: $OS_ERROR';
                    $output_14 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_15> };
                    close $out_15 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_15, 0;
                    my $set1_17 = "\n";
                    my $input_17 = $output_14;
                    my $tr_result_14_2 = q{};
                    for my $char ( split //msx, $input_17 ) {
                        if ( (index $set1_17, $char) == -1 ) {
                            $tr_result_14_2 .= $char;
                        }
                    }
                                        if (!($tr_result_14_2 =~ m{\n\z}msx || $tr_result_14_2 eq q{})) {
                                            $tr_result_14_2 .= "\n";
                                        }
                                        $output_14 = $tr_result_14_2;
                    my $set1_18 = "\\r";
                    my $input_18 = $output_14;
                    my $tr_result_14_3 = q{};
                    for my $char ( split //msx, $input_18 ) {
                        if ( (index $set1_18, $char) == -1 ) {
                            $tr_result_14_3 .= $char;
                        }
                    }
                                        if (!($tr_result_14_3 =~ m{\n\z}msx || $tr_result_14_3 eq q{})) {
                                            $tr_result_14_3 .= "\n";
                                        }
                                        $output_14 = $tr_result_14_3;
                    if ( !$pipeline_success_14 ) { $main_exit_code = 1; }
                    $output_14 =~ s/\n+\z//msx;
                    $output_14;
}; $_pipeline_result; };
                my $SPOTIFY_PLAY_URI;
                my @SPOTIFY_PLAY_URI;
                my %SPOTIFY_PLAY_URI;
                $SPOTIFY_PLAY_URI = "";

sub getAccessToken {
                    cecho("Connecting to Spotify's API");
                    my $SPOTIFY_TOKEN_RESPONSE_DATA;
                    my @SPOTIFY_TOKEN_RESPONSE_DATA;
                    my %SPOTIFY_TOKEN_RESPONSE_DATA;
                    $SPOTIFY_TOKEN_RESPONSE_DATA = do { my @_qx_cmd = ('curl "${SPOTIFY_TOKEN_URI}" --silent -X POST -H "Authorization: Basic ${SHPOTIFY_CREDENTIALS}" -d grant_type=client_credentials'); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if (!(!("${SPOTIFY_TOKEN_RESPONSE_DATA}" =~ /"access_token"/msx))) {
                        cecho("Authorization failed, please check " . ($ENV{USER_CONFG_FILE} // q{}));
                        cecho(${SPOTIFY_TOKEN_RESPONSE_DATA});
                        showAPIHelp();
return q{1};
                    }
                    my $SPOTIFY_ACCESS_TOKEN;
                    my @SPOTIFY_ACCESS_TOKEN;
                    my %SPOTIFY_ACCESS_TOKEN;
                    $SPOTIFY_ACCESS_TOKEN = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                        my $output_19 = q{};
                        my $output_printed_19;
                        my $pipeline_success_19 = 1;
                        my $output_19;
                        {
                            local *STDOUT;
                            open STDOUT, '>', \$output_19 or die "Cannot redirect STDOUT";
                            printf(q{});
                        }
                        if ($CHILD_ERROR != 0) { $pipeline_success_19 = 0; }

                        my $cmd_21 = 'command';
                        my ($in_20, $out_20);
                        my $pid_20 = open3($in_20, $out_20, '>&STDERR', $cmd_21, 'grep', '-E', '-o', "\"access_token\":\".*\",");
                        print {$in_20} $output_19;
                        close $in_20 or croak 'Close failed: $OS_ERROR';
                        $output_19 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
                        close $out_20 or croak 'Close failed: $OS_ERROR';
                        waitpid $pid_20, 0;
                        my @sed_lines_19 = split /\n/msx, $output_19;
                        my @sed_result_19;
                        foreach my $line (@sed_lines_19) {
                        chomp $line;
                        $line =~ s/"access_token"://gmsx;
                        push @sed_result_19, $line;
                        }
                        $output_19 = join "\n", @sed_result_19;

                        my @sed_lines_19 = split /\n/msx, $output_19;
                        my @sed_result_19;
                        foreach my $line (@sed_lines_19) {
                        chomp $line;
                        $line =~ s/"//gmsx;
                        push @sed_result_19, $line;
                        }
                        $output_19 = join "\n", @sed_result_19;

                        my @sed_lines_19 = split /\n/msx, $output_19;
                        my @sed_result_19;
                        foreach my $line (@sed_lines_19) {
                        chomp $line;
                        $line =~ s/,.*//gmsx;
                        push @sed_result_19, $line;
                        }
                        $output_19 = join "\n", @sed_result_19;

                        if ( !$pipeline_success_19 ) { $main_exit_code = 1; }
                        $output_19 =~ s/\n+\z//msx;
                        $output_19;
}; $_pipeline_result; };
                    return;
}

sub searchAndPlay {
                    my $type;
                    my @type;
                    my %type;
                    $type = "$_[0]";
                    my $Q;
                    my @Q;
                    my %Q;
                    $Q = "$_[1]";
                    getAccessToken();
                    cecho("Searching " . ${type} . "s for: $Q");
                    $SPOTIFY_PLAY_URI = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                        my $output_22 = q{};
                        my $output_printed_22;
                        my $pipeline_success_22 = 1;
                        use LWP::UserAgent;
                        use HTTP::Request;
                        use HTTP::Headers;
                        my $ua = LWP::UserAgent->new;
                        my $headers = HTTP::Headers->new;
                        $headers->header("Authorization: Bearer " . ($ENV{SPOTIFY_ACCESS_TOKEN} // q{}));
                        $headers->header("Accept: application/json");
                        my $request = HTTP::Request->new('GET', $SPOTIFY_SEARCH_API);
                        $request->headers($headers);
                        $request->content("type=$type&limit=1&offset=0");
                        my $response = $ua->request($request);
                        if ($response->is_success) {
                        } else {
                        die "curl: HTTP error: $response->code $response->message\n";
                        }
                        if ($CHILD_ERROR != 0) { $pipeline_success_22 = 0; }

                        my $cmd_24 = 'command';
                        my ($in_23, $out_23);
                        my $pid_23 = open3($in_23, $out_23, '>&STDERR', $cmd_24, 'grep', '-E', '-o', '-m', q{1});
                        print {$in_23} $output_22;
                        close $in_23 or croak 'Close failed: $OS_ERROR';
                        $output_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
                        close $out_23 or croak 'Close failed: $OS_ERROR';
                        waitpid $pid_23, 0;
                        if ( !$pipeline_success_22 ) { $main_exit_code = 1; }
                        $output_22 =~ s/\n+\z//msx;
                        $output_22;
}; $_pipeline_result; };
                    return;
}
if ($arg2 =~ /^list$/msx) {
                                        my $_args;
                    my @_args;
                    my %_args;
                    $_args = @array[2..$len];
                                        my $Q;
                    my @Q;
                    my %Q;
                    $Q = $_args;
                                        getAccessToken();
                                        cecho("Searching playlists for: $Q");
                                        my $results;
                    my @results;
                    my %results;
                    $results = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                        my $output_25 = q{};
                        my $output_printed_25;
                        my $pipeline_success_25 = 1;
                        use LWP::UserAgent;
                        use HTTP::Request;
                        use HTTP::Headers;
                        my $ua = LWP::UserAgent->new;
                        my $headers = HTTP::Headers->new;
                        $headers->header("Accept: application/json");
                        $headers->header("Authorization: Bearer " . ($ENV{SPOTIFY_ACCESS_TOKEN} // q{}));
                        my $request = HTTP::Request->new('GET', $SPOTIFY_SEARCH_API);
                        $request->headers($headers);
                        $request->content("type=playlist&limit=10&offset=0");
                        my $response = $ua->request($request);
                        if ($response->is_success) {
                        } else {
                        die "curl: HTTP error: $response->code $response->message\n";
                        }
                        if ($CHILD_ERROR != 0) { $pipeline_success_25 = 0; }

                        my $cmd_27 = 'command';
                        my ($in_26, $out_26);
                        my $pid_26 = open3($in_26, $out_26, '>&STDERR', $cmd_27, 'grep', '-E', '-o', '-m', '10');
                        print {$in_26} $output_25;
                        close $in_26 or croak 'Close failed: $OS_ERROR';
                        $output_25 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_26> };
                        close $out_26 or croak 'Close failed: $OS_ERROR';
                        waitpid $pid_26, 0;
                        if ( !$pipeline_success_25 ) { $main_exit_code = 1; }
                        $output_25 =~ s/\n+\z//msx;
                        $output_25;
}; $_pipeline_result; };
                                        my $count;
                    my @count;
                    my %count;
                    $count = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                        my $output_28 = q{};
                        my $output_printed_28;
                        my $pipeline_success_28 = 1;
                        $output_28 .= $results . "\n";
                        if ( !($output_28 =~ m{\n\z}msx) ) { $output_28 .= "\n"; }
                        $CHILD_ERROR = 0;
                        if ($CHILD_ERROR != 0) { $pipeline_success_28 = 0; }

                        my $cmd_30 = 'command';
                        my ($in_29, $out_29);
                        my $pid_29 = open3($in_29, $out_29, '>&STDERR', $cmd_30, 'grep', '-c');
                        print {$in_29} $output_28;
                        close $in_29 or croak 'Close failed: $OS_ERROR';
                        $output_28 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_29> };
                        close $out_29 or croak 'Close failed: $OS_ERROR';
                        waitpid $pid_29, 0;
                        if ( !$pipeline_success_28 ) { $main_exit_code = 1; }
                        $output_28 =~ s/\n+\z//msx;
                        $output_28;
}; $_pipeline_result; };
                    if (($count > 0)) {
                        my $random;
                        my @random;
                        my %random;
                        my $RANDOM;
                        $random = eval { int( $RANDOM % $count) } // "";
                        $SPOTIFY_PLAY_URI = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                            my $output_31 = q{};
                            my $output_printed_31;
                            my $pipeline_success_31 = 1;
                            $output_31 .= $results . "\n";
                            if ( !($output_31 =~ m{\n\z}msx) ) { $output_31 .= "\n"; }
                            $CHILD_ERROR = 0;
                            if ($CHILD_ERROR != 0) { $pipeline_success_31 = 0; }
                            my @lines = split /\n/msx, $output_31;
                            my @result;
                            foreach my $line (@lines) {
                                chomp $line;
                                if ($line =~ /^\s*$/msx) { next; }
                                my @fields = split /\s+/msx, $line;
                                if (!(/spotify:playlist:[a-zA-Z0-9]+/)) { next; }
                                push @result, (; exit . "\n");
                            }
                            $output_31 = join "", @result;

                            if ( !$pipeline_success_31 ) { $main_exit_code = 1; }
                            $output_31 =~ s/\n+\z//msx;
                            $output_31;
}; $_pipeline_result; };
                    }
                } elsif ($arg2 =~ /^album$/msx or $arg2 =~ /^artist$/msx or $arg2 =~ /^track$/msx) {
                                        $_args = @array[2..$len];
                                        searchAndPlay($2, "$_args");
                } elsif ($arg2 =~ /^uri$/msx) {
                                        $SPOTIFY_PLAY_URI = @array[2..$len];
                } elsif (1) {
                                        $_args = @array[1..$len];
                                        searchAndPlay('track', "$_args");
                }
if ("$SPOTIFY_PLAY_URI" ne "") {
if ("$2" eq "uri") {
                        cecho("Playing Spotify URI: $SPOTIFY_PLAY_URI");
}
                    else {
                        cecho("Playing ($Q Search) -> Spotify URI: $SPOTIFY_PLAY_URI");
                    }
                    $main_exit_code = system('osascript', '-e', "tell application \"Spotify\" to play track \"$SPOTIFY_PLAY_URI\"") >> 8;
}
                else {
                    cecho("No results when searching for $Q");
                }
}
            else {
                cecho("Playing Spotify.");
                $main_exit_code = system('osascript', '-e', "tell application \"Spotify\" to play") >> 8;
            }
            last;        } elsif ($arg =~ /^pause$/msx) {
                        my $state;
            my @state;
            my %state;
            $state = do {
    my ($in_32, $out_32);
    my $pid_32 = open3($in_32, $out_32, '>&STDERR', 'osascript', '-e', "tell application \"Spotify\" to player state as string");
    close $in_32 or croak 'Close failed: $OS_ERROR';
    my $result_32 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_32> };
    close $out_32 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_32, 0;
    $result_32
};
            if ($state eq "playing") {
                cecho("Pausing Spotify.");
}
            else {
                cecho("Playing Spotify.");
            }
                        $main_exit_code = system('osascript', '-e', "tell application \"Spotify\" to playpause") >> 8;
            last;        } elsif ($arg =~ /^stop$/msx) {
                        $state = do {
    my ($in_33, $out_33);
    my $pid_33 = open3($in_33, $out_33, '>&STDERR', 'osascript', '-e', "tell application \"Spotify\" to player state as string");
    close $in_33 or croak 'Close failed: $OS_ERROR';
    my $result_33 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_33> };
    close $out_33 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_33, 0;
    $result_33
};
            if ($state eq "playing") {
                cecho("Pausing Spotify.");
                $main_exit_code = system('osascript', '-e', "tell application \"Spotify\" to playpause") >> 8;
}
            else {
                cecho("Spotify is already stopped.");
            }
            last;        } elsif ($arg =~ /^quit$/msx) {
                        cecho("Quitting Spotify.");
                        $main_exit_code = system('osascript', '-e', "tell application \"Spotify\" to quit") >> 8;
            last;        } elsif ($arg =~ /^next$/msx) {
                        cecho("Going to next track.");
                        $main_exit_code = system('osascript', '-e', "tell application \"Spotify\" to next track") >> 8;
                        showStatus();
            last;        } elsif ($arg =~ /^prev$/msx) {
                        cecho("Going to previous track.");
                        $main_exit_code = system('osascript', '-e', "\n            tell application \"Spotify\"\n                set player position to 0\n                previous track\n            end tell") >> 8;
                        showStatus();
            last;        } elsif ($arg =~ /^replay$/msx) {
                        cecho("Replaying current track.");
                        $main_exit_code = system('osascript', '-e', "tell application \"Spotify\" to set player position to 0") >> 8;
            last;        } elsif ($arg =~ /^vol$/msx) {
                        my $vol;
            my @vol;
            my %vol;
            $vol = do {
    my ($in_34, $out_34);
    my $pid_34 = open3($in_34, $out_34, '>&STDERR', 'osascript', '-e', "tell application \"Spotify\" to sound volume as integer");
    close $in_34 or croak 'Close failed: $OS_ERROR';
    my $result_34 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_34> };
    close $out_34 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_34, 0;
    $result_34
};
            if (($2 eq "" || $2 eq "show")) {
                cecho("Current Spotify volume level is $vol.");
last;
}
            else {
                if ("$2" eq "up") {
if (($vol <= (eval { int( 100-$VOL_INCREMENT ) } // ""))) {
                        my $newvol;
                        my @newvol;
                        my %newvol;
                        $newvol = eval { int( $vol+$VOL_INCREMENT ) } // "";
                        cecho("Increasing Spotify volume to $newvol.");
}
                    else {
                        $newvol = '100';
                        cecho("Spotify volume level is at max.");
                    }
}
                else {
                    if ("$2" eq "down") {
if (($vol >= (eval { int( $VOL_INCREMENT ) } // ""))) {
                            $newvol = eval { int( $vol-$VOL_INCREMENT ) } // "";
                            cecho("Reducing Spotify volume to $newvol.");
}
                        else {
                            $newvol = q{0};
                            cecho("Spotify volume level is at min.");
                        }
}
                    else {
                        if (($ENV{2} =~ /^[0-9]+$/msx && (($2 >= 0) && ($2 <= 100)))) {
                            $newvol = $2;
                            cecho("Setting Spotify volume level to $newvol");
}
                        else {
                            print "Improper use of 'vol' command\n";
                            print "The 'vol' command should be used as follows:\n";
                            do {
    my $__echo_line = "  vol up                       # Increases the volume by $VOL_INCREMENT%.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                            $CHILD_ERROR = 0;
                            do {
    my $__echo_line = "  vol down                     # Decreases the volume by $VOL_INCREMENT%.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                            $CHILD_ERROR = 0;
                            print "  vol [amount]                 # Sets the volume to an amount between 0 and 100.\n";
                            print "  vol                          # Shows the current Spotify volume.\n";
return q{1};
                        }
                    }
                }
            }
                        $main_exit_code = system('osascript', '-e', "tell application \"Spotify\" to set sound volume to $newvol") >> 8;
            last;        } elsif ($arg =~ /^toggle$/msx) {
            if ("$2" eq "shuffle") {
                $main_exit_code = system('osascript', '-e', "tell application \"Spotify\" to set shuffling to not shuffling") >> 8;
                my $curr;
                my @curr;
                my %curr;
                $curr = do {
    my ($in_35, $out_35);
    my $pid_35 = open3($in_35, $out_35, '>&STDERR', 'osascript', '-e', "tell application \"Spotify\" to shuffling");
    close $in_35 or croak 'Close failed: $OS_ERROR';
    my $result_35 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_35> };
    close $out_35 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_35, 0;
    $result_35
};
                cecho("Spotify shuffling set to $curr");
}
            else {
                if ("$2" eq "repeat") {
                    $main_exit_code = system('osascript', '-e', "tell application \"Spotify\" to set repeating to not repeating") >> 8;
                    $curr = do {
    my ($in_36, $out_36);
    my $pid_36 = open3($in_36, $out_36, '>&STDERR', 'osascript', '-e', "tell application \"Spotify\" to repeating");
    close $in_36 or croak 'Close failed: $OS_ERROR';
    my $result_36 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_36> };
    close $out_36 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_36, 0;
    $result_36
};
                    cecho("Spotify repeating set to $curr");
                }
            }
            last;        } elsif ($arg =~ /^status$/msx) {
            if ($# ne 1) {
if ($arg2 =~ /^artist$/msx) {
                                        showArtist();
                    last;                } elsif ($arg2 =~ /^album$/msx) {
                                        showAlbum();
                    last;                } elsif ($arg2 =~ /^track$/msx) {
                                        showTrack();
                    last;                }
}
            else {
                showStatus();
            }
            last;        } elsif ($arg =~ /^info$/msx) {
                        my $info;
            my @info;
            my %info;
            $info = do {
    my ($in_37, $out_37);
    my $pid_37 = open3($in_37, $out_37, '>&STDERR', 'osascript', '-e', "tell application \"Spotify\"\n                set durSec to (duration of current track / 1000)\n                set tM to (round (durSec / 60) rounding down) as text\n                if length of ((durSec mod 60 div 1) as text) is greater than 1 then\n                    set tS to (durSec mod 60 div 1) as text\n                else\n                    set tS to (\"0\" & (durSec mod 60 div 1)) as text\n                end if\n                set myTime to tM as text & \"min \" & tS as text & \"s\"\n                set pos to player position\n                set nM to (round (pos / 60) rounding down) as text\n                if length of ((round (pos mod 60) rounding down) as text) is greater than 1 then\n                    set nS to (round (pos mod 60) rounding down) as text\n                else\n                    set nS to (\"0\" & (round (pos mod 60) rounding down)) as text\n                end if\n                set nowAt to nM as text & \"min \" & nS as text & \"s\"\n                set info to \"\" & \"\\nArtist:         \" & artist of current track\n                set info to info & \"\\nTrack:          \" & name of current track\n                set info to info & \"\\nAlbum Artist:   \" & album artist of current track\n                set info to info & \"\\nAlbum:          \" & album of current track\n                set info to info & \"\\nSeconds:        \" & durSec\n                set info to info & \"\\nSeconds played: \" & pos\n                set info to info & \"\\nDuration:       \" & mytime\n                set info to info & \"\\nNow at:         \" & nowAt\n                set info to info & \"\\nPlayed Count:   \" & played count of current track\n                set info to info & \"\\nTrack Number:   \" & track number of current track\n                set info to info & \"\\nPopularity:     \" & popularity of current track\n                set info to info & \"\\nId:             \" & id of current track\n                set info to info & \"\\nSpotify URL:    \" & spotify url of current track\n                set info to info & \"\\nArtwork:        \" & artwork url of current track\n                set info to info & \"\\nPlayer:         \" & player state\n                set info to info & \"\\nVolume:         \" & sound volume\n                set info to info & \"\\nShuffle:        \" & shuffling\n                set info to info & \"\\nRepeating:      \" & repeating\n            end tell\n            return info");
    close $in_37 or croak 'Close failed: $OS_ERROR';
    my $result_37 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_37> };
    close $out_37 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_37, 0;
    $result_37
};
                        cecho("$info");
            last;        } elsif ($arg =~ /^share$/msx) {
                        my $uri;
            my @uri;
            my %uri;
            $uri = do {
    my ($in_38, $out_38);
    my $pid_38 = open3($in_38, $out_38, '>&STDERR', 'osascript', '-e', "tell application \"Spotify\" to spotify url of current track");
    close $in_38 or croak 'Close failed: $OS_ERROR';
    my $result_38 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_38> };
    close $out_38 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_38, 0;
    $result_38
};
                        my $remove;
            my @remove;
            my %remove;
            $remove = 'spotify:track:';
                        my $url;
            my @url;
            my %url;
            $url = ${uri} =~ s/^\$remove//r;
                        $url = "https://open.spotify.com/track/$url";
            if ("$2" eq "") {
                cecho("Spotify URL: $url");
                cecho("Spotify URI: $uri");
                print "To copy the URL or URI to your clipboard, use:\n";
                do {
    my $__echo_line = (do { my $_chomp_temp = do {
    my ($in_39, $out_39);
    my $pid_39 = open3($in_39, $out_39, '>&STDERR', 'spotify', 'share', 'url');
    close $in_39 or croak 'Close failed: $OS_ERROR';
    my $result_39 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_39> };
    close $out_39 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_39, 0;
    $result_39
}; chomp $_chomp_temp; $_chomp_temp; }) . " or";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                do {
    my $__echo_line = (do { my $_chomp_temp = do {
    my ($in_40, $out_40);
    my $pid_40 = open3($in_40, $out_40, '>&STDERR', 'spotify', 'share', 'uri');
    close $in_40 or croak 'Close failed: $OS_ERROR';
    my $result_40 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_40> };
    close $out_40 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_40, 0;
    $result_40
}; chomp $_chomp_temp; $_chomp_temp; }) . " respectively.";
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
                if ("$2" eq "url") {
                    cecho("Spotify URL: $url");
                    # Original bash: echo -n $url | pbcopy
{
                        my $output_41 = q{};
                        my $output_printed_41;
                        my $pipeline_success_41 = 1;
                        $output_41 .= $url . "\n";
$CHILD_ERROR = 0;

                                                my $cmd_43 = 'pbcopy';
                        my ($in_42, $out_42);
                        my $pid_42 = open3($in_42, $out_42, '>&STDERR', $cmd_43, );
                        print {$in_42} $output_41;
                        close $in_42 or croak 'Close failed: $OS_ERROR';
                        $output_41 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_42> };
                        close $out_42 or croak 'Close failed: $OS_ERROR';
                        waitpid $pid_42, 0;
                        if ($output_41 ne q{} && !defined $output_printed_41) {
                            print $output_41;
                            if (!($output_41 =~ m{\n\z}msx)) {
                                print "\n";
                            }
                        }
                        if ( !$pipeline_success_41 ) { $main_exit_code = 1; }
                        }
}
                else {
                    if ("$2" eq "uri") {
                        cecho("Spotify URI: $uri");
                        # Original bash: echo -n $uri | pbcopy
{
                            my $output_44 = q{};
                            my $output_printed_44;
                            my $pipeline_success_44 = 1;
                            $output_44 .= $uri . "\n";
$CHILD_ERROR = 0;

                                                        my $cmd_46 = 'pbcopy';
                            my ($in_45, $out_45);
                            my $pid_45 = open3($in_45, $out_45, '>&STDERR', $cmd_46, );
                            print {$in_45} $output_44;
                            close $in_45 or croak 'Close failed: $OS_ERROR';
                            $output_44 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_45> };
                            close $out_45 or croak 'Close failed: $OS_ERROR';
                            waitpid $pid_45, 0;
                            if ($output_44 ne q{} && !defined $output_printed_44) {
                                print $output_44;
                                if (!($output_44 =~ m{\n\z}msx)) {
                                    print "\n";
                                }
                            }
                            if ( !$pipeline_success_44 ) { $main_exit_code = 1; }
                            }
                    }
                }
            }
            last;        } elsif ($arg =~ /^pos$/msx) {
                        cecho("Adjusting Spotify play position.");
                        $main_exit_code = system('osascript', '-e', "tell application \"Spotify\" to set player position to $_[1]") >> 8;
            last;        } elsif ($arg =~ /^help$/msx) {
                        showHelp();
            last;        } elsif (1) {
                        showHelp();
            return q{1};        }
    }
    return;
}

exit $main_exit_code;
