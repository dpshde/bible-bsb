using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;

//! v6 instant open: while the chapter grid rests on a chapter, lay that chapter's reader out
//! off screen (load + wrap the first screenful, heading and line bitmaps) in short Timer
//! slices. Opening it then only blits. One Timer; nothing here repaints.
module ReaderPrep {
    // POKE: PREP_DELAY_MS — grid focus must rest this long before its chapter is prepared
    // (scrolling the grid never pays for a chapter load).
    const PREP_DELAY_MS = 450;
    const PREP_TICK_MS = 50;
    const PREP_BUDGET_MS = 10;

    var _view = null;          // prepared ReaderView
    var _key as Lang.Number = -1;
    var _target as Lang.Number = 0;
    var _bg as Lang.Number = -1;
    var _wantKey as Lang.Number = -1;
    var _timer = null;

    function want(book as Lang.Number, chapter as Lang.Number) as Void {
        var key = book * 1000 + chapter;
        if (key == _wantKey) {
            return;
        }
        _wantKey = key;
        start(PREP_DELAY_MS);
    }

    function start(ms as Lang.Number) as Void {
        if (_timer == null) {
            _timer = new Timer.Timer();
        } else {
            (_timer as Timer.Timer).stop();
        }
        (_timer as Timer.Timer).start(new Lang.Method(ReaderPrep, :onTick), ms, false);
    }

    //! Grid hidden (reader opened, or back to books): stop slicing; keep what is prepared.
    function pause() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
        }
        if (_key != _wantKey) {
            _wantKey = -1; // re-arm: the next want() for this chapter schedules again
        }
    }

    function onTick() as Void {
        var pt0 = Perf.start();
        if (_wantKey < 0) {
            return;
        }
        if (_view == null || _key != _wantKey || _bg != Palette.BG) {
            var book = _wantKey / 1000;
            var chapter = _wantKey % 1000;
            var v = new ReaderView();
            _view = null;
            if (!v.prebuild(book, chapter)) {
                return;
            }
            _view = v;
            _key = _wantKey;
            _target = ReaderView.targetFor(book, chapter);
            _bg = Palette.BG;
            Perf.idle("prep-layout", pt0);
            start(PREP_TICK_MS);
            return;
        }
        var more = (_view as ReaderView).prepStep(PREP_BUDGET_MS);
        Perf.idle("prep-bitmaps", pt0);
        if (more) {
            start(PREP_TICK_MS);
        }
    }

    //! The prepared reader for (book, chapter) if it still matches, else null. One use.
    function take(book as Lang.Number, chapter as Lang.Number, target as Lang.Number) {
        var v = _view;
        var ok = v != null && _key == book * 1000 + chapter && _target == target && _bg == Palette.BG;
        _view = null;
        _key = -1;
        _wantKey = -1;
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
        }
        return ok ? v : null;
    }
}
