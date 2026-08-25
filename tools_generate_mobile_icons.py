"""
Generates the Android launcher icon PNGs referenced by export_presets.cfg
(Phase 11 FR10.1), matching the style of icon.svg (dark navy rounded tile,
cyan "M").

Outputs into assets/images/icons/:
- icon_192.png                  main legacy launcher icon (192x192)
- icon_adaptive_foreground.png  adaptive foreground layer (432x432)
- icon_adaptive_background.png  adaptive background layer (424x424)

Run once during Phase 11 setup: python tools_generate_mobile_icons.py
"""
from PIL import Image, ImageDraw, ImageFont

import os

OUT_DIR = os.path.join("assets", "images", "icons")
BG_COLOR = (10, 10, 32, 255)        # #0a0a20
GLYPH_COLOR = (60, 200, 255, 255)   # #3cc8ff

FONT_CANDIDATES = [
    "C:/Windows/Fonts/arialbd.ttf",
    "C:/Windows/Fonts/Arial Bold.ttf",
    "C:/Windows/Fonts/arial.ttf",
]


def _load_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def _draw_glyph(draw, center, glyph_size):
    """Draws the centered cyan 'M' at roughly icon.svg's proportions."""
    font = _load_font(int(glyph_size))
    left, top, right, bottom = draw.textbbox((0, 0), "M", font=font)
    width, height = right - left, bottom - top
    pos = (center[0] - width / 2 - left, center[1] - height / 2 - top)
    draw.text(pos, "M", font=font, fill=GLYPH_COLOR)


def make_main_icon():
    """192x192 rounded-tile icon mirroring icon.svg."""
    img = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((0, 0, 191, 191), radius=30, fill=BG_COLOR)
    _draw_glyph(draw, (96, 96), 120)
    return img


def make_adaptive_foreground():
    """432x432 foreground; glyph kept inside the ~66% adaptive safe zone."""
    img = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    _draw_glyph(draw, (216, 216), 150)
    return img


def make_adaptive_background():
    """424x424 solid navy background layer."""
    return Image.new("RGBA", (424, 424), BG_COLOR)


def make_boot_splash():
    """720x1280 boot splash (Godot's boot splash only accepts PNG):
    navy background with the rounded icon tile centered."""
    img = Image.new("RGBA", (720, 1280), BG_COLOR)
    tile = Image.new("RGBA", (280, 280), (0, 0, 0, 0))
    tdraw = ImageDraw.Draw(tile)
    tdraw.rounded_rectangle((0, 0, 279, 279), radius=44, fill=BG_COLOR)
    _draw_glyph(tdraw, (140, 140), 176)
    img.paste(tile, (220, 430), tile)
    # Flatten onto opaque navy so no transparency survives the save.
    flat = Image.new("RGBA", img.size, BG_COLOR)
    flat.alpha_composite(img)
    return flat.convert("RGB")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    make_main_icon().save(os.path.join(OUT_DIR, "icon_192.png"))
    make_adaptive_foreground().save(
        os.path.join(OUT_DIR, "icon_adaptive_foreground.png"))
    make_adaptive_background().save(
        os.path.join(OUT_DIR, "icon_adaptive_background.png"))
    make_boot_splash().save(
        os.path.join("assets", "images", "ui", "boot_splash.png"))
    print("Wrote launcher icons to", OUT_DIR)


if __name__ == "__main__":
    main()
