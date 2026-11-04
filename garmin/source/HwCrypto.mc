using Toybox.Cryptography;
using Toybox.Lang;
using Toybox.StringUtil;

//! Hidden Word sync crypto (SPEC §5.2–5.3), ported from the hw-watch-crypto spike.
//! Native on Connect IQ: SHA-256, HMAC-SHA256, AES-256-ECB, randomBytes.
//! Hand-built here: HKDF, CTR (one native ECB call per block: the simulator's ECB only transforms
//! the first block of a longer input), GHASH (4-bit table), GCM seal/open, base64url, base32 keys.
module HwB {
    function hex(b as Lang.ByteArray) as Lang.String {
        return StringUtil.convertEncodedString(b, {:fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_HEX}) as Lang.String;
    }
    function unhex(s as Lang.String) as Lang.ByteArray {
        return StringUtil.convertEncodedString(s, {:fromRepresentation => StringUtil.REPRESENTATION_STRING_HEX,
            :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY}) as Lang.ByteArray;
    }
    function utf8(s as Lang.String) as Lang.ByteArray {
        return StringUtil.convertEncodedString(s, {:fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY}) as Lang.ByteArray;
    }
    function text(b as Lang.ByteArray) as Lang.String {
        return StringUtil.convertEncodedString(b, {:fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT}) as Lang.String;
    }
    function b64url(b as Lang.ByteArray) as Lang.String {
        var s = StringUtil.convertEncodedString(b, {:fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_BASE64}) as Lang.String;
        var cs = s.toCharArray();
        var out = new [cs.size()];
        var n = 0;
        for (var i = 0; i < cs.size(); i++) {
            var c = cs[i];
            if (c == '=') { continue; }
            out[n] = c == '+' ? '-' : (c == '/' ? '_' : c);
            n++;
        }
        return StringUtil.charArrayToString(out.slice(0, n));
    }
    function fromB64url(t as Lang.String) as Lang.ByteArray {
        var cs = t.toCharArray();
        var pad = (4 - cs.size() % 4) % 4;
        var out = new [cs.size() + pad];
        for (var i = 0; i < cs.size(); i++) {
            var c = cs[i];
            out[i] = c == '-' ? '+' : (c == '_' ? '/' : c);
        }
        for (var j = 0; j < pad; j++) { out[cs.size() + j] = '='; }
        return StringUtil.convertEncodedString(StringUtil.charArrayToString(out), {:fromRepresentation => StringUtil.REPRESENTATION_STRING_BASE64,
            :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY}) as Lang.ByteArray;
    }

    const B32 = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

    //! SPEC §5.1: sync key text -> 16 key bytes, or null for a typo (length, padding, check byte).
    function parseKey(text as Lang.String) as Lang.ByteArray or Null {
        var cs = text.toUpper().toCharArray();
        var bits = 0;
        var acc = 0;
        var out = []b;
        var count = 0;
        for (var i = 0; i < cs.size(); i++) {
            var c = cs[i];
            if (c == '-' || c == ' ') { continue; }
            if (c == 'O') { c = '0'; } else if (c == 'I' || c == 'L') { c = '1'; }
            var v = B32.find(c.toString());
            if (v == null) { return null; }
            count++;
            acc = ((acc << 5) | v) & 0xFFF; // at most 12 bits pending
            bits += 5;
            if (bits >= 8) {
                bits -= 8;
                out.add((acc >> bits) & 0xFF);
            }
        }
        if (count != 28 || out.size() != 17 || (acc & ((1 << bits) - 1)) != 0) { return null; }
        var key = out.slice(0, 16);
        var h = new Cryptography.Hash({:algorithm => Cryptography.HASH_SHA256});
        h.update(key);
        return h.digest()[0] == out[16] ? key : null;
    }
}

module HwKdf {
    function hmac(key as Lang.ByteArray, msg as Lang.ByteArray) as Lang.ByteArray {
        var h = new Cryptography.HashBasedMessageAuthenticationCode({:algorithm => Cryptography.HASH_SHA256, :key => key});
        h.update(msg);
        return h.digest();
    }
    //! RFC 5869 HKDF-SHA256 (null/empty salt = 32 zero bytes).
    function hkdf(ikm as Lang.ByteArray, salt as Lang.ByteArray or Null, info as Lang.ByteArray, len as Lang.Number) as Lang.ByteArray {
        var s = salt;
        if (s == null || s.size() == 0) { s = new [32]b; }
        var prk = hmac(s, ikm);
        var okm = []b;
        var t = []b;
        var n = 1;
        while (okm.size() < len) {
            var m = []b; m.addAll(t); m.addAll(info); m.add(n);
            t = hmac(prk, m);
            okm.addAll(t);
            n++;
        }
        return okm.slice(0, len);
    }
}

module HwGcm {
    var _m as Lang.Array = [];
    var _hKey as Lang.ByteArray or Null = null;
    const R4 = [0x0000, 0x1c20, 0x3840, 0x2460, 0x7080, 0x6ca0, 0x48c0, 0x54e0,
                0xe100, 0xfd20, 0xd940, 0xc560, 0x9180, 0x8da0, 0xa9c0, 0xb5e0];

    function word(b as Lang.ByteArray, o as Lang.Number) as Lang.Number {
        return (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
    }

    function buildTable(h as Lang.ByteArray) as Void {
        var m = new [16];
        m[0] = [0, 0, 0, 0];
        m[8] = [word(h, 0), word(h, 4), word(h, 8), word(h, 12)];
        var i = 4;
        while (i > 0) {
            var p = m[i * 2] as Lang.Array<Lang.Number>;
            var w0 = (p[0] >> 1) & 0x7FFFFFFF;
            var w1 = ((p[1] >> 1) & 0x7FFFFFFF) | (p[0] << 31);
            var w2 = ((p[2] >> 1) & 0x7FFFFFFF) | (p[1] << 31);
            var w3 = ((p[3] >> 1) & 0x7FFFFFFF) | (p[2] << 31);
            if ((p[3] & 1) != 0) { w0 = w0 ^ 0xE1000000; }
            m[i] = [w0, w1, w2, w3];
            i = i / 2;
        }
        for (i = 2; i < 16; i = i * 2) {
            for (var j = 1; j < i; j++) {
                var a = m[i] as Lang.Array<Lang.Number>;
                var b = m[j] as Lang.Array<Lang.Number>;
                m[i + j] = [a[0] ^ b[0], a[1] ^ b[1], a[2] ^ b[2], a[3] ^ b[3]];
            }
        }
        _m = m;
    }

    function ghash(data as Lang.ByteArray) as Lang.Array<Lang.Number> {
        var z0 = 0; var z1 = 0; var z2 = 0; var z3 = 0;
        var m = _m;
        var nb = data.size() / 16;
        for (var b = 0; b < nb; b++) {
            var o = b * 16;
            var xs = [z0 ^ word(data, o), z1 ^ word(data, o + 4), z2 ^ word(data, o + 8), z3 ^ word(data, o + 12)];
            z0 = 0; z1 = 0; z2 = 0; z3 = 0;
            for (var k = 31; k >= 0; k--) {
                var nib = ((xs[k >> 3] as Lang.Number) >> ((7 - (k & 7)) * 4)) & 0xF;
                if (k != 31) {
                    var rem = z3 & 0xF;
                    z3 = ((z3 >> 4) & 0x0FFFFFFF) | (z2 << 28);
                    z2 = ((z2 >> 4) & 0x0FFFFFFF) | (z1 << 28);
                    z1 = ((z1 >> 4) & 0x0FFFFFFF) | (z0 << 28);
                    z0 = ((z0 >> 4) & 0x0FFFFFFF) ^ ((R4[rem] as Lang.Number) << 16);
                }
                var t = m[nib] as Lang.Array<Lang.Number>;
                z0 = z0 ^ t[0]; z1 = z1 ^ t[1]; z2 = z2 ^ t[2]; z3 = z3 ^ t[3];
            }
        }
        return [z0, z1, z2, z3];
    }

    function pad16(b as Lang.ByteArray) as Void {
        var r = b.size() % 16;
        if (r != 0) { b.addAll(new [16 - r]b); }
    }

    function put32(b as Lang.ByteArray, w as Lang.Number) as Void {
        b.add((w >> 24) & 0xFF); b.add((w >> 16) & 0xFF); b.add((w >> 8) & 0xFF); b.add(w & 0xFF);
    }

    //! Encrypt (decrypt=false: out = ct ‖ tag) or decrypt (out = pt ‖ tag over the given ct).
    function crypt(key as Lang.ByteArray, iv as Lang.ByteArray, aad as Lang.ByteArray, data as Lang.ByteArray,
                   decrypt as Lang.Boolean) as Lang.ByteArray {
        var ecb = new Cryptography.Cipher({:algorithm => Cryptography.CIPHER_AES256, :mode => Cryptography.MODE_ECB, :key => key});
        var n = (data.size() + 15) / 16;
        if (_hKey == null || !(_hKey as Lang.ByteArray).equals(key)) {
            buildTable(ecb.encrypt(new [16]b));
            _hKey = key;
        }
        var ks = []b;
        for (var c = 1; c <= n + 1; c++) {
            var blk = []b; blk.addAll(iv); put32(blk, c);
            ks.addAll(ecb.encrypt(blk));
        }
        var out = new [data.size()]b;
        for (var i = 0; i < data.size(); i++) {
            out[i] = data[i] ^ ks[16 + i];
        }
        var g = []b;
        g.addAll(aad); pad16(g);
        g.addAll(decrypt ? data : out); pad16(g);
        put32(g, 0); put32(g, aad.size() * 8); put32(g, 0); put32(g, data.size() * 8);
        var s = ghash(g);
        for (var i = 0; i < 4; i++) {
            var w = s[i];
            out.add(((w >> 24) & 0xFF) ^ ks[i * 4]);
            out.add(((w >> 16) & 0xFF) ^ ks[1 + i * 4]);
            out.add(((w >> 8) & 0xFF) ^ ks[2 + i * 4]);
            out.add((w & 0xFF) ^ ks[3 + i * 4]);
        }
        return out;
    }

    function seal(key as Lang.ByteArray, iv as Lang.ByteArray, aad as Lang.ByteArray, pt as Lang.ByteArray) as Lang.ByteArray {
        return crypt(key, iv, aad, pt, false);
    }

    //! Plaintext, or null when the tag does not verify.
    function open(key as Lang.ByteArray, iv as Lang.ByteArray, aad as Lang.ByteArray, ctTag as Lang.ByteArray) as Lang.ByteArray or Null {
        if (ctTag.size() < 16) { return null; }
        var n = ctTag.size() - 16;
        var r = crypt(key, iv, aad, ctTag.slice(0, n), true);
        var diff = 0;
        for (var i = 0; i < 16; i++) { diff = diff | (r[n + i] ^ ctTag[n + i]); }
        return diff == 0 ? r.slice(0, n) : null;
    }
}
