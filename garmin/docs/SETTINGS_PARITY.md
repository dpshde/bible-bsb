# Settings parity: Flipper Bible BSB → Garmin (v4)

Source checked: Flipper `bible_bsb/` at origin/main **c4c7a01** (v1.2), which is ahead of the local
checkout `/workspace/dpshde-scan/bible-bsb` at fccc0b8 (clean), plus Dylan's uncommitted
`flipper-headings-wip.patch` (bible_loader.c, bible_state.h, bible_view_reader.c,
scripts/fetch_bsb.py: section headings only, no settings).

**Finding:** the Flipper app has **no Settings screen and no user preferences**. The source has
no settings view, config file or toggle. It persists only `last_read.bin` (book, chapter,
scroll offset) and `collection.json` (saved passages). Everything else is either fixed behavior
or an in-session mode that resets on exit. The table lists each of these settings-like
behaviors and where it lives on Garmin.

| Flipper setting / behavior | Options | Default | Garmin item | Status |
|---|---|---|---|---|
| Resume last read (`last_read.bin`, saved on exit and on change) | none (always on) | on | Automatic: book, chapter and verse; also the glance | match (Garmin resumes the verse, Flipper the scroll offset) |
| Saved passages (`collection.json`; long-press quick-save, "Save to collection") | none | — | Bookmarks: long-press a verse; Menu > Bookmarks (native list, Open / Remove) | match (spirit) |
| Verse select mode for saving (`verse_select_mode`: All / Start / End) | All, Start, End | All | Single-verse bookmarks only | divergence: ranges need a two-step picker that does not suit watch buttons |
| Browse hierarchy (`genre_mode_enabled`: Testament → Genre → Book) | off / on (Right on home toggles it; not saved) | off | Browse > By Testament (native) | divergence: a menu entry instead of a hidden toggle; same hierarchy and genres |
| Book filter (22 options) | All, A to Z, 1, 2, 3 | All | Browse > Filter books (native) | match (see FILTER_PARITY.md) |
| Share via NFC (`bible_nfc`) | — | — | none | divergence: Connect IQ apps cannot emit NFC |
| Header marquee (pause, then scroll) | fixed | — | Two-row pyramid section header | divergence (layout): round screens wrap instead of scrolling |
| Scrolling | fixed: one line per press | line | **Settings > Jump by verse**: on = "Each press moves one verse", off = "Each press moves one line" (`POKE: SCROLL_LABEL`) | Garmin addition; off = Flipper behavior |
| Theme | fixed: monochrome LCD | — | **Settings > Dark theme**: on = "Light text on black", off = "Dark text on white" | Garmin addition |
| Haptics | none (no motor) | — | **Settings > Tap vibration**: on = "Buzz when a tap opens something", off = "No buzz"; the watch's own vibration setting still wins | Garmin addition |

All three Garmin settings are native `ToggleMenuItem`s in **Settings** (reached from Browse and
from the reader menu). The reader menu keeps "Jump by verse" as a quick toggle. Values persist in
`Application.Storage` (`scrollMode`, `theme`, `vibe`). Corrupt or missing values fall back to the
defaults (`testSettingsPersist`, plus the existing storage-hardening tests).

## Persistence test (simulator: toggle, kill, relaunch)
Frames `screens/v4/<device>-v4-settings-{default,toggled,after-relaunch}.png` on Enduro 3 and fr265.
