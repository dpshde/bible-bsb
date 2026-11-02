using Toybox.Lang;
using Toybox.Test;

(:test)
function testGenresForOtAndNt(logger as Test.Logger) as Lang.Boolean {
    var ot = Genres.genresForTestament(0);
    var nt = Genres.genresForTestament(1);
    Test.assertEqual(ot.size(), 5);
    Test.assertEqual(nt.size(), 5);
    return true;
}

(:test)
function testGospelsBooksAreMatthewThroughJohn(logger as Test.Logger) as Lang.Boolean {
    // Gospels genre index 5: books 39..42
    var books = Genres.booksForGenre(5);
    Test.assertEqual(books.size(), 4);
    Test.assertEqual(books[0], 39);
    Test.assertEqual(books[3], 42);
    return true;
}

(:test)
function testExtractSectionsFromHeadings(logger as Test.Logger) as Lang.Boolean {
    var verses = [
        { "n" => 1, "h" => "Jesus and Nicodemus", "t" => "Now there was a man..." },
        { "n" => 2, "t" => "He came..." },
        { "n" => 22, "h" => "John's Testimony about Jesus", "t" => "After this..." }
    ];
    var sections = ContentLoader.extractSections(verses);
    Test.assertEqual(sections.size(), 2);
    Test.assertEqual(sections[0][:startVerse], 1);
    Test.assertEqual(ContentLoader.stickySectionTitle(sections, 10), "Jesus and Nicodemus");
    Test.assertEqual(ContentLoader.stickySectionTitle(sections, 22), "John's Testimony about Jesus");
    return true;
}
