using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

class BookmarksView extends WatchUi.View {
    var focus as Lang.Number = 0;
    var items as Lang.Array = [];
    var _rowTop as Lang.Number = 0;
    var _rowH as Lang.Number = 0;

    function initialize() {
        View.initialize();
        items = Bookmarks.load();
    }

    function onShow() as Void {
        items = Bookmarks.load();
        if (focus >= items.size()) {
            focus = items.size() > 0 ? items.size() - 1 : 0;
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Palette.applyBackground(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        var titleFont = Graphics.FONT_TINY;
        var rowFont = Graphics.FONT_SMALL;
        var y = RoundLayout.edgeMargin(w, h);
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        RoundLayout.drawCenteredInChord(dc, y, "Bookmarks", titleFont);
        y += dc.getFontHeight(titleFont) + 6;
        var ruleLeft = RoundLayout.chordLeft(y - 4, w, h);
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ruleLeft, y - 4, ruleLeft + RoundLayout.chordWidth(y - 4, w, h), y - 4);

        if (items.size() == 0) {
            drawEmptyState(dc, y, w, h);
            _rowTop = 0;
            _rowH = 0;
            return;
        }

        var rowH = dc.getFontHeight(rowFont) + 8;
        _rowTop = y;
        _rowH = rowH;
        var bottom = h - RoundLayout.edgeMargin(w, h);
        var i;
        for (i = 0; i < items.size(); i++) {
            if (y + rowH > bottom) {
                break;
            }
            var label = Bookmarks.formatLabel(items[i] as Lang.Number);
            var midY = y + rowH / 2;
            var left = RoundLayout.chordLeft(midY, w, h);
            var cw = RoundLayout.chordWidth(midY, w, h);
            if (i == focus) {
                dc.setColor(Palette.FOCUS_BG, Palette.FOCUS_FG);
                dc.fillRectangle(left, y, cw, rowH - 2);
                dc.setColor(Palette.FOCUS_FG, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, y + 3, rowFont, label, Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, y + 3, rowFont, label, Graphics.TEXT_JUSTIFY_CENTER);
            }
            y += rowH;
        }
    }

    //! Quiet empty state (Flipper spirit: secondary type + short hint, not a hero headline).
    function drawEmptyState(dc as Graphics.Dc, headerBottom as Lang.Number, w as Lang.Number, h as Lang.Number) as Void {
        var bottom = h - RoundLayout.edgeMargin(w, h);
        var col = RoundLayout.columnRect(w, h, headerBottom + 8, bottom);
        var colLeft = col[:left] as Lang.Number;
        var colW = col[:width] as Lang.Number;
        var colMidX = colLeft + colW / 2;

        var titleFont = Graphics.FONT_XTINY;
        var hintFont = Graphics.FONT_XTINY;
        var titleH = dc.getFontHeight(titleFont);
        var hintH = dc.getFontHeight(hintFont);
        var iconH = 22;
        var gap = 8;
        var blockH = iconH + gap + titleH + gap + hintH;
        var bandTop = col[:top] as Lang.Number;
        var bandBottom = col[:bottom] as Lang.Number;
        var blockTop = bandTop + ((bandBottom - bandTop) - blockH) / 2;
        if (blockTop < bandTop) {
            blockTop = bandTop;
        }

        drawBookmarkIcon(dc, colMidX, blockTop + iconH / 2, iconH);

        var titleY = blockTop + iconH + gap;
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(colMidX, titleY, titleFont, "No bookmarks yet", Graphics.TEXT_JUSTIFY_CENTER);

        // POKE: hint copy — button vs touch; try "Hold Select on a verse" on 5-btn-only.
        var hint = "Hold on a verse to save it";
        if (System.getDeviceSettings().isTouchScreen) {
            hint = "Long-press a verse";
        }
        var hintY = titleY + titleH + gap;
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(colMidX, hintY, hintFont, hint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Small outline bookmark glyph (no bitmap asset required).
    function drawBookmarkIcon(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, size as Lang.Number) as Void {
        var hw = size / 3;
        var top = cy - size / 2;
        var bot = cy + size / 2;
        var left = cx - hw;
        var right = cx + hw;
        var notch = cy + size / 6;
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(left, top, right, top);
        dc.drawLine(left, top, left, bot);
        dc.drawLine(right, top, right, bot);
        dc.drawLine(left, bot, cx, notch);
        dc.drawLine(right, bot, cx, notch);
    }

    function rowAtY(y as Lang.Number) as Lang.Number {
        if (_rowH <= 0 || items.size() == 0) {
            return -1;
        }
        var idx = ((y - _rowTop) / _rowH).toNumber();
        if (idx < 0 || idx >= items.size()) {
            return -1;
        }
        return idx;
    }

    function openFocused() as Void {
        if (items.size() == 0) {
            return;
        }
        var id = items[focus] as Lang.Number;
        var book = Bookmarks.unpackBook(id);
        var chapter = Bookmarks.unpackChapter(id);
        ReaderView.openFor(book, chapter);
        // POKE: snap scrollOffset to verse if verse!=0 after open.
    }
}

class BookmarksDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function bv() as BookmarksView {
        return WatchUi.getCurrentView()[0] as BookmarksView;
    }

    function onNextPage() as Lang.Boolean {
        if (TouchGuard.consumePage()) {
            return true;
        }
        var v = bv();
        if (v.items.size() == 0) {
            return true;
        }
        v.focus = (v.focus + 1) % v.items.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        if (TouchGuard.consumePage()) {
            return true;
        }
        var v = bv();
        if (v.items.size() == 0) {
            return true;
        }
        v.focus = (v.focus + v.items.size() - 1) % v.items.size();
        WatchUi.requestUpdate();
        return true;
    }

    // TAP FIX: on touch watches a screen tap is ALSO mapped to the onSelect behavior
    // (before onTap), which opened the highlighted row instead of the tapped one.
    // onSelect therefore never acts: button Enter arrives via onKey, taps via onTap.
    function onSelect() as Lang.Boolean {
        return false;
    }

    function onKey(evt as WatchUi.KeyEvent) as Lang.Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) {
            return activate();
        }
        return false;
    }

    function activate() as Lang.Boolean {
        bv().openFocused();
        return true;
    }

    function onTap(evt) as Lang.Boolean {
        var coords = evt.getCoordinates();
        var v = bv();
        var idx = v.rowAtY(coords[1]);
        if (idx >= 0) {
            v.focus = idx;
            v.openFocused();
        }
        return true;
    }

    function onSwipe(evt) as Lang.Boolean {
        var dir = evt.getDirection();
        var v = bv();
        if (dir == WatchUi.SWIPE_UP) {
            TouchGuard.markPage();
            if (v.items.size() > 0) {
                v.focus = (v.focus + 1) % v.items.size();
                WatchUi.requestUpdate();
            }
            return true;
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            TouchGuard.markPage();
            if (v.items.size() > 0) {
                v.focus = (v.focus + v.items.size() - 1) % v.items.size();
                WatchUi.requestUpdate();
            }
            return true;
        }
        if (dir == WatchUi.SWIPE_RIGHT) {
            TouchGuard.markBack();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }
        return false;
    }

    function onHold(evt) as Lang.Boolean {
        var v = bv();
        if (v.items.size() == 0) {
            return true;
        }
        var coords = evt.getCoordinates();
        var idx = v.rowAtY(coords[1]);
        if (idx >= 0) {
            v.focus = idx;
        }
        var id = v.items[v.focus] as Lang.Number;
        Bookmarks.toggle(Bookmarks.unpackBook(id), Bookmarks.unpackChapter(id), Bookmarks.unpackVerse(id));
        v.items = Bookmarks.load();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Lang.Boolean {
        if (TouchGuard.consumeBack()) {
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
