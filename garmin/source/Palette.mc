using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;

//! The app's one color constants file. Prime's Selah Tools P1 scheme (launcher icon round 3):
//! cream / dark brown / muted gold, MIP64 white / black / burnt orange. Every hex the watch UI
//! draws is named here; Palette (below) maps them onto roles per screen type and theme.
(:glance)
module BrandColors {
    // P1 (Prime, icon-test/palettes palettes.py "P1"): AMOLED / 16-bit screens.
    const CREAM = 0xF3EFE5;       // P1 foreground: reader text, light-theme paper
    const BROWN = 0x4D3C22;       // P1 dark brown: rules, progress track, light-theme muted text
    const MUTED_GOLD = 0x9A7D52;  // P1 muted gold: subtitles/hints, dividers under titles
    // Dylan: gold stays the selection accent (Prime's P1 does not replace it).
    const GOLD = 0xC89D54;        // focus box, toast pill, headings, verse numbers
    const GOLD_ON_PAPER = 0x8A6420; // light theme accent (gold darkened for contrast on cream)
    const INK = 0x1A1714;         // light theme body text
    // Mixes of the P1 colors (50/50), for roles P1 has no swatch for.
    const CREAM_DIM = 0xA09684;   // cream over brown: unfocused verses (dark)
    const PAPER_RULE = 0xC6B69C;  // cream over muted gold: rules/track on paper (light)
    // MIP64 (Enduro 3, 64-color): P1's MIP mapping is white / black / 0xAA5500. 0xC89D54 would
    // quantize to olive 0xAAAA55 (reads green) and P1's "_B" dot 0x555500 is olive too: unused.
    const MIP_WHITE = 0xFFFFFF;
    const MIP_BLACK = 0x000000;
    const MIP_ORANGE = 0xAA5500;  // P1 MIP muted gold: dividers, rules, progress track
    const MIP_GOLD = 0xFFAA55;    // nearest palette gold: selection, headings
    const MIP_GRAY = 0xAAAAAA;    // MIP muted text (0xAA5500 text is too dim on reflective MIP)
    const MIP_DARK_GRAY = 0x555555;
    // Dylan's secondary accent (burnt orange) and the reserved words-of-Jesus tint.
    const BURNT_ORANGE = 0xC8642A;
    const JESUS = 0xE8C9A0;
}

//! Reading palette with a persisted Dark/Light theme. No green, no deep blue (Dylan).
//! Values are module vars so every custom-drawn screen follows Palette.applyTheme().
//! 64-color MIP (Enduro 3) quantizes 0xC89D54 to olive 0xAAAA55 (reads green), so MIP
//! builds use palette-exact colors (monkey.jungle excludeAnnotations mip/amoled).
//! Flipper was 1-bit mono — see SPEC divergences.
module Palette {
    const STORAGE_KEY = "theme";
    const THEME_DARK = 0;
    const THEME_LIGHT = 1;

    // Theme-independent accents (values in BrandColors).
    const BURNT_ORANGE = BrandColors.BURNT_ORANGE; // secondary accent only
    // POKE: JESUS_TINT — warm (not red) for \wj spans when markup exists.
    const JESUS = BrandColors.JESUS;
    const SCRIM = 0x000000;

    // Role colors: set by applyTheme() (getInitialView calls loadTheme before any drawing).

    var theme as Lang.Number = THEME_DARK;
    var BG as Lang.Number = 0;
    var TEXT as Lang.Number = 0;
    var MUTED as Lang.Number = 0;
    // POKE: DIM_VERSE — non-focused verse body in verse-snap mode (Dylan tune).
    var DIM_VERSE as Lang.Number = 0;
    var GOLD as Lang.Number = 0;
    var DIVIDER as Lang.Number = 0;
    // POKE: DIVIDER_RULE — thin continuation rules.
    var DIVIDER_RULE as Lang.Number = 0;
    var FOCUS_BG as Lang.Number = 0;
    var FOCUS_FG as Lang.Number = 0;
    var TOAST_PILL as Lang.Number = 0;
    var TOAST_FG as Lang.Number = 0;
    // POKE: PROGRESS_ARC track (~20% gold).
    var PROGRESS_TRACK as Lang.Number = 0;
    // POKE: TOAST_DIM — reader text color while the toast pill shows.
    var TOAST_DIM as Lang.Number = 0;

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

    // Backgrounds stay black in dark themes (contrast, AMOLED burn-in/battery).
    (:amoled)
    function applyDark() as Void {
        BG = 0x000000; TEXT = BrandColors.CREAM; MUTED = BrandColors.MUTED_GOLD;
        DIM_VERSE = BrandColors.CREAM_DIM;
        GOLD = BrandColors.GOLD; DIVIDER = BrandColors.MUTED_GOLD; DIVIDER_RULE = BrandColors.BROWN;
        FOCUS_BG = BrandColors.GOLD; FOCUS_FG = 0x000000;
        TOAST_PILL = BrandColors.GOLD; TOAST_FG = 0x000000;
        PROGRESS_TRACK = BrandColors.BROWN; TOAST_DIM = BrandColors.BROWN;
    }

    (:mip)
    function applyDark() as Void {
        BG = BrandColors.MIP_BLACK; TEXT = BrandColors.MIP_WHITE; MUTED = BrandColors.MIP_GRAY;
        DIM_VERSE = BrandColors.MIP_GRAY;
        GOLD = BrandColors.MIP_GOLD; DIVIDER = BrandColors.MIP_ORANGE; DIVIDER_RULE = BrandColors.MIP_ORANGE;
        FOCUS_BG = BrandColors.MIP_GOLD; FOCUS_FG = BrandColors.MIP_BLACK;
        TOAST_PILL = BrandColors.MIP_GOLD; TOAST_FG = BrandColors.MIP_BLACK;
        PROGRESS_TRACK = BrandColors.MIP_ORANGE; TOAST_DIM = BrandColors.MIP_DARK_GRAY;
    }

    // POKE: THEME_LIGHT_PALETTE — paper bg, near-black text, mid-gray dim verses,
    // gold darkened for contrast on paper. No green, no deep blue.
    (:amoled)
    function applyLight() as Void {
        BG = BrandColors.CREAM; TEXT = BrandColors.INK; MUTED = BrandColors.BROWN;
        DIM_VERSE = BrandColors.BROWN;
        GOLD = BrandColors.GOLD_ON_PAPER; DIVIDER = BrandColors.MUTED_GOLD; DIVIDER_RULE = BrandColors.PAPER_RULE;
        FOCUS_BG = BrandColors.GOLD_ON_PAPER; FOCUS_FG = 0xFFFFFF;
        TOAST_PILL = BrandColors.GOLD_ON_PAPER; TOAST_FG = 0xFFFFFF;
        PROGRESS_TRACK = BrandColors.PAPER_RULE; TOAST_DIM = BrandColors.PAPER_RULE;
    }

    // MIP light: white paper, black text; burnt orange 0xAA5500 is the only dark warm
    // accent in the 64-color palette (dark gold 0xAAAA55 reads green).
    (:mip)
    function applyLight() as Void {
        BG = BrandColors.MIP_WHITE; TEXT = BrandColors.MIP_BLACK; MUTED = BrandColors.MIP_DARK_GRAY;
        DIM_VERSE = BrandColors.MIP_DARK_GRAY;
        GOLD = BrandColors.MIP_ORANGE; DIVIDER = BrandColors.MIP_ORANGE; DIVIDER_RULE = BrandColors.MIP_GRAY;
        FOCUS_BG = BrandColors.MIP_ORANGE; FOCUS_FG = BrandColors.MIP_WHITE;
        TOAST_PILL = BrandColors.MIP_ORANGE; TOAST_FG = BrandColors.MIP_WHITE;
        PROGRESS_TRACK = BrandColors.MIP_GRAY; TOAST_DIM = BrandColors.MIP_GRAY;
    }

    function applyBackground(dc as Graphics.Dc) as Void {
        dc.setColor(TEXT, BG);
        dc.clear();
    }
}
