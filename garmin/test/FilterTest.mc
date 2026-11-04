using Toybox.Lang;
using Toybox.Test;

//! Flipper get_filtered_books() parity: 22 labels; "J" = books starting with J;
//! "1"/"2"/"3" each = every numbered book (Flipper's digit rule), not only that digit.
(:test)
function testFilterLabelsMatchFlipper(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(PickList.FILTER_LABELS.size(), 22);
    Test.assertEqual(PickList.booksForFilter(0).size(), 66);
    return true;
}

(:test)
function testFilterNumericMatchesAllNumbered(logger as Test.Logger) as Lang.Boolean {
    var one = PickList.booksForFilter(19);
    var three = PickList.booksForFilter(21);
    Test.assertEqual(one.size(), three.size());
    var i;
    for (i = 0; i < one.size(); i++) {
        var c = Books.name(one[i] as Lang.Number).substring(0, 1);
        Test.assert(c.equals("1") || c.equals("2") || c.equals("3"));
    }
    Test.assertEqual(one.size(), 17); // 7 numbered pairs + 1-3 John
    return true;
}
