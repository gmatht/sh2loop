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

my $LG;
my @LG;
my %LG;
my $SUPPORTED_LOCALES;
my @SUPPORTED_LOCALES;
my %SUPPORTED_LOCALES;
my $langpack;
my @langpack;
my %langpack;
my $DEFAULT_ENVIRONMENT;
my @DEFAULT_ENVIRONMENT;
my %DEFAULT_ENVIRONMENT;
my $STATE;
my @STATE;
my %STATE;
my $DEFAULT_LOCALES;
my @DEFAULT_LOCALES;
my %DEFAULT_LOCALES;

$__set_e = 1;
$LG = "/etc/locale.gen";
my $EE;
my @EE;
my %EE;
$EE = "/etc/locale.conf";
my $LC_ALL;
my @LC_ALL;
my %LC_ALL;
$LC_ALL = q{C};
my $LANG;
my @LANG;
my %LANG;
$LANG = q{C};
$main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;
$main_exit_code = system('db_version', '2.0') >> 8;
$main_exit_code = system('db_capb', 'backup', 'multiselect') >> 8;

sub convert_locale {
    my ($file) = @_;
    # Original bash: echo "$1" | sed -e "s/no_NO/nb_NO/g" -e 's/ks_IN/ks_IN@devanagari/g' -e 's/iw_IL/he_IL/g'
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
        $output_0 .= $1 . "\n";
if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
$CHILD_ERROR = 0;

                my @sed_lines_0 = split /\n/msx, $output_0;
        my @sed_result_0;
        foreach my $line (@sed_lines_0) {
        chomp $line;
        push @sed_result_0, $line;
        }
        $output_0 = join "\n", @sed_result_0;
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
my $PROVIDED_LOCALES;
my @PROVIDED_LOCALES;
my %PROVIDED_LOCALES;
$PROVIDED_LOCALES = "aa_DJ.UTF-8 UTF-8
aa_ER UTF-8
aa_ET UTF-8
af_ZA.UTF-8 UTF-8
agr_PE UTF-8
ak_GH UTF-8
am_ET UTF-8
an_ES.UTF-8 UTF-8
anp_IN UTF-8
ar_AE.UTF-8 UTF-8
ar_BH.UTF-8 UTF-8
ar_DZ.UTF-8 UTF-8
ar_EG.UTF-8 UTF-8
ar_IN UTF-8
ar_IQ.UTF-8 UTF-8
ar_JO.UTF-8 UTF-8
ar_KW.UTF-8 UTF-8
ar_LB.UTF-8 UTF-8
ar_LY.UTF-8 UTF-8
ar_MA.UTF-8 UTF-8
ar_OM.UTF-8 UTF-8
ar_QA.UTF-8 UTF-8
ar_SA.UTF-8 UTF-8
ar_SD.UTF-8 UTF-8
ar_SS UTF-8
ar_SY.UTF-8 UTF-8
ar_TN.UTF-8 UTF-8
ar_YE.UTF-8 UTF-8
ayc_PE UTF-8
az_AZ UTF-8
az_IR UTF-8
as_IN UTF-8
ast_ES.UTF-8 UTF-8
be_BY.UTF-8 UTF-8
be_BY@latin UTF-8
bem_ZM UTF-8
ber_DZ UTF-8
ber_MA UTF-8
bg_BG.UTF-8 UTF-8
bhb_IN.UTF-8 UTF-8
bho_IN UTF-8
bho_NP UTF-8
bi_VU UTF-8
bn_BD UTF-8
bn_IN UTF-8
bo_CN UTF-8
bo_IN UTF-8
br_FR.UTF-8 UTF-8
brx_IN UTF-8
bs_BA.UTF-8 UTF-8
byn_ER UTF-8
ca_AD.UTF-8 UTF-8
ca_ES.UTF-8 UTF-8
ca_ES@valencia UTF-8
ca_FR.UTF-8 UTF-8
ca_IT.UTF-8 UTF-8
ce_RU UTF-8
chr_US UTF-8
ckb_IQ UTF-8
cmn_TW UTF-8
crh_RU UTF-8
crh_UA UTF-8
cs_CZ.UTF-8 UTF-8
csb_PL UTF-8
cv_RU UTF-8
cy_GB.UTF-8 UTF-8
da_DK.UTF-8 UTF-8
de_AT.UTF-8 UTF-8
de_BE.UTF-8 UTF-8
de_CH.UTF-8 UTF-8
de_DE.UTF-8 UTF-8
de_IT.UTF-8 UTF-8
de_LI.UTF-8 UTF-8
de_LU.UTF-8 UTF-8
doi_IN UTF-8
dsb_DE UTF-8
dv_MV UTF-8
dz_BT UTF-8
el_GR.UTF-8 UTF-8
el_CY.UTF-8 UTF-8
en_AG UTF-8
en_AU.UTF-8 UTF-8
en_BW.UTF-8 UTF-8
en_CA.UTF-8 UTF-8
en_DK.UTF-8 UTF-8
en_GB.UTF-8 UTF-8
en_HK.UTF-8 UTF-8
en_IE.UTF-8 UTF-8
en_IL UTF-8
en_IN UTF-8
en_NG UTF-8
en_NZ.UTF-8 UTF-8
en_PH.UTF-8 UTF-8
en_SC.UTF-8 UTF-8
en_SG.UTF-8 UTF-8
en_US.UTF-8 UTF-8
en_ZA.UTF-8 UTF-8
en_ZM UTF-8
en_ZW.UTF-8 UTF-8
eo UTF-8
eo_US.UTF-8 UTF-8
es_AR.UTF-8 UTF-8
es_BO.UTF-8 UTF-8
es_CL.UTF-8 UTF-8
es_CO.UTF-8 UTF-8
es_CR.UTF-8 UTF-8
es_CU UTF-8
es_DO.UTF-8 UTF-8
es_EC.UTF-8 UTF-8
es_ES.UTF-8 UTF-8
es_GT.UTF-8 UTF-8
es_HN.UTF-8 UTF-8
es_MX.UTF-8 UTF-8
es_NI.UTF-8 UTF-8
es_PA.UTF-8 UTF-8
es_PE.UTF-8 UTF-8
es_PR.UTF-8 UTF-8
es_PY.UTF-8 UTF-8
es_SV.UTF-8 UTF-8
es_US.UTF-8 UTF-8
es_UY.UTF-8 UTF-8
es_VE.UTF-8 UTF-8
et_EE.UTF-8 UTF-8
eu_ES.UTF-8 UTF-8
eu_FR.UTF-8 UTF-8
fa_IR UTF-8
ff_SN UTF-8
fi_FI.UTF-8 UTF-8
fil_PH UTF-8
fo_FO.UTF-8 UTF-8
fr_BE.UTF-8 UTF-8
fr_CA.UTF-8 UTF-8
fr_CH.UTF-8 UTF-8
fr_FR.UTF-8 UTF-8
fr_LU.UTF-8 UTF-8
fur_IT UTF-8
fy_NL UTF-8
fy_DE UTF-8
ga_IE.UTF-8 UTF-8
gbm_IN UTF-8
gd_GB.UTF-8 UTF-8
gez_ER UTF-8
gez_ER@abegede UTF-8
gez_ET UTF-8
gez_ET@abegede UTF-8
gl_ES.UTF-8 UTF-8
gu_IN UTF-8
gv_GB.UTF-8 UTF-8
ha_NG UTF-8
hak_TW UTF-8
he_IL.UTF-8 UTF-8
hi_IN UTF-8
hif_FJ UTF-8
hne_IN UTF-8
hr_HR.UTF-8 UTF-8
hsb_DE.UTF-8 UTF-8
ht_HT UTF-8
hu_HU.UTF-8 UTF-8
hy_AM UTF-8
ia_FR UTF-8
id_ID.UTF-8 UTF-8
ig_NG UTF-8
ik_CA UTF-8
is_IS.UTF-8 UTF-8
it_CH.UTF-8 UTF-8
it_IT.UTF-8 UTF-8
iu_CA UTF-8
ja_JP.UTF-8 UTF-8
ka_GE.UTF-8 UTF-8
kab_DZ UTF-8
kk_KZ.UTF-8 UTF-8
kl_GL.UTF-8 UTF-8
km_KH UTF-8
kn_IN UTF-8
ko_KR.UTF-8 UTF-8
kok_IN UTF-8
ks_IN UTF-8
ks_IN@devanagari UTF-8
ku_TR.UTF-8 UTF-8
kv_RU UTF-8
kw_GB.UTF-8 UTF-8
ky_KG UTF-8
lb_LU UTF-8
lg_UG.UTF-8 UTF-8
li_BE UTF-8
li_NL UTF-8
lij_IT UTF-8
ln_CD UTF-8
lo_LA UTF-8
lt_LT.UTF-8 UTF-8
lv_LV.UTF-8 UTF-8
lzh_TW UTF-8
mag_IN UTF-8
mai_IN UTF-8
mai_NP UTF-8
mfe_MU UTF-8
mg_MG.UTF-8 UTF-8
mhr_RU UTF-8
mi_NZ.UTF-8 UTF-8
miq_NI UTF-8
mjw_IN UTF-8
mk_MK.UTF-8 UTF-8
ml_IN UTF-8
mn_MN UTF-8
mni_IN UTF-8
mnw_MM UTF-8
mr_IN UTF-8
ms_MY.UTF-8 UTF-8
mt_MT.UTF-8 UTF-8
my_MM UTF-8
nan_TW UTF-8
nan_TW@latin UTF-8
nb_NO.UTF-8 UTF-8
nds_DE UTF-8
nds_NL UTF-8
ne_NP UTF-8
nhn_MX UTF-8
niu_NU UTF-8
niu_NZ UTF-8
nl_AW UTF-8
nl_BE.UTF-8 UTF-8
nl_NL.UTF-8 UTF-8
nn_NO.UTF-8 UTF-8
nr_ZA UTF-8
nso_ZA UTF-8
oc_FR.UTF-8 UTF-8
om_ET UTF-8
om_KE.UTF-8 UTF-8
or_IN UTF-8
os_RU UTF-8
pa_IN UTF-8
pa_PK UTF-8
pap_AW UTF-8
pap_CW UTF-8
pl_PL.UTF-8 UTF-8
ps_AF UTF-8
pt_BR.UTF-8 UTF-8
pt_PT.UTF-8 UTF-8
quz_PE UTF-8
raj_IN UTF-8
rif_MA UTF-8
ro_RO.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
ru_UA.UTF-8 UTF-8
rw_RW UTF-8
sa_IN UTF-8
sah_RU UTF-8
sat_IN UTF-8
sc_IT UTF-8
sd_IN UTF-8
sd_IN@devanagari UTF-8
sd_PK UTF-8
se_NO UTF-8
sgs_LT UTF-8
shn_MM UTF-8
shs_CA UTF-8
si_LK UTF-8
sid_ET UTF-8
sk_SK.UTF-8 UTF-8
sl_SI.UTF-8 UTF-8
sm_WS UTF-8
so_DJ.UTF-8 UTF-8
so_ET UTF-8
so_KE.UTF-8 UTF-8
so_SO.UTF-8 UTF-8
sq_AL.UTF-8 UTF-8
sq_MK UTF-8
sr_ME UTF-8
sr_RS UTF-8
sr_RS@latin UTF-8
ss_ZA UTF-8
ssy_ER UTF-8
st_ZA.UTF-8 UTF-8
su_ID UTF-8
sv_FI.UTF-8 UTF-8
sv_SE.UTF-8 UTF-8
sw_KE UTF-8
sw_TZ UTF-8
syr UTF-8
szl_PL UTF-8
ta_IN UTF-8
ta_LK UTF-8
tcy_IN.UTF-8 UTF-8
te_IN UTF-8
tg_TJ.UTF-8 UTF-8
th_TH.UTF-8 UTF-8
the_NP UTF-8
ti_ER UTF-8
ti_ET UTF-8
tig_ER UTF-8
tk_TM UTF-8
tl_PH.UTF-8 UTF-8
tn_ZA UTF-8
to_TO UTF-8
tok UTF-8
tpi_PG UTF-8
tr_CY.UTF-8 UTF-8
tr_TR.UTF-8 UTF-8
ts_ZA UTF-8
tt_RU UTF-8
tt_RU@iqtelif UTF-8
ug_CN UTF-8
ug_CN@latin UTF-8
uk_UA.UTF-8 UTF-8
unm_US UTF-8
ur_IN UTF-8
ur_PK UTF-8
uz_UZ.UTF-8 UTF-8
uz_UZ@cyrillic UTF-8
ve_ZA UTF-8
vi_VN UTF-8
wa_BE.UTF-8 UTF-8
wae_CH UTF-8
wal_ET UTF-8
wo_SN UTF-8
xh_ZA.UTF-8 UTF-8
yi_US.UTF-8 UTF-8
yo_NG UTF-8
yue_HK UTF-8
yuw_PG UTF-8
zgh_MA UTF-8
zh_CN.UTF-8 UTF-8
zh_HK.UTF-8 UTF-8
zh_SG.UTF-8 UTF-8
zh_TW.UTF-8 UTF-8
zu_ZA.UTF-8 UTF-8
";
if ((-f '/usr/local/share/i18n/SUPPORTED')) {
    my $USER_LOCALES;
    my @USER_LOCALES;
    my %USER_LOCALES;
    $USER_LOCALES = (do { my $_chomp_temp = do { my @_qx_cmd = (q{sed -e '/^[a-zA-Z]/!d' -e 's/ *$//g' /usr/local/share/i18n/SUPPORTED}); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; });
}
if ((-e $LG)) {
    my $GEN_LOCALES;
    my @GEN_LOCALES;
    my %GEN_LOCALES;
    $GEN_LOCALES = (do { my $_chomp_temp = do { my @_qx_cmd = (q{sed -e '/^[a-zA-Z]/!d' -e 's/ *$//g' $LG}); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; });
    $GEN_LOCALES = (do { my $_chomp_temp = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'convert_locale', "$GEN_LOCALES");
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
}; chomp $_chomp_temp; $_chomp_temp; });
}
$SUPPORTED_LOCALES = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;
    print do {
        my $result = join('', map { sprintf "%s\n", $_ } ("$PROVIDED_LOCALES", "$USER_LOCALES", "$GEN_LOCALES"));
        $result;
    };
    if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }
    my $grep_result_2_1;
    my @grep_lines_2_1 = split /\n/msx, $output_2;
    my @grep_filtered_2_1 = grep { !/^$/msx } @grep_lines_2_1;
    $grep_result_2_1 = join "\n", @grep_filtered_2_1;
        if (!($grep_result_2_1 =~ m{\n\z}msx || $grep_result_2_1 eq q{})) {
            $grep_result_2_1 .= "\n";
        }
    $CHILD_ERROR = scalar @grep_filtered_2_1 > 0 ? 0 : 1;
    $output_2 = $grep_result_2_1;
    my @sort_lines_2_2 = split /\n/msx, $output_2;
    my @sort_sorted_2_2 = sort @sort_lines_2_2;
    $output_2 = join "\n", @sort_sorted_2_2;
        if ($output_2 ne q{} && !($output_2 =~ m{\n\z}msx)) {
            $output_2 .= "\n";
        }
    my $set1_3 = "\\n";
    my $set2_3 = q{,};
    my $input_3 = $output_2;
    # Expand character ranges for tr command
    my $expanded_set1_3 = $set1_3;
    my $expanded_set2_3 = $set2_3;
    # Handle a-z range in set1
    if ($expanded_set1_3 =~ /a-z/msx) {
        $expanded_set1_3 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
    }
    # Handle A-Z range in set1
    if ($expanded_set1_3 =~ /A-Z/msx) {
        $expanded_set1_3 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:upper:] POSIX class in set1
    if ($expanded_set1_3 =~ /\[:upper:\]/msx) {
        $expanded_set1_3 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:lower:] POSIX class in set1
    if ($expanded_set1_3 =~ /\[:lower:\]/msx) {
        $expanded_set1_3 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
    }
    # Handle a-z range in set2
    if ($expanded_set2_3 =~ /a-z/msx) {
        $expanded_set2_3 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
    }
    # Handle A-Z range in set2
    if ($expanded_set2_3 =~ /A-Z/msx) {
        $expanded_set2_3 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:upper:] POSIX class in set2
    if ($expanded_set2_3 =~ /\[:upper:\]/msx) {
        $expanded_set2_3 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:lower:] POSIX class in set2
    if ($expanded_set2_3 =~ /\[:lower:\]/msx) {
        $expanded_set2_3 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
    }
    my $tr_result_2_3 = q{};
    for my $char ( split //msx, $input_3 ) {
        my $pos_3 = index $expanded_set1_3, $char;
        if ( $pos_3 >= 0 && $pos_3 < length $expanded_set2_3 ) {
            $tr_result_2_3 .= substr $expanded_set2_3, $pos_3, 1;
        } else {
            $tr_result_2_3 .= $char;
        }
    }
        if (!($tr_result_2_3 =~ m{\n\z}msx || $tr_result_2_3 eq q{})) {
            $tr_result_2_3 .= "\n";
        }
        $output_2 = $tr_result_2_3;
    my @sed_lines_2 = split /\n/msx, $output_2;
    my @sed_result_2;
    foreach my $line (@sed_lines_2) {
    chomp $line;
    push @sed_result_2, $line;
    }
    $output_2 = join "\n", @sed_result_2;

    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_2 =~ s/\n+\z//msx;
    $output_2;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
$main_exit_code = system('db_subst', 'locales/locales_to_be_generated', 'locales', "$SUPPORTED_LOCALES") >> 8;
if ((-e '/etc/locale.gen')) {
if (((-l $LG) && "$(readlink $LG)" eq "/usr/share/i18n/SUPPORTED")) {
        my $SELECTED_LOCALES;
        my @SELECTED_LOCALES;
        my %SELECTED_LOCALES;
        $SELECTED_LOCALES = "All locales";
}
    else {
        $SELECTED_LOCALES = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_4 = q{};
            my $output_printed_4;
            my $pipeline_success_4 = 1;
            $output_4 .= $GEN_LOCALES . "\n";
            if ( !($output_4 =~ m{\n\z}msx) ) { $output_4 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_4 = 0; }
            my @sort_lines_4_1 = split /\n/msx, $output_4;
            my @sort_sorted_4_1 = sort @sort_lines_4_1;
            $output_4 = join "\n", @sort_sorted_4_1;
                        if ($output_4 ne q{} && !($output_4 =~ m{\n\z}msx)) {
                            $output_4 .= "\n";
                        }
            my $set1_5 = "\\n";
            my $set2_5 = q{,};
            my $input_5 = $output_4;
            # Expand character ranges for tr command
            my $expanded_set1_5 = $set1_5;
            my $expanded_set2_5 = $set2_5;
            # Handle a-z range in set1
            if ($expanded_set1_5 =~ /a-z/msx) {
                $expanded_set1_5 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle A-Z range in set1
            if ($expanded_set1_5 =~ /A-Z/msx) {
                $expanded_set1_5 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:upper:] POSIX class in set1
            if ($expanded_set1_5 =~ /\[:upper:\]/msx) {
                $expanded_set1_5 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:lower:] POSIX class in set1
            if ($expanded_set1_5 =~ /\[:lower:\]/msx) {
                $expanded_set1_5 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle a-z range in set2
            if ($expanded_set2_5 =~ /a-z/msx) {
                $expanded_set2_5 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
            }
            # Handle A-Z range in set2
            if ($expanded_set2_5 =~ /A-Z/msx) {
                $expanded_set2_5 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:upper:] POSIX class in set2
            if ($expanded_set2_5 =~ /\[:upper:\]/msx) {
                $expanded_set2_5 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
            }
            # Handle [:lower:] POSIX class in set2
            if ($expanded_set2_5 =~ /\[:lower:\]/msx) {
                $expanded_set2_5 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
            }
            my $tr_result_4_2 = q{};
            for my $char ( split //msx, $input_5 ) {
                my $pos_5 = index $expanded_set1_5, $char;
                if ( $pos_5 >= 0 && $pos_5 < length $expanded_set2_5 ) {
                    $tr_result_4_2 .= substr $expanded_set2_5, $pos_5, 1;
                } else {
                    $tr_result_4_2 .= $char;
                }
            }
                        if (!($tr_result_4_2 =~ m{\n\z}msx || $tr_result_4_2 eq q{})) {
                            $tr_result_4_2 .= "\n";
                        }
                        $output_4 = $tr_result_4_2;
            my @sed_lines_4 = split /\n/msx, $output_4;
            my @sed_result_4;
            foreach my $line (@sed_lines_4) {
            chomp $line;
            push @sed_result_4, $line;
            }
            $output_4 = join "\n", @sed_result_4;

            if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_4 =~ s/\n+\z//msx;
            $output_4;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
    }
    $main_exit_code = system('db_set', 'locales/locales_to_be_generated', "$SELECTED_LOCALES") >> 8;
}
$DEFAULT_ENVIRONMENT = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_6 = q{};
    my $output_printed_6;
    my $pipeline_success_6 = 1;
    $output_6 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/default/locale' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/default/locale' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/locale.conf' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/locale.conf' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
    my @lines = split /\n/msx, $output_6;
    my @result;
    foreach my $line (@lines) {
    chomp $line;
    if ($line =~ /^\s*$/msx) { next; }
    my @fields = split /\s+/msx, $line;
    if (!(/^LANG=/)) { next; }
    push @result, ($line . "\n");
    }
    push @result, (lang . "\n");
    $output_6 = join "", @result;
    if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_6 =~ s/\n+\z//msx;
    $output_6;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
$DEFAULT_ENVIRONMENT = (do { my $_chomp_temp = do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'convert_locale', "$DEFAULT_ENVIRONMENT");
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
}; chomp $_chomp_temp; $_chomp_temp; });
if (("$SUPPORTED_LOCALES" ne q{} && "$DEFAULT_ENVIRONMENT" ne q{})) {
if (!(    # Original bash: echo "$SUPPORTED_LOCALES" | grep -q -e "\b$DEFAULT_ENVIRONMENT\b" ;
{
        my $output_8 = q{};
        my $output_printed_8;
        my $pipeline_success_8 = 1;
        $output_8 .= $SUPPORTED_LOCALES . "\n";
if ( !($output_8 =~ m{\n\z}msx) ) { $output_8 .= "\n"; }
$CHILD_ERROR = 0;

                my $grep_result_8_1;
        my @grep_lines_8_1 = split /\n/msx, $output_8;
        my @grep_filtered_8_1 = grep { /\b$DEFAULT_ENVIRONMENT\b/msx } @grep_lines_8_1;
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
        })) {
        $main_exit_code = system('db_set', 'locales/default_environment_locale', "$DEFAULT_ENVIRONMENT") >> 8;
    }
}
$STATE = q{1};
while ( $STATE >= 0 ) {
if ("$STATE" =~ /^0$/msx) {
        exit 1;
    } elsif ("$STATE" =~ /^1$/msx) {
                        $main_exit_code = system('db_input', 'medium', 'locales/locales_to_be_generated') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
    } elsif ("$STATE" =~ /^2$/msx) {
                        $main_exit_code = system('db_get', 'locales/locales_to_be_generated') >> 8;
        if ($CHILD_ERROR != 0) {
                        my $RET;
            my @RET;
            my %RET;
            $RET = q{};
        }
        if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('expr', ", $RET,", q{:}, ".*, None,.*") >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $main_exit_code = system('db_set', 'locales/locales_to_be_generated', "") >> 8;
            $RET = q{};
}
        else {
            if (!(            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('expr', ", $RET,", q{:}, ".*, All locales,.*") >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            })) {
                $main_exit_code = system('db_set', 'locales/locales_to_be_generated', "All locales") >> 8;
                $RET = $SUPPORTED_LOCALES;
            }
        }
                $DEFAULT_LOCALES = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_10 = q{};
            my $output_printed_10;
            my $pipeline_success_10 = 1;
            $output_10 .= $RET . "\n";
            if ( !($output_10 =~ m{\n\z}msx) ) { $output_10 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_10 = 0; }
            my @sed_lines_10 = split /\n/msx, $output_10;
            my @sed_result_10;
            foreach my $line (@sed_lines_10) {
            chomp $line;
            push @sed_result_10, $line;
            }
            $output_10 = join "\n", @sed_result_10;

            if ( !$pipeline_success_10 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_10 =~ s/\n+\z//msx;
            $output_10;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
                for my $langpack ('/var/lib/locales/supported.d/*') {
if ((-f $langpack)) {
open STDIN, '<', $langpack or croak "Cannot open file: $OS_ERROR\n";
                my $locale;
                my $charset;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $locale = $_fields[0] // q{};
    $charset = $_fields[1] // q{};
                    $DEFAULT_LOCALES = "$DEFAULT_LOCALES, $locale";
                }
            }
        }
        if ("$DEFAULT_LOCALES" ne q{}) {
            $main_exit_code = system('db_subst', 'locales/default_environment_locale', 'locales', $DEFAULT_LOCALES) >> 8;
                        $main_exit_code = system('db_input', 'medium', 'locales/default_environment_locale') >> 8;
            if ($CHILD_ERROR != 0) {
                1;
            }
        }
    } elsif (1) {
        last;    }
if (!(    $main_exit_code = system('bash', 'db_go') >> 8)) {
        if (defined $STATE) {
            $STATE = eval { int($STATE + 1) } // "";
        }
}
    else {
        if (defined $STATE) {
            $STATE = eval { int($STATE - 1) } // "";
        }
    }
}

exit $main_exit_code;
