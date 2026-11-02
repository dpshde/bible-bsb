using Toybox.Lang;

//! Testament → Genre → book ranges (Flipper bible_books.c @ 51d0ce4).
module Genres {
    const TESTAMENT_COUNT = 2;
    const GENRE_COUNT = 10;

    const TESTAMENT_LABELS = [
        "Old Testament (39)",
        "New Testament (27)"
    ];

    // name, headerName, testament (0=OT/1=NT), startBook, endBook (inclusive)
    const GENRES = [
        { :name => "Law (5)", :header => "< Law >", :testament => 0, :start => 0, :end => 4 },
        { :name => "History (12)", :header => "< OT History >", :testament => 0, :start => 5, :end => 16 },
        { :name => "Poetry (5)", :header => "< Poetry >", :testament => 0, :start => 17, :end => 21 },
        { :name => "Major Prophets (5)", :header => "< Maj Prophets >", :testament => 0, :start => 22, :end => 26 },
        { :name => "Minor Prophets (12)", :header => "< Min Prophets >", :testament => 0, :start => 27, :end => 38 },
        { :name => "Gospels (4)", :header => "< Gospels >", :testament => 1, :start => 39, :end => 42 },
        { :name => "Acts / History (1)", :header => "< Acts >", :testament => 1, :start => 43, :end => 43 },
        { :name => "Paul's Epistles (13)", :header => "< Paul >", :testament => 1, :start => 44, :end => 56 },
        { :name => "Gen. Epistles (8)", :header => "< Gen Epistles >", :testament => 1, :start => 57, :end => 64 },
        { :name => "Prophecy / Rev (1)", :header => "< Prophecy >", :testament => 1, :start => 65, :end => 65 }
    ];

    function genresForTestament(testament as Lang.Number) as Lang.Array {
        var out = [] as Lang.Array;
        var i;
        for (i = 0; i < GENRE_COUNT; i++) {
            var g = GENRES[i];
            if ((g[:testament] as Lang.Number) == testament) {
                out.add(i);
            }
        }
        return out;
    }

    function booksForGenre(genreIdx as Lang.Number) as Lang.Array {
        var out = [] as Lang.Array;
        if (genreIdx < 0 || genreIdx >= GENRE_COUNT) {
            return out;
        }
        var g = GENRES[genreIdx];
        var b;
        for (b = g[:start] as Lang.Number; b <= (g[:end] as Lang.Number); b++) {
            out.add(b);
        }
        return out;
    }

    function genreName(genreIdx as Lang.Number) as Lang.String {
        if (genreIdx < 0 || genreIdx >= GENRE_COUNT) {
            return "?";
        }
        return GENRES[genreIdx][:name] as Lang.String;
    }
}
