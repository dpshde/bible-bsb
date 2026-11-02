#!/usr/bin/env python3
"""Generate Connect IQ BMFont (.fnt + .png) atlases from Noto Sans instances.

Usage:
  python3 scripts/gen-bmfonts.py [--out resources/fonts]

Writes face atlases and a sizes report JSON for the PR/SPEC memory budget.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
TTF_DIR = Path("/tmp/noto-fonts/inst")

# ASCII printable — enough for BSB English + punctuation in spike JSON.
BODY_CHARS = [chr(c) for c in range(32, 127)]
NUM_CHARS = list("0123456789")
CAPS_CHARS = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -:.'")


def render_atlas(
    ttf: Path,
    size_px: int,
    chars: list[str],
    out_stem: Path,
    face_name: str,
    pad: int = 1,
) -> dict:
    font = ImageFont.truetype(str(ttf), size_px)
    # Measure glyphs
    glyphs = []
    for ch in chars:
        bbox = font.getbbox(ch) if ch != " " else (0, 0, max(size_px // 3, 3), size_px)
        if ch == " ":
            # Space: advance-only glyph with 1x1 transparent pixel
            w, h = max(size_px // 3, 3), 1
            xoff, yoff = 0, 0
            adv = max(size_px // 3, 3)
        else:
            x0, y0, x1, y1 = bbox
            w, h = max(x1 - x0, 1), max(y1 - y0, 1)
            xoff, yoff = x0, y0
            adv = int(font.getlength(ch))
            if adv < 1:
                adv = w
        glyphs.append(
            {
                "ch": ch,
                "id": ord(ch),
                "w": w,
                "h": h,
                "xoff": xoff,
                "yoff": yoff,
                "adv": adv,
            }
        )

    # Pack into rows (simple shelf pack)
    max_w = 512
    x = pad
    y = pad
    row_h = 0
    line_h = size_px + 2
    for g in glyphs:
        need = g["w"] + pad
        if x + need > max_w:
            x = pad
            y += row_h + pad
            row_h = 0
        g["x"] = x
        g["y"] = y
        x += need
        row_h = max(row_h, g["h"])
    atlas_h = y + row_h + pad
    atlas_w = max_w

    # White glyphs on transparent — CIQ tints via dc.setColor foreground.
    img = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    ascent, descent = font.getmetrics()
    baseline = ascent  # yoffset relative to top of cell

    for g in glyphs:
        ch = g["ch"]
        if ch == " ":
            # 1px transparent marker
            img.putpixel((g["x"], g["y"]), (255, 255, 255, 0))
            continue
        # Draw into a tight crop then paste
        tmp = Image.new("RGBA", (g["w"] + 2, g["h"] + 2), (0, 0, 0, 0))
        td = ImageDraw.Draw(tmp)
        # Position so bbox (x0,y0) lands at (0,0) of tmp
        td.text((-g["xoff"], -g["yoff"]), ch, font=font, fill=(255, 255, 255, 255))
        img.alpha_composite(tmp, (g["x"], g["y"]))

    png_name = out_stem.name + "_0.png"
    png_path = out_stem.parent / png_name
    img.save(png_path, optimize=True)

    # BMFont text format (Connect IQ)
    lines = []
    lines.append(
        f'info face="{face_name}" size={size_px} bold=0 italic=0 charset="" '
        f"unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0"
    )
    lines.append(
        f"common lineHeight={size_px + 2} base={ascent} scaleW={atlas_w} scaleH={atlas_h} "
        f"pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4"
    )
    lines.append(f'page id=0 file="{png_name}"')
    lines.append(f"chars count={len(glyphs)}")
    for g in glyphs:
        # yoffset: distance from top of line to top of glyph
        yoffset = g["yoff"]
        lines.append(
            f"char id={g['id']:4d} x={g['x']:4d} y={g['y']:4d} "
            f"width={g['w']:4d} height={g['h']:4d} "
            f"xoffset={g['xoff']:4d} yoffset={yoffset:4d} "
            f"xadvance={g['adv']:4d} page=0  chnl=15"
        )

    fnt_path = out_stem.with_suffix(".fnt")
    fnt_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    return {
        "face": face_name,
        "size_px": size_px,
        "chars": len(glyphs),
        "png_bytes": png_path.stat().st_size,
        "fnt_bytes": fnt_path.stat().st_size,
        "atlas": f"{atlas_w}x{atlas_h}",
        "png": str(png_path.relative_to(ROOT)) if png_path.is_relative_to(ROOT) else str(png_path),
        "fnt": str(fnt_path.relative_to(ROOT)) if fnt_path.is_relative_to(ROOT) else str(fnt_path),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=ROOT / "resources" / "fonts")
    ap.add_argument("--out-lowmem", type=Path, default=ROOT / "resources-lowmem" / "fonts")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    args.out_lowmem.mkdir(parents=True, exist_ok=True)

    specs_full = [
        # POKE: body sizes — 14px band body; 16px short-verse bump.
        ("NotoSans-Light.ttf", 14, BODY_CHARS, "body_light_14", "BsbLight14"),
        ("NotoSans-Regular.ttf", 14, BODY_CHARS, "body_regular_14", "BsbRegular14"),
        ("NotoSans-Medium.ttf", 14, BODY_CHARS, "body_medium_14", "BsbMedium14"),
        ("NotoSans-Medium.ttf", 16, BODY_CHARS, "body_medium_16", "BsbMedium16"),
        ("NotoSans-Bold.ttf", 11, NUM_CHARS, "num_bold_11", "BsbNumBold11"),
        ("NotoSans-Regular.ttf", 11, CAPS_CHARS, "header_caps_11", "BsbHeaderCaps11"),
    ]
    # Low-mem: regular body + bold nums + header; light/medium alias to regular at build via XML.
    specs_low = [
        ("NotoSans-Regular.ttf", 14, BODY_CHARS, "body_regular_14", "BsbRegular14"),
        ("NotoSans-Regular.ttf", 16, BODY_CHARS, "body_medium_16", "BsbMedium16"),
        ("NotoSans-Bold.ttf", 11, NUM_CHARS, "num_bold_11", "BsbNumBold11"),
        ("NotoSans-Regular.ttf", 11, CAPS_CHARS, "header_caps_11", "BsbHeaderCaps11"),
    ]

    report = {"full": [], "lowmem": []}
    for ttf_name, size, chars, stem, face in specs_full:
        ttf = TTF_DIR / ttf_name
        if not ttf.exists():
            raise SystemExit(f"missing {ttf}")
        info = render_atlas(ttf, size, chars, args.out / stem, face)
        report["full"].append(info)
        print(f"full {stem}: {info['png_bytes']}B png, {info['atlas']}")

    for ttf_name, size, chars, stem, face in specs_low:
        ttf = TTF_DIR / ttf_name
        info = render_atlas(ttf, size, chars, args.out_lowmem / stem, face)
        report["lowmem"].append(info)
        print(f"low  {stem}: {info['png_bytes']}B png, {info['atlas']}")

    # Also copy regular→light/medium stand-ins for lowmem id parity (same files, different names)
    # Generated separately as tiny duplicate references via fonts.xml filter aliases.

    def total(entries: list[dict]) -> int:
        return sum(e["png_bytes"] + e["fnt_bytes"] for e in entries)

    report["full_total_bytes"] = total(report["full"])
    report["lowmem_total_bytes"] = total(report["lowmem"])
    # Lowmem runtime still loads 4 faces; light/medium map to regular in Fonts.mc.
    report["notes"] = (
        "Full set: Light14 + Regular14 + Medium14 + Medium16 + NumBold11 + HeaderCaps11. "
        "Low-mem devices: Regular14 + Medium16 + NumBold11 + HeaderCaps11; "
        "Light/Medium14 fall back to Regular14 (color dim still separates focus)."
    )

    out_json = ROOT / "docs" / "font-budget.json"
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(report, indent=2) + "\n")
    print("full_total", report["full_total_bytes"])
    print("lowmem_total", report["lowmem_total_bytes"])
    print("wrote", out_json)


if __name__ == "__main__":
    main()
