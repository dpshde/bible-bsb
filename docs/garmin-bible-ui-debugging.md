# Garmin Bible UI debugging notes

These notes document the issues found while bringing up the Connect IQ `garmin_bible` app on `instinct3solar45mm` and the fixes that resolved them.

## Target

- Device: `instinct3solar45mm`
- Display: 176x176, monochrome MIP, semi-octagon
- Key constraint: the device skin has a top-right circular subdisplay area that should be treated as unsafe canvas for the app UI.

## Issues found

### Simulator stayed on the splash screen

The app appeared not to launch. The Connect IQ log showed:

```text
Signature check failed on file: BIBLE_INSTINCT3SOLAR45MM
```

The PRG was being signed with a key the compiler accepted but the simulator rejected at launch.

Resolution:

- Generate/use a DER-encoded RSA 4096-bit developer key.
- Keep the generated key local at `garmin_bible/.developer_key.der`.
- `garmin_bible/scripts/dev_key.sh` now validates or creates the key before builds.

### App crashed after launch with out-of-memory

After signing was fixed, the app started but failed during startup with OOM.

Root cause:

- Test classes under `garmin_bible/source/tests` were being compiled into normal production PRGs.
- On the constrained Instinct target, that extra code pushed the app over the memory limit.

Resolution:

- Mark test classes with `(:test)` so normal builds exclude them.
- Keep this annotation on every class under `garmin_bible/source/tests`.

### Book list showed `No books`

After the app launched, the initial screen rendered but the filtered book list was empty.

Root cause:

- Filter logic compared strings by identity instead of value.
- Some `substring()` results also needed to be treated explicitly as `String` values before comparison.

Resolution:

- Use `.equals()` for string value comparisons in `BibleBooks.mc`.
- Cast substring results to `String` before passing them to helpers such as `isUppercaseLetter()`.

### Book list rendered under the top-right subdisplay

Once books populated, the Instinct 3 Solar UI had clear layout problems:

- The header and top rows were too close to the secondary circular subdisplay.
- Selection highlights were drawn full-width, so the highlight bar extended under the subdisplay.
- Scroll indicators used the full screen's right edge and could collide with the unsafe area.
- Row spacing was tight for the small monochrome display.

Resolution:

- Add small semi-octagon safe-row helpers in `BibleLayout.mc`.
- For 176px-class semi-octagon screens, cap row content to the left of the top-right subdisplay for rows above the subdisplay bottom.
- Draw headers, selectable rows, selection highlights, and scroll indicators using safe row bounds instead of the whole screen width.
- Increase the list row height floor on these screens so rows do not crowd each other.

Current constants:

```monkeyc
const SUBSCREEN_SAFE_RIGHT_SMALL = 88;
const SUBSCREEN_BOTTOM_SMALL = 70;
const SUBSCREEN_GRID_COLS_SMALL = 3;
const MIN_LIST_ROW_HEIGHT_SMALL = 16;
```

These values are intentionally applied only to small semi-octagon screens (`screenWidth <= 180` and `screenHeight <= 180`) so larger round/color devices keep their normal layout.

### Grid navigation jumped by rows

Chapter and filter screens used a visual grid. Up/Down originally moved by a full row (`±5`), which made navigation feel like jumping around the grid rather than stepping through adjacent items.

Expected behavior:

- Move forward and backward incrementally.
- At row boundaries, the next item should remain adjacent on screen.

Resolution:

- Draw chapter/filter grids in a snake order:
  - even rows: left-to-right
  - odd rows: right-to-left
- Change Up/Down handlers to decrement/increment by one item instead of moving by a row.
- On small semi-octagon screens, reduce grids to three columns so each cell stays within safe readable width.

Example order with three columns:

```text
1   2   3
6   5   4
7   8   9
12  11  10
```

## Verification commands

Build the primary target:

```bash
./garmin_bible/build.sh instinct3solar45mm
```

Strict typecheck all configured devices:

```bash
./garmin_bible/build_all.sh typecheck
```

Compile test builds for all configured devices:

```bash
./garmin_bible/build_all.sh test
```

Run the primary target in the simulator:

```bash
cd garmin_bible/bin
/tmp/connectiq/sdk_zip/bin/monkeydo bible_instinct3solar45mm.prg instinct3solar45mm
```

`monkeydo` staying attached is expected when the app is running. If the simulator shows stale or ghosted content after repeated runs, restart the simulator and rerun before judging visual layout.

Check recent Connect IQ errors:

```bash
tail -n 80 /private/var/folders/05/v6ytshgx70n84gfvg39wyt640000gn/T/com.garmin.connectiq/GARMIN/APPS/LOGS/CIQ_LOG.YML
```

## Expected current result

On a fresh `instinct3solar45mm` simulator run:

- The app launches past the splash screen.
- The book list renders instead of `No books`.
- The `< All >` header and top book rows stay left of the top-right subdisplay.
- Selection highlights are clipped to the safe row width.
- Chapter/filter navigation advances one item at a time in snake order.
