using Toybox.Graphics;
using Toybox.Lang;

//! Dylan 2026-11-03: the whole app "zoomed out": smaller built-in fonts, light secondary text,
//! tighter rows and padding, more rows per screen. Every size the lists, menus and grids use is
//! here (POKE points); verse text keeps its own face (Faces.body, bold).
module Zoom {
    // Home book list (PickList): was FONT_SMALL rows + 4 px (two font steps down, like verse text).
    const LIST_FONT = Graphics.FONT_XTINY;
    const LIST_ROW_PAD = 3;
    // Home / list titles: was FONT_TINY then XTINY.
    const LIST_TITLE_FONTS = [Graphics.FONT_XTINY];

    // P1 menus: label was FONT_SMALL, sublabel FONT_TINY, rows 27% of the screen, title 24%.
    const MENU_LABEL_FONT = Graphics.FONT_XTINY; // bold (system face); sublabel light
    // Text room on round screens: the row's text never runs past this share of the width
    // (rows above / below focus sit where the circle is narrower).
    const MENU_ROOM_FRAC = 0.80;
    const MENU_SUB_FONT = Graphics.FONT_XTINY; // drawn in the light face (Faces.light)
    const MENU_TITLE_FONT = Graphics.FONT_XTINY;
    const MENU_TITLE_FRAC = 0.17;
    const MENU_INSET_FRAC = 0.05;
    const MENU_LINE_OVERLAP = 3; // px the sublabel tucks under the label's descender space
    const MENU_ROW_PAD = 6;      // px of air per row (top + bottom)
    // Reader "Go to verse" headings menu (ThemedMenu): rows were 30%, title 22%.
    const THEMED_ROW_FRAC = 0.22;
    const THEMED_TITLE_FRAC = 0.17;

    // Chapter / letter grid: cells were FONT_SMALL, title FONT_TINY.
    const GRID_CELL_FONT = Graphics.FONT_TINY;
    const GRID_TITLE_FONT = Graphics.FONT_XTINY;
    const GRID_SUB_FONT = Graphics.FONT_XTINY; // light face
    const GRID_CELL_PAD = 10;  // was 14

    // Reader: px between verse lines (was 2).
    const READER_LINE_PAD = 1;

    var _menuRow as Lang.Number = 0;

    //! P1 menu row height: label + sublabel + air, from the real font heights.
    function menuRowH() as Lang.Number {
        if (_menuRow == 0) {
            var h = MeasureDc.screenH();
            var dc = MeasureDc.get();
            if (dc == null) {
                _menuRow = (h * 0.19).toNumber();
            } else {
                var d = dc as Graphics.Dc;
                _menuRow = d.getFontHeight(MENU_LABEL_FONT) + d.getFontHeight(Faces.light(MENU_SUB_FONT))
                    - MENU_LINE_OVERLAP + MENU_ROW_PAD;
            }
        }
        return _menuRow;
    }
}
