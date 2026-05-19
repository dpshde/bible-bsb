using Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi as Ui;
using Toybox.System;
using Toybox.Application;

class CollectionView extends Ui.View {
    private const HEADER_HEIGHT = 14;
    private const LINE_HEIGHT = 14;
    private const MARGIN_X = 4;

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
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();

        drawHeader(dc, width);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawLine(0, HEADER_HEIGHT, width, HEADER_HEIGHT);

        if (collection == null || collection.size() == 0) {
            drawEmptyState(dc, width, height);
            return;
        }

        var contentHeight = height - HEADER_HEIGHT - 2;
        var maxVisible = contentHeight / LINE_HEIGHT;
        if (maxVisible < 1) {
            maxVisible = 1;
        }

        var total = collection.size();
        var scroll = computeScroll(selectedIndex, total, maxVisible);

        for (var i = 0; i < maxVisible; i = i + 1) {
            var listIdx = scroll + i;
            if (listIdx >= total) {
                break;
            }

            var y = HEADER_HEIGHT + 2 + (i * LINE_HEIGHT);
            var isSelected = (listIdx == selectedIndex);

            if (isSelected) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(0, y, width, LINE_HEIGHT);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            } else {
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
            }

            var entry = collection[listIdx] as Dictionary;
            var label = entry.get("display_ref") as String;
            if (label == null || label.length() == 0) {
                label = "(unknown)";
            }

            dc.drawText(
                MARGIN_X,
                y + (LINE_HEIGHT / 2) - 1,
                Graphics.FONT_SMALL,
                label,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        if (total > maxVisible) {
            drawScrollIndicator(dc, scroll, total, maxVisible, height);
        }

        drawToastIfActive(dc, width, height);
    }

    private function drawHeader(dc as Graphics.Dc, width as Number) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawText(
            width / 2,
            HEADER_HEIGHT / 2 - 1,
            Graphics.FONT_SMALL,
            "Collection",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawEmptyState(dc as Graphics.Dc, width as Number, height as Number) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        var msg = WatchUi.loadResource(Rez.Strings.NoSavedPassages) as String;
        dc.drawText(
            width / 2,
            height / 2,
            Graphics.FONT_SMALL,
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
        scroll as Number,
        total as Number,
        maxVisible as Number,
        height as Number
    ) as Void {
        var trackTop = HEADER_HEIGHT + 2;
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

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.fillRectangle(172, thumbY, 3, thumbHeight);
    }

    private function drawToastIfActive(dc as Graphics.Dc, width as Number, height as Number) as Void {
        if (toastMessage == null || toastMessage.length() == 0) {
            return;
        }
        if (System.getTimer() >= toastEndTime) {
            return;
        }
        var toastY = height - 24;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(8, toastY, width - 16, 16);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(
            width / 2,
            toastY + 8,
            Graphics.FONT_TINY,
            toastMessage,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

}
