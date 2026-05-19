using Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi as Ui;
using Toybox.System;
using Toybox.Application;

class CollectionView extends Ui.View {
    private const LINE_HEIGHT = 14;

    var layout as Dictionary?;
    var collection as Array<Dictionary> = [] as Array<Dictionary>;
    var selectedIndex as Number = 0;
    var toastMessage as String = "";
    var toastEndTime as Number = 0;

    function initialize() {
        View.initialize();
        refreshCollection();
    }

    function refreshCollection() as Void {
        var all = BibleStorage.loadAll();
        // Reverse to show newest first (captured_at descending)
        collection = [] as Array<Dictionary>;
        for (var i = all.size() - 1; i >= 0; i = i - 1) {
            collection.add(all[i]);
        }
    }

    function onShow() as Void {
        refreshCollection();
        // Clamp selectedIndex to valid range
        if (collection.size() == 0) {
            selectedIndex = 0;
        } else if (selectedIndex >= collection.size()) {
            selectedIndex = collection.size() - 1;
        }
        // Clear stale toast
        toastMessage = "";
        toastEndTime = 0;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        layout = BibleLayout.computeLayout(dc);
        var safeLayout = layout as Dictionary;

        var width = dc.getWidth();
        var height = dc.getHeight();
        var marginX = safeLayout.get("marginX") as Number;
        var textColor = safeLayout.get("textColor") as Number;
        var bgColor = safeLayout.get("bgColor") as Number;
        var selectBg = safeLayout.get("selectBg") as Number;
        var selectText = safeLayout.get("selectText") as Number;
        var fontSize = safeLayout.get("fontSize") as Number;

        dc.setColor(textColor, bgColor);
        dc.clear();

        BibleLayout.drawHeader(dc, safeLayout, "Collection");

        if (collection == null || collection.size() == 0) {
            drawEmptyState(dc, safeLayout, width, height);
            return;
        }

        // Clamp selectedIndex to valid range
        if (selectedIndex >= collection.size()) {
            selectedIndex = collection.size() - 1;
        }
        if (selectedIndex < 0) {
            selectedIndex = 0;
        }

        var contentHeight = height - BibleLayout.HEADER_HEIGHT - 2;
        var maxVisible = contentHeight / LINE_HEIGHT;
        if (maxVisible < 1) {
            maxVisible = 1;
        }

        var total = collection.size();
        var scroll = computeScroll(selectedIndex, total, maxVisible);

        // Font for rows
        var rowFont;
        if (fontSize == BibleLayout.FONT_LARGE) {
            rowFont = Graphics.FONT_LARGE;
        } else if (fontSize == BibleLayout.FONT_MEDIUM) {
            rowFont = Graphics.FONT_MEDIUM;
        } else if (fontSize == BibleLayout.FONT_TINY) {
            rowFont = Graphics.FONT_TINY;
        } else {
            rowFont = Graphics.FONT_SMALL;
        }

        for (var i = 0; i < maxVisible; i = i + 1) {
            var listIdx = scroll + i;
            if (listIdx >= total) {
                break;
            }

            var y = BibleLayout.HEADER_HEIGHT + 2 + (i * LINE_HEIGHT);
            var isSelected = (listIdx == selectedIndex);

            if (isSelected) {
                dc.setColor(selectBg, selectText);
                dc.fillRectangle(0, y, width, LINE_HEIGHT);
                dc.setColor(selectText, selectBg);
            } else {
                dc.setColor(textColor, bgColor);
            }

            var entry = collection[listIdx] as Dictionary;
            var label = entry.get("display_ref") as String;
            if (label == null || label.length() == 0) {
                label = "(unknown)";
            }

            dc.drawText(
                marginX,
                y + (LINE_HEIGHT / 2) - 1,
                rowFont,
                label,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        if (total > maxVisible) {
            drawScrollIndicator(dc, safeLayout, scroll, total, maxVisible, height);
        }

        drawToastIfActive(dc, safeLayout, width, height);
    }

    private function drawEmptyState(dc as Graphics.Dc, layout as Dictionary, width as Number, height as Number) as Void {
        var textColor = layout.get("textColor") as Number;
        var bgColor = layout.get("bgColor") as Number;
        dc.setColor(textColor, bgColor);
        var msg = WatchUi.loadResource(Rez.Strings.NoSavedPassages) as String;
        var fontSize = layout.get("fontSize") as Number;
        var font;
        if (fontSize == BibleLayout.FONT_LARGE) {
            font = Graphics.FONT_LARGE;
        } else if (fontSize == BibleLayout.FONT_MEDIUM) {
            font = Graphics.FONT_MEDIUM;
        } else if (fontSize == BibleLayout.FONT_TINY) {
            font = Graphics.FONT_TINY;
        } else {
            font = Graphics.FONT_SMALL;
        }
        dc.drawText(
            width / 2,
            height / 2,
            font,
            msg,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function computeScroll(pos as Number, total as Number, maxVisible as Number) as Number {
        var scroll = 0;
        if (pos >= maxVisible) {
            scroll = pos - maxVisible + 1;
        }
        if (scroll > total - maxVisible) {
            scroll = total - maxVisible;
        }
        if (scroll < 0) {
            scroll = 0;
        }
        return scroll;
    }

    private function drawScrollIndicator(
        dc as Graphics.Dc,
        layout as Dictionary,
        scroll as Number,
        total as Number,
        maxVisible as Number,
        height as Number
    ) as Void {
        var textColor = layout.get("textColor") as Number;
        var bgColor = layout.get("bgColor") as Number;
        var width = layout.get("screenWidth") as Number;
        var marginX = layout.get("marginX") as Number;
        var scrollBarX = width - marginX - 3;
        if (scrollBarX < 0) {
            scrollBarX = 0;
        }

        var trackTop = BibleLayout.HEADER_HEIGHT + 2;
        var trackBottom = height - 2;
        var trackHeight = trackBottom - trackTop;

        if (trackHeight <= 0) {
            return;
        }

        var thumbHeight = (maxVisible * trackHeight / total);
        if (thumbHeight < 4) {
            thumbHeight = 4;
        }

        var scrollableRange = total - maxVisible;
        var thumbY;
        if (scrollableRange <= 0) {
            thumbY = trackTop;
        } else {
            thumbY = trackTop + (scroll * (trackHeight - thumbHeight) / scrollableRange);
        }

        dc.setColor(textColor, bgColor);
        dc.fillRectangle(scrollBarX, thumbY, 3, thumbHeight);
    }

    private function drawToastIfActive(dc as Graphics.Dc, layout as Dictionary, width as Number, height as Number) as Void {
        if (toastMessage == null || toastMessage.length() == 0) {
            return;
        }
        if (System.getTimer() >= toastEndTime) {
            return;
        }
        var toastY = height - 24;
        var textColor = layout.get("textColor") as Number;
        var bgColor = layout.get("bgColor") as Number;
        var selectBg = layout.get("selectBg") as Number;
        var selectText = layout.get("selectText") as Number;
        dc.setColor(selectBg, selectBg);
        dc.fillRectangle(8, toastY, width - 16, 16);
        dc.setColor(selectText, selectBg);
        dc.drawText(
            width / 2,
            toastY + 8,
            Graphics.FONT_TINY,
            toastMessage,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

}
