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
my $action;
my @action;
my %action;
$action = "$_[0]";
if ((-f '/etc/ca-certificates.conf')) {
    my $CERTSCONF;
    my @CERTSCONF;
    my %CERTSCONF;
    $CERTSCONF = '/etc/ca-certificates.conf';
}
else {
    $CERTSCONF = '/dev/null';
}
my $CERTS_DISABLED;
my @CERTS_DISABLED;
my %CERTS_DISABLED;
$CERTS_DISABLED = do { my @_qx_cmd = ('sed -ne "s/^!\\\\(.*\\\\)/\\\\1/p" $CERTSCONF'); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
my $CERTS_TRUST;
my @CERTS_TRUST;
my %CERTS_TRUST;
$CERTS_TRUST = do { my @_qx_cmd = ('sed -e /^#/d -e /^!/d $CERTSCONF'); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
my $CERTS_AVAILABLE;
my @CERTS_AVAILABLE;
my %CERTS_AVAILABLE;
$CERTS_AVAILABLE = "";
my $CERTS_ENABLED;
my @CERTS_ENABLED;
my %CERTS_ENABLED;
$CERTS_ENABLED = "";
my $CERTS_LIST;
my @CERTS_LIST;
my %CERTS_LIST;
$CERTS_LIST = "mozilla/ACCVRAIZ1.crt, mozilla/AC_RAIZ_FNMT-RCM.crt, mozilla/AC_RAIZ_FNMT-RCM_SERVIDORES_SEGUROS.crt, mozilla/ANF_Secure_Server_Root_CA.crt, mozilla/Actalis_Authentication_Root_CA.crt, mozilla/AffirmTrust_Commercial.crt, mozilla/AffirmTrust_Networking.crt, mozilla/AffirmTrust_Premium.crt, mozilla/AffirmTrust_Premium_ECC.crt, mozilla/Amazon_Root_CA_1.crt, mozilla/Amazon_Root_CA_2.crt, mozilla/Amazon_Root_CA_3.crt, mozilla/Amazon_Root_CA_4.crt, mozilla/Atos_TrustedRoot_2011.crt, mozilla/Atos_TrustedRoot_Root_CA_ECC_TLS_2021.crt, mozilla/Atos_TrustedRoot_Root_CA_RSA_TLS_2021.crt, mozilla/Autoridad_de_Certificacion_Firmaprofesional_CIF_A62634068.crt, mozilla/BJCA_Global_Root_CA1.crt, mozilla/BJCA_Global_Root_CA2.crt, mozilla/Baltimore_CyberTrust_Root.crt, mozilla/Buypass_Class_2_Root_CA.crt, mozilla/Buypass_Class_3_Root_CA.crt, mozilla/CA_Disig_Root_R2.crt, mozilla/CFCA_EV_ROOT.crt, mozilla/COMODO_Certification_Authority.crt, mozilla/COMODO_ECC_Certification_Authority.crt, mozilla/COMODO_RSA_Certification_Authority.crt, mozilla/Certainly_Root_E1.crt, mozilla/Certainly_Root_R1.crt, mozilla/Certigna.crt, mozilla/Certigna_Root_CA.crt, mozilla/Certum_EC-384_CA.crt, mozilla/Certum_Trusted_Network_CA.crt, mozilla/Certum_Trusted_Network_CA_2.crt, mozilla/Certum_Trusted_Root_CA.crt, mozilla/CommScope_Public_Trust_ECC_Root-01.crt, mozilla/CommScope_Public_Trust_ECC_Root-02.crt, mozilla/CommScope_Public_Trust_RSA_Root-01.crt, mozilla/CommScope_Public_Trust_RSA_Root-02.crt, mozilla/Comodo_AAA_Services_root.crt, mozilla/D-TRUST_BR_Root_CA_1_2020.crt, mozilla/D-TRUST_EV_Root_CA_1_2020.crt, mozilla/D-TRUST_Root_Class_3_CA_2_2009.crt, mozilla/D-TRUST_Root_Class_3_CA_2_EV_2009.crt, mozilla/DigiCert_Assured_ID_Root_CA.crt, mozilla/DigiCert_Assured_ID_Root_G2.crt, mozilla/DigiCert_Assured_ID_Root_G3.crt, mozilla/DigiCert_Global_Root_CA.crt, mozilla/DigiCert_Global_Root_G2.crt, mozilla/DigiCert_Global_Root_G3.crt, mozilla/DigiCert_High_Assurance_EV_Root_CA.crt, mozilla/DigiCert_TLS_ECC_P384_Root_G5.crt, mozilla/DigiCert_TLS_RSA4096_Root_G5.crt, mozilla/DigiCert_Trusted_Root_G4.crt, mozilla/Entrust.net_Premium_2048_Secure_Server_CA.crt, mozilla/Entrust_Root_Certification_Authority.crt, mozilla/Entrust_Root_Certification_Authority_-_EC1.crt, mozilla/Entrust_Root_Certification_Authority_-_G2.crt, mozilla/Entrust_Root_Certification_Authority_-_G4.crt, mozilla/GDCA_TrustAUTH_R5_ROOT.crt, mozilla/GLOBALTRUST_2020.crt, mozilla/GTS_Root_R1.crt, mozilla/GTS_Root_R2.crt, mozilla/GTS_Root_R3.crt, mozilla/GTS_Root_R4.crt, mozilla/GlobalSign_ECC_Root_CA_-_R4.crt, mozilla/GlobalSign_ECC_Root_CA_-_R5.crt, mozilla/GlobalSign_Root_CA.crt, mozilla/GlobalSign_Root_CA_-_R3.crt, mozilla/GlobalSign_Root_CA_-_R6.crt, mozilla/GlobalSign_Root_E46.crt, mozilla/GlobalSign_Root_R46.crt, mozilla/Go_Daddy_Class_2_CA.crt, mozilla/Go_Daddy_Root_Certificate_Authority_-_G2.crt, mozilla/HARICA_TLS_ECC_Root_CA_2021.crt, mozilla/HARICA_TLS_RSA_Root_CA_2021.crt, mozilla/Hellenic_Academic_and_Research_Institutions_ECC_RootCA_2015.crt, mozilla/Hellenic_Academic_and_Research_Institutions_RootCA_2015.crt, mozilla/HiPKI_Root_CA_-_G1.crt, mozilla/Hongkong_Post_Root_CA_3.crt, mozilla/ISRG_Root_X1.crt, mozilla/ISRG_Root_X2.crt, mozilla/IdenTrust_Commercial_Root_CA_1.crt, mozilla/IdenTrust_Public_Sector_Root_CA_1.crt, mozilla/Izenpe.com.crt, mozilla/Microsec_e-Szigno_Root_CA_2009.crt, mozilla/Microsoft_ECC_Root_Certificate_Authority_2017.crt, mozilla/Microsoft_RSA_Root_Certificate_Authority_2017.crt, mozilla/NAVER_Global_Root_Certification_Authority.crt, mozilla/NetLock_Arany_=Class_Gold=_Főtanúsítvány.crt, mozilla/OISTE_WISeKey_Global_Root_GB_CA.crt, mozilla/OISTE_WISeKey_Global_Root_GC_CA.crt, mozilla/QuoVadis_Root_CA_1_G3.crt, mozilla/QuoVadis_Root_CA_2.crt, mozilla/QuoVadis_Root_CA_2_G3.crt, mozilla/QuoVadis_Root_CA_3.crt, mozilla/QuoVadis_Root_CA_3_G3.crt, mozilla/SSL.com_EV_Root_Certification_Authority_ECC.crt, mozilla/SSL.com_EV_Root_Certification_Authority_RSA_R2.crt, mozilla/SSL.com_Root_Certification_Authority_ECC.crt, mozilla/SSL.com_Root_Certification_Authority_RSA.crt, mozilla/SSL.com_TLS_ECC_Root_CA_2022.crt, mozilla/SSL.com_TLS_RSA_Root_CA_2022.crt, mozilla/SZAFIR_ROOT_CA2.crt, mozilla/Sectigo_Public_Server_Authentication_Root_E46.crt, mozilla/Sectigo_Public_Server_Authentication_Root_R46.crt, mozilla/SecureSign_RootCA11.crt, mozilla/SecureTrust_CA.crt, mozilla/Secure_Global_CA.crt, mozilla/Security_Communication_ECC_RootCA1.crt, mozilla/Security_Communication_RootCA2.crt, mozilla/Security_Communication_RootCA3.crt, mozilla/Security_Communication_Root_CA.crt, mozilla/Starfield_Class_2_CA.crt, mozilla/Starfield_Root_Certificate_Authority_-_G2.crt, mozilla/Starfield_Services_Root_Certificate_Authority_-_G2.crt, mozilla/SwissSign_Gold_CA_-_G2.crt, mozilla/SwissSign_Silver_CA_-_G2.crt, mozilla/T-TeleSec_GlobalRoot_Class_2.crt, mozilla/T-TeleSec_GlobalRoot_Class_3.crt, mozilla/TUBITAK_Kamu_SM_SSL_Kok_Sertifikasi_-_Surum_1.crt, mozilla/TWCA_Global_Root_CA.crt, mozilla/TWCA_Root_Certification_Authority.crt, mozilla/TeliaSonera_Root_CA_v1.crt, mozilla/Telia_Root_CA_v2.crt, mozilla/TrustAsia_Global_Root_CA_G3.crt, mozilla/TrustAsia_Global_Root_CA_G4.crt, mozilla/Trustwave_Global_Certification_Authority.crt, mozilla/Trustwave_Global_ECC_P256_Certification_Authority.crt, mozilla/Trustwave_Global_ECC_P384_Certification_Authority.crt, mozilla/TunTrust_Root_CA.crt, mozilla/UCA_Extended_Validation_Root.crt, mozilla/UCA_Global_G2_Root.crt, mozilla/USERTrust_ECC_Certification_Authority.crt, mozilla/USERTrust_RSA_Certification_Authority.crt, mozilla/XRamp_Global_CA_Root.crt, mozilla/certSIGN_ROOT_CA.crt, mozilla/certSIGN_Root_CA_G2.crt, mozilla/e-Szigno_Root_CA_2017.crt, mozilla/ePKI_Root_Certification_Authority.crt, mozilla/emSign_ECC_Root_CA_-_C3.crt, mozilla/emSign_ECC_Root_CA_-_G3.crt, mozilla/emSign_Root_CA_-_C1.crt, mozilla/emSign_Root_CA_-_G1.crt, mozilla/vTrus_ECC_Root_CA.crt, mozilla/vTrus_Root_CA.crt";
my $CERTS_NEW;
my @CERTS_NEW;
my %CERTS_NEW;
$CERTS_NEW = "";

sub members {
    my ($file) = @_;
    # Original bash: echo "$1" | tr ',' '\n' | sed -e 's/^[[:space:]]*//' | while read ca
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
        $output_0 .= $1 . "\n";
if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
$CHILD_ERROR = 0;

                my $set1_1 = q{,};
        my $set2_1 = "\\n";
        my $input_1 = $output_0;
        # Expand character ranges for tr command
        my $expanded_set1_1 = $set1_1;
        my $expanded_set2_1 = $set2_1;
        # Handle a-z range in set1
        if ($expanded_set1_1 =~ /a-z/msx) {
        $expanded_set1_1 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_1 =~ /A-Z/msx) {
        $expanded_set1_1 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_1 =~ /\[:upper:\]/msx) {
        $expanded_set1_1 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_1 =~ /\[:lower:\]/msx) {
        $expanded_set1_1 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_1 =~ /a-z/msx) {
        $expanded_set2_1 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_1 =~ /A-Z/msx) {
        $expanded_set2_1 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_1 =~ /\[:upper:\]/msx) {
        $expanded_set2_1 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_1 =~ /\[:lower:\]/msx) {
        $expanded_set2_1 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_0_1 = q{};
        for my $char ( split //msx, $input_1 ) {
        my $pos_1 = index $expanded_set1_1, $char;
        if ( $pos_1 >= 0 && $pos_1 < length $expanded_set2_1 ) {
        $tr_result_0_1 .= substr $expanded_set2_1, $pos_1, 1;
        } else {
        $tr_result_0_1 .= $char;
        }
        }
        if (!($tr_result_0_1 =~ m{\n\z}msx || $tr_result_0_1 eq q{})) {
        $tr_result_0_1 .= "\n";
        }
        $output_0 = $tr_result_0_1;
        $output_0 = $tr_result_0_1;

                my @sed_lines_0 = split /\n/msx, $output_0;
        my @sed_result_0;
        foreach my $line (@sed_lines_0) {
        chomp $line;
        push @sed_result_0, $line;
        }
        $output_0 = join "\n", @sed_result_0;

                my @lines = split /\n/msx, $output_0;
        my $result_0_3 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        if (!(        # Original bash: echo "$2" | grep -q "$ca" > /dev/null 2>&1;
        {
        my $pipeline_success_0 = 1;
        $output_0 .= $2 . "\n";
        if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
        $CHILD_ERROR = 0;
        my $grep_result_0_1;
        my @grep_lines_0_1 = split /\n/msx, $output_0;
        my @grep_filtered_0_1 = grep { /$ENV{ca}/msx } @grep_lines_0_1;
        $grep_result_0_1 = join "\n", @grep_filtered_0_1;
        if (!($grep_result_0_1 =~ m{\n\z}msx || $grep_result_0_1 eq q{})) {
        $grep_result_0_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_0_1 > 0 ? 0 : 1;
        $grep_result_0_1 = q{};
        $output_0 = q{};
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        })) {
        $output .= 'match' . "\n";
        $CHILD_ERROR = 0;
        }
        }
        $output_0 = $result_0_3;

                my $grep_result_0_4;
        my @grep_lines_0_4 = split /\n/msx, $output_0;
        my @grep_filtered_0_4 = grep { /match/msx } @grep_lines_0_4;
        $grep_result_0_4 = join "\n", @grep_filtered_0_4;
        if (!($grep_result_0_4 =~ m{\n\z}msx || $grep_result_0_4 eq q{})) {
        $grep_result_0_4 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_0_4 > 0 ? 0 : 1;
        $grep_result_0_4 = q{};
        $output_0 = q{};
        if ((scalar @grep_filtered_0_4) == 0) {
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
$main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;
if ($CHILD_ERROR != 0) {
    exit $main_exit_code;
}
$main_exit_code = system('db_version', '2.0') >> 8;
$main_exit_code = system('db_capb', 'multiselect') >> 8;
$main_exit_code = system('db_settitle', 'ca-certificates/title') >> 8;
$main_exit_code = system('db_input', 'medium', 'ca-certificates/trust_new_crts') >> 8;
if ($CHILD_ERROR != 0) {
    1;
}
$main_exit_code = system('bash', 'db_go') >> 8;
my $trust_new;
my @trust_new;
my %trust_new;
$trust_new = "yes";
if (!($main_exit_code = system('db_get', 'ca-certificates/trust_new_crts') >> 8)) {
    $trust_new = "$ENV{RET}";
}
my $seen;
my @seen;
my %seen;
$seen = 'false';
if (!($main_exit_code = system('db_fget', 'ca-certificates/enable_crts', 'seen') >> 8)) {
    $seen = "$ENV{RET}";
}
if ((!($main_exit_code = system('test', "$action", q{=}, "reconfigure") >> 8) || !($main_exit_code = system('test', "$ENV{DEBCONF_RECONFIGURE}", q{=}, "1") >> 8))) {
    $seen = 'false';
    $trust_new = 'no';
}
if ((-d '/usr/share/ca-certificates')) {
    chdir('/usr/share/ca-certificates');
    $CHILD_ERROR = 0;
    my $crts;
    my @crts;
    my %crts;
    $crts = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_3 = q{};
        my $output_printed_3;
        my $pipeline_success_3 = 1;
        $output_3 = q{};
        my @_pcmd_5 = ('sh', '-c', q{find . -type f -name '*.crt' -p rint | sed -e "s/^\\.\\///"});
        my ($in_4, $out_4);
        my $pid_4 = open3($in_4, $out_4, '>&STDERR', @_pcmd_5);
        close $in_4 or croak 'Close failed: $OS_ERROR';
        $output_3 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
        close $out_4 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_4, 0;
        my @_pcmd_7 = ('sh', '-c', q{echo "$CERTS_LIST" | tr , "\\n" | sed -e 's/^[[:space:]]*//'});
        my ($in_6, $out_6);
        my $pid_6 = open3($in_6, $out_6, '>&STDERR', @_pcmd_7);
        close $in_6 or croak 'Close failed: $OS_ERROR';
        $output_3 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
        close $out_6 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_6, 0;
        my @sort_lines_3_1 = split /\n/msx, $output_3;
        my @sort_sorted_3_1 = sort @sort_lines_3_1;
        my $output_3_1 = join "\n", @sort_sorted_3_1;
        if ($output_3_1 ne q{} && !($output_3_1 =~ m{\n\z}msx)) {
        $output_3_1 .= "\n";
        }
        $output_3 = $output_3_1;
        $output_3 = $output_3_1;
        my @uniq_lines_3_2 = split /\n/msx, $output_3;
        @uniq_lines_3_2 = grep { $_ ne q{} } @uniq_lines_3_2; # Filter out empty lines
        my %uniq_seen_3_2;
        my @uniq_result_3_2;
        foreach my $line (@uniq_lines_3_2) {
        if (!$uniq_seen_3_2{$line}++) { push @uniq_result_3_2, $line; }
        }
        my $output_3_2 = join "\n", @uniq_result_3_2;
        if ($output_3_2 ne q{} && !($output_3_2 =~ m{\n\z}msx)) {
        $output_3_2 .= "\n";
        }
        $output_3 = $output_3_2;
        if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_3 =~ s/\n+\z//msx;
        $output_3;
}; $_pipeline_result; };
    my $crt;
    for my $crt ($crts) {
if (StringInterpolation(StringInterpolation { parts: [Variable("CERTS_AVAILABLE")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("")] }, None)) {
            $CERTS_AVAILABLE = "$crt";
}
        else {
            $CERTS_AVAILABLE = "$CERTS_AVAILABLE, $crt";
        }
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            do {
                local %ENV = %ENV;
                my $trust_new = $trust_new;
                my $crt = $crt;
                my $action = $action;
                my $seen = $seen;
                my $crts = $crts;
                my $CERTS_AVAILABLE = $CERTS_AVAILABLE;
                my $CERTS_DISABLED = $CERTS_DISABLED;
                my $CERTS_ENABLED = $CERTS_ENABLED;
                my $CERTS_LIST = $CERTS_LIST;
                my $CERTSCONF = $CERTSCONF;
                my $CERTS_TRUST = $CERTS_TRUST;
                my $CERTS_NEW = $CERTS_NEW;
                # Original bash: echo "$CERTS_DISABLED" | grep -F -q -x "$crt")
{
                    my $output_8 = q{};
                    my $output_printed_8;
                    my $pipeline_success_8 = 1;
                    $output_8 .= $CERTS_DISABLED . "\n";
if ( !($output_8 =~ m{\n\z}msx) ) { $output_8 .= "\n"; }
$CHILD_ERROR = 0;

                                        my $grep_result_8_1;
                    my @grep_lines_8_1 = split /\n/msx, $output_8;
                    my @grep_filtered_8_1 = grep { /$crt/msx } @grep_lines_8_1;
                    $grep_result_8_1 = join "\n", @grep_filtered_8_1;
                    if (!($grep_result_8_1 =~ m{\n\z}msx || $grep_result_8_1 eq q{})) {
                    $grep_result_8_1 .= "\n";
                    }
                    $CHILD_ERROR = scalar @grep_filtered_8_1 > 0 ? 0 : 1;
                    $grep_result_8_1 = q{};
                    $output_8 = q{};
                    if ((scalar @grep_filtered_8_1) == 0) {
                        $pipeline_success_8 = 0;
                    }
                    if ($output_8 ne q{} && !defined $output_printed_8) {
                        print $output_8;
                        if (!($output_8 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
                    }
                q{};
            };
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
            if (!(            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                do {
                    local %ENV = %ENV;
                    my $trust_new = $trust_new;
                    my $crt = $crt;
                    my $action = $action;
                    my $seen = $seen;
                    my $crts = $crts;
                    my $CERTS_AVAILABLE = $CERTS_AVAILABLE;
                    my $CERTS_DISABLED = $CERTS_DISABLED;
                    my $CERTS_ENABLED = $CERTS_ENABLED;
                    my $CERTS_LIST = $CERTS_LIST;
                    my $CERTSCONF = $CERTSCONF;
                    my $CERTS_TRUST = $CERTS_TRUST;
                    my $CERTS_NEW = $CERTS_NEW;
                    # Original bash: echo "$CERTS_TRUST" | grep -F -q -x "$crt")
{
                        my $output_9 = q{};
                        my $output_printed_9;
                        my $pipeline_success_9 = 1;
                        $output_9 .= $CERTS_TRUST . "\n";
if ( !($output_9 =~ m{\n\z}msx) ) { $output_9 .= "\n"; }
$CHILD_ERROR = 0;

                                                my $grep_result_9_1;
                        my @grep_lines_9_1 = split /\n/msx, $output_9;
                        my @grep_filtered_9_1 = grep { /$crt/msx } @grep_lines_9_1;
                        $grep_result_9_1 = join "\n", @grep_filtered_9_1;
                        if (!($grep_result_9_1 =~ m{\n\z}msx || $grep_result_9_1 eq q{})) {
                        $grep_result_9_1 .= "\n";
                        }
                        $CHILD_ERROR = scalar @grep_filtered_9_1 > 0 ? 0 : 1;
                        $grep_result_9_1 = q{};
                        $output_9 = q{};
                        if ((scalar @grep_filtered_9_1) == 0) {
                            $pipeline_success_9 = 0;
                        }
                        if ($output_9 ne q{} && !defined $output_printed_9) {
                            print $output_9;
                            if (!($output_9 =~ m{\n\z}msx)) {
                                print "\n";
                            }
                        }
                        if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
                        }
                    q{};
                };
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            })) {
if (StringInterpolation(StringInterpolation { parts: [Variable("CERTS_ENABLED")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("")] }, None)) {
                    $CERTS_ENABLED = "$crt";
}
                else {
                    $CERTS_ENABLED = "$CERTS_ENABLED, $crt";
                }
}
            else {
if (StringInterpolation(StringInterpolation { parts: [Variable("trust_new")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("yes")] }, None)) {
if (StringInterpolation(StringInterpolation { parts: [Variable("CERTS_ENABLED")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("")] }, None)) {
                        $CERTS_ENABLED = "$crt";
}
                    else {
                        $CERTS_ENABLED = "$CERTS_ENABLED, $crt";
                    }
}
                else {
                    if (StringInterpolation(StringInterpolation { parts: [Variable("trust_new")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("ask")] }, None)) {
if (StringInterpolation(StringInterpolation { parts: [Variable("CERTS_NEW")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("")] }, None)) {
                            $CERTS_NEW = "$crt";
}
                        else {
                            $CERTS_NEW = "$CERTS_NEW, $crt";
                        }
}
                    else {
                        $main_exit_code = system('bash', ':') >> 8;
                    }
                }
            }
        }
    }
}
else {
    $CERTS_AVAILABLE = "$CERTS_LIST";
    $CERTS_ENABLED = "$CERTS_AVAILABLE";
    $trust_new = "yes";
    $CERTS_NEW = "";
}
my $enable_crts;
my @enable_crts;
my %enable_crts;
$enable_crts = "";
if (!($main_exit_code = system('db_get', 'ca-certificates/enable_crts') >> 8)) {
    $enable_crts = "$ENV{RET}";
}
my $new_seen;
my @new_seen;
my %new_seen;
$new_seen = 'false';
if (!($main_exit_code = system('db_fget', 'ca-certificates/new_crts', 'seen') >> 8)) {
    $new_seen = "$ENV{RET}";
}
if (!(members("$CERTS_NEW", "$enable_crts"))) {
    $new_seen = 'true';
}
$main_exit_code = system('db_subst', 'ca-certificates/new_crts', 'new_crts', "$CERTS_NEW") >> 8;
if ((!($main_exit_code = system('test', "$trust_new", q{=}, "ask") >> 8) && !($main_exit_code = system('test', "$new_seen", q{=}, "true") >> 8))) {
    $CERTS_ENABLED = "$enable_crts";
}
if (((!($main_exit_code = system('test', "$trust_new", q{=}, "ask") >> 8) && !($main_exit_code = system('test', "$CERTS_NEW", q{!}, q{=}, "") >> 8)) && !($main_exit_code = system('test', "$new_seen", q{=}, "false") >> 8))) {
    $main_exit_code = system('db_fset', 'ca-certificates/new_crts', 'seen', 'false') >> 8;
        $main_exit_code = system('db_input', 'critical', 'ca-certificates/new_crts') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
    $main_exit_code = system('bash', 'db_go') >> 8;
if (!(    $main_exit_code = system('db_get', 'ca-certificates/new_crts') >> 8)) {
if (StringInterpolation(StringInterpolation { parts: [Variable("CERTS_ENABLED")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("")] }, None)) {
            $CERTS_ENABLED = "$ENV{RET}";
}
        else {
            $CERTS_ENABLED = "$CERTS_ENABLED, $ENV{RET}";
        }
    }
    $seen = 'true';
}
$main_exit_code = system('db_fset', 'ca-certificates/new_crts', 'seen', 'true') >> 8;
$main_exit_code = system('db_set', 'ca-certificates/enable_crts', "$CERTS_ENABLED") >> 8;
$main_exit_code = system('db_subst', 'ca-certificates/enable_crts', 'enable_crts', "$CERTS_AVAILABLE") >> 8;
if ((!StringInterpolation(StringInterpolation { parts: [Variable("seen")] }, None) eq true)) {
    $main_exit_code = system('db_fset', 'ca-certificates/enable_crts', 'seen', 'false') >> 8;
}
$main_exit_code = system('db_input', 'low', 'ca-certificates/enable_crts') >> 8;
if ($CHILD_ERROR != 0) {
    1;
}
$main_exit_code = system('bash', 'db_go') >> 8;
exit 0;

exit $main_exit_code;
