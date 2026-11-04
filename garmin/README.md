# Garmin Connect IQ — Selah Bible

Monkey C watch app for the Berean Standard Bible, following the Flipper Zero `bible_bsb` app in
this repo (the Flipper code is not changed from here; everything lives under `garmin/`).
Store name **Selah Bible**, current version **0.9.11** (About screen). Primary device Enduro 3; see the products
in `manifest.xml`. Intentional `// POKE:` markers name the values meant to be tuned.

## Layout

| Path | Purpose |
|------|---------|
| `docs/SPEC.md` | Input, grid, bookmarks, continuation, scroll modes, divergences from Flipper |
| `docs/flipper-baseline.md` | The Flipper behaviour this app is measured against |
| `docs/HW_SYNC.md` | Selah Vault bookmark sync: current state + the v1 contract the watch follows |
| `docs/BUILD.md` | SDK, keys, build, tests, store export, personal build |
| `docs/EDGE_CASES.md`, `FILTER_PARITY.md`, `SETTINGS_PARITY.md`, `font-budget.md` | Reference notes |
| `docs/screens/` | How to capture simulator screenshots; Flipper reference images |
| `source/` | App, views (home list, chapter grid, reader, FastMenu lists), bookmarks, sync |
| `test/` | Toybox.Test unit tests |
| `resources/bsb/` | Full BSB text as JSON resources (`tools/import_bsb_pack.py`) |
| `tools/` | Pack import, personal sync-key overlay |

## Flow

Home (Books) → book → chapter grid → reader (scroll verse by verse or by line). Hold START in the
reader bookmarks a verse; Bookmarks lists verses and merged ranges (a range opens the reader at
its first verse). Optional Selah Vault sync keeps bookmarks in step with the phone/web library.

## Build

See `docs/BUILD.md`. Needs the Connect IQ SDK, device packs and your own `developer_key.der`
(gitignored).
