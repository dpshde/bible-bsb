using Toybox.Application;
using Toybox.Lang;
using Toybox.Timer;

//! Last-read position persisted across relaunch (Storage "last" = [book, chapter, verse];
//! "lastRef" = "John 3:16", "lastText" = first ~160 chars, read by the glance).
//! Written on reader hide and app stop only (not per scroll step) to spare flash.
(:glance)
module LastRead {
    const KEY = "last";
    const KEY_REF = "lastRef";
    const KEY_TEXT = "lastText";

    function ref() as Lang.String or Null {
        var r = Application.Storage.getValue(KEY_REF);
        return r instanceof Lang.String ? r as Lang.String : null;
    }

    function text() as Lang.String or Null {
        var t = Application.Storage.getValue(KEY_TEXT);
        return t instanceof Lang.String ? t as Lang.String : null;
    }
}

module LastReadApp {
    var pending as Lang.Array or Null = null; // [b, c, v] in memory, flushed on hide/stop
    var resumeVerse as Lang.Number = 0;

    var _timer as Timer.Timer or Null = null;
    // POKE: LASTREAD_DEBOUNCE_MS — flush ~3 s after reading stops (survives a hard kill).
    const DEBOUNCE_MS = 3000;

    function note(book as Lang.Number, chapter as Lang.Number, verse as Lang.Number) as Void {
        var p = pending;
        if (p != null && p[0] == book && p[1] == chapter && p[2] == verse) {
            return;
        }
        pending = [book, chapter, verse];
        // PERF: one Timer object reused (stop + restart), no allocation per verse step.
        if (_timer == null) {
            _timer = new Timer.Timer();
        } else {
            (_timer as Timer.Timer).stop();
        }
        (_timer as Timer.Timer).start(new Lang.Method(LastReadApp, :onDebounce), DEBOUNCE_MS, false);
    }

    function onDebounce() as Void {
        flush();
    }

    //! Chapter to open a book at: last-read chapter if this is the last-read book, else 1.
    //! Stored [book, chapter, verse] if well formed and in range, else null (corrupt / old data).
    function stored() as Lang.Array or Null {
        var p = Application.Storage.getValue(LastRead.KEY);
        if (!(p instanceof Lang.Array) || (p as Lang.Array).size() != 3) {
            return null;
        }
        var a = p as Lang.Array;
        var b = a[0];
        var c = a[1];
        var v = a[2];
        if (!(b instanceof Lang.Number) || !(c instanceof Lang.Number) || !(v instanceof Lang.Number)) {
            return null;
        }
        if (b < 0 || b >= Books.BOOK_COUNT || c < 1 || c > Books.chapterCount(b) || v < 1 || v > 200) {
            return null;
        }
        return a;
    }

    function chapterFor(book as Lang.Number) as Lang.Number {
        var p = stored();
        if (p != null && (p as Lang.Array)[0] == book) {
            return (p as Lang.Array)[1] as Lang.Number;
        }
        return 1;
    }

    function flush() as Void {
        var p = pending;
        if (p == null) {
            return;
        }
        var b = p[0] as Lang.Number;
        var c = p[1] as Lang.Number;
        var v = p[2] as Lang.Number;
        Application.Storage.setValue(LastRead.KEY, p);
        Application.Storage.setValue(LastRead.KEY_REF, Books.name(b) + " " + c + ":" + v); // glance: full name, no OSIS code
        var t = ContentLoader.verseText(b, c, v);
        if (t != null) {
            var s = ContentLoader.plainVerseText(t as Lang.String);
            if (s.length() > 160) { // glance wraps at words and ellipsizes only what cannot fit
                s = s.substring(0, 160);
            }
            Application.Storage.setValue(LastRead.KEY_TEXT, s);
        }
    }

    //! On start: restore book/chapter and the verse to resume at.
    function restore() as Void {
        var p = stored();
        if (p != null) {
            var a = p as Lang.Array;
            AppState.selectedBook = a[0] as Lang.Number;
            AppState.selectedChapter = a[1] as Lang.Number;
            resumeVerse = a[2] as Lang.Number;
            pending = a;
        }
    }
}
