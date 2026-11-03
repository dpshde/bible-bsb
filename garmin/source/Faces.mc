using Toybox.Graphics;
using Toybox.Lang;

//! v7/v8 (Dylan): headings and verse text in different weights. v8 inverts the reader:
//! verse text heavy, section headings + reference line light (light()), chapter divider heavy.
//! v7 notes, built-in watch faces only.
//! Enduro 3's system fonts are all RobotoCondensed-Bold, so there the verse body moves to the
//! watch's own RobotoCondensed-Regular (vector face) and headings keep the bold system font.
//! Watches whose system fonts are regular keep the body and get headings in the watch's
//! RobotoCondensed-Bold; watches with neither face (Venu 3, vivoactive 5, Venu Sq 2) get
//! headings over-struck by 1 px. Focus never changes weight: the body face is the same for
//! focused and dimmed verses.
module Faces {
    var _body = null;
    var _bodyDone as Lang.Boolean = false;
    var _head as Lang.Dictionary = {}; // FontDefinition -> VectorFont, or false (none)

    //! Face for verse text (both focused and dimmed lines).
    function body() as Graphics.FontType {
        if (!_bodyDone) {
            _bodyDone = true;
            // v8 (Dylan): verse text is the heavy face. Enduro 3: the bold system font itself;
            // regular-font watches: the watch's RobotoCondensed-Bold when it has one.
            _body = SysWeight.BOLD ? null : vectorLike(["RobotoCondensedBold", "RobotoBold"], Graphics.FONT_XTINY);
        }
        return _body != null ? _body as Graphics.VectorFont : Graphics.FONT_XTINY;
    }

    var _light as Lang.Dictionary = {}; // FontDefinition -> VectorFont, or false (none)

    //! v8: reader section headings and the GEN x:y reference line, in the light (regular) face.
    //! Enduro 3: the watch's RobotoCondensed-Regular; regular-font watches: the system font.
    function light(base as Graphics.FontDefinition) as Graphics.FontType {
        if (!SysWeight.BOLD) {
            return base;
        }
        var v = _light[base];
        if (v == null) {
            var vf = vectorLike(["RobotoCondensedRegular", "RobotoRegular"], base);
            v = vf != null ? vf : false;
            _light[base] = v;
        }
        return (v instanceof Lang.Boolean) ? base : v as Graphics.VectorFont;
    }

    //! Heavy face for a title / landmark (list, grid, menu titles; reader chapter divider).
    function head(base as Graphics.FontDefinition) as Graphics.FontType {
        if (SysWeight.BOLD) {
            return base;
        }
        var v = _head[base];
        if (v == null) {
            var vf = vectorLike(["RobotoCondensedBold", "RobotoBold"], base);
            v = vf != null ? vf : false;
            _head[base] = v;
        }
        return (v == null || v instanceof Lang.Boolean) ? base : v as Graphics.VectorFont;
    }

    //! Draw a heading in the heavier face (1 px over-strike where the watch has no bold face).
    function drawHead(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, base as Graphics.FontDefinition,
                      text as Lang.String, just as Lang.Number) as Void {
        var f = head(base);
        dc.drawText(x, y, f, text, just);
        if (!SysWeight.BOLD && f == base) {
            dc.drawText(x + 1, y, f, text, just);
        }
    }

    //! A built-in vector face sized so its line height matches the system font `base`.
    function vectorLike(faces as Lang.Array<Lang.String>, base as Graphics.FontDefinition) as Graphics.VectorFont or Null {
        if (!(Graphics has :getVectorFont)) {
            return null;
        }
        var mdc = MeasureDc.get();
        if (mdc == null) {
            return null;
        }
        var target = (mdc as Graphics.Dc).getFontHeight(base);
        var vf = Graphics.getVectorFont({:face => faces, :size => target});
        if (vf == null) {
            return null;
        }
        var got = (mdc as Graphics.Dc).getFontHeight(vf);
        if (got > 0 && got != target) {
            var vf2 = Graphics.getVectorFont({:face => faces, :size => (target * target + got / 2) / got});
            if (vf2 != null) {
                vf = vf2;
            }
        }
        return vf;
    }
}

//! Weight of the watch's system fonts (monkey.jungle: POKE SYS_BOLD_DEVICES).
(:sysbold)
module SysWeight {
    const BOLD = true;
}

(:sysregular)
module SysWeight {
    const BOLD = false;
}
