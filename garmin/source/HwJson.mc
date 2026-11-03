using Toybox.Lang;
using Toybox.StringUtil;

//! Minimal JSON for Hidden Word records (decrypted plaintext is a string; Toybox only parses JSON
//! that arrives as a web response). Objects keep their key order in a parallel `keys` list so a
//! record written back keeps its fields (SPEC §1: apps keep fields they don't understand).
module HwJson {
    var _s as Lang.Array<Lang.Char> = [];
    var _i as Lang.Number = 0;

    //! Parse: objects -> HwObj, arrays -> Array, numbers -> Number/Long/Double. null on bad input.
    function parse(text as Lang.String) {
        _s = text.toCharArray();
        _i = 0;
        try {
            var v = value();
            ws();
            return _i == _s.size() ? v : null;
        } catch (e) {
            return null;
        }
    }

    //! Current char; running off the end is a parse error (caught in parse), not a crash.
    function pk() as Lang.Char {
        if (_i >= _s.size()) { throw new Lang.InvalidValueException("eof"); }
        return _s[_i];
    }

    function ws() as Void {
        while (_i < _s.size()) {
            var c = _s[_i];
            if (c == ' ' || c == '\n' || c == '\r' || c == '\t') { _i++; } else { break; }
        }
    }

    function value() {
        ws();
        var c = pk();
        if (c == '{') {
            _i++;
            var o = new HwObj();
            ws();
            if (pk() == '}') { _i++; return o; }
            while (true) {
                ws();
                var k = str();
                ws();
                if (pk() != ':') { throw new Lang.InvalidValueException("colon"); }
                _i++;
                o.put(k, value());
                ws();
                if (pk() == ',') { _i++; continue; }
                if (pk() == '}') { _i++; return o; }
                throw new Lang.InvalidValueException("object");
            }
        }
        if (c == '[') {
            _i++;
            var a = [];
            ws();
            if (pk() == ']') { _i++; return a; }
            while (true) {
                a.add(value());
                ws();
                if (pk() == ',') { _i++; continue; }
                if (pk() == ']') { _i++; return a; }
                throw new Lang.InvalidValueException("array");
            }
        }
        if (c == '"') { return str(); }
        if (c == 't') { _i += 4; return true; }
        if (c == 'f') { _i += 5; return false; }
        if (c == 'n') { _i += 4; return null; }
        var st = _i;
        var frac = false;
        while (_i < _s.size()) {
            var d = _s[_i];
            if ((d >= '0' && d <= '9') || d == '-' || d == '+') { _i++; }
            else if (d == '.' || d == 'e' || d == 'E') { frac = true; _i++; }
            else { break; }
        }
        if (_i == st) { throw new Lang.InvalidValueException("value"); }
        var t = StringUtil.charArrayToString(_s.slice(st, _i));
        return frac ? t.toDouble() : t.toLong();
    }

    function str() as Lang.String {
        if (pk() != '"') { throw new Lang.InvalidValueException("string"); }
        _i++;
        var out = [];
        while (true) {
            var c = pk();
            _i++;
            if (c == '"') { break; }
            if (c == '\\') {
                var e = pk();
                _i++;
                if (e == 'n') { c = '\n'; }
                else if (e == 't') { c = '\t'; }
                else if (e == 'r') { c = '\r'; }
                else if (e == 'b') { c = (8).toChar(); }
                else if (e == 'f') { c = (12).toChar(); }
                else if (e == 'u') {
                    if (_i + 4 > _s.size()) { throw new Lang.InvalidValueException("eof"); }
                    var h = StringUtil.charArrayToString(_s.slice(_i, _i + 4));
                    _i += 4;
                    c = (h.toNumberWithBase(16) as Lang.Number).toChar();
                } else { c = e; }
            }
            out.add(c);
        }
        return StringUtil.charArrayToString(out);
    }

    //! Serialize like JSON.stringify (no spaces).
    function stringify(v) as Lang.String {
        if (v == null) { return "null"; }
        if (v instanceof HwObj) {
            var o = v as HwObj;
            var s = "{";
            for (var i = 0; i < o.keys.size(); i++) {
                if (i > 0) { s += ","; }
                s += quote(o.keys[i] as Lang.String) + ":" + stringify(o.vals[i]);
            }
            return s + "}";
        }
        if (v instanceof Lang.Array) {
            var s = "[";
            for (var i = 0; i < v.size(); i++) {
                if (i > 0) { s += ","; }
                s += stringify(v[i]);
            }
            return s + "]";
        }
        if (v instanceof Lang.String) { return quote(v); }
        if (v instanceof Lang.Boolean) { return v ? "true" : "false"; }
        return v.toString();
    }

    function quote(s as Lang.String) as Lang.String {
        var cs = s.toCharArray();
        var out = "\"";
        for (var i = 0; i < cs.size(); i++) {
            var c = cs[i];
            var n = c.toNumber();
            if (c == '"') { out += "\\\""; }
            else if (c == '\\') { out += "\\\\"; }
            else if (c == '\n') { out += "\\n"; }
            else if (c == '\r') { out += "\\r"; }
            else if (c == '\t') { out += "\\t"; }
            else if (n < 0x20) { out += "\\u" + n.format("%04x"); }
            else { out += c.toString(); }
        }
        return out + "\"";
    }
}

//! An ordered JSON object.
class HwObj {
    var keys as Lang.Array = [];
    var vals as Lang.Array = [];

    function initialize() {}

    function get(k as Lang.String) {
        var i = keys.indexOf(k);
        return i < 0 ? null : vals[i];
    }

    function put(k as Lang.String, v) as HwObj {
        var i = keys.indexOf(k);
        if (i < 0) { keys.add(k); vals.add(v); } else { vals[i] = v; }
        return me;
    }

    function remove(k as Lang.String) as Void {
        var i = keys.indexOf(k);
        if (i >= 0) { keys = keys.slice(0, i).addAll(keys.slice(i + 1, null)); vals = vals.slice(0, i).addAll(vals.slice(i + 1, null)); }
    }
}
