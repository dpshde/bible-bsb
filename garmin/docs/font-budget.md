# Custom BMFont budget — REVERTED

**Status: reverted** after Enduro 3 v6 contact sheet (`fea84d2`). Dylan: custom BMFont weighting “brutally ruined the UI” (focused verse rendered bold, jagged raster, Menu2 huge, band overflow).

Reader / lists / headers are back to **system `Graphics.FONT_*`** rendering (as of the revert commit on top of `279005d` lens work).

## Kept from the weighting pass
- Palette: gold `#C89D54`, burnt orange `#C8642A` secondary, **no green / no deep blue**
- `Palette.DIM_VERSE` focus-via-color
- `// POKE: SHORT_VERSE_CHARS` (system `FONT_TINY` bump for short verses)
- `// POKE: WORDS_OF_JESUS` hook (`ContentLoader.hasJesusMarkup`) — spike JSON still has no `\wj`

## Removed
- `resources/fonts/**`, `resources-lowmem/**`, `source/Fonts.mc`, `scripts/gen-bmfonts.py`
- Per-device low-mem jungle overlays for BMFonts
- `font-budget.json` (deleted with the assets)

Do not reintroduce BMFonts without a fresh Enduro 3 A/B and a smaller, antialiased trial set.
