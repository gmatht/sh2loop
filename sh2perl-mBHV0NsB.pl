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

my $RET;
my @RET;
my %RET;
my $choices;
my @choices;
my %choices;
my $locale;
my @locale;
my %locale;
my $kernel;
my @kernel;
my %kernel;
my $CODESET;
my @CODESET;
my %CODESET;
my $LC_CTYPE;
my @LC_CTYPE;
my %LC_CTYPE;
my $FONTSIZE;
my @FONTSIZE;
my %FONTSIZE;
my $STATE;
my @STATE;
my %STATE;
my $fontface;
my @fontface;
my %fontface;
my $FONTFACE;
my @FONTFACE;
my %FONTFACE;
my $CHARMAP;
my @CHARMAP;
my %CHARMAP;
my $CONFIGFILE;
my @CONFIGFILE;
my %CONFIGFILE;

$__set_e = 1;
$main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;
$CONFIGFILE = '/etc/default/console-setup';
my $default_codeset;
my @default_codeset;
my %default_codeset;
$default_codeset = q{};
my $default_fontface;
my @default_fontface;
my %default_fontface;
$default_fontface = q{};
$CHARMAP = q{};
$CODESET = q{};
$FONTFACE = q{};
$FONTSIZE = q{};
my $fontsets;
my @fontsets;
my %fontsets;
$fontsets = "Arabic-Fixed15\nArabic-Fixed16\nArabic-VGA14\nArabic-VGA16\nArabic-VGA28x16\nArabic-VGA32x16\nArabic-VGA8\nArmenian-Fixed13\nArmenian-Fixed14\nArmenian-Fixed15\nArmenian-Fixed16\nArmenian-Fixed18\nCyrAsia-Fixed13\nCyrAsia-Fixed14\nCyrAsia-Fixed15\nCyrAsia-Fixed16\nCyrAsia-Fixed18\nCyrAsia-Terminus12x6\nCyrAsia-Terminus14\nCyrAsia-Terminus16\nCyrAsia-Terminus18x10\nCyrAsia-Terminus20x10\nCyrAsia-Terminus22x11\nCyrAsia-Terminus24x12\nCyrAsia-Terminus28x14\nCyrAsia-Terminus32x16\nCyrAsia-TerminusBold14\nCyrAsia-TerminusBold16\nCyrAsia-TerminusBold18x10\nCyrAsia-TerminusBold20x10\nCyrAsia-TerminusBold22x11\nCyrAsia-TerminusBold24x12\nCyrAsia-TerminusBold28x14\nCyrAsia-TerminusBold32x16\nCyrAsia-TerminusBoldVGA14\nCyrAsia-TerminusBoldVGA16\nCyrKoi-Fixed13\nCyrKoi-Fixed14\nCyrKoi-Fixed15\nCyrKoi-Fixed16\nCyrKoi-Fixed18\nCyrKoi-Terminus12x6\nCyrKoi-Terminus14\nCyrKoi-Terminus16\nCyrKoi-Terminus18x10\nCyrKoi-Terminus20x10\nCyrKoi-Terminus22x11\nCyrKoi-Terminus24x12\nCyrKoi-Terminus28x14\nCyrKoi-Terminus32x16\nCyrKoi-TerminusBold14\nCyrKoi-TerminusBold16\nCyrKoi-TerminusBold18x10\nCyrKoi-TerminusBold20x10\nCyrKoi-TerminusBold22x11\nCyrKoi-TerminusBold24x12\nCyrKoi-TerminusBold28x14\nCyrKoi-TerminusBold32x16\nCyrKoi-TerminusBoldVGA14\nCyrKoi-TerminusBoldVGA16\nCyrKoi-VGA14\nCyrKoi-VGA16\nCyrKoi-VGA28x16\nCyrKoi-VGA32x16\nCyrKoi-VGA8\nCyrSlav-Fixed13\nCyrSlav-Fixed14\nCyrSlav-Fixed15\nCyrSlav-Fixed16\nCyrSlav-Fixed18\nCyrSlav-Terminus12x6\nCyrSlav-Terminus14\nCyrSlav-Terminus16\nCyrSlav-Terminus18x10\nCyrSlav-Terminus20x10\nCyrSlav-Terminus22x11\nCyrSlav-Terminus24x12\nCyrSlav-Terminus28x14\nCyrSlav-Terminus32x16\nCyrSlav-TerminusBold14\nCyrSlav-TerminusBold16\nCyrSlav-TerminusBold18x10\nCyrSlav-TerminusBold20x10\nCyrSlav-TerminusBold22x11\nCyrSlav-TerminusBold24x12\nCyrSlav-TerminusBold28x14\nCyrSlav-TerminusBold32x16\nCyrSlav-TerminusBoldVGA14\nCyrSlav-TerminusBoldVGA16\nCyrSlav-VGA14\nCyrSlav-VGA16\nCyrSlav-VGA28x16\nCyrSlav-VGA32x16\nCyrSlav-VGA8\nEthiopian-Fixed15\nEthiopian-Fixed16\nEthiopian-Fixed18\nEthiopian-Goha12\nEthiopian-Goha14\nEthiopian-Goha16\nEthiopian-GohaClassic12\nEthiopian-GohaClassic14\nEthiopian-GohaClassic16\nFullCyrAsia-Fixed13\nFullCyrAsia-Fixed14\nFullCyrAsia-Fixed15\nFullCyrAsia-Fixed16\nFullCyrAsia-Fixed18\nFullCyrAsia-Terminus12x6\nFullCyrAsia-Terminus14\nFullCyrAsia-Terminus16\nFullCyrAsia-Terminus18x10\nFullCyrAsia-Terminus20x10\nFullCyrAsia-Terminus22x11\nFullCyrAsia-Terminus24x12\nFullCyrAsia-Terminus28x14\nFullCyrAsia-Terminus32x16\nFullCyrAsia-TerminusBold14\nFullCyrAsia-TerminusBold16\nFullCyrAsia-TerminusBold18x10\nFullCyrAsia-TerminusBold20x10\nFullCyrAsia-TerminusBold22x11\nFullCyrAsia-TerminusBold24x12\nFullCyrAsia-TerminusBold28x14\nFullCyrAsia-TerminusBold32x16\nFullCyrAsia-TerminusBoldVGA14\nFullCyrAsia-TerminusBoldVGA16\nFullCyrSlav-Fixed13\nFullCyrSlav-Fixed14\nFullCyrSlav-Fixed15\nFullCyrSlav-Fixed16\nFullCyrSlav-Fixed18\nFullCyrSlav-Terminus12x6\nFullCyrSlav-Terminus14\nFullCyrSlav-Terminus16\nFullCyrSlav-Terminus18x10\nFullCyrSlav-Terminus20x10\nFullCyrSlav-Terminus22x11\nFullCyrSlav-Terminus24x12\nFullCyrSlav-Terminus28x14\nFullCyrSlav-Terminus32x16\nFullCyrSlav-TerminusBold14\nFullCyrSlav-TerminusBold16\nFullCyrSlav-TerminusBold18x10\nFullCyrSlav-TerminusBold20x10\nFullCyrSlav-TerminusBold22x11\nFullCyrSlav-TerminusBold24x12\nFullCyrSlav-TerminusBold28x14\nFullCyrSlav-TerminusBold32x16\nFullCyrSlav-TerminusBoldVGA14\nFullCyrSlav-TerminusBoldVGA16\nFullCyrSlav-VGA14\nFullCyrSlav-VGA16\nFullCyrSlav-VGA28x16\nFullCyrSlav-VGA32x16\nFullCyrSlav-VGA8\nFullGreek-Fixed13\nFullGreek-Fixed14\nFullGreek-Fixed15\nFullGreek-Fixed16\nFullGreek-Fixed18\nFullGreek-Terminus12x6\nFullGreek-Terminus14\nFullGreek-Terminus16\nFullGreek-Terminus18x10\nFullGreek-Terminus20x10\nFullGreek-Terminus22x11\nFullGreek-Terminus24x12\nFullGreek-Terminus28x14\nFullGreek-Terminus32x16\nFullGreek-TerminusBold14\nFullGreek-TerminusBold16\nFullGreek-TerminusBold18x10\nFullGreek-TerminusBold20x10\nFullGreek-TerminusBold22x11\nFullGreek-TerminusBold24x12\nFullGreek-TerminusBold28x14\nFullGreek-TerminusBold32x16\nFullGreek-TerminusBoldVGA14\nFullGreek-TerminusBoldVGA16\nFullGreek-VGA14\nFullGreek-VGA16\nFullGreek-VGA28x16\nFullGreek-VGA32x16\nFullGreek-VGA8\nGeorgian-Fixed13\nGeorgian-Fixed14\nGeorgian-Fixed15\nGeorgian-Fixed16\nGeorgian-Fixed18\nGreek-Fixed13\nGreek-Fixed14\nGreek-Fixed15\nGreek-Fixed16\nGreek-Fixed18\nGreek-Terminus12x6\nGreek-Terminus14\nGreek-Terminus16\nGreek-Terminus18x10\nGreek-Terminus20x10\nGreek-Terminus22x11\nGreek-Terminus24x12\nGreek-Terminus28x14\nGreek-Terminus32x16\nGreek-TerminusBold14\nGreek-TerminusBold16\nGreek-TerminusBold18x10\nGreek-TerminusBold20x10\nGreek-TerminusBold22x11\nGreek-TerminusBold24x12\nGreek-TerminusBold28x14\nGreek-TerminusBold32x16\nGreek-TerminusBoldVGA14\nGreek-TerminusBoldVGA16\nGreek-VGA14\nGreek-VGA16\nGreek-VGA28x16\nGreek-VGA32x16\nGreek-VGA8\nHebrew-Fixed13\nHebrew-Fixed14\nHebrew-Fixed15\nHebrew-Fixed16\nHebrew-Fixed18\nHebrew-Terminus12x6\nHebrew-Terminus14\nHebrew-Terminus16\nHebrew-Terminus18x10\nHebrew-Terminus20x10\nHebrew-Terminus22x11\nHebrew-Terminus24x12\nHebrew-Terminus28x14\nHebrew-Terminus32x16\nHebrew-TerminusBold14\nHebrew-TerminusBold16\nHebrew-TerminusBold18x10\nHebrew-TerminusBold20x10\nHebrew-TerminusBold22x11\nHebrew-TerminusBold24x12\nHebrew-TerminusBold28x14\nHebrew-TerminusBold32x16\nHebrew-TerminusBoldVGA14\nHebrew-TerminusBoldVGA16\nHebrew-VGA14\nHebrew-VGA16\nHebrew-VGA28x16\nHebrew-VGA32x16\nHebrew-VGA8\nLao-Fixed14\nLao-Fixed15\nLao-Fixed16\nLat15-Fixed13\nLat15-Fixed14\nLat15-Fixed15\nLat15-Fixed16\nLat15-Fixed18\nLat15-Terminus12x6\nLat15-Terminus14\nLat15-Terminus16\nLat15-Terminus18x10\nLat15-Terminus20x10\nLat15-Terminus22x11\nLat15-Terminus24x12\nLat15-Terminus28x14\nLat15-Terminus32x16\nLat15-TerminusBold14\nLat15-TerminusBold16\nLat15-TerminusBold18x10\nLat15-TerminusBold20x10\nLat15-TerminusBold22x11\nLat15-TerminusBold24x12\nLat15-TerminusBold28x14\nLat15-TerminusBold32x16\nLat15-TerminusBoldVGA14\nLat15-TerminusBoldVGA16\nLat15-VGA14\nLat15-VGA16\nLat15-VGA28x16\nLat15-VGA32x16\nLat15-VGA8\nLat2-Fixed13\nLat2-Fixed14\nLat2-Fixed15\nLat2-Fixed16\nLat2-Fixed18\nLat2-Terminus12x6\nLat2-Terminus14\nLat2-Terminus16\nLat2-Terminus18x10\nLat2-Terminus20x10\nLat2-Terminus22x11\nLat2-Terminus24x12\nLat2-Terminus28x14\nLat2-Terminus32x16\nLat2-TerminusBold14\nLat2-TerminusBold16\nLat2-TerminusBold18x10\nLat2-TerminusBold20x10\nLat2-TerminusBold22x11\nLat2-TerminusBold24x12\nLat2-TerminusBold28x14\nLat2-TerminusBold32x16\nLat2-TerminusBoldVGA14\nLat2-TerminusBoldVGA16\nLat2-VGA14\nLat2-VGA16\nLat2-VGA28x16\nLat2-VGA32x16\nLat2-VGA8\nLat38-Fixed13\nLat38-Fixed14\nLat38-Fixed15\nLat38-Fixed16\nLat38-Fixed18\nLat38-Terminus12x6\nLat38-Terminus14\nLat38-Terminus16\nLat38-Terminus18x10\nLat38-Terminus20x10\nLat38-Terminus22x11\nLat38-Terminus24x12\nLat38-Terminus28x14\nLat38-Terminus32x16\nLat38-TerminusBold14\nLat38-TerminusBold16\nLat38-TerminusBold18x10\nLat38-TerminusBold20x10\nLat38-TerminusBold22x11\nLat38-TerminusBold24x12\nLat38-TerminusBold28x14\nLat38-TerminusBold32x16\nLat38-TerminusBoldVGA14\nLat38-TerminusBoldVGA16\nLat38-VGA14\nLat38-VGA16\nLat38-VGA28x16\nLat38-VGA32x16\nLat38-VGA8\nLat7-Fixed13\nLat7-Fixed14\nLat7-Fixed15\nLat7-Fixed16\nLat7-Fixed18\nLat7-Terminus12x6\nLat7-Terminus14\nLat7-Terminus16\nLat7-Terminus18x10\nLat7-Terminus20x10\nLat7-Terminus22x11\nLat7-Terminus24x12\nLat7-Terminus28x14\nLat7-Terminus32x16\nLat7-TerminusBold14\nLat7-TerminusBold16\nLat7-TerminusBold18x10\nLat7-TerminusBold20x10\nLat7-TerminusBold22x11\nLat7-TerminusBold24x12\nLat7-TerminusBold28x14\nLat7-TerminusBold32x16\nLat7-TerminusBoldVGA14\nLat7-TerminusBoldVGA16\nLat7-VGA14\nLat7-VGA16\nLat7-VGA28x16\nLat7-VGA32x16\nLat7-VGA8\nThai-Fixed13\nThai-Fixed14\nThai-Fixed15\nThai-Fixed16\nThai-Fixed18\nUni1-Fixed15\nUni1-Fixed16\nUni1-VGA14\nUni1-VGA16\nUni1-VGA28x16\nUni1-VGA32x16\nUni1-VGA8\nUni2-Fixed13\nUni2-Fixed14\nUni2-Fixed15\nUni2-Fixed16\nUni2-Fixed18\nUni2-Terminus12x6\nUni2-Terminus14\nUni2-Terminus16\nUni2-Terminus18x10\nUni2-Terminus20x10\nUni2-Terminus22x11\nUni2-Terminus24x12\nUni2-Terminus28x14\nUni2-Terminus32x16\nUni2-TerminusBold14\nUni2-TerminusBold16\nUni2-TerminusBold18x10\nUni2-TerminusBold20x10\nUni2-TerminusBold22x11\nUni2-TerminusBold24x12\nUni2-TerminusBold28x14\nUni2-TerminusBold32x16\nUni2-TerminusBoldVGA14\nUni2-TerminusBoldVGA16\nUni2-VGA14\nUni2-VGA16\nUni2-VGA28x16\nUni2-VGA32x16\nUni2-VGA8\nUni3-Fixed13\nUni3-Fixed14\nUni3-Fixed15\nUni3-Fixed16\nUni3-Fixed18\nUni3-Terminus12x6\nUni3-Terminus14\nUni3-Terminus16\nUni3-Terminus18x10\nUni3-Terminus20x10\nUni3-Terminus22x11\nUni3-Terminus24x12\nUni3-Terminus28x14\nUni3-Terminus32x16\nUni3-TerminusBold14\nUni3-TerminusBold16\nUni3-TerminusBold18x10\nUni3-TerminusBold20x10\nUni3-TerminusBold22x11\nUni3-TerminusBold24x12\nUni3-TerminusBold28x14\nUni3-TerminusBold32x16\nUni3-TerminusBoldVGA14\nUni3-TerminusBoldVGA16\nVietnamese-Fixed13\nVietnamese-Fixed14\nVietnamese-Fixed15\nVietnamese-Fixed16\nVietnamese-Fixed18\nVietnamese-Terminus12x6\nVietnamese-Terminus14\nVietnamese-Terminus16\nVietnamese-Terminus18x10\nVietnamese-Terminus20x10\nVietnamese-Terminus22x11\nVietnamese-Terminus24x12\nVietnamese-Terminus28x14\nVietnamese-Terminus32x16\nVietnamese-TerminusBold14\nVietnamese-TerminusBold16\nVietnamese-TerminusBold18x10\nVietnamese-TerminusBold20x10\nVietnamese-TerminusBold22x11\nVietnamese-TerminusBold24x12\nVietnamese-TerminusBold28x14\nVietnamese-TerminusBold32x16\nVietnamese-TerminusBoldVGA14\nVietnamese-TerminusBoldVGA16\n";
my $charmaps;
my @charmaps;
my %charmaps;
$charmaps = "ARMSCII-8\nCP1251\nCP1255\nCP1256\nGEORGIAN-ACADEMY\nGEORGIAN-PS\nIBM1133\nISIRI-3342\nISO-8859-1\nISO-8859-10\nISO-8859-11\nISO-8859-13\nISO-8859-14\nISO-8859-15\nISO-8859-16\nISO-8859-2\nISO-8859-3\nISO-8859-4\nISO-8859-5\nISO-8859-6\nISO-8859-7\nISO-8859-8\nISO-8859-9\nKOI8-R\nKOI8-U\nTIS-620\nVISCII\nUTF-8";
my $codesets;
my @codesets;
my %codesets;
$codesets = "guess*Guess optimal character set\nArabic*. Arabic\nArmenian*# Armenian\nCyrKoi*# Cyrillic - KOI8-R and KOI8-U\nCyrAsia*# Cyrillic - non-Slavic languages\nFullCyrAsia*. Cyrillic - non-Slavic languages (for blind users)\nCyrSlav*# Cyrillic - Slavic languages (also Bosnian and Serbian Latin)\nFullCyrSlav*. Cyrillic - Slavic languages (for blind users)\nEthiopian*. Ethiopic\nGeorgian*# Georgian\nGreek*# Greek\nFullGreek*. Greek (for blind users)\nHebrew*# Hebrew\nLao*# Lao\nLat15*# Latin1 and Latin5 - western Europe and Turkic languages\nLat2*# Latin2 - central Europe and Romanian\nLat38*# Latin3 and Latin8 - Chichewa; Esperanto; Irish; Maltese and Welsh\nLat7*# Latin7 - Lithuanian; Latvian; Maori and Marshallese\nVietnamese*. Latin - Vietnamese\nThai*# Thai\nUni1*. Combined - Latin; Slavic Cyrillic; Hebrew; basic Arabic\nUni2*. Combined - Latin; Slavic Cyrillic; Greek\nUni3*. Combined - Latin; Slavic and non-Slavic Cyrillic";
$main_exit_code = system('db_capb', 'backup') >> 8;

sub which {
    my $IFS;
    $IFS = q{:};
    my $i;
    for my $i ($PATH) {
if (((-f "$i/$1") && (-x "$i/$1"))) {
            do {
    my $__echo_line = "$i/$_[0]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
return q{0};
        }
    }
return q{1};
    return;
}

sub available_fontfaces {
    my $prefix;
if ("$CODESET" =~ /^guess$/msx) {
                $prefix = '[^-]*-';
    } elsif (1) {
                $prefix = "$CODESET";
                $main_exit_code = system('bash', '-') >> 8;
    }
    # Original bash: echo "$fontsets" | sort | \
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
        $output_0 .= $fontsets . "\n";
if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
$CHILD_ERROR = 0;

                my @sort_lines_0_1 = split /\n/msx, $output_0;
        my @sort_sorted_0_1 = sort @sort_lines_0_1;
        my $output_0_1 = join "\n", @sort_sorted_0_1;
        if ($output_0_1 ne q{} && !($output_0_1 =~ m{\n\z}msx)) {
        $output_0_1 .= "\n";
        }
        $output_0 = $output_0_1;
        $output_0 = $output_0_1;

                my $grep_result_0_2;
        my @grep_lines_0_2 = split /\n/msx, $output_0;
        my @grep_filtered_0_2 = grep { /^$prefix/msx } @grep_lines_0_2;
        $grep_result_0_2 = join "\n", @grep_filtered_0_2;
        if (!($grep_result_0_2 =~ m{\n\z}msx || $grep_result_0_2 eq q{})) {
        $grep_result_0_2 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_0_2 > 0 ? 0 : 1;
        $output_0 = $grep_result_0_2;
        $output_0 = $grep_result_0_2;

                my @sed_lines_0 = split /\n/msx, $output_0;
        my @sed_result_0;
        foreach my $line (@sed_lines_0) {
        chomp $line;
        push @sed_result_0, $line;
        }
        $output_0 = join "\n", @sed_result_0;

                my @sort_lines_0_4 = split /\n/msx, $output_0;
        my @sort_sorted_0_4 = sort {
        my @a_fields = split /\s+/msx, $a;
        my @b_fields = split /\s+/msx, $b;
        my $a_num = 0;
        my $b_num = 0;
        my $a_key = ( scalar @a_fields > 0 ) ? $a_fields[0] : q{}; $a_key =~ s/^\s+|\s+$//g;
        my $b_key = ( scalar @b_fields > 0 ) ? $b_fields[0] : q{}; $b_key =~ s/^\s+|\s+$//g;
        if ( $a_key =~ /^\d+(?:[.]\d+)?$/msx ) { $a_num = $a_key; }
        if ( $b_key =~ /^\d+(?:[.]\d+)?$/msx ) { $b_num = $b_key; }
        $a_num <=> $b_num || $a cmp $b
        } @sort_lines_0_4;
        my $output_0_4 = join "\n", @sort_sorted_0_4;
        if ($output_0_4 ne q{} && !($output_0_4 =~ m{\n\z}msx)) {
        $output_0_4 .= "\n";
        }
        $output_0 = $output_0_4;
        $output_0 = $output_0_4;

                my @uniq_lines_0_5 = split /\n/msx, $output_0;
        @uniq_lines_0_5 = grep { $_ ne q{} } @uniq_lines_0_5; # Filter out empty lines
        my %uniq_seen_0_5;
        my @uniq_result_0_5;
        foreach my $line (@uniq_lines_0_5) {
        if (!$uniq_seen_0_5{$line}++) { push @uniq_result_0_5, $line; }
        }
        my $output_0_5 = join "\n", @uniq_result_0_5;
        if ($output_0_5 ne q{} && !($output_0_5 =~ m{\n\z}msx)) {
        $output_0_5 .= "\n";
        }
        $output_0 = $output_0_5;
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

sub available_fontsizes {
    my $prefix;
if ("$CODESET" =~ /^guess$/msx) {
                $prefix = '[^-]*-';
    } elsif (1) {
                $prefix = "$CODESET";
                $main_exit_code = system('bash', '-') >> 8;
    }
if ("$fontface" =~ /^guess$/msx) {
                $prefix = "$prefix[^0-9]*";
    } elsif (1) {
                $prefix = "$prefix$fontface";
    }
    # Original bash: echo "$fontsets" \
{
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
        $output_1 .= $fontsets . "\n";
if ( !($output_1 =~ m{\n\z}msx) ) { $output_1 .= "\n"; }
$CHILD_ERROR = 0;

                my $grep_result_1_1;
        my @grep_lines_1_1 = split /\n/msx, $output_1;
        my @grep_filtered_1_1 = grep { /^$prefix[0-9]/msx } @grep_lines_1_1;
        $grep_result_1_1 = join "\n", @grep_filtered_1_1;
        if (!($grep_result_1_1 =~ m{\n\z}msx || $grep_result_1_1 eq q{})) {
        $grep_result_1_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_1_1 > 0 ? 0 : 1;
        $output_1 = $grep_result_1_1;
        $output_1 = $grep_result_1_1;

                my @sed_lines_1 = split /\n/msx, $output_1;
        my @sed_result_1;
        foreach my $line (@sed_lines_1) {
        chomp $line;
        push @sed_result_1, $line;
        }
        $output_1 = join "\n", @sed_result_1;

                my @sort_lines_1_3 = split /\n/msx, $output_1;
        my @sort_sorted_1_3 = sort {
        my @a_fields = split /\s+/msx, $a;
        my @b_fields = split /\s+/msx, $b;
        my $a_num = 0;
        my $b_num = 0;
        my $a_key = ( scalar @a_fields > 0 ) ? $a_fields[0] : q{}; $a_key =~ s/^\s+|\s+$//g;
        my $b_key = ( scalar @b_fields > 0 ) ? $b_fields[0] : q{}; $b_key =~ s/^\s+|\s+$//g;
        if ( $a_key =~ /^\d+(?:[.]\d+)?$/msx ) { $a_num = $a_key; }
        if ( $b_key =~ /^\d+(?:[.]\d+)?$/msx ) { $b_num = $b_key; }
        $a_num <=> $b_num || $a cmp $b
        } @sort_lines_1_3;
        my $output_1_3 = join "\n", @sort_sorted_1_3;
        if ($output_1_3 ne q{} && !($output_1_3 =~ m{\n\z}msx)) {
        $output_1_3 .= "\n";
        }
        $output_1 = $output_1_3;
        $output_1 = $output_1_3;

                my @uniq_lines_1_4 = split /\n/msx, $output_1;
        @uniq_lines_1_4 = grep { $_ ne q{} } @uniq_lines_1_4; # Filter out empty lines
        my %uniq_seen_1_4;
        my @uniq_result_1_4;
        foreach my $line (@uniq_lines_1_4) {
        if (!$uniq_seen_1_4{$line}++) { push @uniq_result_1_4, $line; }
        }
        my $output_1_4 = join "\n", @uniq_result_1_4;
        if ($output_1_4 ne q{} && !($output_1_4 =~ m{\n\z}msx)) {
        $output_1_4 .= "\n";
        }
        $output_1 = $output_1_4;

                my @lines = split /\n/msx, $output_1;
        my $result_1_5 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        $main_exit_code = system('decode_fontsize', "$ENV{x}") >> 8;
        }
        $output_1 = $result_1_5;
        if ($output_1 ne q{} && !defined $output_printed_1) {
            print $output_1;
            if (!($output_1 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
    return;
}
$main_exit_code = system('db_metaget', 'console-setup/framebuffer_only', 'description') >> 8;
my $framebuffer_only;
my @framebuffer_only;
my %framebuffer_only;
$framebuffer_only = "$RET";

sub decode_fontsize {
    my $a;
    my $b;
    my $fbonly;
if ("$_[0]" =~ /^8x.*$/msx) {
                print '8x' . q{ } . $_[0] =~ s/^.*?x//r . "\n";
        $CHILD_ERROR = 0;
    } elsif ("$_[0]" =~ /^.*x8$/msx) {
                print '8x' . q{ } . scalar reverse( (scalar reverse $_[0]) =~ s/^.*?x//r ) . "\n";
        $CHILD_ERROR = 0;
    } elsif ("$_[0]" =~ /^.*x.*$/msx) {
                $a = $_[0] =~ s/^.*?x//r;
                $b = scalar reverse( (scalar reverse $_[0]) =~ s/^.*?x//r );
        if (($a < $b)) {
            do {
    my $__echo_line = $a . q{ } . q{x} . q{ } . $b . q{ } . "($framebuffer_only)";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
}
        else {
            do {
    my $__echo_line = $b . q{ } . q{x} . q{ } . $a . q{ } . "($framebuffer_only)";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
    } elsif (1) {
                do {
    my $__echo_line = '8x' . q{ } . $1;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    return;
}

sub encode_fontsize {
    # Original bash: echo $1 | sed -e 's/[\, ;].*//'
{
        my $output_2 = q{};
        my $output_printed_2;
        my $pipeline_success_2 = 1;
        $output_2 .= $1 . "\n";
if ( !($output_2 =~ m{\n\z}msx) ) { $output_2 .= "\n"; }
$CHILD_ERROR = 0;

                my @sed_lines_2 = split /\n/msx, $output_2;
        my @sed_result_2;
        foreach my $line (@sed_lines_2) {
        chomp $line;
        push @sed_result_2, $line;
        }
        $output_2 = join "\n", @sed_result_2;
        if ($output_2 ne q{} && !defined $output_printed_2) {
            print $output_2;
            if (!($output_2 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
    return;
}

sub decode_codeset {
    # Original bash: echo "$codesets" | \
{
        my $output_3 = q{};
        my $output_printed_3;
        my $pipeline_success_3 = 1;
        $output_3 .= $codesets . "\n";
if ( !($output_3 =~ m{\n\z}msx) ) { $output_3 .= "\n"; }
$CHILD_ERROR = 0;

                my @sed_lines_3 = split /\n/msx, $output_3;
        my @sed_result_3;
        foreach my $line (@sed_lines_3) {
        chomp $line;
        push @sed_result_3, $line;
        }
        $output_3 = join "\n", @sed_result_3;

                my $grep_result_3_2;
        my @grep_lines_3_2 = split /\n/msx, $output_3;
        my @grep_filtered_3_2 = grep { /_@ARGV*/msx } @grep_lines_3_2;
        $grep_result_3_2 = join "\n", @grep_filtered_3_2;
        if (!($grep_result_3_2 =~ m{\n\z}msx || $grep_result_3_2 eq q{})) {
        $grep_result_3_2 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_3_2 > 0 ? 0 : 1;
        $output_3 = $grep_result_3_2;
        $output_3 = $grep_result_3_2;

                my @sed_lines_3 = split /\n/msx, $output_3;
        my @sed_result_3;
        foreach my $line (@sed_lines_3) {
        chomp $line;
        push @sed_result_3, $line;
        }
        $output_3 = join "\n", @sed_result_3;

                my @sed_lines_3 = split /\n/msx, $output_3;
        my @sed_result_3;
        foreach my $line (@sed_lines_3) {
        chomp $line;
        $line =~ s/.*[*]//gmsx;
        push @sed_result_3, $line;
        }
        $output_3 = join "\n", @sed_result_3;
        if ($output_3 ne q{} && !defined $output_printed_3) {
            print $output_3;
            if (!($output_3 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
    return;
}

sub encode_codeset {
    # Original bash: echo "$codesets" | \
{
        my $output_4 = q{};
        my $output_printed_4;
        my $pipeline_success_4 = 1;
        $output_4 .= $codesets . "\n";
if ( !($output_4 =~ m{\n\z}msx) ) { $output_4 .= "\n"; }
$CHILD_ERROR = 0;

                my $grep_result_4_1;
        my @grep_lines_4_1 = split /\n/msx, $output_4;
        my @grep_filtered_4_1 = grep { /*@ARGV/msx } @grep_lines_4_1;
        $grep_result_4_1 = join "\n", @grep_filtered_4_1;
        if (!($grep_result_4_1 =~ m{\n\z}msx || $grep_result_4_1 eq q{})) {
        $grep_result_4_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_4_1 > 0 ? 0 : 1;
        $output_4 = $grep_result_4_1;
        $output_4 = $grep_result_4_1;

                my @sed_lines_4 = split /\n/msx, $output_4;
        my @sed_result_4;
        foreach my $line (@sed_lines_4) {
        chomp $line;
        $line =~ s/[*].*//gmsx;
        push @sed_result_4, $line;
        }
        $output_4 = join "\n", @sed_result_4;
        if ($output_4 ne q{} && !defined $output_printed_4) {
            print $output_4;
            if (!($output_4 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
    return;
}
$kernel = 'unknown';
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'uname';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
if ((do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^.*Linux.*$/msx) {
                $kernel = 'linux';
    } elsif ((do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^.*FreeBSD.*$/msx) {
                $kernel = 'freebsd';
    }
}
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'locale';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
do { my $eval_input = do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'locale');
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
}; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
}
if ((("$LC_CTYPE") && "$LC_CTYPE" ne C)) {
    $locale = $LC_CTYPE;
}
else {
    if ((!(    $main_exit_code = system('db_get', 'debian-installer/locale') >> 8) && ("$RET"))) {
        $locale = "$RET";
}
    else {
        $locale = q{C};
    }
}
if ("$locale" eq C) {
if ("$kernel" =~ /^freebsd$/msx) {
                $CHARMAP = 'ISO-8859-15';
    } elsif (1) {
                $CHARMAP = 'UTF-8';
    }
    my $charmap_priority;
    my @charmap_priority;
    my %charmap_priority;
    $charmap_priority = 'high';
}
else {
    if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'locale';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        $CHARMAP = do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'locale', 'charmap');
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
};
}
    else {
        $CHARMAP = 'unknown';
    }
}
if (!(# Original bash: echo "$charmaps" | grep "$CHARMAP" >/dev/null;
{
    my $output_10 = q{};
    my $output_printed_10;
    my $pipeline_success_10 = 1;
    $output_10 .= $charmaps . "\n";
if ( !($output_10 =~ m{\n\z}msx) ) { $output_10 .= "\n"; }
$CHILD_ERROR = 0;

        do {
    open my $original_stdout, '>&', STDOUT
    or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
    or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    my $tmp_redirect_11 = q{};
    my $grep_result_12;
    my @grep_lines_12 = split /\n/msx, $output_10;
    my @grep_filtered_12 = grep { /$CHARMAP/msx } @grep_lines_12;
    $grep_result_12 = join "\n", @grep_filtered_12;
    if (!($grep_result_12 =~ m{\n\z}msx || $grep_result_12 eq q{})) {
    $grep_result_12 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_12 > 0 ? 0 : 1;
    $tmp_redirect_11 = $grep_result_12;
    $tmp_redirect_11;
    };
    print $tmp;
    if ($tmp eq q{}) { print $output_10; }
    $output_printed_10 = 1;
    open STDOUT, '>&', $original_stdout
    or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
    or die "Close failed: $OS_ERROR\n";
    };
    if ( !$pipeline_success_10 ) { $main_exit_code = 1; }
    })) {
    $charmap_priority = 'low';
}
else {
    $CHARMAP = 'UTF-8';
    $charmap_priority = 'high';
}
if ("$locale" =~ /^.*KOI8.*$/msx or "$locale" =~ /^.*koi8.*$/msx) {
        $CODESET = 'CyrKoi';
        my $codeset_priority;
    my @codeset_priority;
    my %codeset_priority;
    $codeset_priority = 'low';
} elsif ("$locale" =~ /^aa_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^af_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^am_.*$/msx) {
        $CODESET = 'Ethiopian';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^an_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ar_.*$/msx) {
        $CODESET = 'Arabic';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ast_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^az_.*$/msx) {
        $CODESET = 'Uni3';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^be_.*$/msx) {
        $CODESET = 'CyrSlav';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^bg_.*$/msx) {
        $CODESET = 'CyrSlav';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^bn_.*$/msx) {
        $CODESET = 'unsupported';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^br_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^bs_.*$/msx) {
        $CODESET = 'Uni3';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^byn_.*$/msx) {
        $CODESET = 'Ethiopian';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ca_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^cs_.*$/msx) {
        $CODESET = 'Lat2';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^cy_.*$/msx) {
        $CODESET = 'Lat38';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^da_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^de_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^el_.*$/msx) {
        $CODESET = 'Greek';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^en_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^eo$/msx or "$locale" =~ /^eo..*$/msx or "$locale" =~ /^eo_.*$/msx or "$locale" =~ /^eo\@.*$/msx) {
        $CODESET = 'Lat38';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^es_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^et_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^eu_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^fa_.*$/msx) {
        $CODESET = 'Arabic';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^fi_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^fo_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^fr_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ga_.*$/msx) {
        $CODESET = 'Lat38';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^gd_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^gez_.*$/msx) {
        $CODESET = 'Ethiopian';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^gl_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^gu_.*$/msx) {
        $CODESET = 'unsupported';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^gv_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^he_.*$/msx) {
        $CODESET = 'Hebrew';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^hi_.*$/msx) {
        $CODESET = 'unsupported';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^hr_.*$/msx) {
        $CODESET = 'Lat2';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^hu_.*$/msx) {
        $CODESET = 'Lat2';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^hy_.*$/msx) {
        $CODESET = 'Armenian';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^id_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^is_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^it_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^iw_.*$/msx) {
        $CODESET = 'Hebrew';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ja_.*$/msx) {
        $CODESET = 'unsupported';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ka_.*$/msx) {
        $CODESET = 'Georgian';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^kl_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^kn_.*$/msx) {
        $CODESET = 'unsupported';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ko_.*$/msx) {
        $CODESET = 'unsupported';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^kw_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^lg_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^lo_.*$/msx) {
        $CODESET = 'Lao';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^lt_.*$/msx) {
        $CODESET = 'Lat7';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^lv_.*$/msx) {
        $CODESET = 'Lat7';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ky_.*$/msx) {
        $CODESET = 'CyrAsia';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^mi_.*$/msx) {
        $CODESET = 'Lat7';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^mk_.*$/msx) {
        $CODESET = 'CyrSlav';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ml_.*$/msx) {
        $CODESET = 'unsupported';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^mn_.*$/msx) {
        $CODESET = 'CyrAsia';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^mr_.*$/msx) {
        $CODESET = 'unsupported';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ms_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^mt_.*$/msx) {
        $CODESET = 'Lat38';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^nb_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ne_.*$/msx) {
        $CODESET = 'unsupported';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^nl_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^nn_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^oc_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^om_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^pa_.*$/msx) {
        $CODESET = 'unsupported';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^pl_.*$/msx) {
        $CODESET = 'Lat2';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^pt_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ro_.*$/msx) {
        $CODESET = 'Lat2';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ru_.*$/msx) {
        $CODESET = 'CyrSlav';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^se_.*$/msx) {
        $CODESET = 'Uni1';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^sid_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^sk_.*$/msx) {
        $CODESET = 'Lat2';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^sl_.*$/msx) {
        $CODESET = 'Lat2';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^so_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^sq_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^sr_.*$/msx) {
        $CODESET = 'CyrSlav';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^st_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^sv_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ta_.*$/msx) {
        $CODESET = 'unsupported';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^te_.*$/msx) {
        $CODESET = 'unsupported';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^tg_.*$/msx) {
        $CODESET = 'CyrAsia';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^th_.*$/msx) {
        $CODESET = 'Thai';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ti_.*$/msx) {
        $CODESET = 'Ethiopian';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^tig_.*$/msx) {
        $CODESET = 'Ethiopian';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^tl_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^tr_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^tt_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^uk_.*$/msx) {
        $CODESET = 'CyrSlav';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^ur_.*$/msx) {
        $CODESET = 'Arabic';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^uz_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^uz_.*\@cyrillic$/msx) {
        $CODESET = 'CyrAsia';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^vi_.*$/msx) {
        $CODESET = 'Vietnamese';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^wa_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^xh_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^yi_.*$/msx) {
        $CODESET = 'Hebrew';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^zh_.*$/msx) {
        $CODESET = 'unsupported';
        $codeset_priority = 'low';
} elsif ("$locale" =~ /^zu_.*$/msx) {
        $CODESET = 'Lat15';
        $codeset_priority = 'low';
} elsif (1) {
        $CODESET = 'guess';
    if ("$CHARMAP" eq UTF-8) {
        $codeset_priority = 'high';
}
    else {
        $codeset_priority = 'low';
    }
}
if ("$CODESET" eq unsupported) {
    $CODESET = 'guess';
}
if ("$CODESET" =~ /^Arabic$/msx) {
        $FONTFACE = 'VGA';
} elsif ("$CODESET" =~ /^Armenian$/msx) {
        $FONTFACE = 'Fixed';
} elsif ("$CODESET" =~ /^CyrAsia$/msx) {
        $FONTFACE = 'Fixed';
} elsif ("$CODESET" =~ /^CyrKoi$/msx) {
        $FONTFACE = 'VGA';
} elsif ("$CODESET" =~ /^CyrSlav$/msx) {
        $FONTFACE = 'Fixed';
} elsif ("$CODESET" =~ /^Ethiopian$/msx) {
        $FONTFACE = 'Goha';
} elsif ("$CODESET" =~ /^Georgian$/msx) {
        $FONTFACE = 'Fixed';
} elsif ("$CODESET" =~ /^Greek$/msx) {
        $FONTFACE = 'Fixed';
} elsif ("$CODESET" =~ /^Hebrew$/msx) {
        $FONTFACE = 'Fixed';
} elsif ("$CODESET" =~ /^Lao$/msx) {
        $FONTFACE = 'Fixed';
} elsif ("$CODESET" =~ /^Lat15$/msx) {
} elsif ("$CODESET" =~ /^Lat2$/msx) {
        $FONTFACE = 'Fixed';
} elsif ("$CODESET" =~ /^Lat38$/msx) {
        $FONTFACE = 'Fixed';
} elsif ("$CODESET" =~ /^Lat7$/msx) {
        $FONTFACE = 'Fixed';
} elsif ("$CODESET" =~ /^Thai$/msx) {
        $FONTFACE = 'Fixed';
} elsif ("$CODESET" =~ /^Uni1$/msx) {
        $FONTFACE = 'VGA';
} elsif ("$CODESET" =~ /^Uni2$/msx) {
        $FONTFACE = 'Fixed';
} elsif ("$CODESET" =~ /^Uni3$/msx) {
        $FONTFACE = 'Fixed';
} elsif ("$CODESET" =~ /^Vietnamese$/msx) {
        $FONTFACE = 'Fixed';
} elsif (1) {
        $FONTFACE = 'Fixed';
}
if (!(# Original bash: lsmod | grep -q speakup;
{
    my $output_13 = q{};
    my $output_printed_13;
    my $pipeline_success_13 = 1;
        my ($in_14, $out_14);
    my $pid_14 = open3($in_14, $out_14, '>&STDERR', 'lsmod', );
    close $in_14 or croak 'Close failed: $OS_ERROR';
    $output_13 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_14> };
    close $out_14 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_14, 0;

        my $grep_result_13_1;
    my @grep_lines_13_1 = split /\n/msx, $output_13;
    my @grep_filtered_13_1 = grep { /speakup/msx } @grep_lines_13_1;
    $grep_result_13_1 = join "\n", @grep_filtered_13_1;
    if (!($grep_result_13_1 =~ m{\n\z}msx || $grep_result_13_1 eq q{})) {
    $grep_result_13_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_13_1 > 0 ? 0 : 1;
    $grep_result_13_1 = q{};
    $output_13 = q{};
    if ((scalar @grep_filtered_13_1) == 0) {
        $pipeline_success_13 = 0;
    }
    if ($output_13 ne q{} && !defined $output_printed_13) {
        print $output_13;
        if (!($output_13 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_13 ) { $main_exit_code = 1; }
    })) {
if ("$CODESET" =~ /^CyrAsia$/msx or "$CODESET" =~ /^CyrSlav$/msx or "$CODESET" =~ /^Greek$/msx) {
                $CODESET = "Full$CODESET";
    }
}
if ((-e $CONFIGFILE)) {
        $main_exit_code = system('.', $CONFIGFILE) >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
}
if (("$CODESET")) {
    $default_codeset = (do { my $_chomp_temp = do {
    my ($in_16, $out_16);
    my $pid_16 = open3($in_16, $out_16, '>&STDERR', 'decode_codeset', "$CODESET");
    close $in_16 or croak 'Close failed: $OS_ERROR';
    my $result_16 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_16> };
    close $out_16 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_16, 0;
    $result_16
}; chomp $_chomp_temp; $_chomp_temp; });
}
if ("$FONTFACE" eq guess) {
    $main_exit_code = system('db_metaget', 'console-setup/guess_font', 'description') >> 8;
    $default_fontface = "$RET";
}
else {
    if (("$FONTFACE")) {
        $default_fontface = "$FONTFACE";
}
    else {
        $main_exit_code = system('db_metaget', "console-setup/use_" . "sys" . "tem" . "_font", 'description') >> 8;
        $default_fontface = "$RET";
    }
}
if (("$FONTSIZE" eq guess && "$FONTFACE" ne guess)) {
    $FONTSIZE = '16';
}
if (("$FONTFACE")) {
    $FONTSIZE = (defined ${FONTSIZE} && ${FONTSIZE} ne q{} ? ${FONTSIZE} : '16');
}
$main_exit_code = system('db_get', 'console-setup/store_defaults_in_debconf_db') >> 8;
if ("$RET" eq true) {
    $main_exit_code = system('db_set', 'console-setup/charmap47', "$CHARMAP") >> 8;
    $main_exit_code = system('db_set', 'console-setup/codeset47', "$default_codeset") >> 8;
    $main_exit_code = system('db_set', 'console-setup/fontface47', "$default_fontface") >> 8;
    my $fontsizetext;
    my @fontsizetext;
    my %fontsizetext;
    $fontsizetext = (do { my $_chomp_temp = do {
    my ($in_17, $out_17);
    my $pid_17 = open3($in_17, $out_17, '>&STDERR', 'decode_fontsize', $FONTSIZE);
    close $in_17 or croak 'Close failed: $OS_ERROR';
    my $result_17 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> };
    close $out_17 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_17, 0;
    $result_17
}; chomp $_chomp_temp; $_chomp_temp; });
    $main_exit_code = system('db_set', 'console-setup/fontsize-text47', "$fontsizetext") >> 8;
    $main_exit_code = system('db_set', 'console-setup/fontsize-fb47', "$fontsizetext") >> 8;
    $main_exit_code = system('db_set', 'console-setup/fontsize', "$fontsizetext") >> 8;
    $main_exit_code = system('db_set', 'console-setup/store_defaults_in_debconf_db', 'false') >> 8;
}
$STATE = q{1};
my $old_state;
my @old_state;
my %old_state;
$old_state = q{0};
while ( $main_exit_code = system('bash', ':') >> 8 ) {
    my $starting_state;
    my @starting_state;
    my %starting_state;
    $starting_state = $STATE;
if ("$STATE" =~ /^1$/msx) {
                $choices = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_18 = q{};
            my $output_printed_18;
            my $pipeline_success_18 = 1;
            $output_18 .= $charmaps . "\n";
            if ( !($output_18 =~ m{\n\z}msx) ) { $output_18 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_18 = 0; }
            my @sed_lines_18 = split /\n/msx, $output_18;
            my @sed_result_18;
            foreach my $line (@sed_lines_18) {
            chomp $line;
            push @sed_result_18, $line;
            }
            $output_18 = join "\n", @sed_result_18;

            my @sort_lines_18_2 = split /\n/msx, $output_18;
            my @sort_sorted_18_2 = sort @sort_lines_18_2;
            $output_18 = join "\n", @sort_sorted_18_2;
                        if ($output_18 ne q{} && !($output_18 =~ m{\n\z}msx)) {
                            $output_18 .= "\n";
                        }
            if ( !$pipeline_success_18 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_18 =~ s/\n+\z//msx;
            $output_18;
}; $_pipeline_result; };
                $choices = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_19 = q{};
            my $output_printed_19;
            my $pipeline_success_19 = 1;
            $output_19 .= $choices . "\n";
            if ( !($output_19 =~ m{\n\z}msx) ) { $output_19 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_19 = 0; }
            my @sed_lines_19 = split /\n/msx, $output_19;
            my @sed_result_19;
            foreach my $line (@sed_lines_19) {
            chomp $line;
            push @sed_result_19, $line;
            }
            $output_19 = join "\n", @sed_result_19;

            if ( !$pipeline_success_19 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_19 =~ s/\n+\z//msx;
            $output_19;
}; $_pipeline_result; };
                $main_exit_code = system('db_subst', 'console-setup/charmap47', 'CHOICES', "$choices") >> 8;
                        $main_exit_code = system('db_input', $charmap_priority, 'console-setup/charmap47') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
        if (!(        $main_exit_code = system('bash', 'db_go') >> 8)) {
            if (defined $STATE) {
                $STATE = eval { int($STATE + 1) } // "";
            }
}
        else {
            if (defined $STATE) {
                $STATE = eval { int($STATE - 1) } // "";
            }
        }
    } elsif ("$STATE" =~ /^2$/msx) {
                        $main_exit_code = system('db_input', $codeset_priority, 'console-setup/codeset47') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
        if (!(        $main_exit_code = system('bash', 'db_go') >> 8)) {
            $main_exit_code = system('db_get', 'console-setup/codeset47') >> 8;
            $CODESET = (do { my $_chomp_temp = do {
    my ($in_22, $out_22);
    my $pid_22 = open3($in_22, $out_22, '>&STDERR', 'encode_codeset', "$RET");
    close $in_22 or croak 'Close failed: $OS_ERROR';
    my $result_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_22> };
    close $out_22 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_22, 0;
    $result_22
}; chomp $_chomp_temp; $_chomp_temp; });
            $main_exit_code = system('db_set', 'console-setup/codesetcode', "$CODESET") >> 8;
            if (defined $STATE) {
                $STATE = eval { int($STATE + 1) } // "";
            }
}
        else {
            if (defined $STATE) {
                $STATE = eval { int($STATE - 1) } // "";
            }
        }
    } elsif ("$STATE" =~ /^3$/msx) {
                my $fontfaces;
        my @fontfaces;
        my %fontfaces;
        $fontfaces = do {
    my ($in_23, $out_23);
    my $pid_23 = open3($in_23, $out_23, '>&STDERR', 'available_fontfaces');
    close $in_23 or croak 'Close failed: $OS_ERROR';
    my $result_23 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
    close $out_23 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_23, 0;
    $result_23
};
                $choices = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_24 = q{};
            my $output_printed_24;
            my $pipeline_success_24 = 1;
            $output_24 .= $fontfaces . "\n";
            if ( !($output_24 =~ m{\n\z}msx) ) { $output_24 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_24 = 0; }
            my @sed_lines_24 = split /\n/msx, $output_24;
            my @sed_result_24;
            foreach my $line (@sed_lines_24) {
            chomp $line;
            push @sed_result_24, $line;
            }
            $output_24 = join "\n", @sed_result_24;

            if ( !$pipeline_success_24 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_24 =~ s/\n+\z//msx;
            $output_24;
}; $_pipeline_result; };
                $choices = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_25 = q{};
            my $output_printed_25;
            my $pipeline_success_25 = 1;
            $output_25 .= $choices . "\n";
            if ( !($output_25 =~ m{\n\z}msx) ) { $output_25 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_25 = 0; }
            my @sed_lines_25 = split /\n/msx, $output_25;
            my @sed_result_25;
            foreach my $line (@sed_lines_25) {
            chomp $line;
            push @sed_result_25, $line;
            }
            $output_25 = join "\n", @sed_result_25;

            if ( !$pipeline_success_25 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_25 =~ s/\n+\z//msx;
            $output_25;
}; $_pipeline_result; };
                $main_exit_code = system('db_metaget', "console-setup/use_" . "sys" . "tem" . "_font", 'description') >> 8;
                $choices = "$choices, $RET";
                $main_exit_code = system('db_metaget', 'console-setup/guess_font', 'description') >> 8;
                $choices = "$choices, $RET";
                $main_exit_code = system('db_subst', 'console-setup/fontface47', 'CHOICES', "$choices") >> 8;
                        $main_exit_code = system('db_input', 'medium', 'console-setup/fontface47') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
        if (!(        $main_exit_code = system('bash', 'db_go') >> 8)) {
            if (defined $STATE) {
                $STATE = eval { int($STATE + 1) } // "";
            }
}
        else {
            if (defined $STATE) {
                $STATE = eval { int($STATE - 1) } // "";
            }
        }
                $main_exit_code = system('db_get', 'console-setup/fontface47') >> 8;
                $fontface = $RET;
                $main_exit_code = system('db_metaget', "console-setup/use_" . "sys" . "tem" . "_font", 'description') >> 8;
        if ("$fontface" eq "$RET") {
            $fontface = q{};
        }
                $main_exit_code = system('db_metaget', 'console-setup/guess_font', 'description') >> 8;
        if ("$fontface" eq "$RET") {
            $fontface = 'guess';
        }
    } elsif ("$STATE" =~ /^4$/msx) {
        if ("$kernel" eq freebsd) {
            $main_exit_code = system('db_set', 'console-setup/fontsize', "$FONTSIZE") >> 8;
            if (defined $STATE) {
                $STATE = eval { int( $STATE + $STATE - $old_state ) } // "";
            }
}
        else {
            my $fontsizes;
            my @fontsizes;
            my %fontsizes;
            $fontsizes = do {
    my ($in_27, $out_27);
    my $pid_27 = open3($in_27, $out_27, '>&STDERR', 'available_fontsizes');
    close $in_27 or croak 'Close failed: $OS_ERROR';
    my $result_27 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_27> };
    close $out_27 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_27, 0;
    $result_27
};
            $choices = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_28 = q{};
                my $output_printed_28;
                my $pipeline_success_28 = 1;
                $output_28 .= $fontsizes . "\n";
                if ( !($output_28 =~ m{\n\z}msx) ) { $output_28 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_28 = 0; }
                my @sed_lines_28 = split /\n/msx, $output_28;
                my @sed_result_28;
                foreach my $line (@sed_lines_28) {
                chomp $line;
                push @sed_result_28, $line;
                }
                $output_28 = join "\n", @sed_result_28;

                if ( !$pipeline_success_28 ) { $main_exit_code = 1; }
                exit $main_exit_code if $__set_e && $main_exit_code != 0;
                $output_28 =~ s/\n+\z//msx;
                $output_28;
}; $_pipeline_result; };
            $choices = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_29 = q{};
                my $output_printed_29;
                my $pipeline_success_29 = 1;
                $output_29 .= $choices . "\n";
                if ( !($output_29 =~ m{\n\z}msx) ) { $output_29 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_29 = 0; }
                my @sed_lines_29 = split /\n/msx, $output_29;
                my @sed_result_29;
                foreach my $line (@sed_lines_29) {
                chomp $line;
                push @sed_result_29, $line;
                }
                $output_29 = join "\n", @sed_result_29;

                if ( !$pipeline_success_29 ) { $main_exit_code = 1; }
                exit $main_exit_code if $__set_e && $main_exit_code != 0;
                $output_29 =~ s/\n+\z//msx;
                $output_29;
}; $_pipeline_result; };
if (("$choices" ne q{} && "$FONTSIZE" ne guess)) {
if (!(                # Original bash: echo "$choices" | grep -q x;
{
                    my $output_30 = q{};
                    my $output_printed_30;
                    my $pipeline_success_30 = 1;
                    $output_30 .= $choices . "\n";
if ( !($output_30 =~ m{\n\z}msx) ) { $output_30 .= "\n"; }
$CHILD_ERROR = 0;

                                        my $grep_result_30_1;
                    my @grep_lines_30_1 = split /\n/msx, $output_30;
                    my @grep_filtered_30_1 = grep { /x/msx } @grep_lines_30_1;
                    $grep_result_30_1 = join "\n", @grep_filtered_30_1;
                    if (!($grep_result_30_1 =~ m{\n\z}msx || $grep_result_30_1 eq q{})) {
                    $grep_result_30_1 .= "\n";
                    }
                    $CHILD_ERROR = scalar @grep_filtered_30_1 > 0 ? 0 : 1;
                    $grep_result_30_1 = q{};
                    $output_30 = q{};
                    if ((scalar @grep_filtered_30_1) == 0) {
                        $pipeline_success_30 = 0;
                    }
                    if ($output_30 ne q{} && !defined $output_printed_30) {
                        print $output_30;
                        if (!($output_30 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_30 ) { $main_exit_code = 1; }
                    })) {
                    my $size_template;
                    my @size_template;
                    my %size_template;
                    $size_template = 'console-setup/fontsize-fb47';
}
                else {
                    $size_template = 'console-setup/fontsize-text47';
                }
                $main_exit_code = system('db_subst', $size_template, 'CHOICES', "$choices") >> 8;
                                $main_exit_code = system('db_input', 'medium', $size_template) >> 8;
                if ($CHILD_ERROR != 0) {
                    1;
                }
if (!(                $main_exit_code = system('bash', 'db_go') >> 8)) {
                    if (defined $STATE) {
                        $STATE = eval { int($STATE + 1) } // "";
                    }
}
                else {
                    if (defined $STATE) {
                        $STATE = eval { int($STATE - 1) } // "";
                    }
                }
                $main_exit_code = system('db_get', $size_template) >> 8;
                $FONTSIZE = do {
    my ($in_32, $out_32);
    my $pid_32 = open3($in_32, $out_32, '>&STDERR', 'encode_fontsize', "$RET");
    close $in_32 or croak 'Close failed: $OS_ERROR';
    my $result_32 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_32> };
    close $out_32 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_32, 0;
    $result_32
};
}
            else {
                $FONTSIZE = (defined ${choices} && ${choices} ne q{} ? ${choices} : 'guess');
                if (defined $STATE) {
                    $STATE = eval { int( $STATE + $STATE - $old_state ) } // "";
                }
            }
            $main_exit_code = system('db_set', 'console-setup/fontsize', "$FONTSIZE") >> 8;
        }
    } elsif (1) {
        last;    }
    $old_state = $starting_state;
}
if (($STATE == 0)) {
exit 10;
}
exit 0;

exit $main_exit_code;
