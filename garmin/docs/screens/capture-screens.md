# Capturing the screenshot matrix

Naming: `garmin/docs/screens/<device>/<state>.png` — states listed in SPEC §8.

## After SDK login + device download

```sh
cd garmin
export PATH="$(connect-iq-sdk-manager sdk current-path --bin):$PATH"
monkeyc -f monkey.jungle -d enduro3 -o bin/bsb.prg -y developer_key.der -w
connectiq &          # or: xvfb-run -a connectiq &
monkeydo bin/bsb.prg enduro3
```

Drive each state with the physical/sim buttons (PLAN M4–M8). Use the simulator **File → Save Screen Shot** (or OS capture) into the path above.

## Manual sequences (Enduro 3)

| State | Steps |
|-------|-------|
| book-list | Launch app |
| chapter-grid-start | Select John → grid focus 1 (or 3 for spike start) |
| chapter-grid-mid-wrap | Focus 5, press Down once → 6 |
| chapter-grid-scrolled | Hold/repeat Down into teens |
| chapter-grid-last | Focus last chapter |
| reader / reader-verse-snapped | Select chapter; ensure mode `V` |
| reader-mode-indicator | Menu/Select → toggle; chip shows `L` or `V` |
| reader-incremental-mid-verse | Mode `L`; step into mid-verse |
| continuation-* | From John 3 end, scroll forward (both modes) |
| continuation-cross-book | Malachi 4 → forward |
| bookmarks-* | Menu → Bookmarks; hold in reader to populate |
| rev-22-end / genesis-1-start | When stubs exist; else leave MISSING |
| reader-menu2 | Reader → Select/tap → Menu2 |
| reader-menu2-scroll-mode | Menu2 → Scroll: … → toast/chip |
| touch-book-list-tap | Tap a book row (sim touch) |
| touch-grid-tap | Tap a chapter cell |
| touch-reader-swipe | Swipe up/down in reader |
| touch-reader-hold-bookmark | Long-press reader → pill |

Never commit mocked PNGs. If a device cannot run, note it in the PR.

## Touch + button

On Enduro 3 (and other touch targets), walk both the button column and the touch column of SPEC §1 for each screen. Confirm a single tap does **not** open the chapter twice (TouchGuard).
