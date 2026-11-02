# PLAN — Garmin BSB spike (pair milestones)

Each milestone is verifiable. Dylan drives; agent supports. Every milestone ends with a **teach-back** question. Screenshot captures are called out explicitly — never fake PNGs.

---

## M0 — Orient on Flipper baseline

- Read `docs/flipper-baseline.md` (scenes, inputs, pack, collection, **dual scroll axes**).
- Skim Flipper shots in `bible_bsb/screenshots/`.
- **Verify:** Dylan can name the 8 scenes and the reader Up/Down vs Left/Right difference without notes.
- **Teach-back:** Why does Flipper not need a scroll-mode toggle?

## M1 — Spec lock (input, snake, bookmarks, continuation, scroll modes, divergences)

- Walk `docs/SPEC.md` §§1–9 together.
- Decide POKE defaults: snake wrap vs clamp; columns per class; scroll default = Verse.
- **Verify:** Input table + snake index math agreed; continuation divider sketch on paper for Enduro 3.
- **Screenshots:** none yet (no app).
- **Teach-back:** In verse mode at John 3:36, what does one Down do once John 4 is prefetched?

## M2 — SDK + project skeleton on Mac/VM

- Install Connect IQ SDK Manager; accept agreement; **login**; download SDK + devices in `manifest.xml`.
- Generate developer key; `monkeyc` builds empty app for `enduro3` and one budget device.
- **Verify:** `.prg` produced; sim launches.
- **Screenshots:** `docs/screens/enduro3/_sim-smoke.png` if sim runs (optional smoke).
- **Blocked in cloud agent if:** no Garmin SSO login for device packs (see `BUILD.md`).
- **Teach-back:** What does `monkey.jungle` vs `manifest.xml` each control?

## M3 — SnakeGrid module + unit tests

- Implement `SnakeGrid.mc` index↔row/col, viewport, wrap/clamp.
- Tests: mid-row wrap 5→6, last cell, viewport keeps focus row visible.
- Pair: change `C` and predict John 21 layout.
- **Screenshots:** none (headless tests).
- **Teach-back:** Why is hold-±C still useful if snake is default?

## M4 — Book list + chapter grid UI (thin slice books)

- Book list (John, Malachi, Matthew stubs) + snake chapter grid.
- `// POKE:` column count, wrap, OT/NT filter.
- **Screenshots (capture step):** for `enduro3` then one FR / Venu|Sq / VA:
  - `book-list`, `chapter-grid-start`, `chapter-grid-mid-wrap`, `chapter-grid-scrolled`, `chapter-grid-last`
- Pass criteria: SPEC §8.
- **Teach-back:** After snake wrap from chapter 5 to 6, where is focus visually?

## M5 — ContentLoader + John 3/4 reader

- Load JSON resources; wrap lines; render reader header + body.
- Bundle John 3+4; stubs Mal 4 / Matt 1.
- **Screenshots:** `reader`, `reader-verse-snapped`
- **Teach-back:** Why load one chapter JSON at a time instead of the whole pack?

## M6 — Scroll model (incremental + verse) + toggle

- Implement scroll state machine; Storage persistence; header `V`/`L` chip.
- `// POKE:` toggle binding (menu vs extra key), focus-verse rules, long-verse intra steps.
- Unit tests: line↔verse focus, snap, mode next/prev offsets.
- **Screenshots:** `reader-incremental-mid-verse`, `reader-mode-indicator`, `reader-long-verse-mode`
- **Teach-back:** If `scrollOffset` is mid-verse line 3 of 5, what verse does hold-bookmark use in incremental mode?

## M7 — Chapter continuation

- Prefetch next/prev; divider line; Rev 22 end; Genesis 1 stop; update current chapter for Back/bookmark.
- Unit tests: next/prev chapter across books; Gen1 / Rev22 edges.
- **Screenshots:** `continuation-divider`, `continuation-cross-book`, `continuation-incremental-boundary`, `continuation-verse-boundary`, `continuation-incremental-cross-book`, `continuation-verse-cross-book`, `genesis-1-start`, `rev-22-end`
- **Teach-back:** After continuing into John 4, Back lands on which grid chapter?

## M8 — Bookmarks

- Pack/unpack Number; Storage; hold toggle; list view; jump-to.
- Tests: pack edges (book 0/65, verse 0 chapter bookmark).
- **Screenshots:** `bookmarks-empty`, `bookmarks-populated`, `bookmark-hold-feedback`
- **Teach-back:** Why pack into one Number instead of a Dictionary per entry?

## M9 — Device matrix polish + memory

- Safe insets, fonts per class, sleep/burn-in hooks (`onEnterSleep`), vibe toast.
- Memory high-water while scrubbing John 3↔4 continuously.
- **Screenshots:** re-capture any failing pass-criteria shots on Enduro 3 + budget lines.
- **Teach-back:** Name one Flipper parity item and one deliberate divergence you can see on FR965 vs Enduro 3.

## M10 — Dylan real-device / Monkey Motion

- Manual checklist from SPEC §8 on Enduro 3 hardware.
- File gaps in `docs/screens/MISSING.md` if any sim device still blocked.
- **Teach-back:** Which screenshot state was hardest to get clean on a round MIP and why?

---

## Pairing notes

- Prefer one POKE change per session; re-run the affected unit tests and the related screenshot cells only.
- Cloud/CI without Garmin login stops at M2 device download — docs + tests still advance.
