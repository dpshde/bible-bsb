using Toybox.Lang;

//! Shared navigation state for the thin slice.
module AppState {
    var selectedBook as Lang.Number = 42; // John
    var selectedChapter as Lang.Number = 3;
    var scroll as ScrollModel.State = new ScrollModel.State();
    //! Section headings for the opened chapter: [ { :startVerse, :title }, ... ]
    var sections as Lang.Array = [];

    //! Ring buffer of loaded chapter dicts — POKE: enforce max 3 and heap budgets per device.
    var chapterCache as Lang.Dictionary = {};

    function cacheKey(book as Lang.Number, chapter as Lang.Number) as Lang.String {
        return book + ":" + chapter;
    }
}
