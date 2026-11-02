using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

//! Loads spike chapter JSON from resources. One chapter at a time (SPEC §6).
//! Wrapping is word-based (one getTextWidthInPixels per word, not per char) so a
//! full chapter stays under the stock 240k CIQ watchdog. See WRAP_COST_NOTE.
module ContentLoader {

    //! Measured intent: word-split wrap of John 3 (36 verses) on Enduro 3 must
    //! stay under the stock 240k instruction watchdog when only the focused
    //! chapter is wrapped eagerly and the next chapter is deferred via Timer.
    //! Char-by-char getTextWidthInPixels was ~10s / crash at a20df65+; this path
    //! targets reader open <300ms equivalent with no watchdog raise.
    const WRAP_COST_NOTE = "word-measure wrap; eager=focus chapter only; defer continuation";

    // Word-width memo keyed by "faceKey:word" (custom fonts aren't Lang.Number).
    var _wordCache as Lang.Dictionary = {};

    function resourceFor(book as Lang.Number, chapter as Lang.Number) as Lang.ResourceId or Null {
        // Full BSB bundled offline (1189 chapters, resources/bsb, generated BsbIndex).
        return BsbIndex.rez(book, chapter);
    }

    function hasChapter(book as Lang.Number, chapter as Lang.Number) as Lang.Boolean {
        return resourceFor(book, chapter) != null;
    }

    //! Returns { :book, :chapter, :verses, :sections } or null.
    //! sections = [ { :startVerse, :title }, ... ] from verse "h" fields (BSB USJ).
    // PERF: 2-slot chapter cache (primary + continuation). loadResource + JSON decode is the
    // single most expensive call on device; never repeat it for a chapter already in memory.
    var _ck0 as Lang.Number = -1;
    var _cd0 as Lang.Dictionary or Null = null;
    var _ck1 as Lang.Number = -1;
    var _cd1 as Lang.Dictionary or Null = null;

    function loadChapter(book as Lang.Number, chapter as Lang.Number) as Lang.Dictionary or Null {
        var key = book * 1000 + chapter;
        if (key == _ck0) {
            return _cd0;
        }
        if (key == _ck1) {
            var d = _cd1;
            _ck1 = _ck0;
            _cd1 = _cd0;
            _ck0 = key;
            _cd0 = d;
            return d;
        }
        var res = loadChapterUncached(book, chapter);
        _ck1 = _ck0;
        _cd1 = _cd0;
        _ck0 = key;
        _cd0 = res;
        return res;
    }

    function loadChapterUncached(book as Lang.Number, chapter as Lang.Number) as Lang.Dictionary or Null {
        var rez = resourceFor(book, chapter);
        if (rez == null) {
            return null;
        }
        Perf.loads++;
        var data = WatchUi.loadResource(rez);
        if (data == null || !(data instanceof Lang.Dictionary)) {
            return null;
        }
        var verses = data["verses"];
        if (verses == null) {
            verses = data[:verses];
        }
        var sections = [] as Lang.Array;
        if (verses != null) {
            sections = extractSections(verses as Lang.Array);
        }
        return {
            :book => book,
            :chapter => chapter,
            :verses => verses,
            :sections => sections
        };
    }

    //! Build sticky-header table from optional verse["h"] / [:h] fields.
    function extractSections(verses as Lang.Array) as Lang.Array {
        var out = [] as Lang.Array;
        var i;
        for (i = 0; i < verses.size(); i++) {
            var v = verses[i];
            var h = v["h"];
            if (h == null) {
                h = v[:h];
            }
            if (h == null) {
                continue;
            }
            var title = h as Lang.String;
            if (title.length() == 0) {
                continue;
            }
            var n = v["n"];
            if (n == null) {
                n = v[:n];
            }
            out.add({ :startVerse => n as Lang.Number, :title => title });
        }
        return out;
    }

    //! Active section title for verse, or null.
    function stickySectionTitle(sections as Lang.Array, verse as Lang.Number) as Lang.String or Null {
        var active = null;
        var i;
        for (i = 0; i < sections.size(); i++) {
            var sec = sections[i];
            var start = sec[:startVerse] as Lang.Number;
            if (start <= verse) {
                active = sec[:title] as Lang.String;
            }
        }
        return active;
    }

    function verseCount(book as Lang.Number, chapter as Lang.Number) as Lang.Number {
        var data = loadChapter(book, chapter);
        if (data == null) {
            return 0;
        }
        var verses = data[:verses];
        if (verses == null) {
            return 0;
        }
        return (verses as Lang.Array).size();
    }

    function verseText(book as Lang.Number, chapter as Lang.Number, verse as Lang.Number) as Lang.String or Null {
        var data = loadChapter(book, chapter);
        if (data == null) {
            return null;
        }
        var verses = data[:verses] as Lang.Array;
        // PERF: verses are stored 1..N in order — try the direct slot first.
        if (verse >= 1 && verse <= verses.size()) {
            var dv = verses[verse - 1];
            var dn = dv["n"];
            if (dn == verse) {
                return dv["t"] as Lang.String;
            }
        }
        var i;
        for (i = 0; i < verses.size(); i++) {
            var v = verses[i];
            var n = v["n"];
            if (n == null) {
                n = v[:n];
            }
            if (n == verse) {
                var t = v["t"];
                if (t == null) {
                    t = v[:t];
                }
                return t as Lang.String;
            }
        }
        return null;
    }

    function clearWordCache() as Void {
        _wordCache = {};
    }

    function wordWidth(dc as Graphics.Dc, font as Graphics.FontDefinition, word as Lang.String) as Lang.Number {
        return wordWidthKeyed(dc, font, word, 0);
    }

    function wordWidthKeyed(dc as Graphics.Dc, font as Graphics.FontDefinition, word as Lang.String,
                            faceKey as Lang.Number) as Lang.Number {
        var key = faceKey + ":" + word;
        var hit = _wordCache[key];
        if (hit != null) {
            return hit as Lang.Number;
        }
        Perf.measures++;
        var w = dc.getTextWidthInPixels(word, font);
        _wordCache[key] = w;
        return w;
    }

    //! Spike BSB JSON is plain `{n,t}` only — no USFM \wj / red-letter spans.
    //! POKE: WORDS_OF_JESUS — when pack carries markup, return true and split runs.
    function hasJesusMarkup(text as Lang.String) as Lang.Boolean {
        if (text.find("\\wj") != null) {
            return true;
        }
        if (text.find("<wj>") != null) {
            return true;
        }
        return false;
    }

    //! Returns plain text with any future \wj tags stripped (identity today).
    function plainVerseText(text as Lang.String) as Lang.String {
        // No markup in bundled spike chapters — return as-is.
        return text;
    }

    //! Split on spaces into words (O(n) single pass, no per-char Dc calls).
    function splitWords(text as Lang.String) as Lang.Array {
        var out = [] as Lang.Array;
        var chars = text.toCharArray();
        var n = chars.size();
        var start = 0;
        var i = 0;
        while (i < n) {
            if (chars[i] == ' ') {
                if (i > start) {
                    out.add(text.substring(start, i));
                }
                i++;
                start = i;
            } else {
                i++;
            }
        }
        if (start < n) {
            out.add(text.substring(start, n));
        }
        return out;
    }

    //! Char-budget wrap (unit tests / no-Dc fallback). Word-based, O(words).
    function wrapVerse(verseNum as Lang.Number, text as Lang.String, maxChars as Lang.Number) as Lang.Array {
        var out = [];
        var prefix = verseNum + " ";
        var words = splitWords(text);
        var line = prefix;
        var wi;
        for (wi = 0; wi < words.size(); wi++) {
            var word = words[wi] as Lang.String;
            var candidate;
            if (line.equals(prefix)) {
                candidate = prefix + word;
            } else if (line.length() == 0) {
                candidate = word;
            } else {
                candidate = line + " " + word;
            }
            if (candidate.length() <= maxChars) {
                line = candidate;
            } else {
                if (line.length() > 0) {
                    out.add({ :text => line, :verse => verseNum, :isStart => out.size() == 0 });
                }
                line = word;
            }
        }
        if (line.length() > 0) {
            out.add({ :text => line, :verse => verseNum, :isStart => out.size() == 0 });
        }
        return out;
    }

    //! Pixel wrap — word-based. Returns { :text, :verse, :isStart, :prefixVerse }.
    //! Text does NOT include the leading "N "; caller draws gold number when isStart.
    //! One getTextWidthInPixels per distinct word (cached), never per character.
    function wrapVerseToWidth(dc as Graphics.Dc, font as Graphics.FontDefinition, verseNum as Lang.Number,
                              text as Lang.String, maxWidth as Lang.Number) as Lang.Array {
        return wrapVerseToWidthKeyed(dc, font, verseNum, text, maxWidth, 0);
    }

    function wrapVerseToWidthKeyed(dc as Graphics.Dc, font as Graphics.FontDefinition, verseNum as Lang.Number,
                                   text as Lang.String, maxWidth as Lang.Number,
                                   faceKey as Lang.Number) as Lang.Array {
        var out = [];
        var plain = plainVerseText(text);
        var numStr = verseNum.toString();
        // Number width uses num face at paint; reserve approx via body font digits.
        var numW = wordWidthKeyed(dc, font, numStr, faceKey) + wordWidthKeyed(dc, font, " ", faceKey);
        var spaceW = wordWidthKeyed(dc, font, " ", faceKey);
        var words = splitWords(plain);
        var line = "";
        var lineW = 0;
        var isFirstLine = true;
        var wi;
        for (wi = 0; wi < words.size(); wi++) {
            var word = words[wi] as Lang.String;
            var wordW = wordWidthKeyed(dc, font, word, faceKey);
            var budget = maxWidth;
            if (isFirstLine) {
                budget = maxWidth - numW;
                if (budget < 12) {
                    budget = maxWidth;
                }
            }
            var needSpace = line.length() > 0;
            var addW = wordW + (needSpace ? spaceW : 0);
            if (lineW + addW <= budget) {
                if (needSpace) {
                    line = line + " " + word;
                } else {
                    line = word;
                }
                lineW += addW;
            } else {
                if (line.length() > 0) {
                    out.add({
                        :text => line,
                        :verse => verseNum,
                        :isStart => out.size() == 0,
                        :prefixVerse => (out.size() == 0 ? verseNum : 0)
                    });
                }
                isFirstLine = false;
                line = word;
                lineW = wordW;
            }
        }
        if (line.length() > 0 || out.size() == 0) {
            out.add({
                :text => line,
                :verse => verseNum,
                :isStart => out.size() == 0,
                :prefixVerse => (out.size() == 0 ? verseNum : 0)
            });
        }
        return out;
    }

    //! Estimate wrapped line count without a Dc (char-budget). Used by cost tests.
    function estimateWrapLineCount(text as Lang.String, maxChars as Lang.Number) as Lang.Number {
        var words = splitWords(text);
        if (words.size() == 0) {
            return 1;
        }
        var lines = 1;
        var used = 0;
        var wi;
        for (wi = 0; wi < words.size(); wi++) {
            var wlen = (words[wi] as Lang.String).length();
            var add = (used == 0) ? wlen : (1 + wlen);
            if (used > 0 && used + add > maxChars) {
                lines++;
                used = wlen;
            } else {
                used += add;
            }
        }
        return lines;
    }
}
