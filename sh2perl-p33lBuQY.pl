#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

my $main_exit_code = 0;
my $output         = q{};
our $CHILD_ERROR;

my $old_state;
my $XKBOPTIONS;
my $lalt_allocated;
my $LC_CTYPE;
my $RET;
my $detected_keyboard;
my $lwin_allocated;
my $compose;
my $is_not_debian_installer;
my $unsupported_layout;
my $STATE;
my $caps_allocated;
my $kbdnames;
my $rctrl_allocated;
my $XKBVARIANT;
my $ralt_allocated;
my $XKBLAYOUT;
my $unsupported_options;
my $altgr;
my $menu_allocated;
my $rwin_allocated;
my $OVERRIDE_USE_DEBCONF_LOCALE;
my $XKBMODEL;
my $LC_MESSAGES;
my $CONFIGFILE;
my $switch;
my $toggle;
my $is_debian_installer;

$__set_e = 1;
$main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;
$main_exit_code = system('db_capb', 'backup') >> 8;
$CONFIGFILE = '/etc/default/keyboard';
my $OLDCONFIGFILE = '/etc/default/console-setup';
my $debconf_toggle = q{};
my $debconf_switch = q{};
my $debconf_altgr = q{};
my $debconf_compose = q{};
my $debconf_layout = q{};
my $debconf_variant = q{};
$XKBMODEL = q{};
$XKBLAYOUT = q{};
$XKBVARIANT = q{};
$XKBOPTIONS = q{};
my $CAPB = "$RET";
my $detect_keyboard = 'false';
if ($CAPB =~ /^.*plugin-detect-keyboard.*$/msx) {
        $detect_keyboard = q{:};
}
if ((-f '/usr/share/console-setup/keyboard-configuration.config')) {
    $is_debian_installer = 'yes';
    $is_not_debian_installer = q{};
}
else {
    $is_debian_installer = q{};
    $is_not_debian_installer = 'yes';
}

sub read_config {
    my ($file) = @_;
    if (!((-r $_[0]))) {
        return q{0};    }
        $main_exit_code = system('.', $_[0]) >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
;
    my $var;
    for my $var ('XKBOPTIONS') {
if (        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
my $grep_result_1;
my @grep_lines_1 = ();
my @grep_filtered_1 = grep { /^\ *"\ .\ ${var}\ .\ "=/msx } @grep_lines_1;
$grep_result_1 = join "\n", @grep_filtered_1;
            if (!($grep_result_1 =~ m{\n\z} || $grep_result_1 eq q{})) {
                $grep_result_1 .= "\n";
            }
print $grep_result_1;
$CHILD_ERROR = scalar @grep_filtered_1 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        }) {
do { my $eval_input = $var . "=" . ""; system('bash', '-c', $eval_input); $CHILD_ERROR = $? >> 8; };
        }
    }
;
    return;
}

sub which {
    my ($file) = @_;
    my $IFS;
    $IFS = q{:};
    my $i;
    for my $i ($PATH) {
if (((-f "$i/$_[0]") && (-x "$i/$_[0]"))) {
            say "$i/$_[0]";
return q{0};
        }
    }
;
return q{1};
    return;
}

sub db_default {
    my ($file) = @_;
    $main_exit_code = system('db_get', 'keyboard-configuration/store_defaults_in_debconf_db') >> 8;
if ("$RET" eq true) {
        $main_exit_code = system('db_set', $_[0], "$_[1]") >> 8;
    }
    return;
}

sub regex_escape {
my @sed_lines_2 = split /\n/, $;
my @sed_result_2;
foreach my $line (@sed_lines_2) {
chomp $line;
push @sed_result_2, $line;
}
$ = join "\n", @sed_result_2;

    return;
}

sub regex_pattern_escape {
my @sed_lines_3 = split /\n/, $;
my @sed_result_3;
foreach my $line (@sed_lines_3) {
chomp $line;
push @sed_result_3, $line;
}
$ = join "\n", @sed_result_3;

    return;
}

sub regex_unescape {
my @sed_lines_4 = split /\n/, $;
my @sed_result_4;
foreach my $line (@sed_lines_4) {
chomp $line;
push @sed_result_4, $line;
}
$ = join "\n", @sed_result_4;

    return;
}

sub all_kbdnames {
print q{C*model*a4techKB21*A4Tech KB-21
C*model*a4techKBS8*A4Tech KBS-8
C*model*a4_rfkb23*A4Tech Wireless Desktop RFKB-23
C*model*airkey*Acer AirKey V
C*model*acer_c300*Acer C300
C*model*acer_ferrari4k*Acer Ferrari 4000
C*model*acer_laptop*Acer laptop
C*model*scorpius*Advance Scorpius KI
C*model*amiga*Amiga
C*model*apple*Apple
C*model*applealu_ansi*Apple Aluminium (ANSI)
C*model*applealu_iso*Apple Aluminium (ISO)
C*model*applealu_jis*Apple Aluminium (JIS)
C*model*asus_laptop*Asus laptop
C*model*ataritt*Atari TT
C*model*azonaRF2300*Azona RF2300 Wireless Internet
C*model*btc5090*BTC 5090
C*model*btc5113rf*BTC 5113RF Multimedia
C*model*btc5126t*BTC 5126T
C*model*btc6301urf*BTC 6301URF
C*model*btc9000*BTC 9000
C*model*btc9000a*BTC 9000A
C*model*btc9001ah*BTC 9001AH
C*model*btc9019u*BTC 9019U
C*model*btc9116u*BTC 9116U Mini Wireless Internet and Gaming
C*model*benqx*BenQ X-Touch
C*model*benqx730*BenQ X-Touch 730
C*model*benqx800*BenQ X-Touch 800
C*model*brother*Brother Internet
C*model*cherrybunlim*Cherry B.UNLIMITED
C*model*cherryblue*Cherry Blue Line CyBo@rd
C*model*cherrybluea*Cherry Blue Line CyBo@rd (alt.)
C*model*cherrycyboard*Cherry CyBo@rd USB-Hub
C*model*cherrycmexpert*Cherry CyMotion Expert
C*model*cymotionlinux*Cherry CyMotion Master Linux
C*model*cherryblueb*Cherry CyMotion Master XPress
C*model*chicony*Chicony Internet
C*model*chicony9885*Chicony KB-9885
C*model*chicony0108*Chicony KU-0108
C*model*chicony0420*Chicony KU-0420
C*model*chromebook*Chromebook
C*model*classmate*Classmate PC
C*model*compalfl90*Compal FL90
C*model*armada*Compaq Armada laptop
C*model*compaqeak8*Compaq Easy Access
C*model*compaqik13*Compaq Internet (13 keys)
C*model*compaqik18*Compaq Internet (18 keys)
C*model*compaqik7*Compaq Internet (7 keys)
C*model*presario*Compaq Presario laptop
C*model*ipaq*Compaq iPaq
C*model*creativedw7000*Creative Desktop Wireless 7000
C*model*dtk2000*DTK2000
C*model*dell*Dell
C*model*dell101*Dell 101-key PC
C*model*inspiron*Dell Inspiron 6000/8000 laptop
C*model*latitude*Dell Latitude laptop
C*model*precision_m*Dell Precision M laptop
C*model*dellm65*Dell Precision M65 laptop
C*model*dellsk8125*Dell SK-8125
C*model*dellsk8135*Dell SK-8135
C*model*dellusbmm*Dell USB Multimedia
C*model*dexxa*Dexxa Wireless Desktop
C*model*diamond*Diamond 9801/9802
C*model*SKIP*Do not configure keyboard; keep kernel keymap
C*model*ennyah_dkb1008*Ennyah DKB-1008
C*model*everex*Everex STEPnote
C*model*fscaa1667g*Fujitsu-Siemens Amilo laptop
C*model*pc101*Generic 101-key PC
C*model*pc102*Generic 102-key PC
C*model*pc104*Generic 104-key PC
C*model*pc104alt*Generic 104-key PC with L-shaped Enter key
C*model*pc105*Generic 105-key PC
C*model*pc86*Generic 86-key PC
C*model*geniuscomfy*Genius Comfy KB-12e
C*model*genius*Genius Comfy KB-16M/Multimedia KWD-910
C*model*geniuscomfy2*Genius Comfy KB-21e-Scroll
C*model*geniuskb19e*Genius KB-19e NB
C*model*geniuskkb2050hs*Genius KKB-2050HS
C*model*gyration*Gyration
C*model*hhk*Happy Hacking
C*model*macintosh_hhk*Happy Hacking for Mac
C*model*hpi6*Hewlett-Packard Internet
C*model*hpmini110*Hewlett-Packard Mini 110 laptop
C*model*hp5xx*Hewlett-Packard Omnibook 500
C*model*hp500fa*Hewlett-Packard Omnibook 500 FA
C*model*hp6000*Hewlett-Packard Omnibook 6000/6100
C*model*hpxe3gc*Hewlett-Packard Omnibook XE3 GC
C*model*hpxe3gf*Hewlett-Packard Omnibook XE3 GF
C*model*hpxt1000*Hewlett-Packard Omnibook XT1000
C*model*hpzt11xx*Hewlett-Packard Pavilion ZT1100
C*model*hpdv5*Hewlett-Packard Pavilion dv5
C*model*hp250x*Hewlett-Packard SK-2501 Multimedia
C*model*hpnx9020*Hewlett-Packard nx9020
C*model*honeywell_euroboard*Honeywell Euroboard
C*model*rapidaccess*IBM Rapid Access
C*model*rapidaccess2*IBM Rapid Access II
C*model*ibm_spacesaver*IBM Space Saver
C*model*thinkpad*IBM ThinkPad 560Z/600/600E/A22E
C*model*thinkpad60*IBM ThinkPad R60/T60/R61/T61
C*model*thinkpadz60*IBM ThinkPad Z60m/Z60t/Z61m/Z61t
C*model*flexpro*Keytronic FlexPro
C*model*kinesis*Kinesis
C*model*logitech_base*Logitech
C*model*logiaccess*Logitech Access
C*model*logicd*Logitech Cordless Desktop
C*model*logicda*Logitech Cordless Desktop (alt.)
C*model*logiex110*Logitech Cordless Desktop EX110
C*model*logiclx300*Logitech Cordless Desktop LX-300
C*model*logicd_nav*Logitech Cordless Desktop Navigator
C*model*logicd_opt*Logitech Cordless Desktop Optical
C*model*logicd_it*Logitech Cordless Desktop iTouch
C*model*logitech_g15*Logitech G15 extra keys via G15daemon
C*model*logiik*Logitech Internet
C*model*logimel*Logitech Internet 350
C*model*logicink*Logitech Internet Navigator
C*model*logiultrax*Logitech Ultra-X
C*model*logiultraxc*Logitech Ultra-X Cordless Media Desktop
C*model*logidinovo*Logitech diNovo
C*model*logidinovoedge*Logitech diNovo Edge
C*model*itouch*Logitech iTouch
C*model*logiitc*Logitech iTouch Cordless Y-RB6
C*model*logiinkse*Logitech iTouch Internet Navigator SE
C*model*logiinkseusb*Logitech iTouch Internet Navigator SE USB
C*model*macbook78*MacBook/MacBook Pro
C*model*macbook79*MacBook/MacBook Pro (intl.)
C*model*macintosh*Macintosh
C*model*macintosh_old*Macintosh Old
C*model*mx1998*Memorex MX1998
C*model*mx2500*Memorex MX2500 EZ-Access
C*model*mx2750*Memorex MX2750
C*model*microsoftccurve2k*Microsoft Comfort Curve 2000
C*model*microsoftinet*Microsoft Internet
C*model*microsoftprose*Microsoft Internet Pro (Swedish)
C*model*microsoft*Microsoft Natural
C*model*microsoftelite*Microsoft Natural Elite
C*model*microsoft4000*Microsoft Natural Ergonomic 4000
C*model*microsoftprooem*Microsoft Natural Pro OEM
C*model*microsoftprousb*Microsoft Natural Pro USB/Internet Pro
C*model*microsoftpro*Microsoft Natural Pro/Internet Pro
C*model*microsoft7000*Microsoft Natural Wireless Ergonomic 7000
C*model*microsoftoffice*Microsoft Office Keyboard
C*model*microsoftsurface*Microsoft Surface
C*model*microsoftmult*Microsoft Wireless Multimedia 1.0A
C*model*sk1300*NEC SK-1300
C*model*sk2500*NEC SK-2500
C*model*sk6200*NEC SK-6200
C*model*sk7100*NEC SK-7100
C*model*omnikey101*Northgate OmniKey 101
C*model*olpc*OLPC
C*model*oretec*Ortek Multimedia/Internet MCK-800
C*model*pc98*PC-98
C*model*ppkb*PinePhone Keyboard
C*model*propeller*Propeller Voyager KTEZ-1000
C*model*qtronix*QTronix Scorpius 98N+
C*model*sven*SVEN Ergonomic 2500
C*model*sven303*SVEN Slim 303
C*model*samsung4500*Samsung SDM 4500P
C*model*samsung4510*Samsung SDM 4510P
C*model*sanwaskbkg3*Sanwa Supply SKB-KG3
C*model*silvercrest*Silvercrest Multimedia Wireless
C*model*apex300*SteelSeries Apex 300 (Apex RAW)
C*model*sun4*Sun Type 4
C*model*sun5*Sun Type 5
C*model*sun_type6_jp*Sun Type 6 (Japanese)
C*model*sun_type6_jp_usb*Sun Type 6 USB (Japanese)
C*model*sun_type6_unix_usb*Sun Type 6 USB (Unix)
C*model*sun_type6_usb*Sun Type 6/7 USB
C*model*sun_type6_euro_usb*Sun Type 6/7 USB (European)
C*model*sun_type7_usb*Sun Type 7 USB
C*model*sun_type7_euro_usb*Sun Type 7 USB (European)
C*model*sun_type7_jp_usb*Sun Type 7 USB (Japanese)/Japanese 106-key
C*model*sun_type7_unix_usb*Sun Type 7 USB (Unix)
C*model*sp_inet*Super Power Multimedia
C*model*symplon*Symplon PaceBook tablet
C*model*targa_v811*Targa Visionary 811
C*model*toshiba_s3000*Toshiba Satellite S3000
C*model*teck227*Truly Ergonomic 227
C*model*teck229*Truly Ergonomic 229
C*model*trustda*Trust Direct Access
C*model*trust_slimline*Trust Slimline
C*model*trust*Trust Wireless Classic
C*model*tm2020*TypeMatrix EZ-Reach 2020
C*model*tm2030PS2*TypeMatrix EZ-Reach 2030 PS2
C*model*tm2030USB*TypeMatrix EZ-Reach 2030 USB
C*model*tm2030USB-102*TypeMatrix EZ-Reach 2030 USB (102/105:EU mode)
C*model*tm2030USB-106*TypeMatrix EZ-Reach 2030 USB (106:JP mode)
C*model*unitekkb1925*Unitek KB-1925
C*model*vsonku306*ViewSonic KU-306 Internet
C*model*winbook*Winbook Model XP5
C*model*yahoo*Yahoo! Internet
C*model*emachines*eMachines m6800 laptop
C*layout*custom*A user-defined custom Layout
C*variant*custom**A user-defined custom Layout
C*layout*al*Albanian
C*variant*al**Albanian
C*variant*al*plisi*Albanian - Albanian (Plisi)
C*variant*al*veqilharxhi*Albanian - Albanian (Veqilharxhi)
C*layout*et*Amharic
C*variant*et**Amharic
C*layout*ara*Arabic
C*variant*ara**Arabic
C*variant*ara*azerty*Arabic - Arabic (AZERTY)
C*variant*ara*azerty_digits*Arabic - Arabic (AZERTY, Eastern Arabic numerals)
C*variant*ara*buckwalter*Arabic - Arabic (Buckwalter)
C*variant*ara*digits*Arabic - Arabic (Eastern Arabic numerals)
C*variant*ara*mac*Arabic - Arabic (Macintosh)
C*variant*ara*mac-phonetic*Arabic - Arabic (Macintosh, phonetic)
C*variant*ara*olpc*Arabic - Arabic (OLPC)
C*layout*eg*Arabic (Egypt)
C*variant*eg**Arabic (Egypt)
C*layout*iq*Arabic (Iraq)
C*variant*iq**Arabic (Iraq)
C*variant*iq*ku_ara*Arabic (Iraq) - Kurdish (Iraq, Arabic-Latin)
C*variant*iq*ku_f*Arabic (Iraq) - Kurdish (Iraq, F)
C*variant*iq*ku_alt*Arabic (Iraq) - Kurdish (Iraq, Latin Alt-Q)
C*variant*iq*ku*Arabic (Iraq) - Kurdish (Iraq, Latin Q)
C*layout*ma*Arabic (Morocco)
C*variant*ma**Arabic (Morocco)
C*variant*ma*tifinagh-alt*Arabic (Morocco) - Berber (Morocco, Tifinagh alt.)
C*variant*ma*tifinagh-extended-phonetic*Arabic (Morocco) - Berber (Morocco, Tifinagh extended phonetic)
C*variant*ma*tifinagh-extended*Arabic (Morocco) - Berber (Morocco, Tifinagh extended)
C*variant*ma*tifinagh-phonetic*Arabic (Morocco) - Berber (Morocco, Tifinagh phonetic)
C*variant*ma*tifinagh-alt-phonetic*Arabic (Morocco) - Berber (Morocco, Tifinagh phonetic, alt.)
C*variant*ma*tifinagh*Arabic (Morocco) - Berber (Morocco, Tifinagh)
C*variant*ma*french*Arabic (Morocco) - French (Morocco)
C*variant*ma*rif*Arabic (Morocco) - Tarifit
C*layout*sy*Arabic (Syria)
C*variant*sy**Arabic (Syria)
C*variant*sy*ku_f*Arabic (Syria) - Kurdish (Syria, F)
C*variant*sy*ku_alt*Arabic (Syria) - Kurdish (Syria, Latin Alt-Q)
C*variant*sy*ku*Arabic (Syria) - Kurdish (Syria, Latin Q)
C*variant*sy*syc*Arabic (Syria) - Syriac
C*variant*sy*syc_phonetic*Arabic (Syria) - Syriac (phonetic)
C*layout*am*Armenian
C*variant*am**Armenian
C*variant*am*eastern-alt*Armenian - Armenian (alt. eastern)
C*variant*am*phonetic-alt*Armenian - Armenian (alt. phonetic)
C*variant*am*eastern*Armenian - Armenian (eastern)
C*variant*am*phonetic*Armenian - Armenian (phonetic)
C*variant*am*western*Armenian - Armenian (western)
C*layout*az*Azerbaijani
C*variant*az**Azerbaijani
C*variant*az*cyrillic*Azerbaijani - Azerbaijani (Cyrillic)
C*layout*ml*Bambara
C*variant*ml**Bambara
C*variant*ml*us-mac*Bambara - English (Mali, US, Macintosh)
C*variant*ml*us-intl*Bambara - English (Mali, US, intl.)
C*variant*ml*fr-oss*Bambara - French (Mali, alt.)
C*layout*bd*Bangla
C*variant*bd**Bangla
C*variant*bd*probhat*Bangla - Bangla (Probhat)
C*layout*by*Belarusian
C*variant*by**Belarusian
C*variant*by*latin*Belarusian - Belarusian (Latin)
C*variant*by*intl*Belarusian - Belarusian (intl.)
C*variant*by*legacy*Belarusian - Belarusian (legacy)
C*variant*by*phonetic*Belarusian - Belarusian (phonetic)
C*variant*by*ru*Belarusian - Russian (Belarus)
C*layout*be*Belgian
C*variant*be**Belgian
C*variant*be*iso-alternate*Belgian - Belgian (ISO, alt.)
C*variant*be*oss_latin9*Belgian - Belgian (Latin-9 only, alt.)
C*variant*be*wang*Belgian - Belgian (Wang 724 AZERTY)
C*variant*be*oss*Belgian - Belgian (alt.)
C*variant*be*nodeadkeys*Belgian - Belgian (no dead keys)
C*layout*dz*Berber (Algeria, Latin)
C*variant*dz**Berber (Algeria, Latin)
C*variant*dz*ar*Berber (Algeria, Latin) - Arabic (Algeria)
C*variant*dz*ber*Berber (Algeria, Latin) - Berber (Algeria, Tifinagh)
C*variant*dz*azerty-deadkeys*Berber (Algeria, Latin) - Kabyle (AZERTY, with dead keys)
C*variant*dz*qwerty-gb-deadkeys*Berber (Algeria, Latin) - Kabyle (QWERTY, UK, with dead keys)
C*variant*dz*qwerty-us-deadkeys*Berber (Algeria, Latin) - Kabyle (QWERTY, US, with dead keys)
C*layout*ba*Bosnian
C*variant*ba**Bosnian
C*variant*ba*us*Bosnian - Bosnian (US)
C*variant*ba*unicodeus*Bosnian - Bosnian (US, with Bosnian digraphs)
C*variant*ba*unicode*Bosnian - Bosnian (with Bosnian digraphs)
C*variant*ba*alternatequotes*Bosnian - Bosnian (with guillemets)
C*layout*brai*Braille
C*variant*brai**Braille
C*variant*brai*left_hand_invert*Braille - Braille (left-handed inverted thumb)
C*variant*brai*left_hand*Braille - Braille (left-handed)
C*variant*brai*right_hand_invert*Braille - Braille (right-handed inverted thumb)
C*variant*brai*right_hand*Braille - Braille (right-handed)
C*layout*bg*Bulgarian
C*variant*bg**Bulgarian
C*variant*bg*bekl*Bulgarian - Bulgarian (enhanced)
C*variant*bg*bas_phonetic*Bulgarian - Bulgarian (new phonetic)
C*variant*bg*phonetic*Bulgarian - Bulgarian (traditional phonetic)
C*layout*mm*Burmese
C*variant*mm**Burmese
C*variant*mm*zawgyi*Burmese - Burmese (Zawgyi)
C*variant*mm*mnw*Burmese - Mon
C*variant*mm*mnw-a1*Burmese - Mon (A1)
C*variant*mm*shn*Burmese - Shan
C*variant*mm*zgt*Burmese - Shan (Zawgyi)
C*layout*cn*Chinese
C*variant*cn**Chinese
C*variant*cn*altgr-pinyin*Chinese - Hanyu Pinyin Letters (with AltGr dead keys)
C*variant*cn*mon_trad*Chinese - Mongolian (Bichig)
C*variant*cn*mon_trad_galik*Chinese - Mongolian (Galik)
C*variant*cn*mon_manchu_galik*Chinese - Mongolian (Manchu Galik)
C*variant*cn*mon_trad_manchu*Chinese - Mongolian (Manchu)
C*variant*cn*mon_todo_galik*Chinese - Mongolian (Todo Galik)
C*variant*cn*mon_trad_todo*Chinese - Mongolian (Todo)
C*variant*cn*mon_trad_xibe*Chinese - Mongolian (Xibe)
C*variant*cn*tib*Chinese - Tibetan
C*variant*cn*tib_asciinum*Chinese - Tibetan (with ASCII numerals)
C*variant*cn*ug*Chinese - Uyghur
C*layout*hr*Croatian
C*variant*hr**Croatian
C*variant*hr*us*Croatian - Croatian (US)
C*variant*hr*unicodeus*Croatian - Croatian (US, with Croatian digraphs)
C*variant*hr*unicode*Croatian - Croatian (with Croatian digraphs)
C*variant*hr*alternatequotes*Croatian - Croatian (with guillemets)
C*layout*cz*Czech
C*variant*cz**Czech
C*variant*cz*qwerty*Czech - Czech (QWERTY)
C*variant*cz*qwerty-mac*Czech - Czech (QWERTY, Macintosh)
C*variant*cz*winkeys-qwerty*Czech - Czech (QWERTY, Windows)
C*variant*cz*qwerty_bksl*Czech - Czech (QWERTY, extra backslash)
C*variant*cz*winkeys*Czech - Czech (QWERTZ, Windows)
C*variant*cz*ucw*Czech - Czech (UCW, only accented letters)
C*variant*cz*dvorak-ucw*Czech - Czech (US, Dvorak, UCW support)
C*variant*cz*bksl*Czech - Czech (extra backslash)
C*variant*cz*rus*Czech - Russian (Czechia, phonetic)
C*layout*dk*Danish
C*variant*dk**Danish
C*variant*dk*dvorak*Danish - Danish (Dvorak)
C*variant*dk*mac*Danish - Danish (Macintosh)
C*variant*dk*mac_nodeadkeys*Danish - Danish (Macintosh, no dead keys)
C*variant*dk*winkeys*Danish - Danish (Windows)
C*variant*dk*nodeadkeys*Danish - Danish (no dead keys)
C*layout*af*Dari
C*variant*af**Dari
C*variant*af*fa-olpc*Dari - Dari (Afghanistan, OLPC)
C*variant*af*ps*Dari - Pashto
C*variant*af*ps-olpc*Dari - Pashto (Afghanistan, OLPC)
C*variant*af*uz*Dari - Uzbek (Afghanistan)
C*variant*af*uz-olpc*Dari - Uzbek (Afghanistan, OLPC)
C*layout*mv*Dhivehi
C*variant*mv**Dhivehi
C*layout*nl*Dutch
C*variant*nl**Dutch
C*variant*nl*mac*Dutch - Dutch (Macintosh)
C*variant*nl*us*Dutch - Dutch (US)
C*variant*nl*std*Dutch - Dutch (standard)
C*layout*bt*Dzongkha
C*variant*bt**Dzongkha
C*layout*au*English (Australia)
C*variant*au**English (Australia)
C*layout*cm*English (Cameroon)
C*variant*cm**English (Cameroon)
C*variant*cm*azerty*English (Cameroon) - Cameroon (AZERTY, intl.)
C*variant*cm*dvorak*English (Cameroon) - Cameroon (Dvorak, intl.)
C*variant*cm*qwerty*English (Cameroon) - Cameroon Multilingual (QWERTY, intl.)
C*variant*cm*french*English (Cameroon) - French (Cameroon)
C*variant*cm*mmuock*English (Cameroon) - Mmuock
C*layout*gh*English (Ghana)
C*variant*gh**English (Ghana)
C*variant*gh*akan*English (Ghana) - Akan
C*variant*gh*avn*English (Ghana) - Avatime
C*variant*gh*gillbt*English (Ghana) - English (Ghana, GILLBT)
C*variant*gh*generic*English (Ghana) - English (Ghana, multilingual)
C*variant*gh*ewe*English (Ghana) - Ewe
C*variant*gh*fula*English (Ghana) - Fula
C*variant*gh*ga*English (Ghana) - Ga
C*variant*gh*hausa*English (Ghana) - Hausa (Ghana)
C*layout*nz*English (New Zealand)
C*variant*nz**English (New Zealand)
C*variant*nz*mao*English (New Zealand) - Maori
C*layout*ng*English (Nigeria)
C*variant*ng**English (Nigeria)
C*variant*ng*hausa*English (Nigeria) - Hausa (Nigeria)
C*variant*ng*igbo*English (Nigeria) - Igbo
C*variant*ng*yoruba*English (Nigeria) - Yoruba
C*layout*za*English (South Africa)
C*variant*za**English (South Africa)
C*layout*gb*English (UK)
C*variant*gb**English (UK)
C*variant*gb*colemak*English (UK) - English (UK, Colemak)
C*variant*gb*colemak_dh*English (UK) - English (UK, Colemak-DH)
C*variant*gb*dvorak*English (UK) - English (UK, Dvorak)
C*variant*gb*dvorakukp*English (UK) - English (UK, Dvorak, with UK punctuation)
C*variant*gb*mac*English (UK) - English (UK, Macintosh)
C*variant*gb*mac_intl*English (UK) - English (UK, Macintosh, intl.)
C*variant*gb*extd*English (UK) - English (UK, extended, Windows)
C*variant*gb*intl*English (UK) - English (UK, intl., with dead keys)
C*variant*gb*pl*English (UK) - Polish (British keyboard)
C*variant*gb*gla*English (UK) - Scottish Gaelic
C*layout*us*English (US)
C*variant*us**English (US)
C*variant*us*chr*English (US) - Cherokee
C*variant*us*colemak*English (US) - English (Colemak)
C*variant*us*colemak_dh_iso*English (US) - English (Colemak-DH ISO)
C*variant*us*colemak_dh_ortho*English (US) - English (Colemak-DH Ortholinear)
C*variant*us*colemak_dh_wide_iso*English (US) - English (Colemak-DH Wide ISO)
C*variant*us*colemak_dh_wide*English (US) - English (Colemak-DH Wide)
C*variant*us*colemak_dh*English (US) - English (Colemak-DH)
C*variant*us*dvorak*English (US) - English (Dvorak)
C*variant*us*dvorak-mac*English (US) - English (Dvorak, Macintosh)
C*variant*us*dvorak-alt-intl*English (US) - English (Dvorak, alt. intl.)
C*variant*us*dvorak-intl*English (US) - English (Dvorak, intl., with dead keys)
C*variant*us*dvorak-l*English (US) - English (Dvorak, left-handed)
C*variant*us*dvorak-r*English (US) - English (Dvorak, right-handed)
C*variant*us*mac*English (US) - English (Macintosh)
C*variant*us*norman*English (US) - English (Norman)
C*variant*us*symbolic*English (US) - English (US, Symbolic)
C*variant*us*alt-intl*English (US) - English (US, alt. intl.)
C*variant*us*euro*English (US) - English (US, euro on 5)
C*variant*us*intl*English (US) - English (US, intl., with dead keys)
C*variant*us*workman*English (US) - English (Workman)
C*variant*us*workman-intl*English (US) - English (Workman, intl., with dead keys)
C*variant*us*dvorak-classic*English (US) - English (classic Dvorak)
C*variant*us*altgr-intl*English (US) - English (intl., with AltGr dead keys)
C*variant*us*dvp*English (US) - English (programmer Dvorak)
C*variant*us*olpc2*English (US) - English (the divide/multiply toggle the layout)
C*variant*us*haw*English (US) - Hawaiian
C*variant*us*rus*English (US) - Russian (US, phonetic)
C*variant*us*hbs*English (US) - Serbo-Croatian (US)
C*layout*epo*Esperanto
C*variant*epo**Esperanto
C*variant*epo*legacy*Esperanto - Esperanto (legacy)
C*layout*ee*Estonian
C*variant*ee**Estonian
C*variant*ee*dvorak*Estonian - Estonian (Dvorak)
C*variant*ee*us*Estonian - Estonian (US)
C*variant*ee*nodeadkeys*Estonian - Estonian (no dead keys)
C*layout*fo*Faroese
C*variant*fo**Faroese
C*variant*fo*nodeadkeys*Faroese - Faroese (no dead keys)
C*layout*ph*Filipino
C*variant*ph**Filipino
C*variant*ph*capewell-dvorak-bay*Filipino - Filipino (Capewell-Dvorak, Baybayin)
C*variant*ph*capewell-dvorak*Filipino - Filipino (Capewell-Dvorak, Latin)
C*variant*ph*capewell-qwerf2k6-bay*Filipino - Filipino (Capewell-QWERF 2006, Baybayin)
C*variant*ph*capewell-qwerf2k6*Filipino - Filipino (Capewell-QWERF 2006, Latin)
C*variant*ph*colemak-bay*Filipino - Filipino (Colemak, Baybayin)
C*variant*ph*colemak*Filipino - Filipino (Colemak, Latin)
C*variant*ph*dvorak-bay*Filipino - Filipino (Dvorak, Baybayin)
C*variant*ph*dvorak*Filipino - Filipino (Dvorak, Latin)
C*variant*ph*qwerty-bay*Filipino - Filipino (QWERTY, Baybayin)
C*layout*fi*Finnish
C*variant*fi**Finnish
C*variant*fi*mac*Finnish - Finnish (Macintosh)
C*variant*fi*winkeys*Finnish - Finnish (Windows)
C*variant*fi*classic*Finnish - Finnish (classic)
C*variant*fi*nodeadkeys*Finnish - Finnish (classic, no dead keys)
C*variant*fi*smi*Finnish - Northern Saami (Finland)
C*layout*fr*French
C*variant*fr**French
C*variant*fr*bre*French - Breton (France)
C*variant*fr*azerty*French - French (AZERTY)
C*variant*fr*afnor*French - French (AZERTY, AFNOR)
C*variant*fr*bepo*French - French (BEPO)
C*variant*fr*bepo_afnor*French - French (BEPO, AFNOR)
C*variant*fr*bepo_latin9*French - French (BEPO, Latin-9 only)
C*variant*fr*dvorak*French - French (Dvorak)
C*variant*fr*mac*French - French (Macintosh)
C*variant*fr*us*French - French (US)
C*variant*fr*oss*French - French (alt.)
C*variant*fr*oss_latin9*French - French (alt., Latin-9 only)
C*variant*fr*oss_nodeadkeys*French - French (alt., no dead keys)
C*variant*fr*latin9*French - French (legacy, alt.)
C*variant*fr*latin9_nodeadkeys*French - French (legacy, alt., no dead keys)
C*variant*fr*nodeadkeys*French - French (no dead keys)
C*variant*fr*geo*French - Georgian (France, AZERTY Tskapo)
C*variant*fr*oci*French - Occitan
C*layout*ca*French (Canada)
C*variant*ca**French (Canada)
C*variant*ca*multix*French (Canada) - Canadian (CSA)
C*variant*ca*eng*French (Canada) - English (Canada)
C*variant*ca*fr-dvorak*French (Canada) - French (Canada, Dvorak)
C*variant*ca*fr-legacy*French (Canada) - French (Canada, legacy)
C*variant*ca*ike*French (Canada) - Inuktitut
C*layout*cd*French (Democratic Republic of the Congo)
C*variant*cd**French (Democratic Republic of the Congo)
C*layout*tg*French (Togo)
C*variant*tg**French (Togo)
C*layout*ge*Georgian
C*variant*ge**Georgian
C*variant*ge*mess*Georgian - Georgian (MESS)
C*variant*ge*ergonomic*Georgian - Georgian (ergonomic)
C*variant*ge*os*Georgian - Ossetian (Georgia)
C*variant*ge*ru*Georgian - Russian (Georgia)
C*layout*de*German
C*variant*de**German
C*variant*de*dvorak*German - German (Dvorak)
C*variant*de*e1*German - German (E1)
C*variant*de*e2*German - German (E2)
C*variant*de*mac*German - German (Macintosh)
C*variant*de*mac_nodeadkeys*German - German (Macintosh, no dead keys)
C*variant*de*neo*German - German (Neo 2)
C*variant*de*qwerty*German - German (QWERTY)
C*variant*de*T3*German - German (T3)
C*variant*de*us*German - German (US)
C*variant*de*deadacute*German - German (dead acute)
C*variant*de*deadgraveacute*German - German (dead grave acute)
C*variant*de*deadtilde*German - German (dead tilde)
C*variant*de*nodeadkeys*German - German (no dead keys)
C*variant*de*dsb*German - Lower Sorbian
C*variant*de*dsb_qwertz*German - Lower Sorbian (QWERTZ)
C*variant*de*ro*German - Romanian (Germany)
C*variant*de*ro_nodeadkeys*German - Romanian (Germany, no dead keys)
C*variant*de*ru*German - Russian (Germany, phonetic)
C*variant*de*tr*German - Turkish (Germany)
C*layout*at*German (Austria)
C*variant*at**German (Austria)
C*variant*at*mac*German (Austria) - German (Austria, Macintosh)
C*variant*at*nodeadkeys*German (Austria) - German (Austria, no dead keys)
C*layout*gr*Greek
C*variant*gr**Greek
C*variant*gr*nodeadkeys*Greek - Greek (no dead keys)
C*variant*gr*polytonic*Greek - Greek (polytonic)
C*variant*gr*simple*Greek - Greek (simple)
C*layout*il*Hebrew
C*variant*il**Hebrew
C*variant*il*biblical*Hebrew - Hebrew (Biblical, Tiro)
C*variant*il*si2*Hebrew - Hebrew (SI-1452-2)
C*variant*il*lyx*Hebrew - Hebrew (lyx)
C*variant*il*phonetic*Hebrew - Hebrew (phonetic)
C*layout*hu*Hungarian
C*variant*hu**Hungarian
C*variant*hu*qwerty*Hungarian - Hungarian (QWERTY)
C*variant*hu*101_qwerty_comma_dead*Hungarian - Hungarian (QWERTY, 101-key, comma, dead keys)
C*variant*hu*101_qwerty_comma_nodead*Hungarian - Hungarian (QWERTY, 101-key, comma, no dead keys)
C*variant*hu*101_qwerty_dot_dead*Hungarian - Hungarian (QWERTY, 101-key, dot, dead keys)
C*variant*hu*101_qwerty_dot_nodead*Hungarian - Hungarian (QWERTY, 101-key, dot, no dead keys)
C*variant*hu*102_qwerty_comma_dead*Hungarian - Hungarian (QWERTY, 102-key, comma, dead keys)
C*variant*hu*102_qwerty_comma_nodead*Hungarian - Hungarian (QWERTY, 102-key, comma, no dead keys)
C*variant*hu*102_qwerty_dot_dead*Hungarian - Hungarian (QWERTY, 102-key, dot, dead keys)
C*variant*hu*102_qwerty_dot_nodead*Hungarian - Hungarian (QWERTY, 102-key, dot, no dead keys)
C*variant*hu*101_qwertz_comma_dead*Hungarian - Hungarian (QWERTZ, 101-key, comma, dead keys)
C*variant*hu*101_qwertz_comma_nodead*Hungarian - Hungarian (QWERTZ, 101-key, comma, no dead keys)
C*variant*hu*101_qwertz_dot_dead*Hungarian - Hungarian (QWERTZ, 101-key, dot, dead keys)
C*variant*hu*101_qwertz_dot_nodead*Hungarian - Hungarian (QWERTZ, 101-key, dot, no dead keys)
C*variant*hu*102_qwertz_comma_dead*Hungarian - Hungarian (QWERTZ, 102-key, comma, dead keys)
C*variant*hu*102_qwertz_comma_nodead*Hungarian - Hungarian (QWERTZ, 102-key, comma, no dead keys)
C*variant*hu*102_qwertz_dot_dead*Hungarian - Hungarian (QWERTZ, 102-key, dot, dead keys)
C*variant*hu*102_qwertz_dot_nodead*Hungarian - Hungarian (QWERTZ, 102-key, dot, no dead keys)
C*variant*hu*nodeadkeys*Hungarian - Hungarian (no dead keys)
C*variant*hu*standard*Hungarian - Hungarian (standard)
C*layout*is*Icelandic
C*variant*is**Icelandic
C*variant*is*dvorak*Icelandic - Icelandic (Dvorak)
C*variant*is*mac*Icelandic - Icelandic (Macintosh)
C*variant*is*mac_legacy*Icelandic - Icelandic (Macintosh, legacy)
C*layout*in*Indian
C*variant*in**Indian
C*variant*in*asm-kagapa*Indian - Assamese (KaGaPa, phonetic)
C*variant*in*ben*Indian - Bangla (India)
C*variant*in*ben_inscript*Indian - Bangla (India, Baishakhi InScript)
C*variant*in*ben_baishakhi*Indian - Bangla (India, Baishakhi)
C*variant*in*ben_bornona*Indian - Bangla (India, Bornona)
C*variant*in*ben_gitanjali*Indian - Bangla (India, Gitanjali)
C*variant*in*ben-kagapa*Indian - Bangla (India, KaGaPa, phonetic)
C*variant*in*ben_probhat*Indian - Bangla (India, Probhat)
C*variant*in*eng*Indian - English (India, with rupee)
C*variant*in*guj*Indian - Gujarati
C*variant*in*guj-kagapa*Indian - Gujarati (KaGaPa, phonetic)
C*variant*in*bolnagri*Indian - Hindi (Bolnagri)
C*variant*in*hin-kagapa*Indian - Hindi (KaGaPa, phonetic)
C*variant*in*hin-wx*Indian - Hindi (Wx)
C*variant*in*iipa*Indian - Indic IPA
C*variant*in*kan*Indian - Kannada
C*variant*in*kan-kagapa*Indian - Kannada (KaGaPa, phonetic)
C*variant*in*mal*Indian - Malayalam
C*variant*in*mal_lalitha*Indian - Malayalam (Lalitha)
C*variant*in*mal_poorna*Indian - Malayalam (Poorna, extended InScript)
C*variant*in*mal_enhanced*Indian - Malayalam (enhanced InScript, with rupee)
C*variant*in*mni*Indian - Manipuri (Meitei)
C*variant*in*mar-kagapa*Indian - Marathi (KaGaPa, phonetic)
C*variant*in*marathi*Indian - Marathi (enhanced InScript)
C*variant*in*ori*Indian - Oriya
C*variant*in*ori-bolnagri*Indian - Oriya (Bolnagri)
C*variant*in*ori-wx*Indian - Oriya (Wx)
C*variant*in*jhelum*Indian - Punjabi (Gurmukhi Jhelum)
C*variant*in*guru*Indian - Punjabi (Gurmukhi)
C*variant*in*san-kagapa*Indian - Sanskrit (KaGaPa, phonetic)
C*variant*in*sat*Indian - Santali (Ol Chiki)
C*variant*in*tam*Indian - Tamil (InScript, with Arabic numerals)
C*variant*in*tam_tamilnumbers*Indian - Tamil (InScript, with Tamil numerals)
C*variant*in*tamilnet_tamilnumbers*Indian - Tamil (TamilNet 99 with Tamil numerals)
C*variant*in*tamilnet*Indian - Tamil (TamilNet 99)
C*variant*in*tamilnet_TAB*Indian - Tamil (TamilNet 99, TAB encoding)
C*variant*in*tamilnet_TSCII*Indian - Tamil (TamilNet 99, TSCII encoding)
C*variant*in*tel*Indian - Telugu
C*variant*in*tel-kagapa*Indian - Telugu (KaGaPa, phonetic)
C*variant*in*tel-sarala*Indian - Telugu (Sarala)
C*variant*in*urd-winkeys*Indian - Urdu (Windows)
C*variant*in*urd-phonetic3*Indian - Urdu (alt. phonetic)
C*variant*in*urd-phonetic*Indian - Urdu (phonetic)
C*layout*id*Indonesian (Latin)
C*variant*id**Indonesian (Latin)
C*variant*id*melayu-phoneticx*Indonesian (Latin) - Indonesian (Arab Melayu, extended phonetic)
C*variant*id*melayu-phonetic*Indonesian (Latin) - Indonesian (Arab Melayu, phonetic)
C*variant*id*pegon-phonetic*Indonesian (Latin) - Indonesian (Arab Pegon, phonetic)
C*variant*id*javanese*Indonesian (Latin) - Javanese
C*layout*ie*Irish
C*variant*ie**Irish
C*variant*ie*CloGaelach*Irish - CloGaelach
C*variant*ie*UnicodeExpert*Irish - Irish (UnicodeExpert)
C*variant*ie*ogam*Irish - Ogham
C*variant*ie*ogam_is434*Irish - Ogham (IS434)
C*layout*it*Italian
C*variant*it**Italian
C*variant*it*fur*Italian - Friulian (Italy)
C*variant*it*geo*Italian - Georgian (Italy)
C*variant*it*ibm*Italian - Italian (IBM 142)
C*variant*it*mac*Italian - Italian (Macintosh)
C*variant*it*us*Italian - Italian (US)
C*variant*it*winkeys*Italian - Italian (Windows)
C*variant*it*nodeadkeys*Italian - Italian (no dead keys)
C*variant*it*scn*Italian - Sicilian
C*layout*jp*Japanese
C*variant*jp**Japanese
C*variant*jp*dvorak*Japanese - Japanese (Dvorak)
C*variant*jp*kana86*Japanese - Japanese (Kana 86)
C*variant*jp*kana*Japanese - Japanese (Kana)
C*variant*jp*mac*Japanese - Japanese (Macintosh)
C*variant*jp*OADG109A*Japanese - Japanese (OADG 109A)
C*layout*kz*Kazakh
C*variant*kz**Kazakh
C*variant*kz*latin*Kazakh - Kazakh (Latin)
C*variant*kz*ext*Kazakh - Kazakh (extended)
C*variant*kz*kazrus*Kazakh - Kazakh (with Russian)
C*variant*kz*ruskaz*Kazakh - Russian (Kazakhstan, with Kazakh)
C*layout*kh*Khmer (Cambodia)
C*variant*kh**Khmer (Cambodia)
C*layout*kr*Korean
C*variant*kr**Korean
C*variant*kr*kr104*Korean - Korean (101/104-key compatible)
C*layout*kg*Kyrgyz
C*variant*kg**Kyrgyz
C*variant*kg*phonetic*Kyrgyz - Kyrgyz (phonetic)
C*layout*la*Lao
C*variant*la**Lao
C*variant*la*stea*Lao - Lao (STEA)
C*layout*lv*Latvian
C*variant*lv**Latvian
C*variant*lv*fkey*Latvian - Latvian (F)
C*variant*lv*modern-cyr*Latvian - Latvian (Modern Cyrillic)
C*variant*lv*modern*Latvian - Latvian (Modern Latin)
C*variant*lv*adapted*Latvian - Latvian (adapted)
C*variant*lv*apostrophe*Latvian - Latvian (apostrophe)
C*variant*lv*ergonomic*Latvian - Latvian (ergonomic, ŪGJRMV)
C*variant*lv*tilde*Latvian - Latvian (tilde)
C*layout*lt*Lithuanian
C*variant*lt**Lithuanian
C*variant*lt*ibm*Lithuanian - Lithuanian (IBM)
C*variant*lt*lekp*Lithuanian - Lithuanian (LEKP)
C*variant*lt*lekpa*Lithuanian - Lithuanian (LEKPa)
C*variant*lt*ratise*Lithuanian - Lithuanian (Ratise)
C*variant*lt*us*Lithuanian - Lithuanian (US)
C*variant*lt*std*Lithuanian - Lithuanian (standard)
C*variant*lt*sgs*Lithuanian - Samogitian
C*layout*mk*Macedonian
C*variant*mk**Macedonian
C*variant*mk*nodeadkeys*Macedonian - Macedonian (no dead keys)
C*layout*my*Malay (Jawi, Arabic Keyboard)
C*variant*my**Malay (Jawi, Arabic Keyboard)
C*variant*my*phonetic*Malay (Jawi, Arabic Keyboard) - Malay (Jawi, phonetic)
C*layout*mt*Maltese
C*variant*mt**Maltese
C*variant*mt*alt-gb*Maltese - Maltese (UK, with AltGr overrides)
C*variant*mt*us*Maltese - Maltese (US)
C*variant*mt*alt-us*Maltese - Maltese (US, with AltGr overrides)
C*layout*md*Moldavian
C*variant*md**Moldavian
C*variant*md*gag*Moldavian - Gagauz (Moldova)
C*layout*mn*Mongolian
C*variant*mn**Mongolian
C*layout*me*Montenegrin
C*variant*me**Montenegrin
C*variant*me*cyrillic*Montenegrin - Montenegrin (Cyrillic)
C*variant*me*cyrillicyz*Montenegrin - Montenegrin (Cyrillic, ZE and ZHE swapped)
C*variant*me*cyrillicalternatequotes*Montenegrin - Montenegrin (Cyrillic, with guillemets)
C*variant*me*latinyz*Montenegrin - Montenegrin (Latin, QWERTY)
C*variant*me*latinunicode*Montenegrin - Montenegrin (Latin, Unicode)
C*variant*me*latinunicodeyz*Montenegrin - Montenegrin (Latin, Unicode, QWERTY)
C*variant*me*latinalternatequotes*Montenegrin - Montenegrin (Latin, with guillemets)
C*layout*gn*NKo (AZERTY)
C*variant*gn**NKo (AZERTY)
C*layout*np*Nepali
C*variant*np**Nepali
C*layout*no*Norwegian
C*variant*no**Norwegian
C*variant*no*smi*Norwegian - Northern Saami (Norway)
C*variant*no*smi_nodeadkeys*Norwegian - Northern Saami (Norway, no dead keys)
C*variant*no*colemak*Norwegian - Norwegian (Colemak)
C*variant*no*colemak_dh_wide*Norwegian - Norwegian (Colemak-DH Wide)
C*variant*no*colemak_dh*Norwegian - Norwegian (Colemak-DH)
C*variant*no*dvorak*Norwegian - Norwegian (Dvorak)
C*variant*no*mac*Norwegian - Norwegian (Macintosh)
C*variant*no*mac_nodeadkeys*Norwegian - Norwegian (Macintosh, no dead keys)
C*variant*no*winkeys*Norwegian - Norwegian (Windows)
C*variant*no*nodeadkeys*Norwegian - Norwegian (no dead keys)
C*layout*ir*Persian
C*variant*ir**Persian
C*variant*ir*azb*Persian - Azerbaijani (Iran)
C*variant*ir*ku_ara*Persian - Kurdish (Iran, Arabic-Latin)
C*variant*ir*ku_f*Persian - Kurdish (Iran, F)
C*variant*ir*ku_alt*Persian - Kurdish (Iran, Latin Alt-Q)
C*variant*ir*ku*Persian - Kurdish (Iran, Latin Q)
C*variant*ir*winkeys*Persian - Persian (Windows)
C*variant*ir*pes_keypad*Persian - Persian (with Persian keypad)
C*layout*pl*Polish
C*variant*pl**Polish
C*variant*pl*csb*Polish - Kashubian
C*variant*pl*dvorak*Polish - Polish (Dvorak)
C*variant*pl*dvorak_altquotes*Polish - Polish (Dvorak, with Polish quotes on key 1)
C*variant*pl*dvorak_quotes*Polish - Polish (Dvorak, with Polish quotes on quotemark key)
C*variant*pl*qwertz*Polish - Polish (QWERTZ)
C*variant*pl*legacy*Polish - Polish (legacy)
C*variant*pl*dvp*Polish - Polish (programmer Dvorak)
C*variant*pl*ru_phonetic_dvorak*Polish - Russian (Poland, phonetic Dvorak)
C*variant*pl*szl*Polish - Silesian
C*layout*pt*Portuguese
C*variant*pt**Portuguese
C*variant*pt*nativo-epo*Portuguese - Esperanto (Portugal, Nativo)
C*variant*pt*mac*Portuguese - Portuguese (Macintosh)
C*variant*pt*mac_nodeadkeys*Portuguese - Portuguese (Macintosh, no dead keys)
C*variant*pt*nativo-us*Portuguese - Portuguese (Nativo for US keyboards)
C*variant*pt*nativo*Portuguese - Portuguese (Nativo)
C*variant*pt*nodeadkeys*Portuguese - Portuguese (no dead keys)
C*layout*br*Portuguese (Brazil)
C*variant*br**Portuguese (Brazil)
C*variant*br*nativo-epo*Portuguese (Brazil) - Esperanto (Brazil, Nativo)
C*variant*br*dvorak*Portuguese (Brazil) - Portuguese (Brazil, Dvorak)
C*variant*br*thinkpad*Portuguese (Brazil) - Portuguese (Brazil, IBM/Lenovo ThinkPad)
C*variant*br*nativo-us*Portuguese (Brazil) - Portuguese (Brazil, Nativo for US keyboards)
C*variant*br*nativo*Portuguese (Brazil) - Portuguese (Brazil, Nativo)
C*variant*br*nodeadkeys*Portuguese (Brazil) - Portuguese (Brazil, no dead keys)
C*variant*br*rus*Portuguese (Brazil) - Russian (Brazil, phonetic)
C*layout*ro*Romanian
C*variant*ro**Romanian
C*variant*ro*winkeys*Romanian - Romanian (Windows)
C*variant*ro*std*Romanian - Romanian (standard)
C*layout*ru*Russian
C*variant*ru**Russian
C*variant*ru*ab*Russian - Abkhazian (Russia)
C*variant*ru*bak*Russian - Bashkirian
C*variant*ru*cv*Russian - Chuvash
C*variant*ru*cv_latin*Russian - Chuvash (Latin)
C*variant*ru*xal*Russian - Kalmyk
C*variant*ru*kom*Russian - Komi
C*variant*ru*chm*Russian - Mari
C*variant*ru*os_winkeys*Russian - Ossetian (Windows)
C*variant*ru*os_legacy*Russian - Ossetian (legacy)
C*variant*ru*dos*Russian - Russian (DOS)
C*variant*ru*mac*Russian - Russian (Macintosh)
C*variant*ru*ruchey_en*Russian - Russian (engineering, EN)
C*variant*ru*ruchey_ru*Russian - Russian (engineering, RU)
C*variant*ru*legacy*Russian - Russian (legacy)
C*variant*ru*phonetic*Russian - Russian (phonetic)
C*variant*ru*phonetic_azerty*Russian - Russian (phonetic, AZERTY)
C*variant*ru*phonetic_dvorak*Russian - Russian (phonetic, Dvorak)
C*variant*ru*phonetic_winkeys*Russian - Russian (phonetic, Windows)
C*variant*ru*phonetic_YAZHERTY*Russian - Russian (phonetic, YAZHERTY)
C*variant*ru*typewriter*Russian - Russian (typewriter)
C*variant*ru*typewriter-legacy*Russian - Russian (typewriter, legacy)
C*variant*ru*srp*Russian - Serbian (Russia)
C*variant*ru*tt*Russian - Tatar
C*variant*ru*udm*Russian - Udmurt
C*variant*ru*sah*Russian - Yakut
C*layout*rs*Serbian
C*variant*rs**Serbian
C*variant*rs*rue*Serbian - Pannonian Rusyn
C*variant*rs*yz*Serbian - Serbian (Cyrillic, ZE and ZHE swapped)
C*variant*rs*alternatequotes*Serbian - Serbian (Cyrillic, with guillemets)
C*variant*rs*latin*Serbian - Serbian (Latin)
C*variant*rs*latinyz*Serbian - Serbian (Latin, QWERTY)
C*variant*rs*latinunicode*Serbian - Serbian (Latin, Unicode)
C*variant*rs*latinunicodeyz*Serbian - Serbian (Latin, Unicode, QWERTY)
C*variant*rs*latinalternatequotes*Serbian - Serbian (Latin, with guillemets)
C*layout*lk*Sinhala (phonetic)
C*variant*lk**Sinhala (phonetic)
C*variant*lk*us*Sinhala (phonetic) - Sinhala (US)
C*variant*lk*tam_unicode*Sinhala (phonetic) - Tamil (Sri Lanka, TamilNet 99)
C*variant*lk*tam_TAB*Sinhala (phonetic) - Tamil (Sri Lanka, TamilNet 99, TAB encoding)
C*layout*sk*Slovak
C*variant*sk**Slovak
C*variant*sk*qwerty*Slovak - Slovak (QWERTY)
C*variant*sk*qwerty_bksl*Slovak - Slovak (QWERTY, extra backslash)
C*variant*sk*bksl*Slovak - Slovak (extra backslash)
C*layout*si*Slovenian
C*variant*si**Slovenian
C*variant*si*us*Slovenian - Slovenian (US)
C*variant*si*alternatequotes*Slovenian - Slovenian (with guillemets)
C*layout*es*Spanish
C*variant*es**Spanish
C*variant*es*ast*Spanish - Asturian (Spain, with bottom-dot H and L)
C*variant*es*cat*Spanish - Catalan (Spain, with middle-dot L)
C*variant*es*dvorak*Spanish - Spanish (Dvorak)
C*variant*es*winkeys*Spanish - Spanish (Windows)
C*variant*es*deadtilde*Spanish - Spanish (dead tilde)
C*variant*es*nodeadkeys*Spanish - Spanish (no dead keys)
C*layout*latam*Spanish (Latin American)
C*variant*latam**Spanish (Latin American)
C*variant*latam*colemak*Spanish (Latin American) - Spanish (Latin American, Colemak)
C*variant*latam*dvorak*Spanish (Latin American) - Spanish (Latin American, Dvorak)
C*variant*latam*deadtilde*Spanish (Latin American) - Spanish (Latin American, dead tilde)
C*variant*latam*nodeadkeys*Spanish (Latin American) - Spanish (Latin American, no dead keys)
C*layout*ke*Swahili (Kenya)
C*variant*ke**Swahili (Kenya)
C*variant*ke*kik*Swahili (Kenya) - Kikuyu
C*layout*tz*Swahili (Tanzania)
C*variant*tz**Swahili (Tanzania)
C*layout*se*Swedish
C*variant*se**Swedish
C*variant*se*smi*Swedish - Northern Saami (Sweden)
C*variant*se*rus*Swedish - Russian (Sweden, phonetic)
C*variant*se*dvorak*Swedish - Swedish (Dvorak)
C*variant*se*us_dvorak*Swedish - Swedish (Dvorak, intl.)
C*variant*se*mac*Swedish - Swedish (Macintosh)
C*variant*se*svdvorak*Swedish - Swedish (Svdvorak)
C*variant*se*us*Swedish - Swedish (US)
C*variant*se*nodeadkeys*Swedish - Swedish (no dead keys)
C*variant*se*swl*Swedish - Swedish Sign Language
C*layout*ch*Switzerland
C*variant*ch**Switzerland
C*variant*ch*fr*Switzerland - French (Switzerland)
C*variant*ch*fr_mac*Switzerland - French (Switzerland, Macintosh)
C*variant*ch*fr_nodeadkeys*Switzerland - French (Switzerland, no dead keys)
C*variant*ch*de_mac*Switzerland - German (Switzerland, Macintosh)
C*variant*ch*legacy*Switzerland - German (Switzerland, legacy)
C*variant*ch*de_nodeadkeys*Switzerland - German (Switzerland, no dead keys)
C*layout*tw*Taiwanese
C*variant*tw**Taiwanese
C*variant*tw*saisiyat*Taiwanese - Saisiyat (Taiwan)
C*variant*tw*indigenous*Taiwanese - Taiwanese (indigenous)
C*layout*tj*Tajik
C*variant*tj**Tajik
C*variant*tj*legacy*Tajik - Tajik (legacy)
C*layout*th*Thai
C*variant*th**Thai
C*variant*th*pat*Thai - Thai (Pattachote)
C*variant*th*tis*Thai - Thai (TIS-820.2538)
C*layout*bw*Tswana
C*variant*bw**Tswana
C*layout*tr*Turkish
C*variant*tr**Turkish
C*variant*tr*ku_f*Turkish - Kurdish (Turkey, F)
C*variant*tr*ku_alt*Turkish - Kurdish (Turkey, Latin Alt-Q)
C*variant*tr*ku*Turkish - Kurdish (Turkey, Latin Q)
C*variant*tr*alt*Turkish - Turkish (Alt-Q)
C*variant*tr*e*Turkish - Turkish (E)
C*variant*tr*f*Turkish - Turkish (F)
C*variant*tr*intl*Turkish - Turkish (intl., with dead keys)
C*layout*tm*Turkmen
C*variant*tm**Turkmen
C*variant*tm*alt*Turkmen - Turkmen (Alt-Q)
C*layout*ua*Ukrainian
C*variant*ua**Ukrainian
C*variant*ua*crh_alt*Ukrainian - Crimean Tatar (Turkish Alt-Q)
C*variant*ua*crh_f*Ukrainian - Crimean Tatar (Turkish F)
C*variant*ua*crh*Ukrainian - Crimean Tatar (Turkish Q)
C*variant*ua*winkeys*Ukrainian - Ukrainian (Windows)
C*variant*ua*homophonic*Ukrainian - Ukrainian (homophonic)
C*variant*ua*legacy*Ukrainian - Ukrainian (legacy)
C*variant*ua*macOS*Ukrainian - Ukrainian (macOS)
C*variant*ua*phonetic*Ukrainian - Ukrainian (phonetic)
C*variant*ua*typewriter*Ukrainian - Ukrainian (typewriter)
C*layout*pk*Urdu (Pakistan)
C*variant*pk**Urdu (Pakistan)
C*variant*pk*ara*Urdu (Pakistan) - Arabic (Pakistan)
C*variant*pk*snd*Urdu (Pakistan) - Sindhi
C*variant*pk*urd-crulp*Urdu (Pakistan) - Urdu (Pakistan, CRULP)
C*variant*pk*urd-nla*Urdu (Pakistan) - Urdu (Pakistan, NLA)
C*layout*uz*Uzbek
C*variant*uz**Uzbek
C*variant*uz*latin*Uzbek - Uzbek (Latin)
C*layout*vn*Vietnamese
C*variant*vn**Vietnamese
C*variant*vn*fr*Vietnamese - Vietnamese (France)
C*variant*vn*us*Vietnamese - Vietnamese (US)
C*layout*sn*Wolof
C*variant*sn**Wolof
};
    return;
}

sub keyboard_present {
    my $kern;
    my $kbdpattern;
    my $class;
    my $subclass;
    my $protocol;
    $kern = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; };
if ("$kern" =~ /^2.0.*$/msx or "$kern" =~ /^2.1.*$/msx or "$kern" =~ /^2.2.*$/msx or "$kern" =~ /^2.3.*$/msx or "$kern" =~ /^2.4.*$/msx or "$kern" =~ /^2.5.*$/msx) {
        return q{0};    }
    if (!((-d '/sys/bus/usb/devices'))) {
        return q{0};    }
    my $d;
    for my $d ('/sys/bus/usb/devices/*:*') {
        if (!((-d "$d"))) {
            next;        }
        $class = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$d/bInterfaceClass" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$d/bInterfaceClass" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        $subclass = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$d/bInterfaceSubClass" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$d/bInterfaceSubClass" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        $protocol = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$d/bInterfaceProtocol" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$d/bInterfaceProtocol" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
if ("$class:$subclass:$protocol" =~ /^03:01:01$/msx) {
            return q{0};        }
    }
;
    if (!((-f '/proc/bus/input/devices'))) {
        return q{0};    }
    $kbdpattern = "AT Set \|AT Translated Set\|AT Raw Set";
    $kbdpattern = "$kbdpattern\|Atari Keyboard";
    $kbdpattern = "$kbdpattern\|Amiga Keyboard";
    $kbdpattern = "$kbdpattern\|HIL keyboard";
    $kbdpattern = "$kbdpattern\|ADB keyboard";
    $kbdpattern = "$kbdpattern\|Sun Type";
    $kbdpattern = "$kbdpattern\|bluetooth.*keyboard";
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
my $grep_result_5;
my @grep_lines_5 = ();
my @grep_filenames_5 = ();
if (-e "/proc/bus/input/devices") {
    open my $fh, '<', "/proc/bus/input/devices" or croak "Cannot access file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_5, $line;
        push @grep_filenames_5, "/proc/bus/input/devices";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/bus/input/devices: No such file or directory\n"; }
my @grep_filtered_5 = grep { /$kbdpattern/msxi } @grep_lines_5;
$grep_result_5 = join "\n", @grep_filtered_5;
        if (!($grep_result_5 =~ m{\n\z} || $grep_result_5 eq q{})) {
            $grep_result_5 .= "\n";
        }
print $grep_result_5;
$CHILD_ERROR = scalar @grep_filtered_5 > 0 ? 0 : 1;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };)) {
return q{0};
    }
return q{1};
    return;
}

sub ask_debconf {
    my ($template, $priority) = @_;
    my $template;
    my $priority;
    my $prefix;
    my $default_code;
    my $default_description;
    my $choices;
    my $add;
    $template = "$_[0]";
    $priority = "$_[1]";
    $prefix = (do { local $CHILD_ERROR = 0; do {
    do { do {
        my $output_6 = q{};
        my $output_printed_6;
        my $pipeline_success_6 = 1;
        $output_6 .= $_[2] . "\n";
        if ( !($output_6 =~ m{\n\z}) ) { $output_6 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_6 = 0; }

        my $cmd_8 = 'regex_pattern_escape';
        my ($in_7, $out_7);
        my $pid_7 = open3($in_7, $out_7, '>&STDERR', $cmd_8, );
        print {$in_7} $output_6;
        close $in_7 or croak 'Close failed: $OS_ERROR';
        $output_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
        close $out_7 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_7, 0;
        if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_6 =~ s/\n+\z//msx;
        $output_6;
}; };
}; });
    $default_code = (do { local $CHILD_ERROR = 0; do {
    do { do {
        my $output_9 = q{};
        my $output_printed_9;
        my $pipeline_success_9 = 1;
        $output_9 .= $_[3] . "\n";
        if ( !($output_9 =~ m{\n\z}) ) { $output_9 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_9 = 0; }

        my $cmd_11 = 'regex_pattern_escape';
        my ($in_10, $out_10);
        my $pid_10 = open3($in_10, $out_10, '>&STDERR', $cmd_11, );
        print {$in_10} $output_9;
        close $in_10 or croak 'Close failed: $OS_ERROR';
        $output_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
        close $out_10 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_10, 0;
        if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_9 =~ s/\n+\z//msx;
        $output_9;
}; };
}; });
    $add = (do { local $CHILD_ERROR = 0; do {
    do { do {
        my $output_12 = q{};
        my $output_printed_12;
        my $pipeline_success_12 = 1;
        $output_12 .= $_[4] . "\n";
        if ( !($output_12 =~ m{\n\z}) ) { $output_12 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_12 = 0; }

        my $cmd_14 = 'regex_escape';
        my ($in_13, $out_13);
        my $pid_13 = open3($in_13, $out_13, '>&STDERR', $cmd_14, );
        print {$in_13} $output_12;
        close $in_13 or croak 'Close failed: $OS_ERROR';
        $output_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
        close $out_13 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_13, 0;
        if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_12 =~ s/\n+\z//msx;
        $output_12;
}; };
}; });
    $add = "
$add";
    my $choices1 = do { local $CHILD_ERROR = 0; do {
    do { do {
        my $output_15 = q{};
        my $output_printed_15;
        my $pipeline_success_15 = 1;
        $output_15 .= $kbdnames . "\n";
        if ( !($output_15 =~ m{\n\z}) ) { $output_15 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_15 = 0; }
        my $grep_result_15_1;
        my @grep_lines_15_1 = split /\n/msx, $output_15;
        my @grep_filtered_15_1 = grep { /^$prefix[*]/msx } @grep_lines_15_1;
        $grep_result_15_1 = join "\n", @grep_filtered_15_1;
                if (!($grep_result_15_1 =~ m{\n\z} || $grep_result_15_1 eq q{})) {
                    $grep_result_15_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_15_1 > 0 ? 0 : 1;
        $output_15 = $grep_result_15_1;
        my @sed_lines_15 = split /\n/, $output_15;
        my @sed_result_15;
        foreach my $line (@sed_lines_15) {
        chomp $line;
        push @sed_result_15, $line;
        }
        $output_15 = join "\n", @sed_result_15;

        my @sort_lines_15_3 = split /\n/, $output_15;
        my @sort_sorted_15_3 = sort @sort_lines_15_3;
        $output_15 = join "\n", @sort_sorted_15_3;
                if ($output_15 ne q{} && !($output_15 =~ m{\n\z})) {
                    $output_15 .= "\n";
                }
        if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_15 =~ s/\n+\z//msx;
        $output_15;
}; };
}; };
    my $choices2 = do { local $CHILD_ERROR = 0; do {
    do { do {
        my $output_16 = q{};
        my $output_printed_16;
        my $pipeline_success_16 = 1;
        $output_16 .= $add . "\n";
        if ( !($output_16 =~ m{\n\z}) ) { $output_16 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_16 = 0; }
        my $grep_result_16_1;
        my @grep_lines_16_1 = split /\n/msx, $output_16;
        my @grep_filtered_16_1 = grep { /^$prefix[*]/msx } @grep_lines_16_1;
        $grep_result_16_1 = join "\n", @grep_filtered_16_1;
                if (!($grep_result_16_1 =~ m{\n\z} || $grep_result_16_1 eq q{})) {
                    $grep_result_16_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_16_1 > 0 ? 0 : 1;
        $output_16 = $grep_result_16_1;
        my @sed_lines_16 = split /\n/, $output_16;
        my @sed_result_16;
        foreach my $line (@sed_lines_16) {
        chomp $line;
        push @sed_result_16, $line;
        }
        $output_16 = join "\n", @sed_result_16;

        if ( !$pipeline_success_16 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_16 =~ s/\n+\z//msx;
        $output_16;
}; };
}; };
    $choices = do { local $CHILD_ERROR = 0; do {
    do { do {
        my $output_17 = q{};
        my $output_printed_17;
        my $pipeline_success_17 = 1;
        $output_17 .= "$choices1
        $choices2\n";
        if ( !($output_17 =~ m{\n\z}) ) { $output_17 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_17 = 0; }
        my @sed_lines_17 = split /\n/, $output_17;
        my @sed_result_17;
        foreach my $line (@sed_lines_17) {
        chomp $line;
        push @sed_result_17, $line;
        }
        $output_17 = join "\n", @sed_result_17;

        if ( !$pipeline_success_17 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_17 =~ s/\n+\z//msx;
        $output_17;
}; };
}; };
    $choices = do { local $CHILD_ERROR = 0; do {
    do { do {
        my $output_18 = q{};
        my $output_printed_18;
        my $pipeline_success_18 = 1;
        $output_18 .= $choices . "\n";
        if ( !($output_18 =~ m{\n\z}) ) { $output_18 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_18 = 0; }
        my @sed_lines_18 = split /\n/, $output_18;
        my @sed_result_18;
        foreach my $line (@sed_lines_18) {
        chomp $line;
        $line =~ s/, *$//gmsx;
        push @sed_result_18, $line;
        }
        $output_18 = join "\n", @sed_result_18;


        my $cmd_20 = 'regex_unescape';
        my ($in_19, $out_19);
        my $pid_19 = open3($in_19, $out_19, '>&STDERR', $cmd_20, );
        print {$in_19} $output_18;
        close $in_19 or croak 'Close failed: $OS_ERROR';
        $output_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19> };
        close $out_19 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_19, 0;
        if ( !$pipeline_success_18 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_18 =~ s/\n+\z//msx;
        $output_18;
}; };
}; };
    $choices = do { local $CHILD_ERROR = 0; do {
    do { do {
        my $output_21 = q{};
        my $output_printed_21;
        my $pipeline_success_21 = 1;
        $output_21 .= $choices . "\n";
        if ( !($output_21 =~ m{\n\z}) ) { $output_21 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_21 = 0; }
        my @sed_lines_21 = split /\n/, $output_21;
        my @sed_result_21;
        foreach my $line (@sed_lines_21) {
        chomp $line;
        $line =~ s/,$//gmsx;
        push @sed_result_21, $line;
        }
        $output_21 = join "\n", @sed_result_21;

        if ( !$pipeline_success_21 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_21 =~ s/\n+\z//msx;
        $output_21;
}; };
}; };
if (!(    # Original bash: echo "$choices" | grep '[^\\\\],' >/dev/null;
do {
        my $output_22 = q{};
        my $output_printed_22;
        my $pipeline_success_22 = 1;
        $output_22 .= $choices . "\n";
if ( !($output_22 =~ m{\n\z}) ) { $output_22 .= "\n"; }

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
        or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_23 = q{};
        my $grep_result_24;
        my @grep_lines_24 = split /\n/msx, $output_22;
        my @grep_filtered_24 = grep { /[^\\\[\]],/msx } @grep_lines_24;
        $grep_result_24 = join "\n", @grep_filtered_24;
        if (!($grep_result_24 =~ m{\n\z} || $grep_result_24 eq q{})) {
        $grep_result_24 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_24 > 0 ? 0 : 1;
        $tmp_redirect_23 = $grep_result_24;
        $tmp_redirect_23;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_22; }
        $output_printed_22 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_22 ) { $main_exit_code = 1; }
        };)) {
        $main_exit_code = system('db_subst', $template, 'CHOICES', "$choices") >> 8;
        $default_description = do { local $CHILD_ERROR = 0; do {
    do { do {
            my $output_25 = q{};
            my $output_printed_25;
            my $pipeline_success_25 = 1;
            $output_25 .= "$kbdnames$add\n";
            if ( !($output_25 =~ m{\n\z}) ) { $output_25 .= "\n"; }
            if ($CHILD_ERROR != 0) { $pipeline_success_25 = 0; }
            my $grep_result_25_1;
            my @grep_lines_25_1 = split /\n/msx, $output_25;
            my @grep_filtered_25_1 = grep { /^$prefix[*]"\ .\ ${default_code}\ .\ "[*]/msx } @grep_lines_25_1;
            $grep_result_25_1 = join "\n", @grep_filtered_25_1;
                        if (!($grep_result_25_1 =~ m{\n\z} || $grep_result_25_1 eq q{})) {
                            $grep_result_25_1 .= "\n";
                        }
            $CHILD_ERROR = scalar @grep_filtered_25_1 > 0 ? 0 : 1;
            $output_25 = $grep_result_25_1;
            my @sed_lines_25 = split /\n/, $output_25;
            my @sed_result_25;
            foreach my $line (@sed_lines_25) {
            chomp $line;
            push @sed_result_25, $line;
            }
            $output_25 = join "\n", @sed_result_25;


            my $cmd_27 = 'regex_unescape';
            my ($in_26, $out_26);
            my $pid_26 = open3($in_26, $out_26, '>&STDERR', $cmd_27, );
            print {$in_26} $output_25;
            close $in_26 or croak 'Close failed: $OS_ERROR';
            $output_25 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_26> };
            close $out_26 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_26, 0;
            if ( !$pipeline_success_25 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_25 =~ s/\n+\z//msx;
            $output_25;
}; };
}; };
if ("$default_description" eq q{}) {
            $default_description = do { local $CHILD_ERROR = 0; do {
    do { do {
                my $output_28 = q{};
                my $output_printed_28;
                my $pipeline_success_28 = 1;
                $output_28 .= "$kbdnames$add\n";
                if ( !($output_28 =~ m{\n\z}) ) { $output_28 .= "\n"; }
                if ($CHILD_ERROR != 0) { $pipeline_success_28 = 0; }
                my $grep_result_28_1;
                my @grep_lines_28_1 = split /\n/msx, $output_28;
                my @grep_filtered_28_1 = grep { /^$prefix[*][*]/msx } @grep_lines_28_1;
                $grep_result_28_1 = join "\n", @grep_filtered_28_1;
                                if (!($grep_result_28_1 =~ m{\n\z} || $grep_result_28_1 eq q{})) {
                                    $grep_result_28_1 .= "\n";
                                }
                $CHILD_ERROR = scalar @grep_filtered_28_1 > 0 ? 0 : 1;
                $output_28 = $grep_result_28_1;
                my @sed_lines_28 = split /\n/, $output_28;
                my @sed_result_28;
                foreach my $line (@sed_lines_28) {
                chomp $line;
                push @sed_result_28, $line;
                }
                $output_28 = join "\n", @sed_result_28;


                my $cmd_30 = 'regex_unescape';
                my ($in_29, $out_29);
                my $pid_29 = open3($in_29, $out_29, '>&STDERR', $cmd_30, );
                print {$in_29} $output_28;
                close $in_29 or croak 'Close failed: $OS_ERROR';
                $output_28 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_29> };
                close $out_29 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_29, 0;
                if ( !$pipeline_success_28 ) { $main_exit_code = 1; }
                exit $main_exit_code if $__set_e && $main_exit_code != 0;
                $output_28 =~ s/\n+\z//msx;
                $output_28;
}; };
}; };
        }
if ("$default_description" ne q{}) {
            db_default($template, "$default_description");
}
        else {
            if ("$default_code" ne q{}) {
                $priority = 'critical';
            }
        }
                $main_exit_code = system('db_input', $priority, $template) >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
;
                $main_exit_code = system('bash', 'db_go') >> 8;
        if ($CHILD_ERROR != 0) {
            return '255';        }
;
        $main_exit_code = system('db_get', $template) >> 8;
}
    else {
        if (!(($STATE > $old_state))) {
            return '255';        }
        $RET = do { local $CHILD_ERROR = 0; do {
    do { do {
            my $output_32 = q{};
            my $output_printed_32;
            my $pipeline_success_32 = 1;
            $output_32 .= $choices . "\n";
            if ( !($output_32 =~ m{\n\z}) ) { $output_32 .= "\n"; }
            if ($CHILD_ERROR != 0) { $pipeline_success_32 = 0; }
            my @sed_lines_32 = split /\n/, $output_32;
            my @sed_result_32;
            foreach my $line (@sed_lines_32) {
            chomp $line;
            $line =~ s/ *$//gmsx;
            push @sed_result_32, $line;
            }
            $output_32 = join "\n", @sed_result_32;

            if ( !$pipeline_success_32 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_32 =~ s/\n+\z//msx;
            $output_32;
}; };
}; };
    }
    $RET = do { local $CHILD_ERROR = 0; do {
    do { do {
        my $output_33 = q{};
        my $output_printed_33;
        my $pipeline_success_33 = 1;
        $output_33 .= $RET . "\n";
        if ( !($output_33 =~ m{\n\z}) ) { $output_33 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_33 = 0; }

        my $cmd_35 = 'regex_pattern_escape';
        my ($in_34, $out_34);
        my $pid_34 = open3($in_34, $out_34, '>&STDERR', $cmd_35, );
        print {$in_34} $output_33;
        close $in_34 or croak 'Close failed: $OS_ERROR';
        $output_33 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_34> };
        close $out_34 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_34, 0;
        if ( !$pipeline_success_33 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_33 =~ s/\n+\z//msx;
        $output_33;
}; };
}; };
    $RET = do { local $CHILD_ERROR = 0; do {
    do { do {
        my $output_36 = q{};
        my $output_printed_36;
        my $pipeline_success_36 = 1;
        $output_36 .= "$kbdnames$add\n";
        if ( !($output_36 =~ m{\n\z}) ) { $output_36 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_36 = 0; }
        my $grep_result_36_1;
        my @grep_lines_36_1 = split /\n/msx, $output_36;
        my @grep_filtered_36_1 = grep { /^$prefix[*][^[*]]*[*]/msx } @grep_lines_36_1;
        $grep_result_36_1 = join "\n", @grep_filtered_36_1;
                if (!($grep_result_36_1 =~ m{\n\z} || $grep_result_36_1 eq q{})) {
                    $grep_result_36_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_36_1 > 0 ? 0 : 1;
        $output_36 = $grep_result_36_1;
        my @sed_lines_36 = split /\n/, $output_36;
        my @sed_result_36;
        foreach my $line (@sed_lines_36) {
        chomp $line;
        $line =~ s/  */ /gmsx;
        push @sed_result_36, $line;
        }
        $output_36 = join "\n", @sed_result_36;

        my $grep_result_36_3;
        my @grep_lines_36_3 = split /\n/msx, $output_36;
        my @grep_filtered_36_3 = grep { /[*]$RET$/msx } @grep_lines_36_3;
        $grep_result_36_3 = join "\n", @grep_filtered_36_3;
                if (!($grep_result_36_3 =~ m{\n\z} || $grep_result_36_3 eq q{})) {
                    $grep_result_36_3 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_36_3 > 0 ? 0 : 1;
        $output_36 = $grep_result_36_3;
        my @sed_lines_36 = split /\n/, $output_36;
        my @sed_result_36;
        foreach my $line (@sed_lines_36) {
        chomp $line;
        push @sed_result_36, $line;
        }
        $output_36 = join "\n", @sed_result_36;


        my $cmd_38 = 'regex_unescape';
        my ($in_37, $out_37);
        my $pid_37 = open3($in_37, $out_37, '>&STDERR', $cmd_38, );
        print {$in_37} $output_36;
        close $in_37 or croak 'Close failed: $OS_ERROR';
        $output_36 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_37> };
        close $out_37 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_37, 0;
        if ( !$pipeline_success_36 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_36 =~ s/\n+\z//msx;
        $output_36;
}; };
}; };
return q{0};
    return;
}

sub guess_arch {
    my $arch;
    my $subarch;
    my $line;
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
my $_wa0 = 'archdetect';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };)) {
        $main_exit_code = system('bash', 'archdetect') >> 8;
return q{0};
    }
    $arch = do {
    my ($in_40, $out_40);
    my $pid_40 = open3($in_40, $out_40, '>&STDERR', 'dpkg', '--print-architecture');
    close $in_40 or croak 'Close failed: $OS_ERROR';
    my $result_40 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_40> };
    close $out_40 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_40, 0;
    $result_40
};
if (("$arch" eq 'powerpc' || "$arch" eq 'm68k')) {
if ("$arch" eq powerpc) {
            $line = do { my @_qx_cmd = (q{sed -n 's/^platform.*: *//p' /proc/cpuinfo}); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if (("$line" eq PS3 || "$line" eq Cell)) {
                $subarch = do { local $CHILD_ERROR = 0; do {
    do { do {
                    my $output_41 = q{};
                    my $output_printed_41;
                    my $pipeline_success_41 = 1;
                    $output_41 .= $line . "\n";
                    if ( !($output_41 =~ m{\n\z}) ) { $output_41 .= "\n"; }
                    if ($CHILD_ERROR != 0) { $pipeline_success_41 = 0; }
                    my $set1_42 = 'A-Z';
                    my $set2_42 = 'a-z';
                    my $input_42 = $output_41;;
}
            else {
                $line = do { my @_qx_cmd = (q{sed -n 's/^machine.*: *//p' /proc/cpuinfo}); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ("$line" eq '') {
                    say 'unknown';
return q{0};
                }
                $subarch = do { local $CHILD_ERROR = 0; do {
    do { do {
                    my $output_43 = q{};
                    my $output_printed_43;
                    my $pipeline_success_43 = 1;
                    $output_43 .= $line . "\n";
                    if ( !($output_43 =~ m{\n\z}) ) { $output_43 .= "\n"; }
                    if ($CHILD_ERROR != 0) { $pipeline_success_43 = 0; }
                    my $set1_44 = 'A-Z';
                    my $set2_44 = 'a-z';
                    my $input_44 = $output_43;;
            }
}
        else {
            if ("$arch" eq m68k) {
                $line = do { my @_qx_cmd = (q{sed -n 's/^Model.*: *//p' /proc/hardware}); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ("$line" eq '') {
                    say 'unknown';
return q{0};
                }
                $subarch = do { local $CHILD_ERROR = 0; do {
    do { do {
                    my $output_45 = q{};
                    my $output_printed_45;
                    my $pipeline_success_45 = 1;
                    $output_45 .= $line . "\n";
                    if ( !($output_45 =~ m{\n\z}) ) { $output_45 .= "\n"; }
                    if ($CHILD_ERROR != 0) { $pipeline_success_45 = 0; }
                    my $set1_46 = 'A-Z';
                    my $set2_46 = 'a-z';
                    my $input_46 = $output_45;;
            }
        }
if ("$subarch" =~ /^.*amiga.*$/msx) {
                        $subarch = 'amiga';
        } elsif ("$subarch" =~ /^.*chrp.*$/msx) {
                        $subarch = 'chrp';
        } elsif ("$subarch" =~ /^.*prep.*$/msx) {
                        $subarch = 'prep';
        } elsif ("$subarch" =~ /^.*macintosh.*$/msx or "$subarch" =~ /^.*powermac.*$/msx or "$subarch" =~ /^.*powerbook.*$/msx or "$subarch" =~ /^.*power.*$/msx or "$subarch" =~ /^.*imac.*$/msx or "$subarch" =~ /^.*powermac1.*$/msx) {
                        $subarch = 'mac';
        } elsif ("$subarch" =~ /^.*atari.*$/msx) {
                        $subarch = 'atari';
        } elsif ("$subarch" =~ /^.*motorola.*$/msx) {
                        $subarch = 'mvme';
        } elsif ("$subarch" =~ /^.*bvme.*$/msx) {
                        $subarch = 'bvme';
        } elsif (1) {
                        $subarch = do { local $CHILD_ERROR = 0; do {
    do { do {
                my $output_47 = q{};
                my $output_printed_47;
                my $pipeline_success_47 = 1;
                $output_47 .= $subarch . "\n";
                if ( !($output_47 =~ m{\n\z}) ) { $output_47 .= "\n"; }
                if ($CHILD_ERROR != 0) { $pipeline_success_47 = 0; }
                my @sed_lines_47 = split /\n/, $output_47;
                my @sed_result_47;
                foreach my $line (@sed_lines_47) {
                chomp $line;
                $line =~ s/^\s*//gmsx;
                push @sed_result_47, $line;
                }
                $output_47 = join "\n", @sed_result_47;

                if ( !$pipeline_success_47 ) { $main_exit_code = 1; }
                exit $main_exit_code if $__set_e && $main_exit_code != 0;
                $output_47 =~ s/\n+\z//msx;
                $output_47;
}; };
}; };
        }
        $arch = "$arch/$subarch";
    }
    say $arch;
return q{0};
    return;
}
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
my $_wa0 = 'locale';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};)) {
do { my $eval_input = do {
    my ($in_49, $out_49);
    my $pid_49 = open3($in_49, $out_49, '>&STDERR', 'locale');
    close $in_49 or croak 'Close failed: $OS_ERROR';
    my $result_49 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_49> };
    close $out_49 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_49, 0;
    $result_49
}; system('bash', '-c', $eval_input); $CHILD_ERROR = $? >> 8; };
}
my $locale;
if ((("$LC_CTYPE") && "$LC_CTYPE" ne C)) {
    $locale = $LC_CTYPE;
}
else {
    if ((!(system('db_get', 'debian-installer/locale') >> 8) && ("$RET"))) {
        $locale = "$RET";
}
    else {
        $locale = q{C};
    }
}
my $langcountry = "$locale";
my $lang;
if (do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('type', 'locale') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if ($CHILD_ERROR != 0) {
    ("$OVERRIDE_USE_DEBCONF_LOCALE")}) {
if ((!(system('db_get', 'localechooser/languagelist') >> 8) && ("$RET"))) {
        $lang = "$RET";
if ((!(system('db_get', 'debian-installer/country') >> 8) && ("$RET"))) {
            $langcountry = ${lang} . "_$RET";
        }
    }
}
my $messages;
if ((("$LC_MESSAGES") && "$LC_MESSAGES" ne C)) {
    $messages = $LC_MESSAGES;
}
else {
    if ((!(system('db_get', 'debian-installer/locale') >> 8) && ("$RET"))) {
        $messages = "$RET";
}
    else {
        $messages = q{C};
    }
}
my $messages_lang = do { local $CHILD_ERROR = 0; do {
    do { do {
    my $output_50 = q{};
    my $output_printed_50;
    my $pipeline_success_50 = 1;
    $output_50 .= $messages . "\n";
    if ( !($output_50 =~ m{\n\z}) ) { $output_50 .= "\n"; }
    if ($CHILD_ERROR != 0) { $pipeline_success_50 = 0; }
    my @sed_lines_50 = split /\n/, $output_50;
    my @sed_result_50;
    foreach my $line (@sed_lines_50) {
    chomp $line;
    $line =~ s/_.*//gmsx;
    push @sed_result_50, $line;
    }
    $output_50 = join "\n", @sed_result_50;

    if ( !$pipeline_success_50 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_50 =~ s/\n+\z//msx;
    $output_50;
}; };
}; };
my $messages_country = do { local $CHILD_ERROR = 0; do {
    do { do {
    my $output_51 = q{};
    my $output_printed_51;
    my $pipeline_success_51 = 1;
    $output_51 .= $messages . "\n";
    if ( !($output_51 =~ m{\n\z}) ) { $output_51 .= "\n"; }
    if ($CHILD_ERROR != 0) { $pipeline_success_51 = 0; }
    my @sed_lines_51 = split /\n/, $output_51;
    my @sed_result_51;
    foreach my $line (@sed_lines_51) {
    chomp $line;
    $line =~ s/.*_//gmsx;
    push @sed_result_51, $line;
    }
    $output_51 = join "\n", @sed_result_51;

    if ( !$pipeline_success_51 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_51 =~ s/\n+\z//msx;
    $output_51;
}; };
}; };
my $messages_modif = q{};
do {
    my $output_52 = q{};
    my $output_printed_52;
    my $pipeline_success_52 = 1;
    $output_52 .= $messages . "\n";
if ( !($output_52 =~ m{\n\z}) ) { $output_52 .= "\n"; }

        my $grep_result_52_1;
    my @grep_lines_52_1 = split /\n/msx, $output_52;
    my @grep_filtered_52_1 = grep { !/@/msx } @grep_lines_52_1;
    $grep_result_52_1 = join "\n", @grep_filtered_52_1;
    if (!($grep_result_52_1 =~ m{\n\z} || $grep_result_52_1 eq q{})) {
    $grep_result_52_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_52_1 > 0 ? 0 : 1;
    $grep_result_52_1 = q{};
    $output_52 = q{};
    if ((scalar @grep_filtered_52_1) == 0) {
        $pipeline_success_52 = 0;
    }
    if ($output_52 ne q{} && !defined $output_printed_52) {
        print $output_52;
        if (!($output_52 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_52 ) { $main_exit_code = 1; }
    }
if ($CHILD_ERROR != 0) {
        $messages_modif = do { local $CHILD_ERROR = 0; do {
    do { do {
        my $output_53 = q{};
        my $output_printed_53;
        my $pipeline_success_53 = 1;
        $output_53 .= $messages . "\n";
        if ( !($output_53 =~ m{\n\z}) ) { $output_53 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_53 = 0; }
        my @sed_lines_53 = split /\n/, $output_53;
        my @sed_result_53;
        foreach my $line (@sed_lines_53) {
        chomp $line;
        $line =~ s/.*@//gmsx;
        push @sed_result_53, $line;
        }
        $output_53 = join "\n", @sed_result_53;

        if ( !$pipeline_success_53 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_53 =~ s/\n+\z//msx;
        $output_53;
}; };
}; };
}

sub lang_kbdnames {
    my ($file) = @_;
    # Original bash: all_kbdnames | \
do {
        my $output_54 = q{};
        my $output_printed_54;
        my $pipeline_success_54 = 1;
                my ($in_55, $out_55);
        my $pid_55 = open3($in_55, $out_55, '>&STDERR', 'all_kbdnames', );
        close $in_55 or croak 'Close failed: $OS_ERROR';
        $output_54 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_55> };
        close $out_55 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_55, 0;

                my $cmd_57 = 'regex_escape';
        my ($in_56, $out_56);
        my $pid_56 = open3($in_56, $out_56, '>&STDERR', $cmd_57, );
        print {$in_56} $output_54;
        close $in_56 or croak 'Close failed: $OS_ERROR';
        $output_54 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_56> };
        close $out_56 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_56, 0;

                my $grep_result_54_2;
        my @grep_lines_54_2 = split /\n/msx, $output_54;
        my @grep_filtered_54_2 = grep { /^$_[0][*]/msx } @grep_lines_54_2;
        $grep_result_54_2 = join "\n", @grep_filtered_54_2;
        if (!($grep_result_54_2 =~ m{\n\z} || $grep_result_54_2 eq q{})) {
        $grep_result_54_2 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_54_2 > 0 ? 0 : 1;
        $output_54 = $grep_result_54_2;
        $output_54 = $grep_result_54_2;

                my @sed_lines_54 = split /\n/, $output_54;
        my @sed_result_54;
        foreach my $line (@sed_lines_54) {
        chomp $line;
        push @sed_result_54, $line;
        }
        $output_54 = join "\n", @sed_result_54;
        if ($output_54 ne q{} && !defined $output_printed_54) {
            print $output_54;
            if (!($output_54 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_54 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
;
    return;
}
$kbdnames = do {
    my ($in_58, $out_58);
    my $pid_58 = open3($in_58, $out_58, '>&STDERR', 'lang_kbdnames', $messages_lang, q{_}, $messages_country, '__', $messages_modif);
    close $in_58 or croak 'Close failed: $OS_ERROR';
    my $result_58 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_58> };
    close $out_58 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_58, 0;
    $result_58
};
if (!("$kbdnames" ne q{})) {
        $kbdnames = do {
    my ($in_59, $out_59);
    my $pid_59 = open3($in_59, $out_59, '>&STDERR', 'lang_kbdnames', $messages_lang, q{_}, $messages_country, '__', $messages_modif);
    close $in_59 or croak 'Close failed: $OS_ERROR';
    my $result_59 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_59> };
    close $out_59 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_59, 0;
    $result_59
};
}
if (!("$kbdnames" ne q{})) {
        $kbdnames = do {
    my ($in_60, $out_60);
    my $pid_60 = open3($in_60, $out_60, '>&STDERR', 'lang_kbdnames', $messages_lang, q{_}, $messages_country);
    close $in_60 or croak 'Close failed: $OS_ERROR';
    my $result_60 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_60> };
    close $out_60 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_60, 0;
    $result_60
};
}
if (!("$kbdnames" ne q{})) {
        $kbdnames = do {
    my ($in_61, $out_61);
    my $pid_61 = open3($in_61, $out_61, '>&STDERR', 'lang_kbdnames', $messages_lang);
    close $in_61 or croak 'Close failed: $OS_ERROR';
    my $result_61 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_61> };
    close $out_61 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_61, 0;
    $result_61
};
}
if (!("$kbdnames" ne q{})) {
        $kbdnames = do {
    my ($in_62, $out_62);
    my $pid_62 = open3($in_62, $out_62, '>&STDERR', 'lang_kbdnames', q{C});
    close $in_62 or croak 'Close failed: $OS_ERROR';
    my $result_62 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_62> };
    close $out_62 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_62, 0;
    $result_62
};
}
if (("$is_not_debian_installer")) {
if (        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
my $_wa0 = 'iconv';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        !($kbdnames = (do { local $CHILD_ERROR = 0; do {
    do { do {
            my $output_64 = q{};
            my $output_printed_64;
            my $pipeline_success_64 = 1;
            $output_64 .= $kbdnames . "\n";
            if ( !($output_64 =~ m{\n\z}) ) { $output_64 .= "\n"; }
            if ($CHILD_ERROR != 0) { $pipeline_success_64 = 0; }

            my $cmd_66 = 'iconv';
            my ($in_65, $out_65);
            my $pid_65 = open3($in_65, $out_65, '>&STDERR', $cmd_66, '-f', 'UTF-8', '-t', '//TRANSLIT');
            print {$in_65} $output_64;
            close $in_65 or croak 'Close failed: $OS_ERROR';
            $output_64 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_65> };
            close $out_65 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_65, 0;
            if ( !$pipeline_success_64 ) { $main_exit_code = 1; }
            $output_64 =~ s/\n+\z//msx;
            $output_64;
}; };
}; });)
    }) {
        $kbdnames = do {
    my ($in_67, $out_67);
    my $pid_67 = open3($in_67, $out_67, '>&STDERR', 'lang_kbdnames', q{C});
    close $in_67 or croak 'Close failed: $OS_ERROR';
    my $result_67 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_67> };
    close $out_67 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_67, 0;
    $result_67
};
    }
}
my $arch = do {
    my ($in_68, $out_68);
    my $pid_68 = open3($in_68, $out_68, '>&STDERR', 'guess_arch');
    close $in_68 or croak 'Close failed: $OS_ERROR';
    my $result_68 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_68> };
    close $out_68 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_68, 0;
    $result_68
};
my $model_priority;
if ("$arch" =~ /^alpha.*$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^amd64.*$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^arm.*$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^i386.*$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^hppa.*$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^ia64.*$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^m68k/amiga$/msx) {
        $XKBMODEL = 'amiga';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^m68k/atari$/msx) {
        $XKBMODEL = 'ataritt';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^m68k/mac$/msx) {
        $XKBMODEL = 'macintosh';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^m68k/sun.*$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'critical';
} elsif ("$arch" =~ /^m68k/.*vme.*$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^mips.*$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^powerpc/amiga$/msx) {
        $XKBMODEL = 'amiga';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^powerpc/apus$/msx) {
        $XKBMODEL = 'amiga';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^powerpc/chrp.*$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'critical';
} elsif ("$arch" =~ /^powerpc/mac$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^powerpc/pasemi$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^powerpc/powermac.*$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^powerpc/prep$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^powerpc/ps3$/msx or "$arch" =~ /^powerpc/cell$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^ppc64el/.*$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^sparc.*$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif ("$arch" =~ /^s390.*$/msx) {
        $XKBMODEL = 'pc105';
        $model_priority = 'medium';
} elsif (1) {
        $XKBMODEL = 'pc105';
        $model_priority = 'critical';
}
my $layout_priority = 'high';
if ("$langcountry" =~ /^.*_AL.*$/msx) {
        $XKBLAYOUT = 'al';
} elsif ("$langcountry" =~ /^.*_AZ.*$/msx) {
        $XKBLAYOUT = 'az';
} elsif ("$langcountry" =~ /^.*_BD.*$/msx) {
        $XKBLAYOUT = 'us,bd';
} elsif ("$langcountry" =~ /^.*_BE.*$/msx) {
        $XKBLAYOUT = 'be';
} elsif ("$langcountry" =~ /^.*_BG.*$/msx) {
        $XKBLAYOUT = 'us,bg';
        $layout_priority = 'critical';
} elsif ("$langcountry" =~ /^.*_BR.*$/msx) {
        $XKBLAYOUT = 'br';
} elsif ("$langcountry" =~ /^.*_BT.*$/msx) {
        $XKBLAYOUT = 'us,bt';
} elsif ("$langcountry" =~ /^.*_BY.*$/msx) {
        $XKBLAYOUT = 'us,by';
} elsif ("$langcountry" =~ /^fr_CA.*$/msx) {
        $XKBLAYOUT = 'ca';
} elsif ("$langcountry" =~ /^.*_CA.*$/msx) {
        $XKBLAYOUT = 'us';
} elsif ("$langcountry" =~ /^de_CH.*$/msx) {
        $XKBLAYOUT = 'ch';
} elsif ("$langcountry" =~ /^fr_CH.*$/msx) {
        $XKBLAYOUT = 'ch';
        $XKBVARIANT = 'fr';
} elsif ("$langcountry" =~ /^.*_CH.*$/msx) {
        $XKBLAYOUT = 'ch';
        $layout_priority = 'critical';
} elsif ("$langcountry" =~ /^.*_CZ.*$/msx) {
        $XKBLAYOUT = 'cz';
        $layout_priority = 'critical';
} elsif ("$langcountry" =~ /^.*_DK.*$/msx) {
        $XKBLAYOUT = 'dk';
} elsif ("$langcountry" =~ /^.*_EE.*$/msx) {
        $XKBLAYOUT = 'ee';
} elsif ("$langcountry" =~ /^ast_ES.*$/msx) {
        $XKBLAYOUT = 'es';
        $XKBVARIANT = 'ast';
} elsif ("$langcountry" =~ /^bo_.*$/msx) {
        $XKBLAYOUT = 'us,cn';
        $XKBVARIANT = ',tib';
} elsif ("$langcountry" =~ /^ca_ES.*$/msx) {
        $XKBLAYOUT = 'es';
        $XKBVARIANT = 'cat';
} elsif ("$langcountry" =~ /^.*_ES.*$/msx) {
        $XKBLAYOUT = 'es';
} elsif ("$langcountry" =~ /^.*_ET.*$/msx) {
        $XKBLAYOUT = 'us,et';
} elsif ("$langcountry" =~ /^se_FI.*$/msx) {
        $XKBLAYOUT = 'fi';
        $XKBVARIANT = 'smi';
} elsif ("$langcountry" =~ /^.*_FI.*$/msx) {
        $XKBLAYOUT = 'fi';
} elsif ("$langcountry" =~ /^.*_FR.*$/msx) {
        $XKBLAYOUT = 'fr';
        $XKBVARIANT = 'latin9';
} elsif ("$langcountry" =~ /^.*_GB.*$/msx) {
        $XKBLAYOUT = 'gb';
} elsif ("$langcountry" =~ /^.*_GG.*$/msx) {
        $XKBLAYOUT = 'gb';
} elsif ("$langcountry" =~ /^.*_HU.*$/msx) {
        $XKBLAYOUT = 'hu';
} elsif ("$langcountry" =~ /^.*_IE.*$/msx) {
        $XKBLAYOUT = 'ie';
} elsif ("$langcountry" =~ /^.*_IL.*$/msx) {
        $XKBLAYOUT = 'us,il';
        $layout_priority = 'critical';
} elsif ("$langcountry" =~ /^.*_IM.*$/msx) {
        $XKBLAYOUT = 'gb';
} elsif ("$langcountry" =~ /^.*_IR.*$/msx) {
        $XKBLAYOUT = 'us,ir';
} elsif ("$langcountry" =~ /^.*_IS.*$/msx) {
        $XKBLAYOUT = 'is';
} elsif ("$langcountry" =~ /^.*_IT.*$/msx) {
        $XKBLAYOUT = 'it';
} elsif ("$langcountry" =~ /^.*_JE.*$/msx) {
        $XKBLAYOUT = 'gb';
} elsif ("$langcountry" =~ /^.*_JP.*$/msx) {
        $XKBLAYOUT = 'jp';
} elsif ("$langcountry" =~ /^.*_LT.*$/msx) {
        $XKBLAYOUT = 'lt';
        $layout_priority = 'critical';
} elsif ("$langcountry" =~ /^.*_LV.*$/msx) {
        $XKBLAYOUT = 'lv';
} elsif ("$langcountry" =~ /^.*_KG.*$/msx) {
        $XKBLAYOUT = 'us,kg';
} elsif ("$langcountry" =~ /^.*_KH.*$/msx) {
        $XKBLAYOUT = 'us,kh';
} elsif ("$langcountry" =~ /^.*_KR.*$/msx) {
        $XKBLAYOUT = 'kr';
        $XKBVARIANT = 'kr104';
} elsif ("$langcountry" =~ /^.*_KZ.*$/msx) {
        $XKBLAYOUT = 'us,kz';
} elsif ("$langcountry" =~ /^.*_LK.*$/msx) {
        $XKBLAYOUT = 'us,lk';
} elsif ("$langcountry" =~ /^.*_MA.*$/msx) {
        $XKBLAYOUT = 'us,ma';
} elsif ("$langcountry" =~ /^.*_MK.*$/msx) {
        $XKBLAYOUT = 'us,mk';
} elsif ("$langcountry" =~ /^.*_NL.*$/msx) {
        $XKBLAYOUT = 'us';
        $XKBVARIANT = 'intl';
} elsif ("$langcountry" =~ /^.*_MM.*$/msx) {
        $XKBLAYOUT = 'us,mm';
} elsif ("$langcountry" =~ /^.*_MN.*$/msx) {
        $XKBLAYOUT = 'us,mn';
} elsif ("$langcountry" =~ /^.*_MT.*$/msx) {
        $XKBLAYOUT = 'mt';
        $layout_priority = 'critical';
} elsif ("$langcountry" =~ /^se_NO.*$/msx) {
        $XKBLAYOUT = 'no';
        $XKBVARIANT = 'smi';
} elsif ("$langcountry" =~ /^.*_NO.*$/msx) {
        $XKBLAYOUT = 'no';
} elsif ("$langcountry" =~ /^.*_NP.*$/msx) {
        $XKBLAYOUT = 'us,np';
} elsif ("$langcountry" =~ /^.*_PH.*$/msx) {
        $XKBLAYOUT = 'ph';
} elsif ("$langcountry" =~ /^.*_PL.*$/msx) {
        $XKBLAYOUT = 'pl';
} elsif ("$langcountry" =~ /^.*_PT.*$/msx) {
        $XKBLAYOUT = 'pt';
} elsif ("$langcountry" =~ /^.*_RO.*$/msx) {
        $XKBLAYOUT = 'ro';
} elsif ("$langcountry" =~ /^.*_RU.*$/msx) {
        $XKBLAYOUT = 'us,ru';
        $layout_priority = 'critical';
} elsif ("$langcountry" =~ /^se_SE.*$/msx) {
        $XKBLAYOUT = 'se';
        $XKBVARIANT = 'smi';
} elsif ("$langcountry" =~ /^.*_SK.*$/msx) {
        $XKBLAYOUT = 'sk';
} elsif ("$langcountry" =~ /^.*_SI.*$/msx) {
        $XKBLAYOUT = 'si';
} elsif ("$langcountry" =~ /^tg_.*$/msx) {
        $XKBLAYOUT = 'us,tj';
} elsif ("$langcountry" =~ /^.*_TJ.*$/msx) {
        $XKBLAYOUT = 'us,tj';
} elsif ("$langcountry" =~ /^.*_TH.*$/msx) {
        $XKBLAYOUT = 'us,th';
        $layout_priority = 'critical';
} elsif ("$langcountry" =~ /^ku_TR.*$/msx) {
        $XKBLAYOUT = 'tr';
        $XKBVARIANT = 'ku';
} elsif ("$langcountry" =~ /^.*_TR.*$/msx) {
        $XKBLAYOUT = 'tr';
        $layout_priority = 'critical';
} elsif ("$langcountry" =~ /^zh_TW.*$/msx) {
        $XKBLAYOUT = 'tw';
        $XKBVARIANT = 'indigenous';
} elsif ("$langcountry" =~ /^.*_UA.*$/msx) {
        $XKBLAYOUT = 'us,ua';
} elsif ("$langcountry" =~ /^en_US.*$/msx) {
        $XKBLAYOUT = 'us';
} elsif ("$langcountry" =~ /^.*_VN.*$/msx) {
        $XKBLAYOUT = 'us';
} elsif ("$langcountry" =~ /^.*_ZA.*$/msx) {
        $XKBLAYOUT = 'za';
} elsif ("$langcountry" =~ /^.*_AR.*$/msx or "$langcountry" =~ /^.*_BO.*$/msx or "$langcountry" =~ /^.*_CL.*$/msx or "$langcountry" =~ /^.*_CO.*$/msx or "$langcountry" =~ /^.*_CR.*$/msx or "$langcountry" =~ /^.*_DO.*$/msx or "$langcountry" =~ /^.*_EC.*$/msx or "$langcountry" =~ /^.*_GT.*$/msx or "$langcountry" =~ /^.*_HN.*$/msx or "$langcountry" =~ /^.*_MX.*$/msx or "$langcountry" =~ /^.*_NI.*$/msx or "$langcountry" =~ /^.*_PA.*$/msx or "$langcountry" =~ /^.*_PE.*$/msx or "$langcountry" =~ /^es_PR.*$/msx or "$langcountry" =~ /^.*_PY.*$/msx or "$langcountry" =~ /^.*_SV.*$/msx or "$langcountry" =~ /^es_US.*$/msx or "$langcountry" =~ /^.*_UY.*$/msx or "$langcountry" =~ /^.*_VE.*$/msx) {
        $XKBLAYOUT = 'latam';
} elsif ("$langcountry" =~ /^ar_.*$/msx) {
        $XKBLAYOUT = 'us,ara';
} elsif ("$langcountry" =~ /^bn_.*$/msx) {
        my $XKBLAYOUT = 'us,';
    $main_exit_code = system('bash', 'in') >> 8;
        $XKBVARIANT = ',ben';
} elsif ("$langcountry" =~ /^bs_.*$/msx) {
        $XKBLAYOUT = 'ba';
} elsif ("$langcountry" =~ /^de_LI.*$/msx) {
        $XKBLAYOUT = 'ch';
} elsif ("$langcountry" =~ /^de_.*$/msx) {
        $XKBLAYOUT = 'de';
} elsif ("$langcountry" =~ /^el_.*$/msx) {
        $XKBLAYOUT = 'us,gr';
} elsif ("$langcountry" =~ /^eo$/msx or "$langcountry" =~ /^eo..*$/msx or "$langcountry" =~ /^eo_.*$/msx or "$langcountry" =~ /^eo\@.*$/msx) {
        $XKBLAYOUT = 'epo';
        $layout_priority = 'critical';
} elsif ("$langcountry" =~ /^fr_.*$/msx) {
        $XKBLAYOUT = 'fr';
        $XKBVARIANT = 'oss';
        $layout_priority = 'critical';
} elsif ("$langcountry" =~ /^gu_.*$/msx) {
        $XKBLAYOUT = 'us,';
    $main_exit_code = system('bash', 'in') >> 8;
        $XKBVARIANT = ',guj';
} elsif ("$langcountry" =~ /^hi_.*$/msx) {
        $XKBLAYOUT = 'us,';
    $main_exit_code = system('bash', 'in') >> 8;
} elsif ("$langcountry" =~ /^hr_.*$/msx) {
        $XKBLAYOUT = 'hr';
} elsif ("$langcountry" =~ /^hy_.*$/msx) {
        $XKBLAYOUT = 'us,am';
} elsif ("$langcountry" =~ /^ka_.*$/msx) {
        $XKBLAYOUT = 'us,ge';
        $layout_priority = 'critical';
} elsif ("$langcountry" =~ /^kab_.*$/msx) {
        $XKBLAYOUT = 'dz';
        $XKBVARIANT = 'la';
} elsif ("$langcountry" =~ /^kn_.*$/msx) {
        $XKBLAYOUT = 'us,';
    $main_exit_code = system('bash', 'in') >> 8;
        $XKBVARIANT = ',kan';
} elsif ("$langcountry" =~ /^ku_.*$/msx) {
        $XKBLAYOUT = 'tr';
        $XKBVARIANT = 'ku';
        $layout_priority = 'critical';
} elsif ("$langcountry" =~ /^lo_.*$/msx) {
        $XKBLAYOUT = 'us,la';
} elsif ("$langcountry" =~ /^mr_.*$/msx) {
        $XKBLAYOUT = 'us,';
    $main_exit_code = system('bash', 'in') >> 8;
} elsif ("$langcountry" =~ /^ml_.*$/msx) {
        $XKBLAYOUT = 'us,';
    $main_exit_code = system('bash', 'in') >> 8;
        $XKBVARIANT = ',mal';
} elsif ("$langcountry" =~ /^my_.*$/msx) {
        $XKBLAYOUT = 'us,mm';
} elsif ("$langcountry" =~ /^ne_.*$/msx) {
        $XKBLAYOUT = 'us,np';
} elsif ("$langcountry" =~ /^os_.*$/msx) {
        $XKBLAYOUT = 'ru';
        $XKBVARIANT = 'os';
} elsif ("$langcountry" =~ /^pa_.*$/msx) {
        $XKBLAYOUT = 'us,';
    $main_exit_code = system('bash', 'in') >> 8;
        $XKBVARIANT = ',guru';
} elsif ("$langcountry" =~ /^si_.*$/msx) {
        $XKBLAYOUT = 'us,si';
        $XKBVARIANT = ',sin_phonetic';
} elsif ("$langcountry" =~ /^sr_.*$/msx) {
        $XKBLAYOUT = 'rs,rs';
        $XKBVARIANT = 'latin,';
        $layout_priority = 'critical';
} elsif ("$langcountry" =~ /^sv_.*$/msx) {
        $XKBLAYOUT = 'se';
} elsif ("$langcountry" =~ /^ta_.*$/msx) {
        $XKBLAYOUT = 'us,';
    $main_exit_code = system('bash', 'in') >> 8;
        $XKBVARIANT = ',tam';
} elsif ("$langcountry" =~ /^te_.*$/msx) {
        $XKBLAYOUT = 'us,';
    $main_exit_code = system('bash', 'in') >> 8;
        $XKBVARIANT = ',tel';
} elsif ("$langcountry" =~ /^tg_.*$/msx) {
        $XKBLAYOUT = 'us,tj';
} elsif ("$langcountry" =~ /^the_.*$/msx) {
        $XKBLAYOUT = 'us,np';
} elsif ("$langcountry" =~ /^tl_.*$/msx) {
        $XKBLAYOUT = 'ph';
} elsif ("$langcountry" =~ /^ug_.*$/msx) {
        $XKBLAYOUT = 'us,cn';
        $XKBVARIANT = ',ug';
} elsif ("$langcountry" =~ /^zh_.*$/msx) {
        $XKBLAYOUT = 'cn';
} elsif (1) {
        $XKBLAYOUT = 'us';
}
if ((!(system('db_get', 'keyboard-configuration/modelcode') >> 8) && ("$RET"))) {
    $XKBMODEL = "$RET";
}
if ((!(system('db_get', 'keyboard-configuration/layoutcode') >> 8) && ("$RET"))) {
if ("$RET" ne "$XKBLAYOUT") {
        $XKBVARIANT = q{};
    }
    $XKBLAYOUT = "$RET";
if ((!(system('db_fget', 'keyboard-configuration/layoutcode', 'seen') >> 8) && "$RET" eq true)) {
        $layout_priority = 'medium';
        $main_exit_code = system('db_set', 'console-setup/ask_detect', 'false') >> 8;
        $main_exit_code = system('db_fset', 'console-setup/ask_detect', 'seen', 'true') >> 8;
    }
}
if ((!(system('db_get', 'keyboard-configuration/variantcode') >> 8) && ("$RET"))) {
    $XKBVARIANT = "$RET";
}
if ((!(system('db_get', 'keyboard-configuration/optionscode') >> 8) && ("$RET"))) {
    $XKBOPTIONS = "$RET";
}
my $old_layout_priority;
my $di_keymap;
my $old_xkbvariant;
if ((!(system('db_get', 'debian-installer/keymap') >> 8) && ("$RET"))) {
    $di_keymap = (${RET} =~ s/^mac-usb-//sr =~ s/^mac-usb-//sr);
    $di_keymap = (${di_keymap} =~ s/-latin1$//sr =~ s/-latin1$//sr);
    $old_xkbvariant = "$XKBVARIANT";
    $XKBVARIANT = q{};
    $old_layout_priority = $layout_priority;
    $layout_priority = 'medium';
if ("$di_keymap" =~ /^be2$/msx) {
                $XKBLAYOUT = "be";
    } elsif ("$di_keymap" =~ /^bg$/msx) {
                $XKBLAYOUT = "us,bg";
    } elsif ("$di_keymap" =~ /^br$/msx) {
                $XKBLAYOUT = "us";
                $XKBVARIANT = "intl";
    } elsif ("$di_keymap" =~ /^br-abnt2$/msx) {
                $XKBLAYOUT = "br";
                $XKBVARIANT = "abnt2";
    } elsif ("$di_keymap" =~ /^by$/msx) {
                $XKBLAYOUT = "us,by";
    } elsif ("$di_keymap" =~ /^cf$/msx) {
                $XKBLAYOUT = "ca";
                $XKBVARIANT = "fr";
    } elsif ("$di_keymap" =~ /^croat$/msx) {
                $XKBLAYOUT = "hr";
    } elsif ("$di_keymap" =~ /^cz-lat2$/msx) {
                $XKBLAYOUT = "cz";
    } elsif ("$di_keymap" =~ /^de-latin1-nodeadkeys$/msx) {
                $XKBLAYOUT = "de";
                $XKBVARIANT = "nodeadkeys";
    } elsif ("$di_keymap" =~ /^de$/msx) {
                $XKBLAYOUT = "de";
    } elsif ("$di_keymap" =~ /^dvorak$/msx) {
                $XKBLAYOUT = "us";
                $XKBVARIANT = "dvorak";
    } elsif ("$di_keymap" =~ /^dk$/msx) {
                $XKBLAYOUT = "dk";
    } elsif ("$di_keymap" =~ /^es$/msx) {
                $XKBLAYOUT = "es";
    } elsif ("$di_keymap" =~ /^et$/msx) {
                $XKBLAYOUT = "ee";
    } elsif ("$di_keymap" =~ /^fi$/msx) {
                $XKBLAYOUT = "fi";
    } elsif ("$di_keymap" =~ /^fr-latin9$/msx) {
                $XKBLAYOUT = "fr";
                $XKBVARIANT = "latin9";
    } elsif ("$di_keymap" =~ /^fr_CH$/msx) {
                $XKBLAYOUT = "ch";
                $XKBVARIANT = "fr";
    } elsif ("$di_keymap" =~ /^fr$/msx) {
                $XKBLAYOUT = "fr";
    } elsif ("$di_keymap" =~ /^hebrew$/msx) {
                $XKBLAYOUT = "us,il";
    } elsif ("$di_keymap" =~ /^hu$/msx) {
                $XKBLAYOUT = "hu";
    } elsif ("$di_keymap" =~ /^gb$/msx) {
                $XKBLAYOUT = "gb";
    } elsif ("$di_keymap" =~ /^is$/msx) {
                $XKBLAYOUT = "is";
    } elsif ("$di_keymap" =~ /^it$/msx) {
                $XKBLAYOUT = "it";
    } elsif ("$di_keymap" =~ /^jp106$/msx) {
                $XKBLAYOUT = "jp";
                $XKBVARIANT = "106";
    } elsif ("$di_keymap" =~ /^kr$/msx or "$di_keymap" =~ /^kr106$/msx) {
                $XKBLAYOUT = "kr";
                $XKBVARIANT = q{};
    } elsif ("$di_keymap" =~ /^kr104$/msx) {
                $XKBLAYOUT = "kr";
                $XKBVARIANT = "kr104";
    } elsif ("$di_keymap" =~ /^la$/msx) {
                $XKBLAYOUT = "latam";
    } elsif ("$di_keymap" =~ /^lt$/msx) {
                $XKBLAYOUT = "lt";
    } elsif ("$di_keymap" =~ /^lv-latin4$/msx) {
                $XKBLAYOUT = "lv";
    } elsif ("$di_keymap" =~ /^mac-us-std$/msx) {
                $XKBLAYOUT = "us";
    } elsif ("$di_keymap" =~ /^mac-de2-ext$/msx) {
                $XKBLAYOUT = "de";
                $XKBVARIANT = "nodeadkeys";
    } elsif ("$di_keymap" =~ /^mac-fr2-ext$/msx) {
                $XKBLAYOUT = "fr";
    } elsif ("$di_keymap" =~ /^mac-fr3$/msx) {
                $XKBLAYOUT = "fr";
    } elsif ("$di_keymap" =~ /^mac-es$/msx) {
                $XKBLAYOUT = "es";
    } elsif ("$di_keymap" =~ /^ky$/msx) {
                $XKBLAYOUT = "us,kg";
    } elsif ("$di_keymap" =~ /^mk$/msx) {
                $XKBLAYOUT = "us,mk";
    } elsif ("$di_keymap" =~ /^nl$/msx) {
                $XKBLAYOUT = "nl";
    } elsif ("$di_keymap" =~ /^no$/msx) {
                $XKBLAYOUT = "no";
    } elsif ("$di_keymap" =~ /^pl$/msx) {
                $XKBLAYOUT = "pl";
    } elsif ("$di_keymap" =~ /^pt$/msx) {
                $XKBLAYOUT = "pt";
    } elsif ("$di_keymap" =~ /^ro$/msx) {
                $XKBLAYOUT = "ro";
    } elsif ("$di_keymap" =~ /^ru$/msx) {
                $XKBLAYOUT = "us,ru";
    } elsif ("$di_keymap" =~ /^se$/msx) {
                $XKBLAYOUT = "se";
    } elsif ("$di_keymap" =~ /^sg$/msx) {
                $XKBLAYOUT = "ch";
                $XKBVARIANT = "de";
    } elsif ("$di_keymap" =~ /^sk-qwerty$/msx) {
                $XKBLAYOUT = "sk";
                $XKBVARIANT = "qwerty";
    } elsif ("$di_keymap" =~ /^slovene$/msx) {
                $XKBLAYOUT = "si";
    } elsif ("$di_keymap" =~ /^sr-cy$/msx) {
                $XKBLAYOUT = "rs,rs";
                $XKBVARIANT = "latin,";
    } elsif ("$di_keymap" =~ /^trf$/msx or "$di_keymap" =~ /^trfu$/msx) {
                $XKBLAYOUT = "tr";
                $XKBVARIANT = "f";
    } elsif ("$di_keymap" =~ /^trq$/msx or "$di_keymap" =~ /^trqu$/msx) {
                $XKBLAYOUT = "tr";
    } elsif ("$di_keymap" =~ /^ua$/msx) {
                $XKBLAYOUT = "us,ua";
    } elsif ("$di_keymap" =~ /^uk$/msx) {
                $XKBLAYOUT = "gb";
    } elsif ("$di_keymap" =~ /^us$/msx) {
                $XKBLAYOUT = "us";
    } elsif (1) {
                $XKBVARIANT = "$old_xkbvariant";
                $layout_priority = $old_layout_priority;
    }
}
my $awk_expr;
if ((((-f '/etc/X11/xorg.conf') && (!-e $CONFIGFILE)) && !(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
my $_wa0 = 'awk';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
}))) {
    $awk_expr = "\n{\n    sub(\";
do { my $eval_input = do { my @_qx_cmd = ("awk \"$awk_expr\" < /etc/X11/xorg.conf"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; system('bash', '-c', $eval_input); $CHILD_ERROR = $? >> 8; };
}
read_config($OLDCONFIGFILE);
read_config($CONFIGFILE);
$XKBMODEL = do { local $CHILD_ERROR = 0; do {
    do { do {
    my $output_70 = q{};
    my $output_printed_70;
    my $pipeline_success_70 = 1;
    $output_70 .= $XKBMODEL . "\n";
    if ( !($output_70 =~ m{\n\z}) ) { $output_70 .= "\n"; }
    if ($CHILD_ERROR != 0) { $pipeline_success_70 = 0; }
    my @sed_lines_70 = split /\n/, $output_70;
    my @sed_result_70;
    foreach my $line (@sed_lines_70) {
    chomp $line;
    $line =~ s/ *//gmsx;
    push @sed_result_70, $line;
    }
    $output_70 = join "\n", @sed_result_70;

    if ( !$pipeline_success_70 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_70 =~ s/\n+\z//msx;
    $output_70;
}; };
}; };
$XKBLAYOUT = do { local $CHILD_ERROR = 0; do {
    do { do {
    my $output_71 = q{};
    my $output_printed_71;
    my $pipeline_success_71 = 1;
    $output_71 .= $XKBLAYOUT . "\n";
    if ( !($output_71 =~ m{\n\z}) ) { $output_71 .= "\n"; }
    if ($CHILD_ERROR != 0) { $pipeline_success_71 = 0; }
    my @sed_lines_71 = split /\n/, $output_71;
    my @sed_result_71;
    foreach my $line (@sed_lines_71) {
    chomp $line;
    $line =~ s/ *//gmsx;
    push @sed_result_71, $line;
    }
    $output_71 = join "\n", @sed_result_71;

    if ( !$pipeline_success_71 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_71 =~ s/\n+\z//msx;
    $output_71;
}; };
}; };
$XKBVARIANT = do { local $CHILD_ERROR = 0; do {
    do { do {
    my $output_72 = q{};
    my $output_printed_72;
    my $pipeline_success_72 = 1;
    $output_72 .= $XKBVARIANT . "\n";
    if ( !($output_72 =~ m{\n\z}) ) { $output_72 .= "\n"; }
    if ($CHILD_ERROR != 0) { $pipeline_success_72 = 0; }
    my @sed_lines_72 = split /\n/, $output_72;
    my @sed_result_72;
    foreach my $line (@sed_lines_72) {
    chomp $line;
    $line =~ s/ *//gmsx;
    push @sed_result_72, $line;
    }
    $output_72 = join "\n", @sed_result_72;

    if ( !$pipeline_success_72 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_72 =~ s/\n+\z//msx;
    $output_72;
}; };
}; };
if ("$XKBMODEL" eq q{}) {
    $model_priority = 'critical';
    $XKBMODEL = 'pc105';
    $main_exit_code = system('db_fset', 'keyboard-configuration/model', 'seen', 'false') >> 8;
}
if ("$XKBLAYOUT" eq q{}) {
    $layout_priority = 'critical';
    $XKBLAYOUT = 'us';
    $main_exit_code = system('db_fset', 'keyboard-configuration/layout', 'seen', 'false') >> 8;
    $main_exit_code = system('db_fset', 'keyboard-configuration/variant', 'seen', 'false') >> 8;
}
if (keyboard_present()) {
    $main_exit_code = system('db_set', 'keyboard-configuration/modelcode', "$XKBMODEL") >> 8;
    $main_exit_code = system('db_set', 'keyboard-configuration/layoutcode', "$XKBLAYOUT") >> 8;
    $main_exit_code = system('db_set', 'keyboard-configuration/variantcode', "$XKBVARIANT") >> 8;
if (("$XKBOPTIONS" eq q{} && (!-f $CONFIGFILE))) {
if ("$XKBLAYOUT" =~ /^.*,.*$/msx) {
                        $XKBOPTIONS = "grp_led:scroll";
        } elsif ("$XKBLAYOUT" =~ /^us$/msx) {
                        $XKBOPTIONS = "";
        } elsif (1) {
                        $XKBOPTIONS = "lv3:ralt_switch";
        }
    }
    $main_exit_code = system('db_set', 'keyboard-configuration/optionscode', "$XKBOPTIONS") >> 8;
exit 0;
}
my $debconf_model = "$XKBMODEL";
if (("$XKBLAYOUT")) {
if ("$XKBLAYOUT" =~ /^lt,us$/msx) {
                $debconf_layout = (scalar reverse( (scalar reverse ${XKBLAYOUT}) =~ s/^.*?,//r ) =~ s/,.*?$//r);
                $debconf_variant = (scalar reverse( (scalar reverse ${XKBVARIANT}) =~ s/^.*?,//r ) =~ s/,.*?$//r);
                $unsupported_layout = 'no';
    } elsif ("$XKBLAYOUT" =~ /^rs,rs$/msx or "$XKBLAYOUT" =~ /^us,rs$/msx or "$XKBLAYOUT" =~ /^jp,jp$/msx or "$XKBLAYOUT" =~ /^us,jp$/msx) {
                $debconf_layout = (${XKBLAYOUT} =~ s/^.*?,//r =~ s/^.*?,//r);
                $debconf_variant = (${XKBVARIANT} =~ s/^.*?,//r =~ s/^.*?,//r);
                $unsupported_layout = 'no';
    } elsif ("$XKBLAYOUT" =~ /^us,am$/msx or "$XKBLAYOUT" =~ /^us,af$/msx or "$XKBLAYOUT" =~ /^us,ara$/msx or "$XKBLAYOUT" =~ /^us,ben$/msx or "$XKBLAYOUT" =~ /^us,bd$/msx or "$XKBLAYOUT" =~ /^us,bg$/msx or "$XKBLAYOUT" =~ /^us,bt$/msx or "$XKBLAYOUT" =~ /^us,by$/msx or "$XKBLAYOUT" =~ /^us,cn$/msx or "$XKBLAYOUT" =~ /^us,et$/msx or "$XKBLAYOUT" =~ /^us,ge$/msx or "$XKBLAYOUT" =~ /^us,gh$/msx or "$XKBLAYOUT" =~ /^us,gr$/msx or "$XKBLAYOUT" =~ /^us,guj$/msx or "$XKBLAYOUT" =~ /^us,guru$/msx or "$XKBLAYOUT" =~ /^us,il$/msx or "$XKBLAYOUT" =~ /^us,in$/msx or "$XKBLAYOUT" =~ /^us,ir$/msx or "$XKBLAYOUT" =~ /^us,iku$/msx or "$XKBLAYOUT" =~ /^us,iq$/msx or "$XKBLAYOUT" =~ /^us,ir$/msx or "$XKBLAYOUT" =~ /^us,kan$/msx or "$XKBLAYOUT" =~ /^us,kh$/msx or "$XKBLAYOUT" =~ /^us,kz$/msx or "$XKBLAYOUT" =~ /^us,la$/msx or "$XKBLAYOUT" =~ /^us,lao$/msx or "$XKBLAYOUT" =~ /^us,lk$/msx or "$XKBLAYOUT" =~ /^us,lt$/msx or "$XKBLAYOUT" =~ /^us,kg$/msx or "$XKBLAYOUT" =~ /^us,ma$/msx or "$XKBLAYOUT" =~ /^us,mal$/msx or "$XKBLAYOUT" =~ /^us,mk$/msx or "$XKBLAYOUT" =~ /^us,mm$/msx or "$XKBLAYOUT" =~ /^us,mn$/msx or "$XKBLAYOUT" =~ /^us,mv$/msx or "$XKBLAYOUT" =~ /^us,np$/msx or "$XKBLAYOUT" =~ /^us,ori$/msx or "$XKBLAYOUT" =~ /^us,pk$/msx or "$XKBLAYOUT" =~ /^us,ru$/msx or "$XKBLAYOUT" =~ /^us,scc$/msx or "$XKBLAYOUT" =~ /^us,sy$/msx or "$XKBLAYOUT" =~ /^us,syr$/msx or "$XKBLAYOUT" =~ /^us,tel$/msx or "$XKBLAYOUT" =~ /^us,th$/msx or "$XKBLAYOUT" =~ /^us,tj$/msx or "$XKBLAYOUT" =~ /^us,tam$/msx or "$XKBLAYOUT" =~ /^us,tib$/msx or "$XKBLAYOUT" =~ /^us,ua$/msx or "$XKBLAYOUT" =~ /^us,ug$/msx or "$XKBLAYOUT" =~ /^us,uz$/msx) {
        if ("${XKBVARIANT%,*}" eq '') {
            $debconf_layout = (${XKBLAYOUT} =~ s/^.*?,//r =~ s/^.*?,//r);
            $debconf_variant = (${XKBVARIANT} =~ s/^.*?,//r =~ s/^.*?,//r);
            $unsupported_layout = 'no';
}
        else {
            $unsupported_layout = 'yes';
        }
    } elsif ("$XKBLAYOUT" =~ /^.*,.*$/msx) {
                $unsupported_layout = 'yes';
    } elsif (1) {
                $debconf_layout = "$XKBLAYOUT";
                $debconf_variant = "$XKBVARIANT";
                $unsupported_layout = 'no';
    }
}
if (# Original bash: echo "$kbdnames" \
do {
    my $output_73 = q{};
    my $output_printed_73;
    my $pipeline_success_73 = 1;
    $output_73 .= $kbdnames . "\n";
if ( !($output_73 =~ m{\n\z}) ) { $output_73 .= "\n"; }

        do {
    open my $original_stdout, '>&', STDOUT
    or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
    or die "Cannot access file: $OS_ERROR\n";
    my $tmp = do {
    my $tmp_redirect_74 = q{};
    my $grep_result_75;
    my @grep_lines_75 = split /\n/msx, $output_73;
    my @grep_filtered_75 = grep { /variant[*]$debconf_layout[*]$debconf_variant[*]/msx } @grep_lines_75;
    $grep_result_75 = join "\n", @grep_filtered_75;
    if (!($grep_result_75 =~ m{\n\z} || $grep_result_75 eq q{})) {
    $grep_result_75 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_75 > 0 ? 0 : 1;
    $tmp_redirect_74 = $grep_result_75;
    $tmp_redirect_74;
    };
    print $tmp;
    if ($tmp eq q{}) { print $output_73; }
    $output_printed_73 = 1;
    open STDOUT, '>&', $original_stdout
    or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
    or die "Close failed: $OS_ERROR\n";
    };
    if ( !$pipeline_success_73 ) { $main_exit_code = 1; }
    }) {
    $unsupported_layout = 'yes';
    $debconf_variant = q{};
if (    # Original bash: echo "$kbdnames" \
do {
        my $output_76 = q{};
        my $output_printed_76;
        my $pipeline_success_76 = 1;
        $output_76 .= $kbdnames . "\n";
if ( !($output_76 =~ m{\n\z}) ) { $output_76 .= "\n"; }

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
        or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_77 = q{};
        my $grep_result_78;
        my @grep_lines_78 = split /\n/msx, $output_76;
        my @grep_filtered_78 = grep { /layout[*]$debconf_layout[*]/msx } @grep_lines_78;
        $grep_result_78 = join "\n", @grep_filtered_78;
        if (!($grep_result_78 =~ m{\n\z} || $grep_result_78 eq q{})) {
        $grep_result_78 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_78 > 0 ? 0 : 1;
        $tmp_redirect_77 = $grep_result_78;
        $tmp_redirect_77;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_76; }
        $output_printed_76 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_76 ) { $main_exit_code = 1; }
        }) {
        $debconf_layout = 'us';
    }
}
$debconf_toggle = 'No toggling';
$debconf_switch = 'No temporary switch';
$debconf_altgr = 'The default for the keyboard layout';
$debconf_compose = 'No compose key';
my $debconf_ctrl_alt_bksp = 'false';
if (("$XKBOPTIONS")) {
    $debconf_toggle = 'No toggling';
    $debconf_switch = 'No temporary switch';
    $debconf_altgr = 'The default for the keyboard layout';
    $debconf_compose = 'No compose key';
    my $option;
    for my $option (do { local $CHILD_ERROR = 0; do {
    do { do {
        my $output_79 = q{};
        my $output_printed_79;
        my $pipeline_success_79 = 1;
        $output_79 .= $XKBOPTIONS . "\n";
        if ( !($output_79 =~ m{\n\z}) ) { $output_79 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_79 = 0; }
        my @sed_lines_79 = split /\n/, $output_79;
        my @sed_result_79;
        foreach my $line (@sed_lines_79) {
        chomp $line;
        $line =~ s/,/ /gmsx;
        push @sed_result_79, $line;
        }
        $output_79 = join "\n", @sed_result_79;

        if ( !$pipeline_success_79 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_79 =~ s/\n+\z//msx;
        $output_79;
}; };
}; }) {
if ("$option" =~ /^compose:caps$/msx) {
                        $debconf_compose = 'Caps Lock';
        } elsif ("$option" =~ /^compose:lwin$/msx) {
                        $debconf_compose = 'Left Logo key';
        } elsif ("$option" =~ /^compose:menu$/msx) {
                        $debconf_compose = 'Menu key';
        } elsif ("$option" =~ /^compose:ralt$/msx) {
                        $debconf_compose = 'Right Alt (AltGr)';
        } elsif ("$option" =~ /^compose:rctrl$/msx) {
                        $debconf_compose = 'Right Control';
        } elsif ("$option" =~ /^compose:rwin$/msx) {
                        $debconf_compose = 'Right Logo key';
        } elsif ("$option" =~ /^grp:alt_caps_toggle$/msx) {
                        $debconf_toggle = 'Alt+Caps Lock';
        } elsif ("$option" =~ /^grp:alt_shift_toggle$/msx) {
                        $debconf_toggle = 'Alt+Shift';
        } elsif ("$option" =~ /^grp:caps_toggle$/msx) {
                        $debconf_toggle = 'Caps Lock';
        } elsif ("$option" =~ /^grp:ctrl_alt_toggle$/msx) {
                        $debconf_toggle = 'Control+Alt';
        } elsif ("$option" =~ /^grp:ctrl_shift_toggle$/msx) {
                        $debconf_toggle = 'Control+Shift';
        } elsif ("$option" =~ /^grp:lalt_toggle$/msx) {
                        $debconf_toggle = 'Left Alt';
        } elsif ("$option" =~ /^grp:lctrl_lshift_toggle$/msx) {
                        $debconf_toggle = 'Left Control+Left Shift';
        } elsif ("$option" =~ /^grp:lctrl_toggle$/msx) {
                        $debconf_toggle = 'Left Control';
        } elsif ("$option" =~ /^grp:lshift_toggle$/msx) {
                        $debconf_toggle = 'Left Shift';
        } elsif ("$option" =~ /^grp:lswitch$/msx) {
                        $debconf_switch = 'Left Alt';
        } elsif ("$option" =~ /^grp:lwin_switch$/msx) {
                        $debconf_switch = 'Left Logo key';
        } elsif ("$option" =~ /^grp:lwin_toggle$/msx) {
                        $debconf_toggle = 'Left Logo key';
        } elsif ("$option" =~ /^grp:menu_toggle$/msx) {
                        $debconf_toggle = 'Menu key';
        } elsif ("$option" =~ /^grp:rctrl_toggle$/msx) {
                        $debconf_toggle = 'Right Control';
        } elsif ("$option" =~ /^grp:rshift_toggle$/msx) {
                        $debconf_toggle = 'Right Shift';
        } elsif ("$option" =~ /^grp:rwin_switch$/msx) {
                        $debconf_switch = 'Right Logo key';
        } elsif ("$option" =~ /^grp:rwin_toggle$/msx) {
                        $debconf_toggle = 'Right Logo key';
        } elsif ("$option" =~ /^grp:sclk_toggle$/msx) {
                        $debconf_toggle = 'Scroll Lock key';
        } elsif ("$option" =~ /^grp:switch$/msx) {
                        $debconf_switch = 'Right Alt (AltGr)';
        } elsif ("$option" =~ /^grp:toggle$/msx) {
                        $debconf_toggle = 'Right Alt (AltGr)';
        } elsif ("$option" =~ /^grp:win_switch$/msx) {
                        $debconf_switch = 'Both Logo keys';
        } elsif ("$option" =~ /^lv3:ralt_alt$/msx) {
                        $debconf_altgr = 'No AltGr key';
        } elsif ("$option" =~ /^lv3:alt_switch$/msx) {
                        $debconf_altgr = 'Both Alt keys';
        } elsif ("$option" =~ /^lv3:enter_switch$/msx) {
                        $debconf_altgr = 'Keypad Enter key';
        } elsif ("$option" =~ /^lv3:lalt_switch$/msx) {
                        $debconf_altgr = 'Left Alt';
        } elsif ("$option" =~ /^lv3:lwin_switch$/msx) {
                        $debconf_altgr = 'Left Logo key';
        } elsif ("$option" =~ /^lv3:menu_switch$/msx) {
                        $debconf_altgr = 'Menu key';
        } elsif ("$option" =~ /^lv3:ralt_switch$/msx) {
                        $debconf_altgr = 'Right Alt (AltGr)';
        } elsif ("$option" =~ /^lv3:rwin_switch$/msx) {
                        $debconf_altgr = 'Right Logo key';
        } elsif ("$option" =~ /^lv3:switch$/msx) {
                        $debconf_altgr = 'Right Control';
        } elsif ("$option" =~ /^lv3:win_switch$/msx) {
                        $debconf_altgr = 'Both Logo keys';
        } elsif ("$option" =~ /^terminate:ctrl_alt_bksp$/msx) {
                        $debconf_ctrl_alt_bksp = 'true';
        } elsif ("$option" =~ /^grp_led:scroll$/msx) {
        } elsif (1) {
                        $unsupported_options = 'yes';
        }
    }
;
}
db_default('keyboard-configuration/toggle', "$debconf_toggle");
db_default('keyboard-configuration/switch', "$debconf_switch");
db_default('keyboard-configuration/altgr', "$debconf_altgr");
db_default('keyboard-configuration/compose', "$debconf_compose");
db_default('keyboard-configuration/ctrl_alt_bksp', "$debconf_ctrl_alt_bksp");
$STATE = q{1};
$old_state = q{0};
my $adjust_layout;
my $terminate;
my $variant;
my $starting_state;
my $rshift_allocated;
my $options;
my $template;
my $lctrl_allocated;
my $leds;
my $lshift_allocated;
while ( $main_exit_code = system('bash', ':') >> 8 ) {
    $starting_state = $STATE;
if ("$STATE" =~ /^1$/msx) {
        if (("$is_debian_installer")) {
            $main_exit_code = system('db_set', 'keyboard-configuration/modelcode', "$debconf_model") >> 8;
            $main_exit_code = system('db_fset', 'keyboard-configuration/model', 'seen', 'true') >> 8;
            if (defined $STATE) {
                $STATE = eval { int( $STATE + $STATE - $old_state ) } // "";
            }
}
        else {
if (!(            ask_debconf(template => 'keyboard-configuration/model', priority => $model_priority, 'model', "$debconf_model"))) {
                $debconf_model = "$RET";
                $main_exit_code = system('db_set', 'keyboard-configuration/modelcode', "$RET") >> 8;
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
    } elsif ("$STATE" =~ /^2$/msx) {
        if (((!(        $CHILD_ERROR = 0) && "$XKBMODEL" ne SKIP) && (-e "/usr/share/console-setup-mini/$XKBMODEL.tree"))) {
                        $main_exit_code = system('db_input', 'high', 'console-setup/ask_detect') >> 8;
            if ($CHILD_ERROR != 0) {
                1;
            }
;
if (!(system('bash', 'db_go') >> 8)) {
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
        else {
            if (defined $STATE) {
                $STATE = eval { int($STATE + $STATE - $old_state) } // "";
            }
        }
    } elsif ("$STATE" =~ /^3$/msx) {
        if ((((((($STATE >= $old_state) && !(        $CHILD_ERROR = 0)) && "$XKBMODEL" ne SKIP) && (-e "/usr/share/console-setup-mini/$XKBMODEL.tree")) && !(system('db_get', 'console-setup/ask_detect') >> 8)) && "$RET" eq true)) {
            $main_exit_code = system('db_subst', 'console-setup/detect', 'FILENAME', "/usr/share/console-setup-mini/$XKBMODEL.tree") >> 8;
if ((!(system('db_input', 'critical', 'console-setup/detect') >> 8) && !(system('bash', 'db_go') >> 8))) {
                $main_exit_code = system('db_get', 'console-setup/detect') >> 8;
                $detected_keyboard = "$RET";
                $main_exit_code = system('db_subst', 'console-setup/detected', 'LAYOUT', "$detected_keyboard") >> 8;
                                $main_exit_code = system('db_input', 'high', 'console-setup/detected') >> 8;
                if ($CHILD_ERROR != 0) {
                    1;
                }
;
if (!(system('bash', 'db_go') >> 8)) {
                    $unsupported_layout = 'no';
                    if (defined $STATE) {
                        $STATE = eval { int($STATE + 1) } // "";
                    }
}
                else {
                    $detected_keyboard = q{};
                    if (defined $STATE) {
                        $STATE = eval { int($STATE - 1) } // "";
                    }
                }
}
            else {
                if (defined $STATE) {
                    $STATE = eval { int($STATE - 1) } // "";
                }
            }
}
        else {
            $detected_keyboard = q{};
            if (defined $STATE) {
                $STATE = eval { int($STATE + $STATE - $old_state) } // "";
            }
        }
    } elsif ("$STATE" =~ /^4$/msx) {
        if ((("$detected_keyboard") || "$XKBMODEL" eq SKIP)) {
            if (defined $STATE) {
                $STATE = eval { int( $STATE + $STATE - $old_state ) } // "";
            }
}
        else {
            if ("$unsupported_layout" eq yes) {
if ((-f $CONFIGFILE)) {
                    $template = 'keyboard-configuration/unsupported_config_layout';
}
                else {
                    $template = 'keyboard-configuration/unsupported_layout';
if ("$XKBVARIANT" =~ /^,$/msx or "$XKBVARIANT" =~ /^,,$/msx or "$XKBVARIANT" =~ /^,,,$/msx or "$XKBVARIANT" =~ /^$/msx) {
                                                $main_exit_code = system('db_subst', $template, 'XKBLAYOUTVARIANT', "$XKBLAYOUT") >> 8;
                    } elsif (1) {
                                                $main_exit_code = system('db_subst', $template, 'XKBLAYOUTVARIANT', "$XKBLAYOUT/$XKBVARIANT") >> 8;
                    }
                }
                $main_exit_code = system('db_subst', $template, 'XKBLAYOUT', "$XKBLAYOUT") >> 8;
                $main_exit_code = system('db_subst', $template, 'XKBVARIANT', "$XKBVARIANT") >> 8;
                                $main_exit_code = system('db_input', 'medium', $template) >> 8;
                if ($CHILD_ERROR != 0) {
                    1;
                }
;
if (!(system('bash', 'db_go') >> 8)) {
                    if (defined $STATE) {
                        $STATE = eval { int($STATE + 1) } // "";
                    }
}
                else {
                                        $main_exit_code = system('db_reset', $template) >> 8;
                    if ($CHILD_ERROR != 0) {
                        1;
                    }
;
                    $main_exit_code = system('db_fset', $template, 'seen', 'false') >> 8;
                    if (defined $STATE) {
                        $STATE = eval { int($STATE - 1) } // "";
                    }
                }
                $main_exit_code = system('db_get', $template) >> 8;
if ("$RET" ne true) {
                    $unsupported_layout = 'no';
                }
}
            else {
                                $main_exit_code = system('db_reset', 'keyboard-configuration/unsupported_config_layout') >> 8;
                if ($CHILD_ERROR != 0) {
                    1;
                }
;
                $main_exit_code = system('db_fset', 'keyboard-configuration/unsupported_config_layout', 'seen', 'false') >> 8;
                                $main_exit_code = system('db_reset', 'keyboard-configuration/unsupported_layout') >> 8;
                if ($CHILD_ERROR != 0) {
                    1;
                }
;
                $main_exit_code = system('db_fset', 'keyboard-configuration/unsupported_layout', 'seen', 'false') >> 8;
                if (defined $STATE) {
                    $STATE = eval { int( $STATE + $STATE - $old_state ) } // "";
                }
            }
        }
    } elsif ("$STATE" =~ /^5$/msx) {
        if (("$detected_keyboard")) {
            $XKBLAYOUT = (${detected_keyboard} =~ s/:.*$//sr =~ s/:.*$//sr);
            $debconf_layout = "$XKBLAYOUT";
            $main_exit_code = system('db_set', 'keyboard-configuration/layoutcode', "$XKBLAYOUT") >> 8;
            if (defined $STATE) {
                $STATE = eval { int( $STATE + $STATE - $old_state ) } // "";
            }
}
        else {
            if ("$XKBMODEL" eq SKIP) {
                if (defined $STATE) {
                    $STATE = eval { int( $STATE + $STATE - $old_state ) } // "";
                }
}
            else {
                if ("$unsupported_layout" eq yes) {
                    if (defined $STATE) {
                        $STATE = eval { int( $STATE + $STATE - $old_state ) } // "";
                    }
}
                else {
                    if (!(                    ask_debconf(template => 'keyboard-configuration/layout', priority => "$layout_priority", 'layout', "$debconf_layout"))) {
                        $debconf_layout = "$RET";
                        if (defined $STATE) {
                            $STATE = eval { int($STATE + 1) } // "";
                        }
}
                    else {
                        if (defined $STATE) {
                            $STATE = eval { int($STATE + 1) } // "";
                        }
                    }
                }
            }
        }
    } elsif ("$STATE" =~ /^6$/msx) {
                $adjust_layout = 'false';
        if (("$detected_keyboard")) {
if ($detected_keyboard =~ /^.*:.*$/msx) {
                                $variant = (${detected_keyboard} =~ s/^.*?://r =~ s/^.*?://r);
            } elsif (1) {
                                $variant = q{};
            }
            $debconf_variant = "$variant";
            $adjust_layout = q{:};
            if (defined $STATE) {
                $STATE = eval { int( $STATE + $STATE - $old_state ) } // "";
            }
}
        else {
            if ("$XKBMODEL" eq SKIP) {
                if (defined $STATE) {
                    $STATE = eval { int( $STATE + $STATE - $old_state ) } // "";
                }
}
            else {
                if ("$unsupported_layout" eq yes) {
                    if (defined $STATE) {
                        $STATE = eval { int( $STATE + $STATE - $old_state ) } // "";
                    }
}
                else {
                    if (                    ask_debconf(template => 'keyboard-configuration/variant', priority => "$layout_priority", "variant*" . ${debconf_layout}, "$debconf_variant")) {
                        $starting_state = eval { int($STATE - 1) } // "";
                        if (defined $STATE) {
                            $STATE = eval { int($STATE - 2) } // "";
                        }
}
                    else {
                        $debconf_variant = "$RET";
                        $variant = "$RET";
                        $adjust_layout = q{:};
                        if (defined $STATE) {
                            $STATE = eval { int($STATE + 1) } // "";
                        }
                    }
                }
            }
        }
        if (!(        $CHILD_ERROR = 0)) {
if ("$debconf_layout" =~ /^rs$/msx) {
                if ("$debconf_variant" =~ /^latin.*$/msx) {
                                        $XKBLAYOUT = $debconf_layout;
                } elsif (1) {
                                        $XKBLAYOUT = 'rs,rs';
                }
            } elsif ("$debconf_layout" =~ /^jp$/msx) {
                if ("$debconf_variant" =~ /^106$/msx or "$debconf_variant" =~ /^common$/msx or "$debconf_variant" =~ /^OADG109A$/msx or "$debconf_variant" =~ /^nicola_f_bs$/msx or "$debconf_variant" =~ /^$/msx) {
                                        $XKBLAYOUT = $debconf_layout;
                } elsif (1) {
                                        $XKBLAYOUT = 'jp,jp';
                }
            } elsif ("$debconf_layout" =~ /^lt$/msx) {
                                $XKBLAYOUT = 'lt,us';
            } elsif ("$debconf_layout" =~ /^me$/msx) {
                if ("$debconf_variant" =~ /^basic$/msx or "$debconf_variant" =~ /^latin.*$/msx) {
                                        $XKBLAYOUT = $debconf_layout;
                } elsif (1) {
                                        $XKBLAYOUT = 'me,me';
                }
            } elsif ("$debconf_layout" =~ /^af$/msx or "$debconf_layout" =~ /^am$/msx or "$debconf_layout" =~ /^ara$/msx or "$debconf_layout" =~ /^ben$/msx or "$debconf_layout" =~ /^bd$/msx or "$debconf_layout" =~ /^bg$/msx or "$debconf_layout" =~ /^bt$/msx or "$debconf_layout" =~ /^by$/msx or "$debconf_layout" =~ /^et$/msx or "$debconf_layout" =~ /^ge$/msx or "$debconf_layout" =~ /^gh$/msx or "$debconf_layout" =~ /^gr$/msx or "$debconf_layout" =~ /^guj$/msx or "$debconf_layout" =~ /^guru$/msx or "$debconf_layout" =~ /^il$/msx or "$debconf_layout" =~ /^in$/msx or "$debconf_layout" =~ /^iq$/msx or "$debconf_layout" =~ /^ir$/msx or "$debconf_layout" =~ /^iku$/msx or "$debconf_layout" =~ /^kan$/msx or "$debconf_layout" =~ /^kh$/msx or "$debconf_layout" =~ /^kz$/msx or "$debconf_layout" =~ /^la$/msx or "$debconf_layout" =~ /^lao$/msx or "$debconf_layout" =~ /^lk$/msx or "$debconf_layout" =~ /^kg$/msx or "$debconf_layout" =~ /^ma$/msx or "$debconf_layout" =~ /^mk$/msx or "$debconf_layout" =~ /^mm$/msx or "$debconf_layout" =~ /^mn$/msx or "$debconf_layout" =~ /^mv$/msx or "$debconf_layout" =~ /^mal$/msx or "$debconf_layout" =~ /^np$/msx or "$debconf_layout" =~ /^ori$/msx or "$debconf_layout" =~ /^pk$/msx or "$debconf_layout" =~ /^ru$/msx or "$debconf_layout" =~ /^scc$/msx or "$debconf_layout" =~ /^sy$/msx or "$debconf_layout" =~ /^syr$/msx or "$debconf_layout" =~ /^tel$/msx or "$debconf_layout" =~ /^th$/msx or "$debconf_layout" =~ /^tj$/msx or "$debconf_layout" =~ /^tam$/msx or "$debconf_layout" =~ /^tib$/msx or "$debconf_layout" =~ /^ua$/msx or "$debconf_layout" =~ /^ug$/msx or "$debconf_layout" =~ /^uz$/msx) {
                                $XKBLAYOUT = 'us,';
                                $CHILD_ERROR = 0;
            } elsif (1) {
                                $XKBLAYOUT = $debconf_layout;
            }
if ("$XKBLAYOUT" =~ /^rs,rs$/msx) {
                if ("$debconf_variant" =~ /^yz$/msx) {
                                        $XKBVARIANT = "latinyz,$debconf_variant";
                } elsif ("$debconf_variant" =~ /^alternatequotes$/msx) {
                                        $XKBVARIANT = "latinalternatequotes,$debconf_variant";
                } elsif (1) {
                                        $XKBVARIANT = "latin,$debconf_variant";
                }
            } elsif ("$XKBLAYOUT" =~ /^lt,us$/msx) {
                if ("$debconf_variant" =~ /^us$/msx) {
                                        $XKBVARIANT = "us,";
                } elsif (1) {
                                        $XKBVARIANT = "$debconf_variant,altgr-intl";
                }
            } elsif ("$XKBLAYOUT" =~ /^.*,.*$/msx) {
                                $XKBVARIANT = ",$debconf_variant";
            } elsif (1) {
                                $XKBVARIANT = "$debconf_variant";
            }
        }
                $main_exit_code = system('db_set', 'keyboard-configuration/layoutcode', "$XKBLAYOUT") >> 8;
                $main_exit_code = system('db_set', 'keyboard-configuration/variantcode', "$XKBVARIANT") >> 8;
    } elsif ("$STATE" =~ /^7$/msx) {
        if (("$unsupported_options" eq yes && ("$is_not_debian_installer"))) {
if ((-f $CONFIGFILE)) {
                $template = 'keyboard-configuration/unsupported_config_options';
}
            else {
                $template = 'keyboard-configuration/unsupported_options';
            }
            $main_exit_code = system('db_subst', $template, 'XKBOPTIONS', "$XKBOPTIONS") >> 8;
                        $main_exit_code = system('db_input', 'medium', $template) >> 8;
            if ($CHILD_ERROR != 0) {
                1;
            }
;
if (!(system('bash', 'db_go') >> 8)) {
                if (defined $STATE) {
                    $STATE = eval { int($STATE + 1) } // "";
                }
}
            else {
                                $main_exit_code = system('db_reset', $template) >> 8;
                if ($CHILD_ERROR != 0) {
                    1;
                }
;
                $main_exit_code = system('db_fset', $template, 'seen', 'false') >> 8;
                if (defined $STATE) {
                    $STATE = eval { int($STATE - 1) } // "";
                }
            }
            $main_exit_code = system('db_get', $template) >> 8;
if ("$RET" ne true) {
                $unsupported_options = 'no';
            }
}
        else {
                        $main_exit_code = system('db_reset', 'keyboard-configuration/unsupported_config_options') >> 8;
            if ($CHILD_ERROR != 0) {
                1;
            }
;
            $main_exit_code = system('db_fset', 'keyboard-configuration/unsupported_config_options', 'seen', 'false') >> 8;
                        $main_exit_code = system('db_reset', 'keyboard-configuration/unsupported_options') >> 8;
            if ($CHILD_ERROR != 0) {
                1;
            }
;
            $main_exit_code = system('db_fset', 'keyboard-configuration/unsupported_options', 'seen', 'false') >> 8;
            if (defined $STATE) {
                $STATE = eval { int( $STATE + $STATE - $old_state ) } // "";
            }
        }
    } elsif ("$STATE" =~ /^8$/msx) {
        if ("$unsupported_options" eq yes) {
            $main_exit_code = system('db_set', 'keyboard-configuration/optionscode', "$XKBOPTIONS") >> 8;
            if (defined $STATE) {
                $STATE = eval { int( $STATE + $STATE - $old_state ) } // "";
            }
}
        else {
            if ("$XKBMODEL" eq SKIP) {
                if (defined $STATE) {
                    $STATE = eval { int( $STATE + $STATE - $old_state ) } // "";
                }
}
            else {
                $caps_allocated = 'no';
                $lalt_allocated = 'no';
                $lctrl_allocated = 'no';
                $lshift_allocated = 'no';
                $lwin_allocated = 'no';
                $menu_allocated = 'no';
                $ralt_allocated = 'no';
                $rctrl_allocated = 'no';
                $rshift_allocated = 'no';
                $rwin_allocated = 'no';
if ("$XKBLAYOUT" =~ /^.*,.*$/msx) {
                } elsif (1) {
                                        $main_exit_code = system('db_set', 'keyboard-configuration/toggle', 'No toggling') >> 8;
                                        $main_exit_code = system('db_set', 'keyboard-configuration/switch', 'No temporary switch') >> 8;
                }
                $main_exit_code = system('bash', 'db_beginblock') >> 8;
if ("$XKBLAYOUT" =~ /^.*,.*$/msx) {
                                                            $main_exit_code = system('db_input', 'high', 'keyboard-configuration/toggle') >> 8;
                    if ($CHILD_ERROR != 0) {
                        1;
                    }
                    if (("$is_not_debian_installer")) {
                                                $main_exit_code = system('db_input', 'medium', 'keyboard-configuration/switch') >> 8;
                        if ($CHILD_ERROR != 0) {
                            1;
                        }
;
                    }
                } elsif (1) {
                }
if (("$is_not_debian_installer")) {
                                        $main_exit_code = system('db_input', 'medium', 'keyboard-configuration/altgr') >> 8;
                    if ($CHILD_ERROR != 0) {
                        1;
                    }
;
                                        $main_exit_code = system('db_input', 'medium', 'keyboard-configuration/compose') >> 8;
                    if ($CHILD_ERROR != 0) {
                        1;
                    }
;
                }
if ((-f '/usr/bin/X')) {
                                        $main_exit_code = system('db_input', 'medium', 'keyboard-configuration/ctrl_alt_bksp') >> 8;
                    if ($CHILD_ERROR != 0) {
                        1;
                    }
;
                }
                $main_exit_code = system('bash', 'db_endblock') >> 8;
if (!(system('bash', 'db_go') >> 8)) {
                    if (defined $STATE) {
                        $STATE = eval { int($STATE + 1) } // "";
                    }
}
                else {
                    if (defined $STATE) {
                        $STATE = eval { int($STATE - 1) } // "";
                    }
                }
                $main_exit_code = system('db_get', 'keyboard-configuration/toggle') >> 8;
if ("$RET" =~ /^Caps\ Lock$/msx) {
                                        $caps_allocated = 'yes';
                                        $toggle = 'caps_toggle';
                } elsif ("$RET" =~ /^Right\ Alt.*$/msx) {
                                        $ralt_allocated = 'yes';
                                        $toggle = 'toggle';
                } elsif ("$RET" =~ /^Right\ Control$/msx) {
                                        $rctrl_allocated = 'yes';
                                        $toggle = 'rctrl_toggle';
                } elsif ("$RET" =~ /^Right\ Shift$/msx) {
                                        $rshift_allocated = 'yes';
                                        $toggle = 'rshift_toggle';
                } elsif ("$RET" =~ /^Right\ Logo.key$/msx) {
                                        $rwin_allocated = 'yes';
                                        $toggle = 'rwin_toggle';
                } elsif ("$RET" =~ /^Menu.key$/msx) {
                                        $menu_allocated = 'yes';
                                        $toggle = 'menu_toggle';
                } elsif ("$RET" =~ /^Alt+Shift$/msx) {
                                        $toggle = 'alt_shift_toggle';
                } elsif ("$RET" =~ /^Control+Shift$/msx) {
                                        $toggle = 'ctrl_shift_toggle';
                } elsif ("$RET" =~ /^Left\ Control+Left\ Shift$/msx) {
                                        $toggle = 'lctrl_lshift_toggle';
                } elsif ("$RET" =~ /^Scroll\ Lock\ key$/msx) {
                                        $toggle = 'sclk_toggle';
                } elsif ("$RET" =~ /^Alt+Caps\ Lock$/msx) {
                                        $toggle = 'alt_caps_toggle';
                } elsif ("$RET" =~ /^Control+Alt$/msx) {
                                        $toggle = 'ctrl_alt_toggle';
                } elsif ("$RET" =~ /^Left\ Alt$/msx) {
                                        $lalt_allocated = 'yes';
                                        $toggle = 'lalt_toggle';
                } elsif ("$RET" =~ /^Left\ Control$/msx) {
                                        $lctrl_allocated = 'yes';
                                        $toggle = 'lctrl_toggle';
                } elsif ("$RET" =~ /^Left\ Shift$/msx) {
                                        $lshift_allocated = 'yes';
                                        $toggle = 'lshift_toggle';
                } elsif ("$RET" =~ /^Left\ Logo.key$/msx) {
                                        $lwin_allocated = 'yes';
                                        $toggle = 'lwin_toggle';
                } elsif ("$RET" =~ /^No\ toggling$/msx) {
                                        $toggle = q{};
                } elsif (1) {
                                        say 'Unknown' . q{ } . 'toggle' . q{ } . 'key' . q{ } . 'option';
                    exit 1;
                }
if (("$toggle")) {
                    $toggle = 'grp:';
                    $CHILD_ERROR = 0;
                }
                $main_exit_code = system('db_get', 'keyboard-configuration/switch') >> 8;
                $switch = q{};
if ("$RET" =~ /^Right\ Alt.*$/msx) {
                    if ("$ralt_allocated" ne yes) {
                        $switch = 'switch';
                        $ralt_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Left\ Alt$/msx) {
                    if ("$lalt_allocated" ne yes) {
                        $switch = 'lswitch';
                        $lalt_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Right\ Logo.key$/msx) {
                    if ("$rwin_allocated" ne yes) {
                        $switch = 'rwin_switch';
                        $rwin_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Left\ Logo.key$/msx) {
                    if ("$lwin_allocated" ne yes) {
                        $switch = 'lwin_switch';
                        $lwin_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Both\ Logo.keys$/msx) {
                    if (("$rwin_allocated" ne yes && "$lwin_allocated" ne yes)) {
                        $switch = 'win_switch';
                        $rwin_allocated = 'yes';
                        $lwin_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^No\ temporary\ switch$/msx) {
                                        $switch = q{};
                } elsif (1) {
                                        say 'Unknown' . q{ } . 'switch' . q{ } . 'key' . q{ } . 'option';
                    exit 1;
                }
if (("$switch")) {
                    $switch = 'grp:';
                    $CHILD_ERROR = 0;
                }
                $main_exit_code = system('db_get', 'keyboard-configuration/altgr') >> 8;
                $altgr = q{};
if ("$RET" =~ /^The.default.for.the.keyboard.layout$/msx) {
                                        $altgr = q{};
                } elsif ("$RET" =~ /^No.AltGr.key$/msx) {
                    if ("$ralt_allocated" ne yes) {
                        $altgr = 'ralt_alt';
                    }
                } elsif ("$RET" =~ /^Right.Alt.*$/msx) {
                    if ("$ralt_allocated" ne yes) {
                        $altgr = 'ralt_switch';
                        $ralt_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Right.Control$/msx) {
                    if ("$rctrl_allocated" ne yes) {
                        $altgr = 'switch';
                        $rctrl_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Menu.key$/msx) {
                    if ("$menu_allocated" ne yes) {
                        $altgr = 'menu_switch';
                        $menu_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Keypad.Enter.key$/msx) {
                                        $altgr = 'enter_switch';
                } elsif ("$RET" =~ /^Right.Logo.key$/msx) {
                    if ("$rwin_allocated" ne yes) {
                        $altgr = 'rwin_switch';
                        $rwin_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Left.Logo.key$/msx) {
                    if ("$lwin_allocated" ne yes) {
                        $altgr = 'lwin_switch';
                        $lwin_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Both.Logo.keys$/msx) {
                    if (("$rwin_allocated" ne yes && "$lwin_allocated" ne yes)) {
                        $altgr = 'win_switch';
                        $rwin_allocated = 'yes';
                        $lwin_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Both.Alt.keys$/msx) {
                    if (("$lalt_allocated" ne yes && "$ralt_allocated" ne yes)) {
                        $altgr = 'alt_switch';
                        $ralt_allocated = 'yes';
                        $lalt_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Left.Alt$/msx) {
                    if ("$lalt_allocated" ne yes) {
                        $altgr = 'lalt_switch';
                        $lalt_allocated = 'yes';
                    }
                } elsif (1) {
                                        say 'Unknown' . q{ } . 'altgr' . q{ } . 'key' . q{ } . 'option';
                    exit 1;
                }
if (("$altgr")) {
                    $altgr = 'lv3:';
                    $CHILD_ERROR = 0;
                }
                $main_exit_code = system('db_get', 'keyboard-configuration/compose') >> 8;
                $compose = q{};
if ("$RET" =~ /^No.compose.key$/msx) {
                                        $compose = q{};
                } elsif ("$RET" =~ /^Right.Alt.*$/msx) {
                    if ("$ralt_allocated" ne yes) {
                        $compose = 'ralt';
                        $ralt_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Right.Logo.key$/msx) {
                    if ("$rwin_allocated" ne yes) {
                        $compose = 'rwin';
                        $rwin_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Left.Logo.key$/msx) {
                    if ("$lwin_allocated" ne yes) {
                        $compose = 'lwin';
                        $lwin_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Right.Control$/msx) {
                    if ("$rctrl_allocated" ne yes) {
                        $compose = 'rctrl';
                        $rctrl_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Menu.key$/msx) {
                    if ("$menu_allocated" ne yes) {
                        $compose = 'menu';
                        $menu_allocated = 'yes';
                    }
                } elsif ("$RET" =~ /^Caps.Lock$/msx) {
                    if ("$caps_allocated" ne yes) {
                        $compose = 'caps';
                        $caps_allocated = 'yes';
                    }
                } elsif (1) {
                                        say 'Unknown' . q{ } . 'compose' . q{ } . 'key' . q{ } . 'option';
                    exit 1;
                }
if (("$compose")) {
                    $compose = 'compose:';
                    $CHILD_ERROR = 0;
                }
                $main_exit_code = system('db_get', 'keyboard-configuration/ctrl_alt_bksp') >> 8;
if ("$RET" eq true) {
                    $terminate = 'terminate:ctrl_alt_bksp';
}
                else {
                    $terminate = q{};
                }
if (("$ralt_allocated" eq yes && "$altgr" eq lv3:ralt_alt)) {
                    $altgr = q{};
                }
if ("$XKBLAYOUT" =~ /^.*,.*$/msx) {
                                        $leds = 'grp_led:scroll';
                } elsif (1) {
                                        $leds = q{};
                }
                $options = do { local $CHILD_ERROR = 0; do {
    do {;
                $main_exit_code = system('db_set', 'keyboard-configuration/optionscode', "$options") >> 8;
            }
        }
    } elsif (1) {
        last;    }
    $old_state = $starting_state;
}
if (($STATE == 0)) {
exit 10;
}
else {
    $main_exit_code = system('db_set', 'keyboard-configuration/store_defaults_in_debconf_db', 'false') >> 8;
}
exit 0;

exit $main_exit_code;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
