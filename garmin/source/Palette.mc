using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;

//! Reading palette with a persisted Dark/Light theme. No green, no deep blue (Dylan).
//! Values are module vars so every custom-drawn screen follows Palette.applyTheme().
//! 64-color MIP (Enduro 3) quantizes 0xC89D54 to olive 0xAAAA55 (reads green), so MIP
//! builds use palette-exact colors (monkey.jungle excludeAnnotations mip/amoled).
//! Flipper was 1-bit mono — see SPEC divergences.
module Palette {
    const STORAGE_KEY = "theme";
    const THEME_DARK = 0;
    const THEME_LIGHT = 1;

    // Theme-independent accents.
    const BURNT_ORANGE = 0xC8642A; // secondary accent only
    // POKE: JESUS_TINT — warm (not red) for \wj spans when markup exists.
    const JESUS = 0xE8C9A0;
    const SCRIM = 0x000000;

    var theme as Lang.Number = THEME_DARK;
    var BG as Lang.Number = 0x000000;
    var TEXT as Lang.Number = 0xF2EFE9;
    var MUTED as Lang.Number = 0x8A8680;
    // POKE: DIM_VERSE — non-focused verse body in verse-snap mode (Dylan tune).
    var DIM_VERSE as Lang.Number = 0x9A968F;
    var GOLD as Lang.Number = 0xC89D54;
    var DIVIDER as Lang.Number = 0xC89D54;
    // POKE: DIVIDER_RULE — thin continuation rules.
    var DIVIDER_RULE as Lang.Number = 0x3A3631;
    var FOCUS_BG as Lang.Number = 0xC89D54;
    var FOCUS_FG as Lang.Number = 0x000000;
    var TOAST_PILL as Lang.Number = 0xC89D54;
    var TOAST_FG as Lang.Number = 0x000000;
    // POKE: PROGRESS_ARC track (~20% gold).
    var PROGRESS_TRACK as Lang.Number = 0x2E2414;
    // POKE: TOAST_DIM — reader text color while the toast pill shows.
    var TOAST_DIM as Lang.Number = 0x555555;

    function loadTheme() as Void {
        var v = Application.Storage.getValue(STORAGE_KEY);
        applyTheme(v instanceof Lang.Number && v == THEME_LIGHT ? THEME_LIGHT : THEME_DARK);
    }

    function toggleTheme() as Void {
        applyTheme(theme == THEME_LIGHT ? THEME_DARK : THEME_LIGHT);
        Application.Storage.setValue(STORAGE_KEY, theme);
    }

    function themeLabel() as Lang.String {
        return theme == THEME_LIGHT ? "Light" : "Dark";
    }

    function applyTheme(t as Lang.Number) as Void {
        theme = t;
        if (t == THEME_LIGHT) {
            applyLight();
        } else {
            applyDark();
        }
    }

    (:amoled)
    function applyDark() as Void {
        BG = 0x000000; TEXT = 0xF2EFE9; MUTED = 0x8A8680; DIM_VERSE = 0x9A968F;
        GOLD = 0xC89D54; DIVIDER = 0xC89D54; DIVIDER_RULE = 0x3A3631;
        FOCUS_BG = 0xC89D54; FOCUS_FG = 0x000000; TOAST_PILL = 0xC89D54; TOAST_FG = 0x000000;
        PROGRESS_TRACK = 0x2E2414; TOAST_DIM = 0x555555;
    }

    (:mip)
    function applyDark() as Void {
        BG = 0x000000; TEXT = 0xFFFFFF; MUTED = 0xAAAAAA; DIM_VERSE = 0xAAAAAA;
        GOLD = 0xFFAA55; DIVIDER = 0xFFAA55; DIVIDER_RULE = 0xAA5500;
        FOCUS_BG = 0xFFAA55; FOCUS_FG = 0x000000; TOAST_PILL = 0xFFAA55; TOAST_FG = 0x000000;
        PROGRESS_TRACK = 0x555555; TOAST_DIM = 0x555555;
    }

    // POKE: THEME_LIGHT_PALETTE — paper bg, near-black text, mid-gray dim verses,
    // gold darkened for contrast on paper. No green, no deep blue.
    (:amoled)
    function applyLight() as Void {
        BG = 0xF4EFE6; TEXT = 0x1A1714; MUTED = 0x6E675C; DIM_VERSE = 0x6B665E;
        GOLD = 0x8A6420; DIVIDER = 0x8A6420; DIVIDER_RULE = 0xC9BFAE;
        FOCUS_BG = 0x8A6420; FOCUS_FG = 0xFFFFFF; TOAST_PILL = 0x8A6420; TOAST_FG = 0xFFFFFF;
        PROGRESS_TRACK = 0xE3D9C6; TOAST_DIM = 0xBDB6AA;
    }

    // MIP light: white paper, black text; burnt orange 0xAA5500 is the only dark warm
    // accent in the 64-color palette (dark gold 0xAAAA55 reads green).
    (:mip)
    function applyLight() as Void {
        BG = 0xFFFFFF; TEXT = 0x000000; MUTED = 0x555555; DIM_VERSE = 0x555555;
        GOLD = 0xAA5500; DIVIDER = 0xAA5500; DIVIDER_RULE = 0xAAAAAA;
        FOCUS_BG = 0xAA5500; FOCUS_FG = 0xFFFFFF; TOAST_PILL = 0xAA5500; TOAST_FG = 0xFFFFFF;
        PROGRESS_TRACK = 0xAAAAAA; TOAST_DIM = 0xAAAAAA;
    }

    function applyBackground(dc as Graphics.Dc) as Void {
        dc.setColor(TEXT, BG);
        dc.clear();
    }
}
