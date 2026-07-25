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

$main_exit_code = system('test', '-n', "$ENV{SMARTD_ADDRESS}") >> 8;
if ($CHILD_ERROR != 0) {
    exit 0;
}
my $mailer;
for my $mailer (do { my @_qx_cmd = ("command -v mail 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }, do { my @_qx_cmd = ("command -v mailx 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }, '/usr/bin/mail', '/usr/bin/mailx') {
        $main_exit_code = system('test', '-f', "$mailer") >> 8;
    if ($CHILD_ERROR != 0) {
        next;    }
        $main_exit_code = system('test', '-x', "$mailer") >> 8;
    if ($CHILD_ERROR != 0) {
        next;    }
my $temp_content = '${SMARTD_FULLMESSAGE-[SMARTD_FULLMESSAGE]}
';
use File::Path qw(make_path);
if (!-d q{/tmp}) { make_path(q{/tmp}); }
open my $fh_1, '>', q{/tmp} . '/heredoc_temp' or croak "Cannot create temp file: $OS_ERROR\n";
print $fh_1 $temp_content;
close $fh_1 or croak "Close failed: $OS_ERROR\n";
open STDIN, '<', q{/tmp} . '/heredoc_temp' or croak "Cannot open temp file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
}
my $sendmail;
for my $sendmail ('/usr/sbin/sendmail', '/usr/lib/sendmail') {
        $main_exit_code = system('test', '-f', "$sendmail") >> 8;
    if ($CHILD_ERROR != 0) {
        next;    }
        $main_exit_code = system('test', '-x', "$sendmail") >> 8;
    if ($CHILD_ERROR != 0) {
        next;    }
my $temp_content = 'Subject: ${SMARTD_SUBJECT-[SMARTD_SUBJECT]}
To: $(echo $SMARTD_ADDRESS | sed \'s/ /, /g\')

${SMARTD_FULLMESSAGE-[SMARTD_FULLMESSAGE]}
';
use File::Path qw(make_path);
if (!-d q{/tmp}) { make_path(q{/tmp}); }
open my $fh_2, '>', q{/tmp} . '/heredoc_temp' or croak "Cannot create temp file: $OS_ERROR\n";
print $fh_2 $temp_content;
close $fh_2 or croak "Close failed: $OS_ERROR\n";
open STDIN, '<', q{/tmp} . '/heredoc_temp' or croak "Cannot open temp file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
}
do {
    my $__echo_line = "$PROGRAM_NAME: found none of 'mail', 'mailx' or 'sendmail'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
exit 1;

exit $main_exit_code;
