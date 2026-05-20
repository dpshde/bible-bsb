import Toybox.Lang;
using Toybox.Graphics;
using Toybox.System;

module BibleLayout {

    // Font size enum
    const FONT_SMALL = 0;
    const FONT_MEDIUM = 1;
    const FONT_LARGE = 2;
    const FONT_TINY = 3;

    // Default layout constants (may be overridden by device settings)
    const HEADER_HEIGHT = 14;
    const DIVIDER_HEIGHT = 1;
    const FOOTER_HEIGHT = 8;
    const CONTENT_PADDING = 4;
    const LINE_SPACING = 2;

    // Approximate char widths for built-in fonts (pixels)
    const CHAR_WIDTH_SMALL = 6;
    const CHAR_WIDTH_MEDIUM = 8;
    const CHAR_WIDTH_LARGE = 12;
    const CHAR_WIDTH_TINY = 5;

    // Font heights for layout computation (pixels)
    const FONT_HEIGHT_TINY = 10;
    const FONT_HEIGHT_SMALL = 12;
    const FONT_HEIGHT_MEDIUM = 16;
    const FONT_HEIGHT_LARGE = 22;

    // Safe area margins by screen shape
    const MARGIN_SEMI_OCTAGON = 18;
    const MARGIN_ROUND = 10;
    const MARGIN_RECTANGLE = 4;

    // Screen width breakpoints for font selection
    const WIDTH_SMALL_MAX = 180;
    const WIDTH_MEDIUM_MAX = 260;

    // Color constants for restrained color palette
    const COLOR_BG_MONO = Graphics.COLOR_WHITE;
    const COLOR_TEXT_MONO = Graphics.COLOR_BLACK;
    const COLOR_HEADER_MONO = Graphics.COLOR_BLACK;
    const COLOR_ACCENT_MONO = Graphics.COLOR_BLACK;

    const COLOR_BG_COLOR = Graphics.COLOR_BLACK;
    const COLOR_TEXT_COLOR = Graphics.COLOR_WHITE;
    const COLOR_HEADER_COLOR = Graphics.COLOR_WHITE;
    const COLOR_ACCENT_COLOR = Graphics.COLOR_YELLOW;

    // Font selection based on screen width
    // small <= 180, medium 181-260, large >= 261
    function selectFontSize(screenWidth as Number) as Number {
        if (screenWidth <= WIDTH_SMALL_MAX) {
            return FONT_SMALL;
        } else if (screenWidth <= WIDTH_MEDIUM_MAX) {
            return FONT_MEDIUM;
        } else {
            return FONT_LARGE;
        }
    }

    // Get font height for font size enum
    function getFontHeightForSize(size as Number) as Number {
        if (size == FONT_TINY) {
            return FONT_HEIGHT_TINY;
        } else if (size == FONT_MEDIUM) {
            return FONT_HEIGHT_MEDIUM;
        } else if (size == FONT_LARGE) {
            return FONT_HEIGHT_LARGE;
        } else {
            return FONT_HEIGHT_SMALL;
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

    // Check if enhanced readability font scale is active (fontScale > 1)
    function isEnhancedReadability() as Boolean {
        var deviceSettings = System.getDeviceSettings();
        if (deviceSettings has :fontScale) {
            var scale = deviceSettings.fontScale;
            if (scale != null) {
                var scaleNum = scale as Number;
                if (scaleNum > 1) {
                    return true;
                }
            }
        }
        return false;
    }

    // Check if device has touch screen
    function hasTouchScreen() as Boolean {
        var deviceSettings = System.getDeviceSettings();
        if (deviceSettings has :hasTouchScreen) {
            var touch = deviceSettings.hasTouchScreen;
            if (touch != null) {
                return touch as Boolean;
            }
        }
        return false;
    }

    // Determine if device is monochrome (1-bit)
    function isMonochrome() as Boolean {
        var deviceSettings = System.getDeviceSettings();
        var monoFlag = false;
        if (deviceSettings has :screenIsMonochrome) {
            var mono = deviceSettings.screenIsMonochrome;
            if (mono != null) {
                monoFlag = mono as Boolean;
            }
        }
        if (!monoFlag && (deviceSettings has :bitsPerPixel)) {
            var bpp = deviceSettings.bitsPerPixel;
            if (bpp != null && bpp == 1) {
                monoFlag = true;
            }
        }
        return monoFlag;
    }

    // Get colors based on monochrome flag
    function getColors(mono as Boolean) as Dictionary {
        var colors = {} as Dictionary;
        if (mono) {
            colors.put("textColor", COLOR_TEXT_MONO);
            colors.put("bgColor", COLOR_BG_MONO);
            colors.put("headerColor", COLOR_HEADER_MONO);
            colors.put("accentColor", COLOR_ACCENT_MONO);
            colors.put("dividerColor", COLOR_TEXT_MONO);
            colors.put("selectBg", COLOR_TEXT_MONO);
            colors.put("selectText", COLOR_BG_MONO);
        } else {
            colors.put("textColor", COLOR_TEXT_COLOR);
            colors.put("bgColor", COLOR_BG_COLOR);
            colors.put("headerColor", COLOR_HEADER_COLOR);
            colors.put("accentColor", COLOR_ACCENT_COLOR);
            colors.put("dividerColor", COLOR_TEXT_COLOR);
            colors.put("selectBg", COLOR_TEXT_COLOR);
            colors.put("selectText", COLOR_BG_COLOR);
        }
        return colors;
    }

    // Compute safe area margins based on screen shape
    function computeMargins(deviceSettings as System.DeviceSettings) as Dictionary {
        var margins = {} as Dictionary;
        var screenShape = deviceSettings.screenShape;

        var marginX;
        var marginTop;
        var marginBottom;

        if (screenShape == System.SCREEN_SHAPE_SEMI_OCTAGON) {
            marginX = MARGIN_SEMI_OCTAGON;
            marginTop = MARGIN_SEMI_OCTAGON;
            marginBottom = MARGIN_SEMI_OCTAGON;
        } else if (screenShape == System.SCREEN_SHAPE_ROUND) {
            marginX = MARGIN_ROUND;
            marginTop = MARGIN_ROUND;
            marginBottom = MARGIN_ROUND;
        } else {
            marginX = MARGIN_RECTANGLE;
            marginTop = MARGIN_RECTANGLE;
            marginBottom = MARGIN_RECTANGLE;
        }

        margins.put("marginX", marginX);
        margins.put("marginTop", marginTop);
        margins.put("marginBottom", marginBottom);
        return margins;
    }

    // Compute layout from DC and DeviceSettings
    // Returns a Dictionary with all layout parameters
    function computeLayout(dc as Graphics.Dc) as Dictionary {
        var layout = {} as Dictionary;
        var screenWidth = dc.getWidth();
        var screenHeight = dc.getHeight();
        layout.put("screenWidth", screenWidth);
        layout.put("screenHeight", screenHeight);

        var deviceSettings = System.getDeviceSettings();

        // Font selection with readability scaling
        var fontSize = selectFontSize(screenWidth);
        if (isEnhancedReadability() && fontSize < FONT_LARGE) {
            fontSize = fontSize + 1;
        }
        layout.put("fontSize", fontSize);

        var fontHeight = getFontHeightForSize(fontSize);
        var lineHeight = fontHeight + LINE_SPACING;
        layout.put("lineHeight", lineHeight);

        // Safe area margins
        var margins = computeMargins(deviceSettings);
        var marginX = margins.get("marginX") as Number;
        var marginTop = margins.get("marginTop") as Number;
        var marginBottom = margins.get("marginBottom") as Number;
        layout.put("marginX", marginX);
        layout.put("marginTop", marginTop);
        layout.put("marginBottom", marginBottom);

        // Content area
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
        var monoFlag = isMonochrome();
        layout.put("isMonochrome", monoFlag);

        var colors = getColors(monoFlag);
        layout.put("textColor", colors.get("textColor") as Number);
        layout.put("bgColor", colors.get("bgColor") as Number);
        layout.put("headerColor", colors.get("headerColor") as Number);
        layout.put("accentColor", colors.get("accentColor") as Number);
        layout.put("dividerColor", colors.get("dividerColor") as Number);
        layout.put("selectBg", colors.get("selectBg") as Number);
        layout.put("selectText", colors.get("selectText") as Number);

        // Touch support
        layout.put("hasTouchScreen", hasTouchScreen());

        // Char width for text wrapping
        layout.put("charWidth", getCharWidthForFontSize(fontSize));

        return layout;
    }

    // Create a mock layout dictionary for unit testing
    // All parameters are explicit — no calls to System.getDeviceSettings()
    function mockLayout(
        screenWidth as Number,
        screenHeight as Number,
        fontSize as Number,
        lineHeight as Number,
        isMonochrome as Boolean,
        screenShape as Number
    ) as Dictionary {
        var layout = {} as Dictionary;
        layout.put("screenWidth", screenWidth);
        layout.put("screenHeight", screenHeight);
        layout.put("fontSize", fontSize);
        layout.put("lineHeight", lineHeight);

        var marginX;
        var marginTop;
        var marginBottom;
        if (screenShape == System.SCREEN_SHAPE_SEMI_OCTAGON) {
            marginX = MARGIN_SEMI_OCTAGON;
            marginTop = MARGIN_SEMI_OCTAGON;
            marginBottom = MARGIN_SEMI_OCTAGON;
        } else if (screenShape == System.SCREEN_SHAPE_ROUND) {
            marginX = MARGIN_ROUND;
            marginTop = MARGIN_ROUND;
            marginBottom = MARGIN_ROUND;
        } else {
            marginX = MARGIN_RECTANGLE;
            marginTop = MARGIN_RECTANGLE;
            marginBottom = MARGIN_RECTANGLE;
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

        layout.put("isMonochrome", isMonochrome);

        var colors = getColors(isMonochrome);
        layout.put("textColor", colors.get("textColor") as Number);
        layout.put("bgColor", colors.get("bgColor") as Number);
        layout.put("headerColor", colors.get("headerColor") as Number);
        layout.put("accentColor", colors.get("accentColor") as Number);
        layout.put("dividerColor", colors.get("dividerColor") as Number);
        layout.put("selectBg", colors.get("selectBg") as Number);
        layout.put("selectText", colors.get("selectText") as Number);

        layout.put("hasTouchScreen", false);
        layout.put("charWidth", getCharWidthForFontSize(fontSize));

        return layout;
    }

    // Convenience: apply background color and clear screen
    function clearBackground(dc as Graphics.Dc, layout as Dictionary) as Void {
        var bgColor = layout.get("bgColor") as Number;
        var textColor = layout.get("textColor") as Number;
        dc.setColor(textColor, bgColor);
        dc.clear();
    }

    // Convenience: draw header text centered, respecting marginTop for safe area
    function drawHeader(
        dc as Graphics.Dc,
        layout as Dictionary,
        text as String
    ) as Void {
        var screenWidth = layout.get("screenWidth") as Number;
        var fontSize = layout.get("fontSize") as Number;
        var headerColor = layout.get("headerColor") as Number;
        var bgColor = layout.get("bgColor") as Number;
        var dividerColor = layout.get("dividerColor") as Number;
        var marginTop = layout.get("marginTop") as Number;

        // Use marginTop as header Y offset so header stays inside safe area
        var headerY = marginTop > CONTENT_PADDING ? marginTop - 2 : (HEADER_HEIGHT / 2 - 1);
        if (headerY < 0) { headerY = 0; }

        dc.setColor(headerColor, bgColor);
        var font;
        if (fontSize == FONT_LARGE) {
            font = Graphics.FONT_LARGE;
        } else if (fontSize == FONT_MEDIUM) {
            font = Graphics.FONT_MEDIUM;
        } else if (fontSize == FONT_TINY) {
            font = Graphics.FONT_TINY;
        } else {
            font = Graphics.FONT_SMALL;
        }
        dc.drawText(
            screenWidth / 2,
            headerY,
            font,
            text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Divider below header, also respecting marginTop
        var dividerY = marginTop > CONTENT_PADDING ? (marginTop + HEADER_HEIGHT - CONTENT_PADDING) : HEADER_HEIGHT;
        if (dividerY < headerY + 4) { dividerY = headerY + 4; }
        dc.setColor(dividerColor, bgColor);
        dc.drawLine(0, dividerY, screenWidth, dividerY);
    }

    // Convenience: draw a selectable row with highlight
    function drawSelectableRow(
        dc as Graphics.Dc,
        layout as Dictionary,
        y as Number,
        rowHeight as Number,
        text as String,
        isSelected as Boolean,
        x as Number
    ) as Void {
        var width = layout.get("screenWidth") as Number;
        var fontSize = layout.get("fontSize") as Number;
        var textColor = layout.get("textColor") as Number;
        var bgColor = layout.get("bgColor") as Number;
        var selectBg = layout.get("selectBg") as Number;
        var selectText = layout.get("selectText") as Number;

        if (isSelected) {
            dc.setColor(selectBg, selectText);
            dc.fillRectangle(0, y, width, rowHeight);
            dc.setColor(selectText, selectBg);
        } else {
            dc.setColor(textColor, bgColor);
        }

        var font;
        if (fontSize == FONT_LARGE) {
            font = Graphics.FONT_LARGE;
        } else if (fontSize == FONT_MEDIUM) {
            font = Graphics.FONT_MEDIUM;
        } else if (fontSize == FONT_TINY) {
            font = Graphics.FONT_TINY;
        } else {
            font = Graphics.FONT_SMALL;
        }
        dc.drawText(
            x,
            y + (rowHeight / 2) - 1,
            font,
            text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    // Convenience: draw centered message text
    function drawMessage(
        dc as Graphics.Dc,
        layout as Dictionary,
        text as String
    ) as Void {
        var screenWidth = layout.get("screenWidth") as Number;
        var screenHeight = layout.get("screenHeight") as Number;
        var fontSize = layout.get("fontSize") as Number;
        var textColor = layout.get("textColor") as Number;
        var bgColor = layout.get("bgColor") as Number;

        dc.setColor(textColor, bgColor);
        var font;
        if (fontSize == FONT_LARGE) {
            font = Graphics.FONT_LARGE;
        } else if (fontSize == FONT_MEDIUM) {
            font = Graphics.FONT_MEDIUM;
        } else if (fontSize == FONT_TINY) {
            font = Graphics.FONT_TINY;
        } else {
            font = Graphics.FONT_SMALL;
        }
        dc.drawText(
            screenWidth / 2,
            screenHeight / 2,
            font,
            text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
