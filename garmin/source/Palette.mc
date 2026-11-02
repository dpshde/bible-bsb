using Toybox.Graphics;
using Toybox.Lang;

//! Dark AMOLED reading palette (center-band lens). Flipper was 1-bit mono — see SPEC divergences.
module Palette {
    const BG = 0x000000;
    const TEXT = 0xF2EFE9;
    const MUTED = 0x8A8680;       // ~30% gray for preview / secondary
    // POKE: DIM_VERSE — non-focused verse body in verse-snap mode (Dylan tune).
    const DIM_VERSE = 0x9A968F;
    const GOLD = 0xC89D54;
    const DIVIDER = 0xC89D54;
    // POKE: DIVIDER_RULE — thin continuation rules (~40% gold / dark warm).
    const DIVIDER_RULE = 0x3A3631;
    const FOCUS_BG = 0xC89D54;
    const FOCUS_FG = 0x000000;
    const SCRIM = 0x000000;       // full-screen toast overlay (no gray band)
    const TOAST_PILL = 0xC89D54;
    const TOAST_FG = 0x000000;

    function applyBackground(dc as Graphics.Dc) as Void {
        dc.setColor(TEXT, BG);
        dc.clear();
    }
}
