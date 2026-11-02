# v4: native menus and name fit

## Native Menu2 (Dylan, 4:39 PM)
- **Browse:** Testament (sublabel: book count), then section (sublabel: book count, or the
  book's name for a single-book section, which opens straight to the grid), then books
  (sublabel: chapter count). `NativeLists.openBrowse`.
- **Bookmarks:** label is the reference ("John 3:16"), sublabel is a verse snippet (newest 12;
  `POKE: BOOKMARK_SNIPPETS`). Select opens a native submenu: Open (lands on the verse) or
  Remove (deletes the row in place). Empty list: one "No bookmarks yet / Long-press a verse" row.
- **Go to verse:** heading as the label, "Verses 1–25" as the sublabel, plus "Start of chapter"
  when needed and "Verse…" (pick any verse). The range and verse pickers are native too.
- **Filter books:** the 22 Flipper options as a native list (sublabel: book names, or a count).
- **Reader menu and home Browse menu:** native.
- **Style (`POKE: MENU_STYLE`):** on targets with Menu2 themes (API 4.1.8+), MENU_THEME_ORANGE,
  the closest system accent to gold. Older targets fall back to a minimal CustomMenu (gold text
  focus, no cards or pills) with the same delegate API. Native menus follow the system palette,
  so the app's Light theme does not tint them.
- **Retired custom views:** BrowseView, BookmarksView, GotoSectionsView and FilterGridView
  (kept outside the repo in `labs/garmin/retired-v3/`).

## Still custom
The book list, chapter grid and reader. **Opinion on the book list:** a native Menu2 would also work
(66 items, sublabel "50 chapters"), and it would get system scroll and wrap for free. But it loses
the one-blit pixel drag and momentum, the instant focus, and the big centered names that make the
home screen feel fast. Keep it custom unless it starts to feel worse than the native lists.

## Book names: one font (Dylan, 4:39 PM)
- List rows: every row uses `PickList.LIST_FONT` (FONT_SMALL); there is no per-name step-down.
  The fit is checked at the row's own position on the circle. Only a row in the narrow top or
  bottom band whose full name truly doesn't fit uses the abbreviation (`Books.ABBREV`,
  `POKE: BOOK_ABBREV`). Every use is logged as `NOTE ABBR …`. The focused row is centered,
  where the circle is widest, and the gold bar grows to the name.
- Grid header: the book name keeps the header font. If it is too wide at the top of the dial, the
  header moves down (by up to one line), and only then uses the logged abbreviation
  (`POKE: GRID_TITLE_SHIFT`).
- `RoundLayout.drawCenteredInChord` never steps the font down: it shifts, then ellipsizes at a word.
- Reader header: fixed font with pyramid rows (unchanged; it had no step-down).

## Edge fixes carried in
- Glance verse of the day: centered and word-wrapped, with a word-boundary ellipsis.
- Acts grid subtitle: pyramid split over two lines, an ellipsis only after line 2 and at a word.
- edgeB navigation: stale drag focus across lists is fixed; the section range skips missing
  verses (Matthew 17 now reads "19–20").
- Esther footer: the rule is confirmed (it follows the focused verse). No change needed.
