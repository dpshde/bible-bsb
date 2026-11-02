# SPEC — Garmin Connect IQ BSB Bible (spike)

Primary device: **Enduro 3** (5-button + touch, round MIP ~280×280). Budget lines: Forerunner 165/265/965, Venu / Venu Sq, Vivoactive 5/6. Flipper `bible_bsb` is the **gold standard** for navigation spirit and layout logic; Garmin may only diverge where listed in [Deliberate divergences from Flipper](#deliberate-divergences-from-flipper). Baseline: [`flipper-baseline.md`](./flipper-baseline.md). Terminology: always **bookmark** (never favorite/collection in UI copy).

---

## 1. Input mapping

### Flipper → Garmin behavior keys

| Flipper | Action class | Garmin `BehaviorDelegate` / key | Notes |
|---------|--------------|----------------------------------|-------|
| OK Short | Select / confirm | `onSelect` | Also touch tap on selectable row/cell |
| OK Long | Bookmark toggle (reader/chapter) or delete (bookmark list) | Hold: `onKeyPressed`/`onKeyReleased` timing **or** `onHold` where supported | See long-press rules below |
| Back Short | Pop / cancel | `onBack` | System may also swipe-back on touch |
| Up / Down | Primary linear nav | `onPreviousPage` / `onNextPage` | On 5-button: UP/DOWN physical |
| Left / Right | Secondary axis / enter side screens | Map per screen (table below); often unused under snake | Touch: swipe L/R when useful |
| — | Menu | `onMenu` | Opens top-level: Books / Bookmarks / About |

### Per-screen mapping — buttons (Garmin)

| Screen | Select | Hold | Back | NextPage | PreviousPage | Menu |
|--------|--------|------|------|----------|--------------|------|
| Book list | Open chapter snake grid | — | Exit app (or clear OT/NT filter first, Flipper-like) | Next book | Prev book | Bookmarks list |
| Chapter snake grid | Open reader (full chapter; verse picker deferred — POKE) | Bookmark **chapter** | Book list | Next cell (snake) | Prev cell (snake) | — |
| Reader | Open native **Menu2** | Bookmark **focused verse** | Return to grid **for current chapter** | Scroll per mode | Scroll per mode | Open Menu2 |
| Bookmarks list | Jump to passage | Remove bookmark | Previous | Next item | Prev item | — |
| Toast/feedback | — | — | Dismiss | — | — | — |

### Per-screen mapping — touch (`BehaviorDelegate`)

Coexists with buttons on Enduro 3, FR165/265/965, Venu/Venu Sq, VA5/6. `TouchGuard` suppresses the matching button callback when a gesture already handled the action (no double-fire).

| Screen | `onTap` | `onSwipe` Up/Down | `onSwipe` Right | `onHold` |
|--------|---------|-------------------|-----------------|----------|
| Book list | Hit-test row → focus + open grid | Move focus ±1 | Back / pop | — |
| Chapter snake grid | Hit-test cell → open that chapter | Snake ±1 (POKE: ±row) | Back to book list | Hit-test cell → bookmark **chapter** |
| Reader | Open Menu2 (POKE: tap = next verse) | Scroll per current mode (line/verse) | Back to grid | Bookmark focused verse (same as button hold) |
| Bookmarks list | Hit-test row → jump | Move focus ±1 | Back | Remove bookmark at row |

Menu2 itself uses native touch/button scrolling (`WatchUi.Menu2` / `Menu2InputDelegate`).

### Reader Menu2 items (Flipper ActionMenu mirror)

Flipper (`bible_view_action_menu.c:17-21`) order: **Save to collection**, **Share via NFC**, **Back to reading**.

| # | Garmin Menu2 label | Flipper counterpart | Notes |
|---|--------------------|---------------------|-------|
| 1 | Scroll: Verse\|Line | *(Garmin-only)* | Toggle; replaces custom V/L overlay |
| 2 | Bookmark verse / Remove bookmark | Save to collection | Toggle; uses **bookmark** wording |
| 3 | Bookmarks | *(Collection via Left on book list)* | Surfaced in-menu for touch-first devices |
| 4 | Jump to chapter | *(no Flipper item — Back then grid)* | Pops reader → chapter grid |
| 5 | Back to reading | Back to reading | Dismiss menu |
| — | ~~Share via NFC~~ | Share via NFC | **Dropped** — see divergences |

### Long-press rules & platform constraints

- Prefer measuring hold ≥ ~700 ms via `onKeyPressed` + `Timer` + `onKeyReleased` so behavior is consistent across devices.
- **System-reserved holds:** on many watches, holding LIGHT / BACK is system (power menu / controls). Do **not** bind bookmark to Back hold. Bind bookmark to Select hold (and touch `onHold` on the content).
- `BehaviorDelegate.onHold(ClickEvent)` fires for touch holds; also handle Select key hold for button-only devices (FR165 class without relying on touch).
- Enduro 3: 5 buttons + touch — both paths must work (validation walks both).

### Device classes (input)

| Class | Examples | Buttons | Touch | Strategy |
|-------|----------|---------|-------|----------|
| 5-btn + touch MIP | Enduro 3 | UP/DOWN/START/BACK/LAP-ish | Yes | Full mapping; START=Select |
| 5-btn AMOLED | FR265/965 | Similar | Yes | Same; richer fonts/color |
| Compact AMOLED | FR165, VA5/6 | Fewer physical in practice + touch | Yes | BehaviorDelegate first; touch backup |
| Touch-first | Venu, Venu Sq | Minimal / bezel | Yes | Swipes + onMenu + onBack; onSelect via tap |

---

## 2. Screen layout per display class

### Display classes

| Class | Devices (spike targets) | Typical res | Notes |
|-------|-------------------------|-------------|-------|
| Round MIP | Enduro 3, FR255/265 MIP cousins | ~280×280 | High contrast, limited color; always-on friendly |
| Round AMOLED | FR265/965, Venu, Vivoactive 5/6 | ~360–454 | Color, burn-in risk; richer fonts |
| Rectangular | Venu Sq / Sq 2 | ~240×240-ish rect | No round inset; use square safe margins |

### Safe insets (round)

Keep all text and focus rings inside an inscribed square inset by ~8–12% of diameter (POKE: measure per device in sim). Never clip glyphs on the curved edge. Page indicators sit in the bottom inset, not on the bevel.

### Fonts & wrapping

- Prefer system fonts; on devices with vector/scalable fonts use a readable body size that yields **≥4 verse lines** on Enduro 3 and **≥6** on 416px AMOLED (divergence from Flipper’s ~4 lines @ 128×64).
- Word-wrap on whitespace (one `getTextWidthInPixels` per word, cached); never per-character measure (watchdog). Long tokens ellipsize only as last resort.
- Reader: **every verse starts on a new line** (no run-on paragraph). Gold `#C89D54` inline verse number at line start (slightly smaller than body). Inter-verse gap ≈ `VERSE_GAP_FRAC` × line height (POKE: 0.4–0.5). In Verse mode, non-focused verses may use `Palette.DIM_VERSE` (POKE).

### Center-band lens (round default)

Geometry for diameter **D**, height **H** (also used as a rectangular band on venusq2):

| Zone | Frac of H | Contents |
|------|-----------|----------|
| Top meta | 0–18% | Centered reference only (`JHN 3:16` OSIS; full name if it fits). Nothing else. |
| Reading band | 20–80% | Straight-left column, width = min raw chord across the band (floor 0.75 D), clipped. Max ~4–5 lines. |
| Bottom preview | 82–100% | Dimmed verse counter `16 / 36` **or** next-verse first words (POKE: `LENS_PREVIEW_VERSE_COUNTER`). |

Progress: 1.5–2 px gold bezel arc from 12 o’clock (chapter position) + small ticks at bookmarked verses. No scrollbar.

Palette (AMOLED): bg `#000000`, text `#F2EFE9`, gold `#C89D54`, muted/dim as in `Palette.mc`. Applied to grid, lists, empty states. Flipper remains 1-bit mono — see divergences.

### Scrolling & page indicators

- Line mode = one wrapped band line; Verse mode = snap so focused verse starts at band top. Content outside the band is never drawn.
- Bottom-arc counter / bezel progress arc replace the old corner chip + scrollbar.

### Side-by-side: Flipper ASCII → Garmin layout

**Book list (Flipper 128×64)**
```
< All >
------------
 Genesis      ▐
 Exodus
 Leviticus
 Numbers
```
Garmin round: header OT|NT (or All) centered in top inset; full-width inverted/focus row; 6–10 books visible by class; scroll thumb or fade.

**Chapter grid (Flipper 5-col)**
```
John
------------
 1  2  3  4  5
 6  7  8  9 10
11 12 13 14 15  ▐
```
Garmin: same grid spirit, **snake** focus order (below); columns by class (see §3); larger cells / color focus on AMOLED.

**Reader (Flipper)**
```
John 3:1-36
------------
1 Now there was a
man of the...
2 He came to...
              1/8
```
Garmin: larger type, more lines; header updates under continuation (§5); divider line between chapters.

**Collection → Bookmarks**
```
Collection >
------------
 John 3:16
 Psalms 23:1-6
```
Garmin: title **Bookmarks**; empty state copy; hold-to-remove with vibe/toast.

---

## 3. Navigation — horizontal SNAKE chapter grid

### Algorithm (precise)

Let `N` = chapter count for the book, `C` = column count for the display class.  
Chapters are 1-indexed. Linear index `i = chapter - 1` (0 … N-1).

- `row = i / C` (integer)
- `col = i % C`
- Inverse: `i = row * C + col` → `chapter = i + 1` (invalid if `chapter > N`)

**Snake order (Dylan):** Up/Down (PreviousPage/NextPage) move **±1 in linear index**, not ±C. The grid is a rendering of a single linear list left→right, top→bottom.

- Next: `i' = (i + 1) % N` (wrap) **or** clamp — **spike default: wrap** at ends for chapter grid (matches Flipper book list wrap; POKE: try clamp).
- Prev: `i' = (i - 1 + N) % N`
- Mid-row wrap example (C=5): from chapter 5 → Next → chapter 6 (row 0 col 4 → row 1 col 0).

**Viewport:** visible rows `R` (e.g. 4–6 by class). Keep focused row visible:

```
startRow = clamp(row - (R-1), 0, max(0, totalRows - R))  // or: if row < startRow → startRow=row;
                                                         // if row >= startRow+R → startRow=row-R+1
```

**Columns by class (recommended):**

| Class | C | Visible rows (approx) |
|-------|---|------------------------|
| Round MIP ~280 | 5 | 4–5 |
| Round AMOLED ~416 | 6 | 5–6 |
| Rectangular Sq | 5 | 5 |

**Jump accelerators:**

- Long-press Next/Prev: skip **one full row** (±C) — Flipper Up/Down parity as a *secondary* gesture.
- Optional: Menu → jump OT/NT when browsing books; in Psalms, long-press skip 10 chapters (POKE).

**OT/NT split:** Book list filter toggles All / OT / NT (indices 0–38 / 39–65), replacing Flipper’s letter grid on small round faces (see divergences). Letter filter remains a POKE for large AMOLED.

### Alternatives (honest compare)

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Snake (proposed)** | One-thumb Up/Down only; predictable; great on 5-btn without Left/Right | Mid-row wrap surprises D-pad muscle memory; need onboarding toast once | **Recommend** for Enduro 3 primary |
| Classic 2-axis D-pad (±1 / ±C) | Matches Flipper chapter grid exactly | Needs Left/Right; weak on touch-first / 2-btn | Keep as POKE fallback compile flag |
| Number picker / digit entry | Fast for known chapter (Ps 119) | Poor discovery; awkward on round MIP | Secondary accelerator later |
| Tens-then-units | Fast for large N | Extra screen; Flipper didn’t need it for most books | Optional for Psalms only |
| Linear list of “Chapter N” | Trivial | Wastes Garmin real estate; slower scan | Reject for primary |

**Recommendation:** Ship snake as default; document wrap; offer ±C on hold; POKE a jungle flag `UseDpadGrid` for A/B with Dylan.

---

## 4. Bookmarks

Use the word **bookmark** everywhere (UI, docs, code comments for user-facing strings).

### Gestures

| Context | Hold Select / onHold | Result |
|---------|----------------------|--------|
| Reader (verse focused) | Toggle bookmark for `(book, chapter, verse)` | Toast + vibe |
| Chapter grid (chapter focused) | Toggle bookmark for `(book, chapter, verse=0)` meaning “chapter” | Toast + vibe |
| Bookmarks list | Remove selected | Toast “Removed” |

Toggle: if packed id exists → remove; else append (newest first). Cap **maxCount** (recommend 40 default; lower on tiny-heap devices — read from device config POKE).

### Feedback

- `Attention.vibrate` pattern short if `Attention has :vibrate`
- On-screen toast 1.5–2s: `Bookmarked` / `Removed` / `Bookmarks full`

### Data model

Pack into a `Number` (32-bit):

```
id = (book & 0xFF) << 16 | (chapter & 0xFF) << 8 | (verse & 0xFF)
```

- `verse == 0` → chapter-level bookmark  
- Unpack helpers required; unit-tested  

Persist: `Application.Storage.setValue("bookmarks", Array<Number>)`.  
Size: 40 × 4 bytes + array overhead ≪ Storage limits; still enforce maxCount. Ordering: newest first. Surface: `onMenu` → Bookmarks; empty state; Select jumps to reader (chapter bookmark → verse 1).

---

## 5. Chapter continuation (Garmin-only)

When the reader scrolls **past the final line of the current chapter**, seamlessly append the **next** chapter (and across books: last chapter of book B → chapter 1 of book B+1). Not in Flipper.

### Divider / header between chapters

- One centered gold label (e.g. **`John 4`**) with thin `#3A3631` rules left/right, **6–8px** gap from the label, **~1 line** spacer above and below.
- Fully inside the band chord at its y. **Not** a modal or full-screen flash.

### End of Bible

- After **Revelation 22** last verse: show an end marker line (`— End —` or `Revelation 22 · End`). **Do not** wrap to Genesis 1 (Bible reading metaphor; avoids accidental teleport). Back-scroll still works.

### Start of Bible

- At **Genesis 1** verse 1, previous-scroll is a no-op (optionally toast once).

### Backward crossing

- Scrolling up before the first line of the loaded window loads/shows the **previous** chapter (or previous book’s last chapter) with the same divider style above the current chapter when both are visible.

### Title / position indicator

- Header always reflects the **focused** verse’s book+chapter (+ verse if space): as the focus crosses the divider, title updates to the new chapter (e.g. `John 3:36` → `John 4:1`).
- Page/position indicator uses the focused chapter’s verse index.

### Current chapter updates (critical)

- App state `currentBook` / `currentChapter` / `focusedVerse` track the **focus line**, not the session start.
- Hold-to-bookmark uses focus → bookmarks the verse (or chapter) **under focus**.
- Back from reader opens the snake grid for **`currentBook`** with focus on **`currentChapter`**.

### Loading / memory strategy

- Keep a small ring of chapter payloads in memory: prefer **prev / current / next** (max 3).
- When focus enters the last ~N verses (POKE: N=3) of current, **prefetch next** (if any).
- When focus leaves a chapter by >1 chapter distance, **evict** farthest.
- Heap budgets differ wildly (FR165 vs FR965); never hold full-Bible strings. Decode/load **one chapter JSON** at a time into typed verse arrays; discard raw resource after parse.
- Spike content: bundle John 3+4 fully; Malachi 4 + Matthew 1 stubs for cross-book demo.

### Edge cases

| Case | Behavior |
|------|----------|
| One-verse chapters (Obadiah, Jude, …) | Divider still shows; next chapter follows immediately |
| Very long verses | Wrap normally; continuation trigger is last **line** of last verse, not last verse number alone |
| Missing next chapter resource | Stop with toast `Chapter unavailable`; no skip |
| Cross-book OT→NT (Mal 4 → Matt 1) | Same as chapter; divider shows `Matthew 1` |

---

## 6. Content / storage (BSB on Connect IQ)

### Measured from this repo (`bible_bsb/assets/bsb.pack`)

| Metric | Value |
|--------|-------|
| Pack size (heatshrink) | ~2.15 MB (2 257 626 B) |
| Chapters | 1189 |
| Raw JSON total | ~4.35 MB |
| Avg chapter raw / comp | ~3.7 KB / ~1.9 KB |
| Max chapter (Ps 119) | ~15 KB raw |
| John 3 | ~4.4 KB raw |

Connect IQ app size and **runtime heap** are both constrained. From SDK 9.3 device reference docs (Watch App memory limit): **Enduro 3 / FR165 / FR265 / FR965 / Venu 3 / Venu Sq 2 / VA5 / VA6 = 786 432 bytes (768 KB)** each — far above Flipper’s FAP heap, but still far below a 4.35 MB raw Bible. Resolutions: Enduro 3 **280×280**, FR165 **390×390**, FR265 **416×416**, FR965/Venu3 **454×454**, Venu Sq 2 **320×360**, VA5/6 **390×390**.

### Options

| Option | Pros | Cons |
|--------|------|------|
| Per-chapter JSON resources | Simple Rez load; matches Flipper one-chapter-at-a-time | Many resource entries; app package size ~raw unless compressed by tooling |
| Per-book JSON chunks | Fewer files | Large books (Psalms) hurt heap if loaded whole |
| String resources | Easy i18n hooks | Terrible for 31k verses |
| Custom compressed pack + Monkey C decoder | Smallest | Heavy to implement; heatshrink port cost |
| **Recommend (spike→prod path):** per-chapter (or small multi-chapter) **JSON in resources**, load one chapter to heap, optional build-time minify; later POKE: pack+decode if package size blocks store limits | | |

Spike ships only John 3, John 4, Malachi 4 (stub), Matthew 1 (stub) under `resources/json/`.

---

## 7. Deliberate divergences from Flipper

Everything **not** listed here should match Flipper behavior/spirit from `flipper-baseline.md`.

| Flipper behavior | Garmin behavior | Why (hardware) | Devices |
|------------------|-----------------|----------------|---------|
| 128×64 mono, ~4 text lines | More verses visible; larger type | Higher res displays | All |
| FontPrimary 6×8 bitmap | See **Custom BMFont** row below (weights replace system-font-only approach) | — | — |
| No color | Accent focus + divider color; MIP: 1–2 muted colors if supported | AMOLED color; MIP limited palette | AMOLED full; MIP limited |
| No always-on app mode | `onEnterSleep`/`onExitSleep`: simplify reader chrome in sleep; avoid static bright header burn-in | AOD / low-power; AMOLED burn-in | AMOLED especially; MIP opportunistic |
| 5-col chapter D-pad (±1/±5) | Snake ±1 linear default; hold = ±row | 5-btn watches often want single-axis; touch taps still 2D | All; Enduro 3 primary |
| Letter filter grid | OT/NT/All segmented filter first | Round inset makes 22-cell letter grid cramped | Round MIP/AMOLED; letter grid POKE on large |
| Collection + rich JSON entries | Compact packed Number bookmarks | Storage/heap; faster | All |
| OK Long saves passage range | Hold bookmarks **focused verse/chapter** (toggle) | Precision + Garmin vibe feedback | All |
| Reader locked to one loaded passage | **Chapter continuation** across chapter/book | Screen real estate + scroll UX expected on watches | All |
| Verse scroll on Up/Down **and** incremental on Left/Right **simultaneously** (no toggle) | **Toggle** which mode owns Up/Down (`V`/`L` chip + menu); persist in Storage | Many Garmin targets lack a reliable second axis; BehaviorDelegate is page-based | All (5-btn may later POKE Left/Right as the other mode without toggle) |
| NFC share / Kindled export | Omitted in spike | No Flipper NFC; CIQ comms different | — |
| Toast software frames @30fps | Toast + `Attention.vibrate` | Haptics exist on Garmin | Devices with Attention |
| SceneManager stack | `WatchUi.pushView`/`popView` | CIQ navigation model | All |
| Fixed 128px column / 2px margins | Default **center-band lens** (`RoundLayout.lensBand`, band 20–80% H, width ≥0.75 D, straight left, clipped). RECT / CENTERED_CHORD kept behind `// POKE: READER_LAYOUT` for A/B. | Dylan rejected RECT (unused mid-band, cramped column); lens is the round reading default | All round; square uses rectangular band |
| 1-bit mono (black/white) | AMOLED palette `#000` / `#F2EFE9` / gold `#C89D54` (+ burnt orange `#C8642A` secondary only). **No green, no deep blue** anywhere (grid focus, headers, dividers, menu). | Color watches; Flipper has no gray/gold | AMOLED primary; MIP best-effort |
| FontPrimary 6×8 bitmap only | **Custom BMFont** weights (Light/Regular/Medium/Bold nums/Header caps) via `resources/fonts`; low-mem devices alias Light/Medium→Regular (`resources-lowmem`). Focus=Regular+`#F2EFE9`; surround=Light+`DIM_VERSE`; verse nums=Bold gold; headers=letterspaced small caps gold; short verses (≤`SHORT_VERSE_CHARS`) step to Medium-16. | System fonts lack weight axis; Dylan text-weighting pass | All; see `docs/font-budget.json` (~78 KB full / ~45 KB low-mem) |
| N/A (no red-letter in Flipper UI) | Words-of-Jesus warm tint `#E8C9A0` + Medium face **hook only** — spike BSB JSON has no `\wj`/red-letter spans (`ContentLoader.hasJesusMarkup`) | Data gap; do not invent spans | When pack grows markup |
| Left-aligned headers / bottom hints | Top-arc OSIS meta only; bottom-arc counter/preview; bezel progress arc | Circle radius + lens zones | Round primarily |
| N/A (Flipper had no mode chip) | No permanent `V`/`L` corner letter; ~1s centered **“Verse scroll” / “Line scroll”** banner on change (`showModeBanner`) | Corner letter was unclear on Enduro 3 | All |
| Custom menu item sublabels OK on 128×64 | Menu2 items use **title only** (ref folded into bookmark title; no sublabel) | Enduro 3 Menu2 clipped `John 3:1` sublabel at left (v3/v4) | Round primarily |
| Collection empty: `No saved passages` + `Back to home` (FontSecondary, left) | Bookmarks empty: small outline icon + `No bookmarks yet` + muted how-to hint (hold / long-press), centered in column | Same quiet secondary voice; Garmin adds icon + action hint; wording uses **bookmark** | All |
| No chapter divider (single passage) | Continuation divider: **~1 line pad** above/below, thin `#3A3631` rules with 6–8px gap from **gold** centered label | v4 rules were tight to the label with wasted side space; blue label mismatched palette | All |
| Black toast box over text | Full-screen solid scrim + single centered gold pill (`★ Bookmarked`), ~1s, then full redraw — **no** gray band | v4 pill sat on a full-width gray strip with verse bleed | All |
| Custom ActionMenu canvas (3 items) | Native **`WatchUi.Menu2`**: Scroll mode, Bookmark toggle, Bookmarks, Jump to chapter, Back to reading | System menu look + touch/button for free; Flipper had no scroll-mode item | All |
| Share via NFC in ActionMenu | **Omitted** from Menu2 | No Flipper NFC stack on CIQ; route.bible share is a later POKE | All |
| D-pad only (no touch) | Full **touch map** (`onTap`/`onSwipe`/`onHold`) + `TouchGuard` anti-double-fire with buttons | Enduro 3 / Venu / VA / FR touchscreens | Touch-capable products |

### Flipper ↔ Garmin layout references

See ASCII in §2. Flipper device screenshots live in repo `bible_bsb/screenshots/` / root `screenshots/` when present; Garmin captures go under `docs/screens/<device>/<state>.png` per §8. Until Garmin shots exist, layout review uses the ASCII + this divergence table.

---

## 8. Screenshot matrix & validation checklist

Screenshots are **essential**. No fakes/mocks. Missing shots must be listed with reason.

### File naming

`garmin/docs/screens/<device>/<state>.png`

Device folder names: `enduro3`, `fr165`, `fr265`, `fr965`, `venu3` (or `venu2`), `venusq2`, `vivoactive5`, `vivoactive6`.

### Required states (`<state>`)

| State id | What to show |
|----------|--------------|
| `book-list` | Book list with focus visible |
| `chapter-grid-start` | Snake grid, focus chapter 1 |
| `chapter-grid-mid-wrap` | Focus on last cell of a row (e.g. 5) **and/or** first of next row after wrap (6) — capture after wrap |
| `chapter-grid-scrolled` | Focus far down (e.g. John 15+) with viewport scrolled |
| `chapter-grid-last` | Focus last chapter of book |
| `reader` | Verse reader mid-chapter |
| `reader-incremental-mid-verse` | Incremental mode, scrolled mid-verse (not on verse-first line) |
| `reader-verse-snapped` | Verse mode, snapped to verse start |
| `reader-mode-indicator` | Header chip `V` or `L` clearly visible after toggle |
| `continuation-divider` | Mid-boundary: end of ch N + divider + start of ch N+1 |
| `continuation-cross-book` | Malachi 4 → Matthew 1 divider visible |
| `continuation-incremental-boundary` | Incremental mode crossing chapter divider line-by-line |
| `continuation-verse-boundary` | Verse mode: one step from last verse → divider+v1 |
| `continuation-incremental-cross-book` | Incremental across Mal→Matt |
| `continuation-verse-cross-book` | Verse mode across Mal→Matt |
| `reader-long-verse-mode` | Verse taller than screen; snapped then stepped within |
| `bookmarks-empty` | Empty bookmarks |
| `bookmarks-populated` | ≥1 bookmark |
| `bookmark-hold-feedback` | Toast/vibe feedback UI after hold |
| `reader-menu2` | Native Menu2 open (all items visible / scrolled if needed) |
| `reader-menu2-scroll-mode` | After toggling Verse/Line from Menu2 (chip + toast) |
| `touch-book-list-tap` | Book opened via tap (same as select) |
| `touch-grid-tap` | Chapter opened via cell tap |
| `touch-reader-swipe` | Reader mid-scroll after swipe (note mode in filename suffix `-verse` / `-line` if useful) |
| `touch-reader-hold-bookmark` | Bookmark pill after touch long-press |
| `genesis-1-start` | Genesis 1 start (when content available; spike may stub) |
| `rev-22-end` | Revelation 22 end marker (stub OK) |

**Minimum device coverage for a complete validation:** Enduro 3 (**all** states) + at least one Forerunner 165/265-class + one Venu/Venu Sq + one Vivoactive 5/6 for every major state (subset allowed on budget lines if matrix notes “parity with enduro3”, but **reader**, **reader-mode-indicator**, **reader-menu2**, **continuation-divider**, **continuation-verse-boundary**, **chapter-grid-mid-wrap**, **bookmarks-populated**, and at least one **touch-*** state on each touch device are mandatory on each class).

### Pass criteria (every shot)

1. No clipping in round insets (text/focus inside safe circle/square).
2. No overlapping elements (header vs body vs indicator).
3. No truncated glyphs mid-character.
4. Consistent margins (≥ Flipper’s 2px spirit; Garmin ≥ ~4–6 px usable).
5. Focus visible (invert, ring, or accent).
6. Continuation divider readable and not mistaken for a verse.
7. End marker only on Rev 22 end shot.

### Capture method (reproducible)

1. **Preferred:** `monkeydo` + sim + scripted UI harness that pushes views/states via a debug `(:debug)` menu or automated input (`scripts/capture-screens.md` steps). Save PNGs to the matrix paths.
2. **Fallback (manual):** documented key/touch sequence per state in PLAN milestones; capture with sim screenshot tool / `gnome-screenshot` under xvfb.
3. CIQ SDK + device packages + developer key required; see `docs/BUILD.md`.

### Functional validation checklist

- [ ] Input coverage table walked on button-only and touch
- [ ] Snake index math unit tests green
- [ ] Bookmark pack/unpack + persistence across restart
- [ ] Continuation: cross-chapter, cross-book, Rev 22 end, backward cross
- [ ] Bookmark after crossing uses new focus
- [ ] Back to grid focuses continued chapter
- [ ] Memory high-water under each device limit during long continuous scroll
- [ ] Long-verse wrap + one-verse chapter continuation
- [ ] Screenshot matrix complete or gaps listed with blocker reason
- [ ] Scroll modes: incremental mid-verse, verse snap, toggle indicator, both modes across chapter and book boundaries, long verse in verse mode
- [ ] Focus-verse bookmark correct in both scroll modes (unit + manual)
- [ ] Monkey Motion / real-device pass by Dylan (manual)

---

## 9. Reader scroll modes (Flipper parity on limited Garmin input)

Flipper baseline: **both modes always live on different axes** — Up/Down = verse, Left/Right = incremental; **no toggle, no persistence** (`flipper-baseline.md` Reader section). Garmin often only exposes a reliable vertical pair (`onNextPage`/`onPreviousPage`), so we **toggle which mode owns Up/Down**, while preserving both behaviors Dylan loves.

### Modes

1. **Incremental** — one wrapped display line per Up/Down (Flipper Left/Right).  
2. **Verse** — snap `scrollOffset` to the first line of the prev/next verse (Flipper Up/Down). Continuation header lines are special-cased below.

Default for new installs: **Verse** (matches Flipper’s primary thumb axis).

### Toggle binding (must not collide with bookmark hold, Back, or Menu)

| Binding | Priority | Devices |
|---------|----------|---------|
| **Reader menu item** “Scroll: Verse|Line” (opened via `onMenu` **or** Select **Short**) | Primary — universal | All |
| **LAP / extra key Short** toggles mode when a 5th button exists and is not system-reserved | Secondary accelerator | Enduro 3 / FR265/965 class (POKE: confirm which physical key maps to a free `Key` enum) |
| **Two-finger tap** or **swipe-left while holding** | Avoid — easy to misfire | — |
| Touch-only (Venu / VA): `onMenu` → toggle; also a small tappable mode chip in the header | Primary | Venu, Venu Sq, VA5/6 |

**Explicitly not used for toggle:** Select **Long** (bookmark), Back, Back-hold (system), Menu-hold.

Justification: Select Short already opened Flipper’s ActionMenu; on Garmin, Select Short opens a slim reader menu whose first item is scroll mode — same “OK opens menu” muscle memory, without eating the hold used for bookmark.

### On-screen mode indicator

- Compact chip in reader header trailing edge: `V` (verse) or `L` (line/incremental), or `Verse`/`Line` when width allows (AMOLED).  
- Must sit inside round safe inset; must not collide with reference title (title truncates first).  
- On toggle: brief toast `Verse scroll` / `Line scroll` + optional vibe.

### Persistence

- **Yes** — `Application.Storage.setValue("scrollMode", 0|1)` (`0=verse`, `1=incremental`).  
- Restored in reader `onShow`. Flipper had no persistence because both modes were always bound; Garmin toggle needs memory so Dylan doesn’t re-select every launch.

### Continuation interaction

| Mode | Forward across chapter/book | Backward |
|------|-----------------------------|----------|
| Incremental | Scrolls through the divider **header line as its own line**; next actions reveal v1 lines | Reverse: leave v1 line-by-line, then divider line, then previous chapter’s last lines |
| Verse | From last verse of ch N, **one** Next action lands on **divider + first verse together** (offset = divider line index, which is glued to v1 — never leave the viewport showing only the orphan header). Prefer: snap so divider is the top line and v1 starts immediately below (or top=divider if v1 fits). | From first verse, Previous snaps to previous chapter’s last verse start (divider may appear below focus when both chapters buffered) |

Genesis 1 start / Rev 22 end: same stop + end-marker rules as §5, in **both** modes.

### Very long verses (taller than the screen) in verse mode

1. Entering the verse (from prev/next verse action) **always snaps to the verse’s first line**.  
2. While focus verse is unchanged and the verse height > viewport: **further Next/Prev in verse mode first step by one line within the verse** until the opposite end of that verse, then the next action crosses to the next/prev verse (or continuation).  
   - Alternative POKE: require switching to incremental to explore within a tall verse — rejected as default because it forces a toggle mid-reading.  
3. Indicator still shows the verse number; line chip optional (`v16 · 2/5`).

### Focus verse for press-and-hold bookmark

| Mode | Focus verse definition |
|------|------------------------|
| Verse | The verse whose **first line index == scrollOffset**, or if scrollOffset is a continuation divider line, the **next chapter’s verse 1** (divider is attached to v1). |
| Incremental | The verse owning the **first fully visible content line at `scrollOffset`**. If `scrollOffset` points at a divider line, focus is the following verse (v1 of the chapter below). If it points at a wrapped continuation line of verse V, focus is V (not only when `is_verse_number`). |

Unit-test: `lineOffsetToFocusVerse`, `snapToVerseStart`, `nextOffset(mode)`, boundary crossing.

`// POKE:` sites: scroll model state machine, toggle binding per device, focus-verse rules.

---

## 10. Out of scope for thin spike

Full 1189-chapter ship, NFC, letter filter, verse-range picker UI (Flipper VerseSelect — POKE), store listing assets beyond launcher icon stub.

## 11. FUTURE (logged — not in this spike)

| Idea | Notes |
|------|-------|
| Concentric bezel dial picker | Book → chapter → verse via rotating bezel / crown; replaces or augments snake grid for bezel devices. |
| Clause-by-clause / meditation mode | First-letter memorization aids; not a reader default. |

Snake chapter grid remains required (Dylan).
