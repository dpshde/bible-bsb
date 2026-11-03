# Edge cases: simulator pass (v3 to v4)

Run on Monday, November 2, 2026, 4:00 to 5:00 PM Eastern Time. Simulator on Xvfb :55, SDK 9.3.0.
Scripts: `edgeA.sh` (bounds), `edgeB3.sh` (input and state), `edgeC.sh` / `edgeC2.sh` (touch core
subset, fr265 and vivoactive5), `edgeD.sh` (glance, Esther, long names, filters).
Every frame is grabbed only after the screen stops changing (`drive.py` settle), and the capture
helpers use the device under test's own geometry (`v3cap.py` used to hard-code Enduro 3, which
offset the bezel in the earlier vivoactive5 and fr265 tiles).
Frames: `screens/edge/<device>/`. Crash check: no unhandled exception, watchdog or out-of-memory
error in any run log.

## Navigation bounds (Enduro 3)

| Case | Result | Frame |
|---|---|---|
| Genesis 1:1: scroll up, back, previous chapter | Pass: stays at 1:1, back goes to the grid | A01–A04 |
| Grid wrap at book ends (Genesis 1 and 50) | Pass | A05–A06 |
| Revelation 22:21: scroll down, next chapter | Pass: "End" marker, no wrap past the Bible | A08–A09 |
| Single-chapter books (Obadiah, Philemon, 2 John, 3 John, Jude) | Pass: open the reader directly, with no one-cell grid (Flipper parity) | A11–A16 |
| Psalm 117 (shortest) | Pass | A18–A19 |
| Psalm 119:176 (longest) | Pass: range level, then verse | g01–g04 (v3 sheet) |
| Esther 8:9 (longest verse), verse mode | Pass: each press steps one verse; the tall verse pages through | D02–D06 |
| Esther 8:9, line mode | Pass | D07–D08 |
| Missing verses (Matthew 17:21, Acts 8:37) | Pass: the verse list skips 21; the section range now ends on 20 (fixed) | A28–A30 |

**Esther footer rule (confirmed):** the footer, header and dimming all follow the focused verse.
In D05 and D08, verse 10 is visible but dimmed, so 8:9 is still focused and the footer correctly
reads EST 8:9. The next press moves focus to 10, and the footer follows.

## Input (Enduro 3)

| Case | Result | Frame |
|---|---|---|
| Rapid taps on a grid cell during the flash and load | Pass: one reader, no extra menu, no timer exhaustion (fixed: input gate plus flash guards plus timer reuse) | B02–B03 |
| Tap below the grid or on the title area | Pass: no action | B04–B05 |
| Tap in the left gap beside chapter 6 | Opens 6. Expected: that point is inside the leftmost cell's rectangle (hit-test is strict) | first B pass |
| Fast drag plus momentum, then tap | Pass: opens the book under the finger | B06–B07 |
| Drag past the top of the list (15 drags) | Pass: clamps at Genesis | B08 |
| Long-press bookmark twice | Pass: "Bookmarked", then "Bookmark removed" | B10–B11 |
| Empty bookmark list | Pass | B12, A42 |

## State (Enduro 3)

| Case | Result | Frame |
|---|---|---|
| Kill and relaunch mid-chapter | Pass: resumes at JHN 14:6 (fixed: offset was reset after the resume) | B14–B17 |
| Scroll mode toggle mid-verse | Pass | B18–B20 |
| Theme toggle on every screen, then relaunch | Pass: Light persists | B21–B29 |
| Corrupt or old stored data | Pass (unit tests: last-read, bookmarks, scroll mode, theme) | test/EdgeCaseTest.mc |
| Glance, fresh install | Fixed in v4 (see below) | D01, G4-* |
| Glance, last read | Pass | D13 |

## Filters

All 22 Flipper options (All, A to Z, 1, 2, 3) pass. "K" shows "No books" (every Kings book is numbered).
1, 2 and 3 each list all numbered books (Flipper parity). Back returns to the filter. A36–A41, D11–D12.
**Fixed:** a drag or momentum focus left over from the home list leaked into the next list, so
the filtered list opened with no highlighted row (D12). `PickList.takeFocus` now drops a focus
that belongs to another list and clamps it into range. Covered by `testStaleDragFocusDropsOnNewList`.

## Display and resources

| Case | Result |
|---|---|
| Go to verse in a chapter with no headings | Pass: straight to the verse picker |
| Go to verse where the first heading is after verse 1 | Pass: "Start of chapter" row |
| Long book names | v4: one font for every row, no step-down (see below) |
| Grid subtitles (Acts 13 "Paul's First Missionary Journey Begins") | v4: pyramid two lines; an ellipsis only after line 2, at a word |
| Memory: Psalm 119, Isaiah 66, Jeremiah 52 back to back | Pass: peak 412 of 763 KB, no watchdog |

## fr265 and vivoactive5 (touch core subset)

Pass: list drag, tap open, tap flash, swipe step, menu, swipe back, filter and back, drag to top,
and opening the top book. The earlier clipped tiles were a capture bug (wrong device geometry);
recaptured frames show no clipping. On fr265, a swipe right at the root list exits the app (correct).

## Glance (v4)

The ref is centered in the glance area, and the verse word-wraps over the rows that fit. If it
doesn't fit, it ends at a whole word with "…". The dropped word came from a character-level cut.
The small square at the left edge of the glance frames is the system-drawn app launcher icon plus
the separator line, not a missing-character box. The simulator previews the glance in the top slot
of the loop, where the bezel crops that icon. Verse-of-the-day text uses —, ‘ ’ and “ ”, which the
system glance font renders.

## v4 milestone checks (7:10 PM ET)
| Check | Result |
|---|---|
| Settings flip: Jump by verse, Dark theme, Tap vibration | pass: sublabel states the new value at once; Dark theme repaints the whole menu (no dark gutter in Light) |
| Settings persist (storage write, reload, corrupt value) | pass: `.DAT` written on flip; `testSettingsPersist`. Simulator relaunch wipes app data, so the kill/relaunch check is pending on the watch (see SETTINGS_PARITY.md) |
| Go to verse headings (John 14) | pass: wrap to up to 3 rows, range kept ("In My Father's House Are Many Rooms (1–4)") |
| Bookmark snippets | pass: cut at a word ("Through Him all…", "In the beginning…") |
| vivoactive5 Acts 13 subtitle | pass: 3-row pyramid "Paul's First / Missionary / Journey Begins", no "…" |
| Grid insets (fr265 2 Chronicles, chapter 1 pill) | pass: pill clears the rule; bottom row inset from the edge |
| Long names, same font (enduro3, fr265, vivoactive5) | pass; logged last resort: grid title "Song of Solomon" → "Song" on fr265/vivoactive5; off-center list rows abbreviate (`logs/abbr-*.txt`) |
| Menus on vivoactive5 / venu3 / venusq2 | pass: dark gold CustomMenu (their Menu2 draws a white panel) |
| Unit tests | 54/54 pass |
