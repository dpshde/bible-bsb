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
| Book filter (22 options) | All, A to Z, 1, 2, 3 | All | Menu > Filter books: a cell grid like the chapter grid (v7); the subtitle names the focused filter's books | match (see FILTER_PARITY.md) |
| Share via NFC (`bible_nfc`) | — | — | none | divergence: Connect IQ apps cannot emit NFC |
| Header marquee (pause, then scroll) | fixed | — | Two-row pyramid section header | divergence (layout): round screens wrap instead of scrolling |
| Scrolling | fixed: one line per press | line | **Settings > Jump by verse**: on = "One verse per press", off = "One line per press" (`POKE: SCROLL_LABEL`) | Garmin addition; off = Flipper behavior |
| Theme | fixed: monochrome LCD | — | **Settings > Dark theme**: on = "Light on black", off = "Dark on white" | Garmin addition |
| Haptics | none (no motor) | — | **Settings > Tap vibration**: on = "Buzz on tap", off = "No buzz"; the watch's own vibration setting still wins | Garmin addition |
| Scroll haptics | none (no motor) | — | **Settings > Vibrate on scroll** (v7): on = "Tick on each step", off = "No tick". A 12 ms, 25% detent per book, chapter, filter or verse step, at most one per 45 ms (`POKE: STEP_VIBE`) | Garmin addition |

All four Garmin settings live in **Settings** (reached from Browse and from the reader menu), a
gold CustomMenu on every target: Menu2's ToggleMenuItem draws a green system switch and its
off-focus rows clip at the round edge. Each row's sublabel states the current value, so no
switch is drawn. The reader menu keeps "Jump by verse" as a quick native row (same sublabels). Values persist in
`Application.Storage` (`scrollMode`, `theme`, `vibe`, `vibeScroll`). Corrupt or missing values fall back to the
defaults (`testSettingsPersist`, plus the existing storage-hardening tests).

## Persistence test (toggle, kill, relaunch)
| Check | Result |
|---|---|
| Toggle writes storage at once | **pass**: `FR265.DAT`/`.IDX` appear in the simulator's app data the moment a setting flips (no exit needed) |
| Unit test `testSettingsPersist` (write, reload, corrupt value falls back to default) | **pass** (54/54 tests) |
| Simulator kill + relaunch | **not verifiable in the simulator**: every simulator restart and every `monkeydo` install wipes the app's data directory (checked: `.DAT` gone before the app starts), so settings read as defaults after any relaunch there. Frames: `screens/v4/per/`. |
| On-watch kill + relaunch | pending: needs the installed v4 on the Enduro 3 (Settings → flip all three → hold Back to exit → reopen) |

Frames: `screens/v4/after/<device>-settings-{default,toggled}.png` (Enduro 3, fr265).
