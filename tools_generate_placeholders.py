"""
Generates solid-color placeholder PNGs at the EXACT dimensions specified in
Math_Invaders_Spec_v2.md, Section 7 (Sprite & Image Asset List).

Per Tech Stack §7 "Placeholder Strategy": these are pixel-exact substitutes
saved under the real target filenames, so later art can be dropped in with
no code/scene changes.

Run once during Phase 0 setup: python3 tools_generate_placeholders.py
"""
from PIL import Image, ImageDraw

ROOT = "assets/images"

# (relative_path, width, height, has_alpha, rgba_color, label)
ASSETS = [
    ("background/background_space.png", 720, 1280, False, (8, 10, 28, 255), "BG"),
    ("background/starfield_overlay.png", 720, 1280, True, (200, 210, 255, 40), "STARS"),
    ("ships/player_ship.png", 128, 128, True, (60, 200, 255, 255), "PLYR"),
    ("ships/player_bullet.png", 16, 48, True, (255, 240, 90, 255), "BLT"),
    ("ships/enemy_bullet.png", 16, 48, True, (255, 90, 90, 255), "EBLT"),
    ("enemies/enemy_ship_addition.png", 96, 96, True, (255, 90, 90, 255), "ADD"),
    ("enemies/enemy_ship_subtraction.png", 96, 96, True, (255, 160, 60, 255), "SUB"),
    ("enemies/enemy_ship_multiplication.png", 96, 96, True, (170, 90, 255, 255), "MUL"),
    ("enemies/enemy_ship_division.png", 96, 96, True, (90, 220, 140, 255), "DIV"),
    ("enemies/enemy_ship_prime.png", 96, 96, True, (255, 90, 220, 255), "PRM"),
    ("effects/enemy_explosion_spritesheet.png", 512, 128, True, (255, 200, 60, 255), "BOOM"),
    ("ui/question_panel_bg.png", 720, 360, True, (20, 24, 48, 235), "QPANEL"),
    ("ui/answer_button_normal.png", 320, 100, True, (40, 70, 120, 255), ""),
    ("ui/answer_button_pressed.png", 320, 100, True, (70, 110, 170, 255), ""),
    ("ui/heart_icon.png", 48, 48, True, (255, 70, 90, 255), "HP"),
    ("ui/life_icon.png", 48, 48, True, (90, 180, 255, 255), "LIFE"),
    ("ui/wave_complete_banner.png", 600, 200, True, (255, 210, 60, 255), "WAVE!"),
    ("ui/level_complete_banner.png", 600, 200, True, (60, 255, 160, 255), "LEVEL!"),
    ("ui/game_over_bg.png", 720, 1280, False, (30, 4, 8, 255), "GAMEOVER"),
]


def make_asset(path, w, h, alpha, color, label):
    mode = "RGBA" if alpha else "RGB"
    img = Image.new(mode, (w, h), color)
    draw = ImageDraw.Draw(img)
    # Simple border + centered label so placeholders are visually identifiable
    border_color = tuple(min(c + 40, 255) for c in color[:3]) + ((color[3],) if alpha else ())
    draw.rectangle([0, 0, w - 1, h - 1], outline=border_color, width=max(2, w // 100))
    try:
        bbox = draw.textbbox((0, 0), label)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    except Exception:
        tw, th = (len(label) * 6, 10)
    draw.text(((w - tw) / 2, (h - th) / 2), label, fill=(255, 255, 255, 255) if alpha else (255, 255, 255))
    img.save(path, "PNG")
    print(f"wrote {path} ({w}x{h})")


if __name__ == "__main__":
    for rel, w, h, alpha, color, label in ASSETS:
        make_asset(f"{ROOT}/{rel}", w, h, alpha, color, label)
