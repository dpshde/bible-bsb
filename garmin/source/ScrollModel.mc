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
            if (v == null) {
                return MODE_VERSE; // default matches Flipper primary axis
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

        function next() as Void {
            if (mode == MODE_INCREMENTAL) {
                scrollOffset++;
                clampOffset();
                return;
            }
            verseNext();
        }

        function prev() as Void {
            if (mode == MODE_INCREMENTAL) {
                scrollOffset--;
                clampOffset();
                return;
            }
            versePrev();
        }

        //! Verse mode: snap to verse starts; tall verses step by line inside (SPEC §9).
        function verseNext() as Void {
            // POKE: simplify tall-verse intra-line stepping after trying pure snap-only.
            if (lines.size() == 0) {
                return;
            }
            var cur = lines[scrollOffset < lines.size() ? scrollOffset : lines.size() - 1] as Line;
            var i = scrollOffset + 1;
            // If still inside same verse on non-start lines, step one line.
            if (cur.kind == KIND_VERSE && !atVerseEnd(scrollOffset)) {
                var nextLine = i < lines.size() ? lines[i] as Line : null;
                if (nextLine != null && nextLine.kind == KIND_VERSE && nextLine.verse == cur.verse
                    && nextLine.book == cur.book && nextLine.chapter == cur.chapter) {
                    scrollOffset = i;
                    clampOffset();
                    return;
                }
            }
            // Find next verse start OR divider (divider+v1 treated as one stop: land on divider).
            while (i < lines.size()) {
                var ln = lines[i] as Line;
                if (ln.kind == KIND_DIVIDER) {
                    scrollOffset = i;
                    clampOffset();
                    return;
                }
                if (ln.kind == KIND_VERSE && ln.isVerseStart) {
                    if (cur.kind == KIND_DIVIDER || ln.verse != cur.verse || ln.chapter != cur.chapter || ln.book != cur.book) {
                        scrollOffset = i;
                        clampOffset();
                        return;
                    }
                }
                if (ln.kind == KIND_END) {
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
            // Step back within tall verse first.
            if (cur.kind == KIND_VERSE && !cur.isVerseStart) {
                scrollOffset--;
                return;
            }
            var i = scrollOffset - 1;
            while (i >= 0) {
                var ln = lines[i] as Line;
                if (ln.kind == KIND_DIVIDER) {
                    // Prefer previous verse start before orphaning on divider when going back.
                    var j = i - 1;
                    while (j >= 0) {
                        var p = lines[j] as Line;
                        if (p.kind == KIND_VERSE && p.isVerseStart) {
                            scrollOffset = j;
                            return;
                        }
                        j--;
                    }
                    scrollOffset = i;
                    return;
                }
                if (ln.kind == KIND_VERSE && ln.isVerseStart) {
                    scrollOffset = i;
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
