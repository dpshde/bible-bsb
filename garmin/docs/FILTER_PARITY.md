# Filter parity: Flipper Bible BSB → Garmin (v3)

Source of truth: Flipper app `bible_bsb/` at origin/main **c4c7a01** (v1.2 sticky headers):
`bible_books.c` (`BIBLE_FILTER_LABELS`, `get_filtered_books`), `bible_view_book_filter.c`,
`bible_view_book_list.c`. Dylan's uncommitted work was checked too:
`flipper-headings-wip.patch` (touches bible_loader.c, bible_state.h, bible_view_reader.c,
scripts/fetch_bsb.py; **no filter changes**) and `/workspace/dpshde-scan/bible-bsb` (clean at fccc0b8).

| # | Flipper item | Garmin v3 item | Status | Note |
|---|---|---|---|---|
| 1 | Filter labels: All, A, C, D, E, G, H, I, J, K, L, M, N, O, P, R, S, T, Z, 1, 2, 3 (22) | `PickList.FILTER_LABELS`, same 22 in the same order | match | unit test `testFilterLabelsMatchFlipper` |
| 2 | "All" = all 66 books | "All" → "All books" list (66) | match | |
| 3 | Letter = books whose name starts with that letter | same rule on full BSB names | match | |
| 4 | 1 / 2 / 3 = **every** numbered book (first char '1'–'3') | same: each digit lists all 17 numbered books | **fixed in v3** | v2 matched only the exact digit. Title "Numbered books" says what you get. Test `testFilterNumericMatchesAllNumbered` |
| 5 | "< Select Filter" 5-column grid, 3 rows visible, scrolls | "Filter books" grid with **all 22 visible at once**: All on top, letters and numbers spread over the rows by circle chord | divergence (layout) | Round screen: rows reflow to the circle so nothing is clipped or hidden off screen |
| 6 | OK applies the filter → book list headed "< X >" | Select or tap → book list headed "Books: X" (or "All books" / "Numbered books") | match (wording) | Full words, no "< >" glyph headers (Dylan's no-abbreviation rule) |
| 7 | Home "< All >": Right opens the filter | Home: **swipe left** opens the filter grid; Menu → Browse → "Filter books" | match (gesture) | Watch has no Right key; swipe left is the touch equivalent, the menu entry is the button path |
| 8 | Home Left = Collection, or exit genre mode | Menu → Browse → Bookmarks | match (path) | Bookmarks = Flipper collection |
| 9 | Testament → Genre → Book (genre mode, header "< Maj Prophets >") | By Testament → genre list → books, header uses full genre names ("Major Prophets") | match (wording) | No abbreviations |
| 10 | Book list: inverted full-width highlight row | Gold focus pill, row text centered in chord | divergence (style) | Palette rules (gold #C89D54, theme aware) |
| 11 | Tap a filter (n/a on Flipper) | Tap a cell: gold flash + haptic tick, opens after ~100 ms | Garmin only | `// POKE: TAP_FLASH_MS`, `// POKE: TAP_VIBE` |

Screenshot: `screens/v3/b01-filter-grid.png` (full list, nothing clipped).
