using Toybox.Lang;

//! Horizontal SNAKE chapter/book grid math (SPEC §3).
//! Linear index i = chapter-1 walks left→right across a row, then next row.
module SnakeGrid {

    class Model {
        var itemCount as Lang.Number;
        var columns as Lang.Number;
        var visibleRows as Lang.Number;
        var focusIndex as Lang.Number; // 0 .. itemCount-1
        var startRow as Lang.Number;
        var wrap as Lang.Boolean;

        function initialize(itemCount as Lang.Number, columns as Lang.Number, visibleRows as Lang.Number) {
            me.itemCount = itemCount;
            me.columns = columns;
            me.visibleRows = visibleRows;
            me.focusIndex = 0;
            me.startRow = 0;
            // POKE: try wrap=false (clamp at ends) vs Flipper book-list wrap — Dylan's call.
            me.wrap = true;
        }

        function totalRows() as Lang.Number {
            if (itemCount <= 0 || columns <= 0) {
                return 0;
            }
            return (itemCount + columns - 1) / columns;
        }

        function rowOf(index as Lang.Number) as Lang.Number {
            return index / columns;
        }

        function colOf(index as Lang.Number) as Lang.Number {
            return index % columns;
        }

        function indexAt(row as Lang.Number, col as Lang.Number) as Lang.Number {
            return row * columns + col;
        }

        //! Chapter number is 1-based: chapter = focusIndex + 1
        function focusedChapter() as Lang.Number {
            return focusIndex + 1;
        }

        function setFocusIndex(index as Lang.Number) as Void {
            if (itemCount <= 0) {
                focusIndex = 0;
                startRow = 0;
                return;
            }
            if (index < 0) {
                index = wrap ? (itemCount - 1) : 0;
            } else if (index >= itemCount) {
                index = wrap ? 0 : (itemCount - 1);
            }
            focusIndex = index;
            ensureFocusVisible();
        }

        function moveBy(delta as Lang.Number) as Void {
            setFocusIndex(focusIndex + delta);
        }

        //! Snake primary: ±1 linear.
        function next() as Void {
            moveBy(1);
        }

        function prev() as Void {
            moveBy(-1);
        }

        //! Accelerator: skip a full row (±columns). Flipper Up/Down parity.
        function nextRow() as Void {
            moveBy(columns);
        }

        function prevRow() as Void {
            moveBy(-columns);
        }

        function ensureFocusVisible() as Void {
            var row = rowOf(focusIndex);
            var tr = totalRows();
            var vr = visibleRows;
            if (vr < 1) {
                vr = 1;
            }
            if (row < startRow) {
                startRow = row;
            } else if (row >= startRow + vr) {
                startRow = row - vr + 1;
            }
            var maxStart = tr > vr ? (tr - vr) : 0;
            if (startRow < 0) {
                startRow = 0;
            }
            if (startRow > maxStart) {
                startRow = maxStart;
            }
        }
    }

    function columnsForDisplayWidth(width as Lang.Number) as Lang.Number {
        // POKE: tune per display class after Enduro 3 / FR265 / Venu Sq screenshots.
        if (width >= 390) {
            return 6;
        }
        return 5;
    }

    function visibleRowsForHeight(height as Lang.Number) as Lang.Number {
        if (height >= 400) {
            return 6;
        }
        if (height >= 280) {
            return 5;
        }
        return 4;
    }
}
