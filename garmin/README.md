# Garmin Connect IQ — BSB Bible (spike)

Monkey C recreation spike of the Flipper Zero `bible_bsb` app. **Docs first, thin working slice second** — intentional `// POKE:` markers for pair mode with Dylan.

## Layout

| Path | Purpose |
|------|---------|
| `docs/flipper-baseline.md` | Flipper screens/inputs/pack/collection/scroll axes |
| `docs/SPEC.md` | Garmin input, snake grid, bookmarks, continuation, scroll modes, divergences, screenshot matrix |
| `docs/PLAN.md` | Pair milestones + teach-backs + screenshot capture steps |
| `docs/BUILD.md` | SDK install / blockers / Dylan Mac commands |
| `docs/screens/` | Simulator PNGs (`<device>/<state>.png`) — see `MISSING.md` |
| `source/` | App, views, SnakeGrid, Bookmarks, ContentLoader, ScrollModel, ChapterNav |
| `test/` | Toybox.Test unit tests |
| `resources/json/` | Spike chapters: John 3–4, Malachi 4, Matthew 1 stubs |

Do **not** change Flipper code from this spike; everything lives under `garmin/`.

## Thin slice

Open app → pick book → snake chapter grid → read John 3 → scroll into John 4 (continuation) → hold to bookmark → Bookmarks list. Toggle Verse/Line scroll from reader Select/Menu.

## Build

See `docs/BUILD.md`. Requires Connect IQ SDK + device packs (Garmin login) + `developer_key.der`.
