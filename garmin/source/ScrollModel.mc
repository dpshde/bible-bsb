using Toybox.Application;
using Toybox.Lang;

//! Reader scroll: Verse vs Incremental (SPEC §9). Flipper had both axes; Garmin toggles.
module ScrollModel {
    enum {
        MODE_VERSE = 0,
        MODE_INCREMENTAL = 1
    }

    const STORAGE_KEY = "scrollMode";

    //! Line kinds in the flattened reader buffer.
    enum {
        KIND_VERSE = 0,
        KIND_DIVIDER = 1,
        KIND_END = 2,
        KIND_SPACER = 3
    }

    class Line {
        var kind as Lang.Number;
        var book as Lang.Number;
        var chapter as Lang.Number;
        var verse as Lang.Number; // 0 for divider/end
        var text as Lang.String;
        var isVerseStart as Lang.Boolean;
        var pullQuote as Lang.Boolean; // short verse → heavier/larger face
        var verseChars as Lang.Number; // full verse char count (for font pick)

        function initialize(kind as Lang.Number, book as Lang.Number, chapter as Lang.Number,
                            verse as Lang.Number, text as Lang.String, isVerseStart as Lang.Boolean) {
            me.kind = kind;
            me.book = book;
            me.chapter = chapter;
            me.verse = verse;
            me.text = text;
            me.isVerseStart = isVerseStart;
            me.pullQuote = false;
            me.verseChars = 0;
        }
    }

    class State {
        var mode as Lang.Number;
        var lines as Lang.Array; // Array<Line>
        var scrollOffset as Lang.Number;
        var visibleCount as Lang.Number;

        function initialize() {
            me.mode = loadMode();
            me.lines = [];
            me.scrollOffset = 0;
            me.visibleCount = 4;
        }

        function loadMode() as Lang.Number {
            var v = Application.Storage.getValue(STORAGE_KEY);
            if (!(v instanceof Lang.Number) || (v != MODE_VERSE && v != MODE_INCREMENTAL)) {
                return MODE_VERSE; // default (also corrupt / old values)
            }
            return v as Lang.Number;
        }

        function setMode(m as Lang.Number) as Void {
            me.mode = m;
            Application.Storage.setValue(STORAGE_KEY, m);
        }

        function toggleMode() as Lang.Number {
            // POKE: try defaulting new installs to INCREMENTAL after usability on Enduro 3.
            setMode(mode == MODE_VERSE ? MODE_INCREMENTAL : MODE_VERSE);
            return mode;
        }

        function modeLabel() as Lang.String {
            return mode == MODE_VERSE ? "V" : "L";
        }

        function maxScroll() as Lang.Number {
            // Verse mode: focused verse starts at band top — allow last line as
            // offset even when it leaves empty space below (SPEC §9). The old
            // lines-visibleCount clamp blocked boundary snaps and tall-verse
            // steps at end of buffer (tests + Enduro validation).
            if (mode == MODE_VERSE) {
                if (lines.size() == 0) {
                    return 0;
                }
                return lines.size() - 1;
            }
            if (lines.size() <= visibleCount) {
                return 0;
            }
            return lines.size() - visibleCount;
        }

        function clampOffset() as Void {
            var max = maxScroll();
            if (scrollOffset < 0) {
                scrollOffset = 0;
            }
            if (scrollOffset > max) {
                scrollOffset = max;
            }
        }

        //! Focus verse for bookmarking (SPEC §9).
        //! Empty buffer returns book=-1 so callers keep AppState (never invent Genesis).
        function focusVerse() as Lang.Dictionary {
            // POKE: validate "first fully visible content line" vs top-line rule on round insets.
            if (lines.size() == 0) {
                return { :book => -1, :chapter => 1, :verse => 1 };
            }
            var idx = scrollOffset;
            if (idx < 0) {
                idx = 0;
            }
            if (idx >= lines.size()) {
                idx = lines.size() - 1;
            }
            var line = lines[idx] as Line;
            if (line.kind == KIND_DIVIDER || line.kind == KIND_END || line.kind == KIND_SPACER) {
                // Divider/spacer attaches to following verse 1
                var j = idx + 1;
                while (j < lines.size()) {
                    var n = lines[j] as Line;
                    if (n.kind == KIND_VERSE) {
                        return { :book => n.book, :chapter => n.chapter, :verse => n.verse };
                    }
                    j++;
                }
                // Look backward if at trailing spacers
                j = idx - 1;
                while (j >= 0) {
                    var p = lines[j] as Line;
                    if (p.kind == KIND_VERSE) {
                        return { :book => p.book, :chapter => p.chapter, :verse => p.verse };
                    }
                    j--;
                }
                return { :book => line.book, :chapter => line.chapter, :verse => 1 };
            }
            return { :book => line.book, :chapter => line.chapter, :verse => line.verse };
        }

        // POKE: SCROLL_STEP — v3 step sizes.
        //   Verse mode: one press = next / previous verse START (a 5-line verse moves 5 lines).
        //     Only a verse taller than the band pages inside itself (visibleCount - 1 lines).
        //     Chapter boundary = one stop with the divider padded (spacer above it at the top).
        //   Line mode: buttons = 1 line; swipe = page (visibleCount - 1 lines) via page().
        //   Both: the scroll never rests ON a divider (it would butt against the header).
        function next() as Void {
            if (mode == MODE_INCREMENTAL) {
                scrollOffset++;
                clampOffset();
                skipDivider(1);
                return;
            }
            verseNext();
        }

        function prev() as Void {
            if (mode == MODE_INCREMENTAL) {
                scrollOffset--;
                clampOffset();
                skipDivider(-1);
                return;
            }
            versePrev();
        }

        //! Line-mode page step (swipe). Verse mode: same as a verse step.
        function page(dir as Lang.Number) as Void {
            if (mode != MODE_INCREMENTAL) {
                if (dir > 0) {
                    verseNext();
                } else {
                    versePrev();
                }
                return;
            }
            var step = visibleCount > 2 ? visibleCount - 1 : 1;
            scrollOffset += dir * step;
            clampOffset();
            skipDivider(dir);
        }

        //! Divider padding: an offset on a divider moves one line on in the step direction
        //! (down -> spacer under it; up -> spacer above it), so ~1 blank line separates the
        //! divider from the header and from the next text.
        function skipDivider(dir as Lang.Number) as Void {
            if (scrollOffset >= 0 && scrollOffset < lines.size()
                && (lines[scrollOffset] as Line).kind == KIND_DIVIDER) {
                scrollOffset += dir;
                clampOffset();
            }
        }

        //! Boundary stop = the spacer above a divider (or the divider when it has no spacer).
        function boundaryStop(div as Lang.Number) as Lang.Number {
            if (div > 0 && (lines[div - 1] as Line).kind == KIND_SPACER) {
                return div - 1;
            }
            return div;
        }

        function verseStartOf(i as Lang.Number) as Lang.Number {
            var ln = lines[i] as Line;
            while (i > 0) {
                var p = lines[i - 1] as Line;
                if (ln.kind != KIND_VERSE || ln.isVerseStart || p.kind != KIND_VERSE
                    || p.verse != ln.verse || p.chapter != ln.chapter || p.book != ln.book) {
                    break;
                }
                i--;
                ln = p;
            }
            return i;
        }

        function verseEndOf(i as Lang.Number) as Lang.Number {
            while (i + 1 < lines.size() && !atVerseEnd(i)) {
                i++;
            }
            return i;
        }

        function verseNext() as Void {
            if (lines.size() == 0) {
                return;
            }
            var n = lines.size();
            var cur = lines[scrollOffset < n ? scrollOffset : n - 1] as Line;
            if (cur.kind == KIND_VERSE) {
                // Tall verse: page inside it until its tail is on screen.
                var end = verseEndOf(scrollOffset);
                var pageStep = visibleCount > 2 ? visibleCount - 1 : 1;
                if (end - scrollOffset + 1 > visibleCount) {
                    scrollOffset += pageStep;
                    clampOffset();
                    return;
                }
            }
            var i = scrollOffset + 1;
            var atBoundary = cur.kind == KIND_SPACER || cur.kind == KIND_DIVIDER;
            while (i < n) {
                var ln = lines[i] as Line;
                if (ln.kind == KIND_DIVIDER || (ln.kind == KIND_SPACER && i + 1 < n
                        && (lines[i + 1] as Line).kind == KIND_DIVIDER)) {
                    if (!atBoundary) {
                        scrollOffset = boundaryStop(ln.kind == KIND_DIVIDER ? i : i + 1);
                        clampOffset();
                        return;
                    }
                } else if (ln.kind == KIND_VERSE && ln.isVerseStart) {
                    if (atBoundary || ln.verse != cur.verse || ln.chapter != cur.chapter || ln.book != cur.book) {
                        scrollOffset = i;
                        clampOffset();
                        return;
                    }
                } else if (ln.kind == KIND_END) {
                    scrollOffset = i;
                    clampOffset();
                    return;
                }
                i++;
            }
            clampOffset();
        }

        function versePrev() as Void {
            if (lines.size() == 0 || scrollOffset <= 0) {
                scrollOffset = 0;
                return;
            }
            var cur = lines[scrollOffset] as Line;
            if (cur.kind == KIND_VERSE && !cur.isVerseStart) {
                // Mid tall verse: page back, never above its own start.
                var st = verseStartOf(scrollOffset);
                var pageStep = visibleCount > 2 ? visibleCount - 1 : 1;
                scrollOffset = scrollOffset - pageStep > st ? scrollOffset - pageStep : st;
                return;
            }
            var atBoundary = cur.kind == KIND_SPACER || cur.kind == KIND_DIVIDER;
            var i = scrollOffset - 1;
            while (i >= 0) {
                var ln = lines[i] as Line;
                if (ln.kind == KIND_DIVIDER) {
                    if (!atBoundary) {
                        scrollOffset = boundaryStop(i); // v1 -> padded divider stop
                        return;
                    }
                } else if (ln.kind == KIND_VERSE) {
                    scrollOffset = verseStartOf(i);  // previous verse's first line
                    return;
                }
                i--;
            }
            scrollOffset = 0;
        }

        function atVerseEnd(offset as Lang.Number) as Lang.Boolean {
            if (offset + 1 >= lines.size()) {
                return true;
            }
            var cur = lines[offset] as Line;
            var n = lines[offset + 1] as Line;
            if (n.kind != KIND_VERSE) {
                return true;
            }
            return n.verse != cur.verse || n.chapter != cur.chapter || n.book != cur.book;
        }
    }

    //! Pure helpers for unit tests (no Storage).
    function snapToVerseStart(lines as Lang.Array, offset as Lang.Number) as Lang.Number {
        if (lines.size() == 0) {
            return 0;
        }
        if (offset < 0) {
            offset = 0;
        }
        if (offset >= lines.size()) {
            offset = lines.size() - 1;
        }
        var i = offset;
        while (i > 0) {
            var ln = lines[i] as Line;
            if (ln.kind == KIND_VERSE && ln.isVerseStart) {
                return i;
            }
            if (ln.kind == KIND_DIVIDER) {
                return i;
            }
            i--;
        }
        return 0;
    }

    function lineOffsetToFocusVerse(lines as Lang.Array, offset as Lang.Number) as Lang.Dictionary {
        var s = new State();
        s.lines = lines;
        s.scrollOffset = offset;
        return s.focusVerse();
    }
}
