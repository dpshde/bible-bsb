using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

//! Loads spike chapter JSON from resources. One chapter at a time (SPEC §6).
module ContentLoader {

    function resourceFor(book as Lang.Number, chapter as Lang.Number) as Lang.ResourceId or Null {
        // John=42, Malachi=38, Matthew=39
        if (book == 42 && chapter == 3) {
            return Rez.JsonData.John3;
        }
        if (book == 42 && chapter == 4) {
            return Rez.JsonData.John4;
        }
        if (book == 38 && chapter == 4) {
            return Rez.JsonData.Malachi4;
        }
        if (book == 39 && chapter == 1) {
            return Rez.JsonData.Matthew1;
        }
        // POKE: map full canon once pack/chunk pipeline exists.
        return null;
    }

    function hasChapter(book as Lang.Number, chapter as Lang.Number) as Lang.Boolean {
        return resourceFor(book, chapter) != null;
    }

    //! Returns { :book, :chapter, :verses => [ { :n, :t }, ... ] } or null.
    function loadChapter(book as Lang.Number, chapter as Lang.Number) as Lang.Dictionary or Null {
        var rez = resourceFor(book, chapter);
        if (rez == null) {
            return null;
        }
        var data = WatchUi.loadResource(rez);
        if (data == null || !(data instanceof Lang.Dictionary)) {
            return null;
        }
        var verses = data["verses"];
        if (verses == null) {
            verses = data[:verses];
        }
        return {
            :book => book,
            :chapter => chapter,
            :verses => verses
        };
    }

    //! Char-budget wrap (tests / fallback). O(n) char-array scan — avoids CIQ watchdog.
    function wrapVerse(verseNum as Lang.Number, text as Lang.String, maxChars as Lang.Number) as Lang.Array {
        var out = [];
        var prefix = verseNum + " ";
        var chars = text.toCharArray();
        var n = chars.size();
        var pos = 0;
        var first = true;
        while (pos < n) {
            var chunk = "";
            var budget = maxChars;
            if (first) {
                chunk = prefix;
                budget = maxChars - prefix.length();
                if (budget < 8) {
                    budget = maxChars;
                    chunk = "";
                }
            }
            if (n - pos <= budget) {
                out.add({ :text => chunk + text.substring(pos, n), :verse => verseNum, :isStart => first });
                break;
            }
            var take = budget;
            var i;
            for (i = budget - 1; i > 0; i--) {
                if (chars[pos + i] == ' ') {
                    take = i;
                    break;
                }
            }
            out.add({ :text => chunk + text.substring(pos, pos + take), :verse => verseNum, :isStart => first });
            pos += take;
            while (pos < n && chars[pos] == ' ') {
                pos++;
            }
            first = false;
        }
        return out;
    }

    //! Pixel wrap to a max width (chord / square content width). Returns { :text, :verse, :isStart }.
    function wrapVerseToWidth(dc as Graphics.Dc, font as Lang.Number, verseNum as Lang.Number,
                              text as Lang.String, maxWidth as Lang.Number) as Lang.Array {
        var out = [];
        var prefix = verseNum + " ";
        var chars = text.toCharArray();
        var n = chars.size();
        var pos = 0;
        var first = true;
        while (pos < n) {
            var linePrefix = first ? prefix : "";
            var prefixW = dc.getTextWidthInPixels(linePrefix, font);
            var budgetPx = maxWidth - prefixW;
            if (budgetPx < 12) {
                linePrefix = "";
                budgetPx = maxWidth;
            }

            // Entire remainder fits.
            var rest = text.substring(pos, n);
            if (dc.getTextWidthInPixels(rest, font) <= budgetPx) {
                out.add({ :text => linePrefix + rest, :verse => verseNum, :isStart => first });
                break;
            }

            // Walk forward by words until width exceeded (char scan, break on spaces).
            var end = pos;
            var lastSpace = -1;
            while (end < n) {
                var probe = text.substring(pos, end + 1);
                if (dc.getTextWidthInPixels(probe, font) > budgetPx) {
                    break;
                }
                if (chars[end] == ' ') {
                    lastSpace = end;
                }
                end++;
            }
            var takeEnd = end;
            if (lastSpace > pos) {
                takeEnd = lastSpace;
            } else if (end == pos) {
                // Single overlong token — force one char to make progress.
                takeEnd = pos + 1;
            }
            out.add({
                :text => linePrefix + text.substring(pos, takeEnd),
                :verse => verseNum,
                :isStart => first
            });
            pos = takeEnd;
            while (pos < n && chars[pos] == ' ') {
                pos++;
            }
            first = false;
        }
        return out;
    }
}
