#!/bin/bash
# fix.sh - Fix missing XKB Compose file mappings for 41 affected locales
#
# libX11's compose.dir and locale.dir are missing legacy ISO8859-1 fallback
# entries for 41 locales, causing KWin/XKB errors on KDE Plasma Wayland.
#
# This script adds the missing mappings pointing to en_US.UTF-8, which is
# the same Compose file that the UTF-8 variants already use.
#
# Usage:
#   sudo ./fix.sh            Fix all 41 affected locales
#   sudo ./fix.sh --single en_IN   Fix only a specific locale
#   ./fix.sh --check         Dry run — show what's missing
#   ./fix.sh --help          Show help

set -euo pipefail

COMPOSE_DIR="/usr/share/X11/locale/compose.dir"
LOCALE_DIR="/usr/share/X11/locale/locale.dir"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ── All 41 affected locales ──────────────────────────────────────────
# These have UTF-8 Compose entries in compose.dir but no legacy
# ISO8859-1 fallback, causing XKB lookup failures.
AFFECTED_LOCALES=(
    am_ET       # Amharic - Ethiopia
    ar_IN       # Arabic - India
    as_IN       # Assamese - India
    ast_ES      # Asturian - Spain
    bn_BD       # Bengali - Bangladesh
    bn_IN       # Bengali - India
    bo_IN       # Tibetan - India
    de_IT       # German - Italy (South Tyrol)
    el_CY       # Greek - Cyprus
    en_DK       # English - Denmark
    en_IN       # English - India
    en_MT       # English - Malta
    gu_IN       # Gujarati - India
    hne_IN      # Chhattisgarhi - India
    iu_CA       # Inuktitut - Canada
    kk_KZ       # Kazakh - Kazakhstan
    km_KH       # Khmer - Cambodia
    kn_IN       # Kannada - India
    ks_IN       # Kashmiri - India
    ku_TR       # Kurdish - Turkey
    ky_KG       # Kyrgyz - Kyrgyzstan
    mai_IN      # Maithili - India
    ml_IN       # Malayalam - India
    mr_IN       # Marathi - India
    ne_NP       # Nepali - Nepal
    or_IN       # Odia - India
    pa_IN       # Punjabi - India
    pa_PK       # Punjabi - Pakistan
    sa_IN       # Sanskrit - India
    sd_IN       # Sindhi - India
    se_NO       # Northern Sami - Norway
    sh_BA       # Serbo-Croatian - Bosnia
    si_LK       # Sinhala - Sri Lanka
    sr_ME       # Serbian - Montenegro
    sr_RS       # Serbian - Serbia
    te_IN       # Telugu - India
    ti_ER       # Tigrinya - Eritrea
    ti_ET       # Tigrinya - Ethiopia
    ur_IN       # Urdu - India
    ve_ZA       # Venda - South Africa
    zh_SG       # Chinese - Singapore
)

# ── Parse arguments ──────────────────────────────────────────────────
CHECK_ONLY=false
SINGLE_LOCALE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --single)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error: --single requires a locale argument (e.g. --single en_IN)${NC}"
                exit 1
            fi
            SINGLE_LOCALE="$2"
            shift 2
            ;;
        -h|--help)
            echo -e "${BOLD}xkb-compose-missing-locales-fix${NC}"
            echo ""
            echo "Fix missing XKB Compose file mappings for 41 affected locales."
            echo ""
            echo -e "${BOLD}Usage:${NC}"
            echo "  sudo ./fix.sh              Fix all 41 affected locales"
            echo "  sudo ./fix.sh --single XX  Fix only locale XX (e.g. en_IN)"
            echo "  ./fix.sh --check           Dry run — show what's missing"
            echo "  ./fix.sh --help            Show this help"
            echo ""
            echo -e "${BOLD}Affected locales:${NC}"
            for loc in "${AFFECTED_LOCALES[@]}"; do
                echo "  $loc"
            done
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Run with --help for usage."
            exit 1
            ;;
    esac
done

# ── Preflight checks ────────────────────────────────────────────────
if [[ "$CHECK_ONLY" == false && $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root (use sudo).${NC}"
    echo "Run with --check for a dry run without root."
    exit 1
fi

for f in "$COMPOSE_DIR" "$LOCALE_DIR"; do
    if [[ ! -f "$f" ]]; then
        echo -e "${RED}Error: $f not found. Is libX11 installed?${NC}"
        exit 1
    fi
done

# ── Filter to single locale if requested ─────────────────────────────
if [[ -n "$SINGLE_LOCALE" ]]; then
    found=false
    for loc in "${AFFECTED_LOCALES[@]}"; do
        if [[ "$loc" == "$SINGLE_LOCALE" ]]; then
            found=true
            break
        fi
    done
    if [[ "$found" == false ]]; then
        echo -e "${YELLOW}Note: '$SINGLE_LOCALE' is not in the known affected list, but proceeding anyway.${NC}"
    fi
    AFFECTED_LOCALES=("$SINGLE_LOCALE")
fi

# ── Main loop ────────────────────────────────────────────────────────
echo -e "${BOLD}=== XKB Compose Fix for Missing Locale Mappings ===${NC}"
echo ""

fixed_compose=0
fixed_locale=0
skipped=0
missing_compose=0
missing_locale=0

for loc in "${AFFECTED_LOCALES[@]}"; do
    iso_locale="${loc}.ISO8859-1"

    # Check compose.dir
    compose_missing=false
    if ! grep -q "$iso_locale" "$COMPOSE_DIR" 2>/dev/null; then
        compose_missing=true
        missing_compose=$((missing_compose + 1))
    fi

    # Check locale.dir
    locale_missing=false
    if ! grep -q "$iso_locale" "$LOCALE_DIR" 2>/dev/null; then
        locale_missing=true
        missing_locale=$((missing_locale + 1))
    fi

    # ── Check-only mode ──
    if [[ "$CHECK_ONLY" == true ]]; then
        if [[ "$compose_missing" == true || "$locale_missing" == true ]]; then
            detail=""
            [[ "$compose_missing" == true ]] && detail+="compose.dir "
            [[ "$locale_missing" == true ]] && detail+="locale.dir"
            echo -e "  ${RED}[MISSING]${NC} $iso_locale  (missing in: $detail)"
        else
            echo -e "  ${GREEN}[OK]${NC}      $iso_locale"
        fi
        continue
    fi

    # ── Apply fixes ──
    if [[ "$compose_missing" == true ]]; then
        echo "en_US.UTF-8/Compose		${iso_locale}" >> "$COMPOSE_DIR"
        fixed_compose=$((fixed_compose + 1))
    fi

    if [[ "$locale_missing" == true ]]; then
        echo "en_US.UTF-8/XLC_LOCALE			${iso_locale}" >> "$LOCALE_DIR"
        fixed_locale=$((fixed_locale + 1))
    fi

    if [[ "$compose_missing" == true || "$locale_missing" == true ]]; then
        echo -e "  ${GREEN}[FIXED]${NC}   $iso_locale"
    else
        echo -e "  ${YELLOW}[SKIP]${NC}    $iso_locale (already present)"
        skipped=$((skipped + 1))
    fi
done

# ── Summary ──────────────────────────────────────────────────────────
echo ""

if [[ "$CHECK_ONLY" == true ]]; then
    total_missing=$((missing_compose + missing_locale))
    if [[ $total_missing -eq 0 ]]; then
        echo -e "${GREEN}All locales are properly mapped. No fix needed!${NC}"
    else
        echo -e "${BLUE}Found ${missing_compose} missing compose.dir and ${missing_locale} missing locale.dir entries.${NC}"
        echo "Run without --check to apply the fix (requires sudo)."
    fi
else
    echo -e "${GREEN}Done!${NC} Fixed ${fixed_compose} compose.dir and ${fixed_locale} locale.dir entries."
    [[ $skipped -gt 0 ]] && echo "Skipped ${skipped} already present."
    echo ""
    echo "Reboot or log out and back in for changes to take effect."
fi
