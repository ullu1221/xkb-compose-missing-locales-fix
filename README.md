# xkb-compose-missing-locales-fix

**Fix missing XKB Compose file mappings that cause KDE Plasma (Wayland) errors at boot.**

41 locales across 20+ countries are affected by a bug in libX11's locale data. This repo documents the issue and provides an automated fix.

---

## The Problem

On KDE Plasma (Wayland), users with certain locales see these errors at every boot:

```
$ journalctl -b -p 3

kwin_wayland: XKB: [XKB-679] No Compose file for locale "xx_YY.ISO8859-1": locale is either invalid or not installed
kwin_wayland: XKB: [XKB-679] couldn't find a Compose file for locale "xx_YY" (mapped to "xx_YY.ISO8859-1")
```

## Root Cause

When KWin starts on Wayland, it initializes **XKB** (X Keyboard Extension) for keyboard input handling. XKB needs a **Compose file** to support multi-key character composition (e.g. typing accented characters).

Here's what happens:

```
User locale: en_IN.UTF-8
         │
         ▼
XKB looks up compose.dir
         │
         ├── en_IN.UTF-8 → en_US.UTF-8/Compose  ✅ Found
         │
         ├── Fallback: bare "en_IN" → mapped to "en_IN.ISO8859-1"
         │
         └── en_IN.ISO8859-1 → ???  ❌ No entry! → ERROR
```

The file `/usr/share/X11/locale/compose.dir` has UTF-8 entries for these locales but is **missing legacy ISO8859-1 fallback entries**. When XKB does its fallback lookup, it fails and logs an error.

## Affected Locales

**41 locales** across **20+ countries** are affected:

### Asia & South Asia
| Locale | Language | Country |
|--------|----------|---------|
| `ar_IN` | Arabic | 🇮🇳 India |
| `as_IN` | Assamese | 🇮🇳 India |
| `bn_BD` | Bengali | 🇧🇩 Bangladesh |
| `bn_IN` | Bengali | 🇮🇳 India |
| `bo_IN` | Tibetan | 🇮🇳 India |
| `en_IN` | English | 🇮🇳 India |
| `gu_IN` | Gujarati | 🇮🇳 India |
| `hne_IN` | Chhattisgarhi | 🇮🇳 India |
| `kn_IN` | Kannada | 🇮🇳 India |
| `ks_IN` | Kashmiri | 🇮🇳 India |
| `mai_IN` | Maithili | 🇮🇳 India |
| `ml_IN` | Malayalam | 🇮🇳 India |
| `mr_IN` | Marathi | 🇮🇳 India |
| `ne_NP` | Nepali | 🇳🇵 Nepal |
| `or_IN` | Odia | 🇮🇳 India |
| `pa_IN` | Punjabi | 🇮🇳 India |
| `pa_PK` | Punjabi | 🇵🇰 Pakistan |
| `sa_IN` | Sanskrit | 🇮🇳 India |
| `sd_IN` | Sindhi | 🇮🇳 India |
| `si_LK` | Sinhala | 🇱🇰 Sri Lanka |
| `te_IN` | Telugu | 🇮🇳 India |
| `ur_IN` | Urdu | 🇮🇳 India |
| `km_KH` | Khmer | 🇰🇭 Cambodia |
| `zh_SG` | Chinese | 🇸🇬 Singapore |

### Central Asia
| Locale | Language | Country |
|--------|----------|---------|
| `kk_KZ` | Kazakh | 🇰🇿 Kazakhstan |
| `ky_KG` | Kyrgyz | 🇰🇬 Kyrgyzstan |

### Europe
| Locale | Language | Country |
|--------|----------|---------|
| `ast_ES` | Asturian | 🇪🇸 Spain |
| `de_IT` | German | 🇮🇹 Italy (South Tyrol) |
| `el_CY` | Greek | 🇨🇾 Cyprus |
| `en_DK` | English | 🇩🇰 Denmark |
| `en_MT` | English | 🇲🇹 Malta |
| `ku_TR` | Kurdish | 🇹🇷 Turkey |
| `se_NO` | Northern Sami | 🇳🇴 Norway |
| `sh_BA` | Serbo-Croatian | 🇧🇦 Bosnia |
| `sr_ME` | Serbian | 🇲🇪 Montenegro |
| `sr_RS` | Serbian | 🇷🇸 Serbia |

### Africa
| Locale | Language | Country |
|--------|----------|---------|
| `am_ET` | Amharic | 🇪🇹 Ethiopia |
| `ti_ER` | Tigrinya | 🇪🇷 Eritrea |
| `ti_ET` | Tigrinya | 🇪🇹 Ethiopia |
| `ve_ZA` | Venda | 🇿🇦 South Africa |

### Americas
| Locale | Language | Country |
|--------|----------|---------|
| `iu_CA` | Inuktitut | 🇨🇦 Canada |

## Quick Start

### Check if you're affected

```bash
# Check boot errors
journalctl -b -p 3 --grep="Compose|XKB"

# Or run the diagnostic
./fix.sh --check
```

### Apply the fix

```bash
sudo ./fix.sh
```

### Fix only your locale

```bash
sudo ./fix.sh --single en_IN
```

## How It Works

The script adds missing legacy fallback entries to two X11 locale files:

| File | Entry Added |
|------|-------------|
| `/usr/share/X11/locale/compose.dir` | `en_US.UTF-8/Compose  xx_YY.ISO8859-1` |
| `/usr/share/X11/locale/locale.dir` | `en_US.UTF-8/XLC_LOCALE  xx_YY.ISO8859-1` |

This points the legacy fallback to the same `en_US.UTF-8` Compose file that the UTF-8 variant already uses — a safe and correct mapping.

The script is:
- ✅ **Idempotent** — safe to run multiple times
- ✅ **Non-destructive** — only appends, never modifies existing entries
- ✅ **Selective** — use `--single LOCALE` to fix just your locale

## Verification

After applying the fix, **reboot** and check:

```bash
journalctl -b -p 3 --grep="Compose|XKB"
# Expected: -- No entries --
```

### Before

```
$ journalctl -b -p 3
...
kwin_wayland: XKB: [XKB-679] No Compose file for locale "en_IN.ISO8859-1"
kwin_wayland: XKB: [XKB-679] couldn't find a Compose file for locale "en_IN"
```

### After

```
$ journalctl -b -p 3
(no XKB errors)
```

## Notes

- ⚠️ The fix may be **overwritten when `libx11` is updated**. Re-run the script after package updates if the errors reappear.
- This is an **upstream bug** in libX11's locale data — these locales were simply never added to the mapping files.
- Consider reporting this upstream to [freedesktop.org/xorg](https://gitlab.freedesktop.org/xorg/lib/libx11).

## Tested On

- **OS:** Arch Linux / Manjaro
- **Desktop:** KDE Plasma 6 (Wayland)
- **Locale:** `en_IN.UTF-8`

## License

[Unlicense](LICENSE) — public domain. Use it however you want.
