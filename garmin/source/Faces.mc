using Toybox.Graphics;
using Toybox.Lang;

//! v7 (Dylan): headings and verse text in different weights, built-in watch faces only.
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
            _body = SysWeight.BOLD ? vectorLike(["RobotoCondensedRegular", "RobotoRegular"], Graphics.FONT_XTINY) : null;
        }
        return _body != null ? _body as Graphics.VectorFont : Graphics.FONT_XTINY;
    }

    //! Face for a heading drawn at the size of `base`.
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
