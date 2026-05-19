import Toybox.Lang;
using Toybox.Graphics;
using Toybox.System;

module BibleRenderer {

    // Layout constants
    const HEADER_HEIGHT = 14;
    const DIVIDER_HEIGHT = 1;
    const FOOTER_HEIGHT = 8;
    const MARGIN_X = 2;
    const MARGIN_Y = 2;
    const CONTENT_PADDING = 4;
    const LINE_SPACING = 2;

    // Font size enum (safely stored in Dictionary)
    const FONT_SMALL = 0;
    const FONT_MEDIUM = 1;
    const FONT_LARGE = 2;
    const FONT_TINY = 3;

    // Approximate char widths for built-in fonts
    const CHAR_WIDTH_SMALL = 6;
    const CHAR_WIDTH_MEDIUM = 8;
    const CHAR_WIDTH_LARGE = 12;
    const CHAR_WIDTH_TINY = 5;

    // Convert font size enum to Graphics font constant
    function fontFromEnum(size as Number) as Object {
        if (size == FONT_MEDIUM) {
            return Graphics.FONT_MEDIUM;
        } else if (size == FONT_LARGE) {
            return Graphics.FONT_LARGE;
        } else if (size == FONT_TINY) {
            return Graphics.FONT_TINY;
        } else {
            return Graphics.FONT_SMALL;
        }
    }

    // Get char width for font size enum
    function getCharWidthForFontSize(size as Number) as Number {
        if (size == FONT_MEDIUM) {
            return CHAR_WIDTH_MEDIUM;
        } else if (size == FONT_LARGE) {
            return CHAR_WIDTH_LARGE;
        } else if (size == FONT_TINY) {
            return CHAR_WIDTH_TINY;
        } else {
            return CHAR_WIDTH_SMALL;
        }
    }

    // Font selection based on screen width -> returns enum
    function selectFontSize(screenWidth as Number) as Number {
        if (screenWidth <= 180) {
            return FONT_SMALL;
        } else if (screenWidth <= 260) {
            return FONT_MEDIUM;
        } else {
            return FONT_LARGE;
        }
    }

    // Hardcoded font heights for layout computation
    function getFontHeightForSize(size as Number) as Number {
        if (size == FONT_TINY) {
            return 10;
        } else if (size == FONT_MEDIUM) {
            return 16;
        } else if (size == FONT_LARGE) {
            return 22;
        } else {
            return 12;
        }
    }

    // Compute layout from DC and DeviceSettings
    function computeLayout(dc as Graphics.Dc) as Dictionary {
        var layout = {} as Dictionary;
        var screenWidth = dc.getWidth();
        var screenHeight = dc.getHeight();
        layout.put("screenWidth", screenWidth);
        layout.put("screenHeight", screenHeight);

        var fontSize = selectFontSize(screenWidth);
        layout.put("fontSize", fontSize);

        var fontHeight = getFontHeightForSize(fontSize);
        var lineHeight = fontHeight + LINE_SPACING;
        layout.put("lineHeight", lineHeight);

        // Safe area margins based on screen shape
        var deviceSettings = System.getDeviceSettings();
        var marginX = MARGIN_X;
        var marginTop = MARGIN_Y;
        var marginBottom = MARGIN_Y;

        var screenShape = deviceSettings.screenShape;
        if (screenShape == System.SCREEN_SHAPE_SEMI_OCTAGON) {
            marginX = 18;
            marginTop = 18;
            marginBottom = 18;
        } else if (screenShape == System.SCREEN_SHAPE_ROUND) {
            marginX = 10;
            marginTop = 10;
            marginBottom = 10;
        } else {
            marginX = 4;
            marginTop = 4;
            marginBottom = 4;
        }

        layout.put("marginX", marginX);
        layout.put("marginTop", marginTop);
        layout.put("marginBottom", marginBottom);

        var contentTop = HEADER_HEIGHT + DIVIDER_HEIGHT + CONTENT_PADDING;
        if (contentTop < marginTop + HEADER_HEIGHT) {
            contentTop = marginTop + HEADER_HEIGHT;
        }
        layout.put("contentTop", contentTop);

        var contentBottom = screenHeight - marginBottom - FOOTER_HEIGHT;
        layout.put("contentBottom", contentBottom);

        var contentWidth = screenWidth - (marginX * 2);
        layout.put("contentWidth", contentWidth);

        var contentHeight = contentBottom - contentTop;
        layout.put("contentHeight", contentHeight);

        var linesPerPage = contentHeight / lineHeight;
        if (linesPerPage < 1) {
            linesPerPage = 1;
        }
        layout.put("linesPerPage", linesPerPage);

        // Color scheme
        var isMonochrome = false;
        if (deviceSettings has :screenIsMonochrome) {
            isMonochrome = deviceSettings.screenIsMonochrome;
        }
        if (!isMonochrome && (deviceSettings has :bitsPerPixel)) {
            if (deviceSettings.bitsPerPixel == 1) {
                isMonochrome = true;
            }
        }
        var monoFlag = isMonochrome as Boolean;
        layout.put("isMonochrome", monoFlag);

        if (monoFlag) {
            layout.put("textColor", Graphics.COLOR_BLACK);
            layout.put("bgColor", Graphics.COLOR_WHITE);
            layout.put("headerColor", Graphics.COLOR_BLACK);
            layout.put("accentColor", Graphics.COLOR_BLACK);
        } else {
            layout.put("textColor", Graphics.COLOR_WHITE);
            layout.put("bgColor", Graphics.COLOR_BLACK);
            layout.put("headerColor", Graphics.COLOR_WHITE);
            layout.put("accentColor", Graphics.COLOR_YELLOW);
        }

        // Char width for wrapping
        layout.put("charWidth", getCharWidthForFontSize(fontSize));

        return layout;
    }

    // Create a mock layout dictionary for unit testing
    function mockLayout(
        screenWidth as Number,
        screenHeight as Number,
        fontSize as Number,
        lineHeight as Number,
        isMonochrome as Boolean
    ) as Dictionary {
        var layout = {} as Dictionary;
        layout.put("screenWidth", screenWidth);
        layout.put("screenHeight", screenHeight);
        layout.put("fontSize", fontSize);
        layout.put("lineHeight", lineHeight);

        var marginX = MARGIN_X;
        var marginTop = MARGIN_Y;
        var marginBottom = MARGIN_Y;
        if (screenWidth <= 180) {
            marginX = 18;
            marginTop = 18;
            marginBottom = 18;
        } else if (screenHeight <= 260) {
            marginX = 10;
            marginTop = 10;
            marginBottom = 10;
        } else {
            marginX = 4;
            marginTop = 4;
            marginBottom = 4;
        }
        layout.put("marginX", marginX);
        layout.put("marginTop", marginTop);
        layout.put("marginBottom", marginBottom);

        var contentTop = HEADER_HEIGHT + DIVIDER_HEIGHT + CONTENT_PADDING;
        layout.put("contentTop", contentTop);

        var contentBottom = screenHeight - marginBottom - FOOTER_HEIGHT;
        layout.put("contentBottom", contentBottom);

        var contentWidth = screenWidth - (marginX * 2);
        layout.put("contentWidth", contentWidth);

        var contentHeight = contentBottom - contentTop;
        layout.put("contentHeight", contentHeight);

        var linesPerPage = contentHeight / lineHeight;
        if (linesPerPage < 1) {
            linesPerPage = 1;
        }
        layout.put("linesPerPage", linesPerPage);

        layout.put("isMonochrome", isMonochrome);
        if (isMonochrome) {
            layout.put("textColor", Graphics.COLOR_BLACK);
            layout.put("bgColor", Graphics.COLOR_WHITE);
            layout.put("headerColor", Graphics.COLOR_BLACK);
            layout.put("accentColor", Graphics.COLOR_BLACK);
        } else {
            layout.put("textColor", Graphics.COLOR_WHITE);
            layout.put("bgColor", Graphics.COLOR_BLACK);
            layout.put("headerColor", Graphics.COLOR_WHITE);
            layout.put("accentColor", Graphics.COLOR_YELLOW);
        }

        layout.put("charWidth", getCharWidthForFontSize(fontSize));

        return layout;
    }

    // Split text on whitespace into words
    function splitWords(text as String) as Array<String> {
        var words = [] as Array<String>;
        if (text == null || text.length() == 0) {
            return words;
        }

        var current = "";
        for (var i = 0; i < text.length(); i++) {
            var ch = text.substring(i, i + 1) as String;
            if (ch == " " || ch == "\t" || ch == "\n" || ch == "\r") {
                if (current.length() > 0) {
                    words.add(current);
                    current = "";
                }
            } else {
                current = current + ch;
            }
        }
        if (current.length() > 0) {
            words.add(current);
        }
        return words;
    }

    // Word-wrap verses into display lines.
    // Each returned Dictionary has keys: "text", "verseNumber", "isFirstLine"
    function wrapVerses(
        verses as Array<Dictionary>,
        maxWidthPx as Number,
        charWidth as Number
    ) as Array<Dictionary> {
        var result = [] as Array<Dictionary>;

        if (verses == null || verses.size() == 0) {
            return result;
        }

        var maxChars = maxWidthPx / charWidth;
        if (maxChars < 1) {
            maxChars = 1;
        }

        for (var v = 0; v < verses.size(); v++) {
            var verse = verses[v] as Dictionary;
            var verseNumber = verse.get("verseNumber") as Number;
            var verseText = verse.get("verseText") as String;

            if (verseText == null) {
                verseText = "";
            }

            var numPrefix = verseNumber.toString() + " ";
            var numPrefixLen = numPrefix.length();
            var firstLineChars = maxChars - numPrefixLen;
            if (firstLineChars < 1) {
                firstLineChars = 1;
            }

            var words = splitWords(verseText);
            if (words.size() == 0) {
                // Empty verse: just the number
                var emptyLine = {} as Dictionary;
                emptyLine.put("text", numPrefix);
                emptyLine.put("verseNumber", verseNumber);
                emptyLine.put("isFirstLine", true);
                result.add(emptyLine);
                continue;
            }

            var currentLine = "";
            var isFirstLine = true;
            var lineCharLimit = isFirstLine ? firstLineChars : maxChars;
            var prefix = numPrefix;

            for (var w = 0; w < words.size(); w++) {
                var word = words[w] as String;
                var wordLen = word.length();

                // If single word exceeds line limit and line is empty
                if (wordLen > lineCharLimit && currentLine.length() == 0) {
                    var truncated = word;
                    if (lineCharLimit > 3) {
                        truncated = word.substring(0, lineCharLimit - 3) + "...";
                    } else if (lineCharLimit > 0) {
                        truncated = word.substring(0, lineCharLimit);
                    }
                    var lineDict = {} as Dictionary;
                    lineDict.put("text", prefix + truncated);
                    lineDict.put("verseNumber", verseNumber);
                    lineDict.put("isFirstLine", isFirstLine);
                    result.add(lineDict);

                    isFirstLine = false;
                    prefix = "";
                    lineCharLimit = maxChars;
                    continue;
                }

                if (currentLine.length() == 0) {
                    currentLine = word;
                } else if (currentLine.length() + 1 + wordLen <= lineCharLimit) {
                    currentLine = currentLine + " " + word;
                } else {
                    // Flush current line
                    var lineDict = {} as Dictionary;
                    lineDict.put("text", prefix + currentLine);
                    lineDict.put("verseNumber", verseNumber);
                    lineDict.put("isFirstLine", isFirstLine);
                    result.add(lineDict);

                    currentLine = word;
                    isFirstLine = false;
                    prefix = "";
                    lineCharLimit = maxChars;
                }
            }

            // Flush remaining words
            if (currentLine.length() > 0) {
                var lineDict = {} as Dictionary;
                lineDict.put("text", prefix + currentLine);
                lineDict.put("verseNumber", verseNumber);
                lineDict.put("isFirstLine", isFirstLine);
                result.add(lineDict);
            }
        }

        return result;
    }

    // Pagination
    function computeTotalPages(lineCount as Number, linesPerPage as Number) as Number {
        if (lineCount <= 0 || linesPerPage <= 0) {
            return 1;
        }
        var pages = (lineCount + linesPerPage - 1) / linesPerPage;
        if (pages < 1) {
            pages = 1;
        }
        return pages;
    }

    function clampPage(page as Number, totalPages as Number) as Number {
        if (page < 0) {
            return 0;
        }
        if (page >= totalPages) {
            return totalPages - 1;
        }
        return page;
    }

    function clampScroll(scroll as Number, maxScroll as Number) as Number {
        if (scroll < 0) {
            return 0;
        }
        if (scroll > maxScroll) {
            return maxScroll;
        }
        return scroll;
    }

    function scrollToPage(scroll as Number, linesPerPage as Number) as Number {
        if (linesPerPage <= 0) {
            return 0;
        }
        return scroll / linesPerPage;
    }

    function pageToScroll(page as Number, linesPerPage as Number) as Number {
        return page * linesPerPage;
    }

    function maxScroll(lineCount as Number, linesPerPage as Number) as Number {
        if (lineCount <= linesPerPage) {
            return 0;
        }
        return lineCount - linesPerPage;
    }

    function scrollUp(scroll as Number) as Number {
        if (scroll > 0) {
            return scroll - 1;
        }
        return 0;
    }

    function scrollDown(scroll as Number, maxS as Number) as Number {
        if (scroll < maxS) {
            return scroll + 1;
        }
        return maxS;
    }

    function pageLeft(scroll as Number, linesPerPage as Number) as Number {
        if (scroll >= linesPerPage) {
            return scroll - linesPerPage;
        }
        return 0;
    }

    function pageRight(scroll as Number, maxS as Number, linesPerPage as Number) as Number {
        if (scroll + linesPerPage <= maxS) {
            return scroll + linesPerPage;
        }
        return maxS;
    }

    // Build page indicator string
    function buildPageIndicator(currentPage as Number, totalPages as Number) as String {
        if (totalPages <= 1) {
            return "";
        }
        return (currentPage + 1) + "/" + totalPages;
    }

    // Helper: draw header text with correct font constant
    function drawHeaderText(
        dc as Graphics.Dc,
        fontSize as Number,
        x as Number,
        y as Number,
        text as String,
        color as Number,
        bg as Number
    ) as Void {
        dc.setColor(color, bg);
        if (fontSize == FONT_LARGE) {
            dc.drawText(x, y, Graphics.FONT_LARGE, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (fontSize == FONT_MEDIUM) {
            dc.drawText(x, y, Graphics.FONT_MEDIUM, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (fontSize == FONT_TINY) {
            dc.drawText(x, y, Graphics.FONT_TINY, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.drawText(x, y, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Helper: draw content line text with correct font constant
    function drawContentText(
        dc as Graphics.Dc,
        fontSize as Number,
        x as Number,
        y as Number,
        text as String
    ) as Void {
        if (fontSize == FONT_LARGE) {
            dc.drawText(x, y, Graphics.FONT_LARGE, text, Graphics.TEXT_JUSTIFY_LEFT);
        } else if (fontSize == FONT_MEDIUM) {
            dc.drawText(x, y, Graphics.FONT_MEDIUM, text, Graphics.TEXT_JUSTIFY_LEFT);
        } else if (fontSize == FONT_TINY) {
            dc.drawText(x, y, Graphics.FONT_TINY, text, Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            dc.drawText(x, y, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // Helper: draw message text with correct font constant
    function drawMessageText(
        dc as Graphics.Dc,
        fontSize as Number,
        x as Number,
        y as Number,
        text as String
    ) as Void {
        if (fontSize == FONT_LARGE) {
            dc.drawText(x, y, Graphics.FONT_LARGE, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (fontSize == FONT_MEDIUM) {
            dc.drawText(x, y, Graphics.FONT_MEDIUM, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (fontSize == FONT_TINY) {
            dc.drawText(x, y, Graphics.FONT_TINY, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.drawText(x, y, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Render a page
    function renderPage(
        dc as Graphics.Dc,
        lines as Array<Dictionary>,
        scroll as Number,
        layout as Dictionary,
        headerText as String,
        pageIndicator as String
    ) as Void {
        var screenWidth = layout.get("screenWidth") as Number;
        var screenHeight = layout.get("screenHeight") as Number;
        var fontSize = layout.get("fontSize") as Number;
        var lineHeight = layout.get("lineHeight") as Number;
        var contentTop = layout.get("contentTop") as Number;
        var contentBottom = layout.get("contentBottom") as Number;
        var marginX = layout.get("marginX") as Number;
        var textColor = layout.get("textColor") as Number;
        var bgColor = layout.get("bgColor") as Number;
        var headerColor = layout.get("headerColor") as Number;

        // Clear background
        dc.setColor(textColor, bgColor);
        dc.clear();

        // Draw header
        drawHeaderText(dc, fontSize, screenWidth / 2, 6, headerText, headerColor, bgColor);

        // Draw divider
        dc.setColor(textColor, bgColor);
        dc.drawLine(0, HEADER_HEIGHT, screenWidth, HEADER_HEIGHT);

        // Draw content lines
        dc.setColor(textColor, bgColor);
        var y = contentTop;
        var linesPerPage = layout.get("linesPerPage") as Number;
        var visibleCount = 0;

        for (var i = scroll; i < lines.size() && visibleCount < linesPerPage; i++) {
            var line = lines[i] as Dictionary;
            var text = line.get("text") as String;

            drawContentText(dc, fontSize, marginX, y, text);

            y = y + lineHeight;
            visibleCount = visibleCount + 1;

            // Don't draw past content bottom
            if (y > contentBottom) {
                break;
            }
        }

        // Draw page indicator
        if (pageIndicator != null && pageIndicator.length() > 0) {
            dc.setColor(headerColor, bgColor);
            dc.drawText(
                screenWidth - marginX,
                screenHeight - 8,
                Graphics.FONT_TINY,
                pageIndicator,
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }

    // Render empty/placeholder page
    function renderEmptyPage(
        dc as Graphics.Dc,
        layout as Dictionary,
        headerText as String,
        message as String
    ) as Void {
        var screenWidth = layout.get("screenWidth") as Number;
        var screenHeight = layout.get("screenHeight") as Number;
        var fontSize = layout.get("fontSize") as Number;
        var textColor = layout.get("textColor") as Number;
        var bgColor = layout.get("bgColor") as Number;
        var headerColor = layout.get("headerColor") as Number;

        dc.setColor(textColor, bgColor);
        dc.clear();

        drawHeaderText(dc, fontSize, screenWidth / 2, 6, headerText, headerColor, bgColor);

        dc.setColor(textColor, bgColor);
        dc.drawLine(0, HEADER_HEIGHT, screenWidth, HEADER_HEIGHT);

        dc.setColor(textColor, bgColor);
        drawMessageText(dc, fontSize, screenWidth / 2, screenHeight / 2, message);
    }
}
