using Toybox.Application;
using Toybox.Communications;
import Toybox.Lang;

module BibleApi {
    function buildUrl(bookIndex as Number, chapter as Number) as String {
        var osis = BibleBooks.getOsisCode(bookIndex);
        return "https://bible.helloao.org/api/BSB/" + osis + "/" + chapter + ".json";
    }

    function fetchChapter(
        bookIndex as Number,
        chapter as Number,
        callback as Method(responseCode as Number, data as Dictionary or String or Null) as Void
    ) as Void {
        var url = buildUrl(bookIndex, chapter);
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
        };
        Communications.makeWebRequest(url, null, options, callback);
    }

    function parseResponse(data as Dictionary or String or Null) as Array<Dictionary> {
        if (data == null) {
            return [] as Array<Dictionary>;
        }
        var str = data as String;
        if (str == null || str.length() == 0) {
            return [] as Array<Dictionary>;
        }
        var verses = BibleJsonScanner.parseVerses(str);
        if (verses == null) {
            return [] as Array<Dictionary>;
        }
        return verses;
    }

    function getErrorMessage(responseCode as Number) as String {
        return BibleError.getErrorMessageForCode(responseCode);
    }

    // Offline resource fallback ----------------------------------------------

    function isOfflineAvailable(bookIndex as Number, chapter as Number) as Boolean {
        return BibleResources.hasResource(bookIndex, chapter);
    }

    function loadFromResource(bookIndex as Number, chapter as Number) as Array<Dictionary> {
        var resourceId = BibleResources.getResourceId(bookIndex, chapter);
        if (resourceId == null) {
            return [] as Array<Dictionary>;
        }
        var loaded = Application.loadResource(resourceId);
        if (loaded == null || !(loaded instanceof Dictionary)) {
            return [] as Array<Dictionary>;
        }
        // Connect IQ loads jsonData as a Monkey C Dictionary/Array structure.
        // The compact resource stores {"chapter":{"content":[...]}}.
        // Parse directly from the loaded Object — no O(n²) string conversion.
        return BibleJsonScanner.parseVersesFromObject(loaded as Dictionary);
    }
}

class BibleJsonScanner {
    var json as String;
    var pos as Number;
    var len as Number;

    function initialize(data as String) {
        json = data;
        pos = 0;
        len = data.length();
    }

    static function parseVerses(data as String) as Array<Dictionary> {
        var scanner = new BibleJsonScanner(data);
        return scanner.scanForVerses();
    }

    // Parse verses directly from a loaded resource Object (Dictionary/Array).
    // This eliminates O(n²) string conversion — traverses the Monkey C structure directly.
    static function parseVersesFromObject(loaded as Dictionary) as Array<Dictionary> {
        var verses = [] as Array<Dictionary>;

        var chapter = loaded.get("chapter");
        if (chapter == null || !(chapter instanceof Dictionary)) {
            // Try direct content array at root level
            var rootContent = loaded.get("content");
            if (rootContent != null && rootContent instanceof Array) {
                parseContentArrayFromObject(rootContent as Array, verses);
            }
            return verses;
        }

        var chapterDict = chapter as Dictionary;
        var content = chapterDict.get("content");
        if (content == null || !(content instanceof Array)) {
            return verses;
        }

        parseContentArrayFromObject(content as Array, verses);
        return verses;
    }

    private static function parseContentArrayFromObject(content as Array, verses as Array<Dictionary>) as Void {
        for (var i = 0; i < content.size(); i++) {
            var item = content[i];
            if (item == null || !(item instanceof Dictionary)) {
                continue;
            }
            var obj = item as Dictionary;
            var type = obj.get("type");
            if (type == null || !(type instanceof String) || !((type as String).equals("verse"))) {
                continue;
            }

            var number = obj.get("number");
            var verseNumber = 0;
            if (number != null && number instanceof Number) {
                verseNumber = number as Number;
            }

            var verseContent = obj.get("content");
            var verseText = "";
            if (verseContent != null && verseContent instanceof Array) {
                verseText = extractVerseTextFromArray(verseContent as Array);
            } else if (verseContent != null && verseContent instanceof String) {
                verseText = verseContent as String;
            }

            var verse = {} as Dictionary;
            verse.put("verseNumber", verseNumber);
            verse.put("verseText", verseText);
            verses.add(verse);
        }
    }

    private static function extractVerseTextFromArray(arr as Array) as String {
        var result = "";
        for (var i = 0; i < arr.size(); i++) {
            var item = arr[i];
            if (item == null) {
                continue;
            }
            if (item instanceof String) {
                result = joinVerseText(result, item as String, result.length() == 0);
            } else if (item instanceof Dictionary) {
                var obj = item as Dictionary;
                var text = obj.get("text");
                if (text != null && text instanceof String) {
                    var noteId = obj.get("noteId");
                    var isNoteId = noteId != null;
                    var isHeading = obj.get("heading") != null;
                    var isLineBreak = obj.get("lineBreak") != null;
                    if (!isNoteId && !isHeading && !isLineBreak) {
                        result = joinVerseText(result, text as String, result.length() == 0);
                    }
                }
            }
        }
        return result;
    }

    private static function joinVerseText(current as String, next as String, isFirst as Boolean) as String {
        if (isFirst) {
            return next;
        }
        if (current.length() == 0 || next.length() == 0) {
            return current + next;
        }
        var lastIsSpace = false;
        if (current.length() > 0) {
            var lastChar = current.substring(current.length() - 1, current.length());
            if (lastChar != null) {
                lastIsSpace = (lastChar == " ");
            }
        }
        var firstIsSpace = false;
        if (next.length() > 0) {
            var firstChar = next.substring(0, 1);
            if (firstChar != null) {
                firstIsSpace = (firstChar == " ");
            }
        }
        if (!lastIsSpace && !firstIsSpace) {
            return current + " " + next;
        }
        return current + next;
    }

    public function scanForVerses() as Array<Dictionary> {
        var verses = [] as Array<Dictionary>;

        if (!findKeyAtCurrentLevel("chapter")) {
            pos = 0;
            if (!findKeyAtCurrentLevel("content")) {
                return verses;
            }
        } else {
            skipWhitespace();
            if (!consumeColon()) {
                return verses;
            }
            skipWhitespace();
            if (!consumeBraceOpen()) {
                return verses;
            }
            if (!findKeyAtCurrentLevel("content")) {
                return verses;
            }
        }

        skipWhitespace();
        if (!consumeColon()) {
            return verses;
        }
        skipWhitespace();
        parseContentArray(verses);
        return verses;
    }

    private function parseContentArray(verses as Array<Dictionary>) as Void {
        if (!consumeBracketOpen()) {
            return;
        }
        skipWhitespace();
        while (pos < len && !peekIsBracketClose()) {
            skipWhitespace();
            if (peekIsBraceOpen()) {
                var verse = scanVerseObject();
                if (verse != null) {
                    verses.add(verse);
                }
            } else {
                skipValue();
            }
            skipWhitespace();
            if (peekIsComma()) {
                pos = pos + 1;
            }
        }
        consumeBracketClose();
    }

    private function scanVerseObject() as Dictionary? {
        if (!consumeBraceOpen()) {
            return null;
        }
        skipWhitespace();
        var isVerse = false;
        var verseNumber = 0;
        var verseText = "";
        while (pos < len && !peekIsBraceClose()) {
            skipWhitespace();
            var key = readString();
            skipWhitespace();
            if (!consumeColon()) {
                break;
            }
            skipWhitespace();
            if (key.equals("type")) {
                var typeVal = readString();
                if (typeVal.equals("verse")) {
                    isVerse = true;
                }
            } else if (key.equals("number")) {
                if (peekIsQuote()) {
                    skipValue();
                    verseNumber = 0;
                } else {
                    verseNumber = readNumber();
                }
            } else if (key.equals("content")) {
                if (peekIsBracketOpen()) {
                    verseText = scanVerseContentArray();
                } else {
                    skipValue();
                    verseText = "";
                }
            } else {
                skipValue();
            }
            skipWhitespace();
            if (peekIsComma()) {
                pos = pos + 1;
            }
        }
        consumeBraceClose();
        if (isVerse) {
            return {
                "verseNumber" => verseNumber,
                "verseText" => verseText
            } as Dictionary;
        }
        return null;
    }

    private function scanVerseContentArray() as String {
        if (!consumeBracketOpen()) {
            return "";
        }
        skipWhitespace();
        var text = "";
        var first = true;
        while (pos < len && !peekIsBracketClose()) {
            skipWhitespace();
            if (peekIsQuote()) {
                var s = readString();
                text = appendText(text, s, first);
                first = false;
            } else if (peekIsBraceOpen()) {
                var objText = scanContentObject();
                if (objText != null) {
                    text = appendText(text, objText, first);
                    first = false;
                }
            } else if (peekIsBracketOpen()) {
                skipArray();
            } else {
                skipValue();
            }
            skipWhitespace();
            if (peekIsComma()) {
                pos = pos + 1;
            }
        }
        consumeBracketClose();
        return text;
    }

    private function appendText(current as String, next as String, isFirst as Boolean) as String {
        if (isFirst) {
            return next;
        }
        if (current.length() == 0 || next.length() == 0) {
            return current + next;
        }
        var lastIsSpace = false;
        if (current.length() > 0) {
            var lastChar = current.substring(current.length() - 1, current.length());
            if (lastChar != null) {
                lastIsSpace = (lastChar == " ");
            }
        }
        var firstIsSpace = false;
        if (next.length() > 0) {
            var firstChar = next.substring(0, 1);
            if (firstChar != null) {
                firstIsSpace = (firstChar == " ");
            }
        }
        if (!lastIsSpace && !firstIsSpace) {
            return current + " " + next;
        }
        return current + next;
    }

    private function scanContentObject() as String? {
        if (!consumeBraceOpen()) {
            return null;
        }
        skipWhitespace();
        var text = null as String?;
        var isNoteId = false;
        var isHeading = false;
        var isLineBreak = false;
        while (pos < len && !peekIsBraceClose()) {
            skipWhitespace();
            var key = readString();
            skipWhitespace();
            if (!consumeColon()) {
                break;
            }
            skipWhitespace();
            if (key.equals("text")) {
                text = readString();
            } else if (key.equals("noteId")) {
                isNoteId = true;
                skipValue();
            } else if (key.equals("heading")) {
                isHeading = true;
                skipValue();
            } else if (key.equals("lineBreak")) {
                isLineBreak = true;
                skipValue();
            } else if (key.equals("poem")) {
                skipValue();
            } else if (key.equals("wordsOfJesus")) {
                skipValue();
            } else {
                skipValue();
            }
            skipWhitespace();
            if (peekIsComma()) {
                pos = pos + 1;
            }
        }
        consumeBraceClose();
        if (isNoteId || isHeading || isLineBreak) {
            return null;
        }
        return text;
    }

    private function consumeColon() as Boolean { return consumeChar(58); }
    private function consumeBraceOpen() as Boolean { return consumeChar(123); }
    private function consumeBraceClose() as Boolean { return consumeChar(125); }
    private function consumeBracketOpen() as Boolean { return consumeChar(91); }
    private function consumeBracketClose() as Boolean { return consumeChar(93); }
    private function consumeComma() as Boolean { return consumeChar(44); }
    private function consumeQuote() as Boolean { return consumeChar(34); }

    private function charCodeAt(index as Number) as Number {
        if (index < 0 || index >= len) {
            return -1;
        }
        var ch = json.substring(index, index + 1);
        if (ch == null) {
            return -1;
        }
        var code = ch.toNumber();
        if (code == null) {
            return -1;
        }
        return code;
    }

    private function consumeChar(expectedCode as Number) as Boolean {
        if (pos < len && charCodeAt(pos) == expectedCode) {
            pos = pos + 1;
            return true;
        }
        if (pos < len) {
            pos = pos + 1;
        }
        return false;
    }

    private function peekIsChar(code as Number) as Boolean {
        if (pos >= len) {
            return false;
        }
        return charCodeAt(pos) == code;
    }
    private function peekIsQuote() as Boolean { return peekIsChar(34); }
    private function peekIsBraceOpen() as Boolean { return peekIsChar(123); }
    private function peekIsBraceClose() as Boolean { return peekIsChar(125); }
    private function peekIsBracketOpen() as Boolean { return peekIsChar(91); }
    private function peekIsBracketClose() as Boolean { return peekIsChar(93); }
    private function peekIsComma() as Boolean { return peekIsChar(44); }
    private function peekIsColon() as Boolean { return peekIsChar(58); }

    private function skipWhitespace() as Void {
        while (pos < len) {
            var code = charCodeAt(pos);
            if (code == 32 || code == 10 || code == 13 || code == 9) {
                pos = pos + 1;
            } else {
                break;
            }
        }
    }

    private function readString() as String {
        consumeQuote();
        var result = "";
        while (pos < len) {
            var code = charCodeAt(pos);
            if (code == 34) {
                pos = pos + 1;
                return result;
            } else if (code == 92) {
                pos = pos + 1;
                if (pos < len) {
                    var nextCode = charCodeAt(pos);
                    if (nextCode == 110) {
                        result = result + "\n";
                    } else if (nextCode == 114) {
                        result = result + "\r";
                    } else if (nextCode == 116) {
                        result = result + "\t";
                    } else if (nextCode == 92) {
                        result = result + "\\";
                    } else if (nextCode == 34) {
                        result = result + "\"";
                    } else if (nextCode == 47) {
                        result = result + "/";
                    } else {
                        var next = json.substring(pos, pos + 1);
                        if (next != null) {
                            result = result + next;
                        }
                    }
                    pos = pos + 1;
                }
            } else {
                var c = json.substring(pos, pos + 1);
                if (c != null) {
                    result = result + c;
                }
                pos = pos + 1;
            }
        }
        return result;
    }

    private function isDigit(ch as String) as Boolean {
        if (ch.length() != 1) {
            return false;
        }
        var num = ch.toNumber();
        if (num == null) {
            return false;
        }
        return num >= 48 && num <= 57;
    }

    private function readNumber() as Number {
        var negative = false;
        if (peekIsChar(45)) {
            negative = true;
            pos = pos + 1;
        }
        var value = 0;
        var hasDigits = false;
        while (pos < len) {
            var c = json.substring(pos, pos + 1);
            if (c != null && isDigit(c)) {
                var num = c.toNumber();
                if (num != null) {
                    value = value * 10 + num;
                    hasDigits = true;
                    pos = pos + 1;
                } else {
                    break;
                }
            } else {
                break;
            }
        }
        if (!hasDigits) {
            return 0;
        }
        return negative ? -value : value;
    }

    private function skipObjectRemainder() as Void {
        var depth = 1;
        while (pos < len && depth > 0) {
            var code = charCodeAt(pos);
            if (code == 34) {
                readString();
            } else if (code == 123) {
                depth = depth + 1;
                pos = pos + 1;
            } else if (code == 125) {
                depth = depth - 1;
                pos = pos + 1;
                if (depth == 0) {
                    break;
                }
            } else {
                pos = pos + 1;
            }
        }
    }

    private function skipObject() as Void {
        skipWhitespace();
        if (peekIsBraceOpen()) {
            pos = pos + 1;
            skipObjectRemainder();
        }
    }

    private function skipArray() as Void {
        skipWhitespace();
        if (peekIsBracketOpen()) {
            pos = pos + 1;
            var depth = 1;
            while (pos < len && depth > 0) {
                var code = charCodeAt(pos);
                if (code == 34) {
                    readString();
                } else if (code == 91) {
                    depth = depth + 1;
                    pos = pos + 1;
                } else if (code == 93) {
                    depth = depth - 1;
                    pos = pos + 1;
                    if (depth == 0) {
                        break;
                    }
                } else {
                    pos = pos + 1;
                }
            }
        }
    }

    private function skipValue() as Void {
        skipWhitespace();
        if (pos >= len) {
            return;
        }
        var code = charCodeAt(pos);
        if (code == 34) {
            readString();
        } else if (code == 123) {
            skipObject();
        } else if (code == 91) {
            skipArray();
        } else if (code == 116 || code == 102 || code == 110) {
            skipLiteral();
        } else {
            while (pos < len) {
                var ch = json.substring(pos, pos + 1);
                if (ch == null) {
                    break;
                }
                var chCode = ch.toNumber();
                if (chCode == null) {
                    break;
                }
                if ((chCode >= 48 && chCode <= 57) || chCode == 45 || chCode == 46 || chCode == 101 || chCode == 69 || chCode == 43) {
                    pos = pos + 1;
                } else {
                    break;
                }
            }
        }
    }

    private function skipLiteral() as Void {
        if (pos + 4 <= len) {
            var s = json.substring(pos, pos + 4);
            if (s != null && s.equals("true")) {
                pos = pos + 4;
                return;
            }
        }
        if (pos + 5 <= len) {
            var s = json.substring(pos, pos + 5);
            if (s != null && s.equals("false")) {
                pos = pos + 5;
                return;
            }
        }
        if (pos + 4 <= len) {
            var s = json.substring(pos, pos + 4);
            if (s != null && s.equals("null")) {
                pos = pos + 4;
                return;
            }
        }
        pos = pos + 1;
    }

    private function findKeyAtCurrentLevel(targetKey as String) as Boolean {
        while (pos < len) {
            skipWhitespace();
            if (peekIsBraceClose()) {
                return false;
            }
            if (peekIsQuote()) {
                var key = readString();
                skipWhitespace();
                if (peekIsColon()) {
                    pos = pos + 1;
                }
                if (key.equals(targetKey)) {
                    return true;
                }
                skipValue();
                skipWhitespace();
                if (peekIsComma()) {
                    pos = pos + 1;
                }
            } else {
                pos = pos + 1;
            }
        }
        return false;
    }
}
