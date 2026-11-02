using Toybox.Lang;
using Toybox.WatchUi;

//! Loads spike chapter JSON from resources. One chapter at a time (SPEC §6).
module ContentLoader {

    function resourceFor(book as Lang.Number, chapter as Lang.Number) as Lang.Symbol or Null {
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

    //! Naive wrap for spike — returns Array of { :text, :verse, :isStart }.
    //! POKE: measure with device fonts; use Graphics.getTextWidthForNumberOfLines.
    function wrapVerse(verseNum as Lang.Number, text as Lang.String, maxChars as Lang.Number) as Lang.Array {
        var out = [];
        var prefix = verseNum + " ";
        var remaining = text;
        var first = true;
        while (remaining.length() > 0) {
            var budget = maxChars;
            var chunk = "";
            if (first) {
                chunk = prefix;
                budget = maxChars - prefix.length();
                if (budget < 8) {
                    budget = maxChars; // fall back
                    chunk = "";
                }
            }
            if (remaining.length() <= budget) {
                out.add({ :text => chunk + remaining, :verse => verseNum, :isStart => first });
                break;
            }
            var take = budget;
            var space = -1;
            var i;
            for (i = 0; i < budget && i < remaining.length(); i++) {
                if (remaining.substring(i, i + 1).equals(" ")) {
                    space = i;
                }
            }
            if (space > 0) {
                take = space;
            }
            var part = remaining.substring(0, take);
            out.add({ :text => chunk + part, :verse => verseNum, :isStart => first });
            remaining = remaining.substring(take, remaining.length());
            if (remaining.length() > 0 && remaining.substring(0, 1).equals(" ")) {
                remaining = remaining.substring(1, remaining.length());
            }
            first = false;
        }
        return out;
    }
}
