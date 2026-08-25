"""
Generates FINAL-STYLE art for every image asset in Math_Invaders_Spec.md
Section 7/8, replacing the Phase 0 solid-color placeholders in place
(same filenames, same dimensions - Phase 10 FR9.9 placeholder audit).

Run:  python tools_generate_final_art.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join("assets", "images")

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\arialbd.ttf",
    r"C:\Windows\Fonts\Arial Bold.ttf",
    r"C:\Windows\Fonts\segoeuib.ttf",
    r"C:\Windows\Fonts\arial.ttf",
]

NAVY = (6, 9, 26)
OUTLINE = (14, 18, 44)


def load_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def v_gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img


def new_rgba(size):
    return Image.new("RGBA", size, (0, 0, 0, 0))


def radial_glow(size, center, radius, color, peak=110):
    """Soft additive-looking radial glow on its own RGBA layer."""
    layer = new_rgba(size)
    d = ImageDraw.Draw(layer)
    cx, cy = center
    steps = max(8, int(radius / 2))
    for i in range(steps, 0, -1):
        r = radius * i / steps
        a = int(peak * (1.0 - i / steps) ** 2)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (a,))
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.08))


def paste(base, layer):
    base.alpha_composite(layer)


def star_field(img, count, seed, bright_min=40, bright_max=160, big_every=12):
    rnd = random.Random(seed)
    d = ImageDraw.Draw(img)
    w, h = img.size
    for i in range(count):
        x = rnd.uniform(0, w)
        y = rnd.uniform(0, h)
        b = rnd.randint(bright_min, bright_max)
        tint = random.Random(seed + i).choice([(255, 255, 255), (200, 214, 255), (255, 240, 220)])
        if i % big_every == 0:
            r = 1.6
        else:
            r = 1.0
        d.ellipse([x - r, y - r, x + r, y + r], fill=tint + (b,))
    return img


# ---------------------------------------------------------------- backgrounds

def make_background_space():
    img = v_gradient((720, 1280), (10, 13, 38), (4, 5, 14)).convert("RGBA")
    # faint nebula blobs
    neb = new_rgba((720, 1280))
    nd = ImageDraw.Draw(neb)
    rnd = random.Random(11)
    for _ in range(5):
        cx, cy = rnd.uniform(80, 640), rnd.uniform(100, 1180)
        rx, ry = rnd.uniform(120, 260), rnd.uniform(90, 200)
        col = rnd.choice([(60, 70, 160), (90, 50, 130), (40, 90, 150)])
        nd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=col + (26,))
    neb = neb.filter(ImageFilter.GaussianBlur(90))
    img.alpha_composite(neb)
    star_field(img, 120, seed=3, bright_min=36, bright_max=120)
    img.convert("RGB").save(os.path.join(ROOT, "background", "background_space.png"))


def make_starfield_overlay():
    """Vertically tileable sparse star layer (transparent background)."""
    img = new_rgba((720, 1280))
    rnd = random.Random(21)
    d = ImageDraw.Draw(img)
    H = 1280
    for i in range(150):
        x = rnd.uniform(0, 720)
        y = rnd.uniform(0, H)
        r = rnd.choice([0.8, 0.9, 1.0, 1.0, 1.2, 1.8])
        b = rnd.randint(90, 235)
        tint = rnd.choice([(255, 255, 255), (205, 218, 255), (190, 235, 255), (255, 244, 214)])
        for dy in (-H, 0, H):  # wrap vertically so scrolling is seamless
            d.ellipse([x - r, y + dy - r, x + r, y + dy + r], fill=tint + (b,))
        if r >= 1.8:  # halo on the biggest stars
            glow = radial_glow((720, 1280), (int(x), int(y)), 7, tint, peak=70)
            img.alpha_composite(glow)
    img.save(os.path.join(ROOT, "background", "starfield_overlay.png"))


def make_game_over_bg():
    img = v_gradient((720, 1280), (34, 6, 14), (8, 2, 6)).convert("RGBA")
    neb = new_rgba((720, 1280))
    nd = ImageDraw.Draw(neb)
    rnd = random.Random(31)
    for _ in range(4):
        cx, cy = rnd.uniform(100, 620), rnd.uniform(100, 1180)
        rx, ry = rnd.uniform(140, 300), rnd.uniform(110, 240)
        nd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(140, 30, 40, 24))
    neb = neb.filter(ImageFilter.GaussianBlur(100))
    img.alpha_composite(neb)
    star_field(img, 90, seed=33, bright_min=30, bright_max=95)
    img.convert("RGB").save(os.path.join(ROOT, "ui", "game_over_bg.png"))


# ---------------------------------------------------------------------- ships

def draw_player_ship():
    s = 128
    img = new_rgba((s, s))
    d = ImageDraw.Draw(img)
    cx = s // 2
    paste(img, radial_glow((s, s), (cx, 66), 52, (90, 210, 255), peak=60))

    def poly(points, fill, outline=OUTLINE):
        d.polygon(points, fill=fill)
        d.line(list(points) + [points[0]], fill=outline, width=3, joint="curve")

    dark = (24, 60, 110, 255)
    mid = (46, 130, 205, 255)
    light = (150, 225, 255, 255)
    # wings
    poly([(16, 84), (52, 58), (52, 98), (28, 108)], dark)
    poly([(112, 84), (76, 58), (76, 98), (100, 108)], dark)
    # fuselage
    poly([(64, 6), (79, 42), (75, 96), (64, 114), (53, 96), (49, 42)], mid)
    poly([(64, 6), (79, 42), (72, 60), (56, 60), (49, 42)], light)
    # cockpit
    d.ellipse([54, 36, 74, 62], fill=(210, 250, 255, 255), outline=OUTLINE, width=2)
    d.ellipse([58, 40, 66, 50], fill=(255, 255, 255, 255))
    # engine flame
    flame = new_rgba((s, s))
    fd = ImageDraw.Draw(flame)
    fd.polygon([(54, 100), (74, 100), (64, 126)], fill=(120, 220, 255, 220))
    fd.polygon([(59, 100), (69, 100), (64, 118)], fill=(240, 252, 255, 240))
    paste(img, flame.filter(ImageFilter.GaussianBlur(1)))
    img.save(os.path.join(ROOT, "ships", "player_ship.png"))


def draw_life_icon():
    src = Image.open(os.path.join(ROOT, "ships", "player_ship.png")).convert("RGBA")
    icon = src.resize((48, 48), Image.LANCZOS)
    icon.save(os.path.join(ROOT, "ui", "life_icon.png"))


def draw_heart_icon():
    s = 48
    img = new_rgba((s, s))
    d = ImageDraw.Draw(img)
    paste(img, radial_glow((s, s), (24, 22), 20, (255, 90, 120), peak=70))
    red = (232, 58, 92, 255)
    dark = (120, 16, 40, 255)
    d.ellipse([4, 8, 24, 28], fill=red)
    d.ellipse([24, 8, 44, 28], fill=red)
    d.polygon([(5, 20), (43, 20), (24, 44)], fill=red)
    d.line([(5, 20), (24, 44), (43, 20), (24, 9), (5, 20)], fill=dark, width=3, joint="curve")
    d.ellipse([11, 13, 19, 21], fill=(255, 190, 205, 255))
    img.save(os.path.join(ROOT, "ui", "heart_icon.png"))


def draw_bullets():
    for name, core, glow in [
        ("player_bullet.png", (255, 250, 210), (255, 220, 80)),
        ("enemy_bullet.png", (255, 220, 225), (255, 70, 90)),
    ]:
        img = new_rgba((16, 48))
        paste(img, radial_glow((16, 48), (8, 24), 14, glow, peak=150))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([4, 6, 12, 42], radius=4, fill=glow + (230,))
        d.rounded_rectangle([6, 10, 10, 32], radius=2, fill=core + (255,))
        img.save(os.path.join(ROOT, "ships", name))


# --------------------------------------------------------------- enemy ships

def _symbol_plus(d, cx, cy, bar=14, thick=6, color=(255, 255, 255, 240)):
    d.rectangle([cx - thick // 2, cy - bar // 2, cx + thick // 2, cy + bar // 2], fill=color)
    d.rectangle([cx - bar // 2, cy - thick // 2, cx + bar // 2, cy + thick // 2], fill=color)


def _symbol_minus(d, cx, cy, bar=16, thick=6, color=(255, 255, 255, 240)):
    d.rectangle([cx - bar // 2, cy - thick // 2, cx + bar // 2, cy + thick // 2], fill=color)


def _symbol_times(d, cx, cy, arm=9, thick=6, color=(255, 255, 255, 240)):
    for sign in (1, -1):
        pts = []
        for t in (-arm, arm):
            pts.append((cx + sign * t, cy + t))
        d.line(pts, fill=color, width=thick)


def _symbol_divide(d, cx, cy, bar=16, thick=6, dot=3, color=(255, 255, 255, 240)):
    d.rectangle([cx - bar // 2, cy - thick // 2, cx + bar // 2, cy + thick // 2], fill=color)
    d.ellipse([cx - dot - 1, cy - 11 - dot, cx + dot + 1, cy - 11 + dot], fill=color)
    d.ellipse([cx - dot - 1, cy + 11 - dot, cx + dot + 1, cy + 11 + dot], fill=color)


def _symbol_prime(d, cx, cy, color=(255, 255, 255, 240)):
    # double-prime tick marks
    for off in (-6, 6):
        d.line([(cx + off - 3, cy + 9), (cx + off + 3, cy - 9)], fill=color, width=6)


def _enemy_base(color_main, color_dark, color_light, symbol_fn):
    s = 96
    img = new_rgba((s, s))
    cx = s // 2
    paste(img, radial_glow((s, s), (cx, 52), 42, color_main, peak=55))

    def poly(points, fill):
        ImageDraw.Draw(img).polygon(points, fill=fill)
        ImageDraw.Draw(img).line(list(points) + [points[0]], fill=OUTLINE + (255,), width=3, joint="curve")

    return img, cx, poly, color_main, color_dark, color_light, symbol_fn


def finish_enemy(img, symbol_fn, cx):
    d = ImageDraw.Draw(img)
    symbol_fn(d, cx, 50)
    img.save_path = None
    return img


def make_enemy_ships():
    # Addition: round saucer, red
    img, cx, poly, main, dark, light, sym = _enemy_base(
        (255, 90, 90), (150, 35, 45), (255, 170, 170), _symbol_plus)
    poly([(14, 52), (82, 52), (70, 72), (26, 72)], dark)          # lower hull
    poly([(cx - 34, 52), (cx + 34, 52), (cx + 20, 38), (cx - 20, 38)], main)  # saucer deck
    d2 = ImageDraw.Draw(img)
    d2.ellipse([cx - 16, 22, cx + 16, 44], fill=light, outline=OUTLINE + (255,), width=3)  # dome
    d2.ellipse([cx - 8, 27, cx + 2, 36], fill=(255, 255, 255, 230))
    finish_enemy(img, sym, cx).save(os.path.join(ROOT, "enemies", "enemy_ship_addition.png"))

    # Subtraction: angular fighter, orange, faces downward
    img, cx, poly, main, dark, light, sym = _enemy_base(
        (255, 160, 60), (160, 88, 20), (255, 210, 150), _symbol_minus)
    poly([(cx, 90), (cx - 16, 56), (cx - 40, 66), (cx - 26, 34), (cx + 26, 34),
          (cx + 40, 66), (cx + 16, 56)], main)
    poly([(cx - 12, 78), (cx + 12, 78), (cx + 8, 52), (cx - 8, 52)], light)
    finish_enemy(img, sym, cx).save(os.path.join(ROOT, "enemies", "enemy_ship_subtraction.png"))

    # Multiplication: X-wing cross hull, purple
    img, cx, poly, main, dark, light, sym = _enemy_base(
        (170, 90, 255), (86, 40, 140), (215, 175, 255), _symbol_times)
    poly([(cx - 8, 20), (cx + 8, 20), (cx + 8, 80), (cx - 8, 80)], main)
    poly([(cx - 36, 34), (cx + 36, 68), (cx + 36, 78), (cx - 36, 44)], dark)
    poly([(cx - 36, 68), (cx + 36, 34), (cx + 36, 44), (cx - 36, 78)], dark)
    poly([(cx - 12, 30), (cx + 12, 30), (cx + 12, 44), (cx - 12, 44)], light)
    finish_enemy(img, sym, cx).save(os.path.join(ROOT, "enemies", "enemy_ship_multiplication.png"))

    # Division: hexagonal hull, green
    img, cx, poly, main, dark, light, sym = _enemy_base(
        (90, 220, 140), (30, 120, 70), (180, 255, 210), _symbol_divide)
    poly([(cx, 16), (cx + 30, 34), (cx + 30, 68), (cx, 86), (cx - 30, 68), (cx - 30, 34)], main)
    poly([(cx, 28), (cx + 20, 40), (cx + 20, 62), (cx, 74), (cx - 20, 62), (cx - 20, 40)], dark)
    poly([(cx - 10, 36), (cx + 10, 36), (cx + 10, 50), (cx - 10, 50)], light)
    finish_enemy(img, sym, cx).save(os.path.join(ROOT, "enemies", "enemy_ship_division.png"))

    # Prime: tall diamond, magenta
    img, cx, poly, main, dark, light, sym = _enemy_base(
        (255, 90, 220), (140, 35, 120), (255, 185, 240), _symbol_prime)
    poly([(cx, 10), (cx + 26, 50), (cx, 90), (cx - 26, 50)], main)
    poly([(cx, 24), (cx + 15, 50), (cx, 76), (cx - 15, 50)], dark)
    poly([(cx - 7, 38), (cx + 7, 38), (cx, 52)], light)
    finish_enemy(img, sym, cx).save(os.path.join(ROOT, "enemies", "enemy_ship_prime.png"))


# ------------------------------------------------------------------ explosion

def make_explosion_spritesheet():
    sheet = new_rgba((512, 128))
    rnd = random.Random(77)
    sparks = [(rnd.uniform(-1, 1), rnd.uniform(-1, 1)) for _ in range(16)]
    for f in range(4):
        t = f / 3.0                      # 0 .. 1 progress through the blast
        frame = new_rgba((128, 128))
        c = (64, 64)
        d = ImageDraw.Draw(frame)

        def ball(radius, color, alpha):
            layers = 6
            for i in range(layers, 0, -1):
                r = radius * i / layers
                a = int(alpha * (1 - i / layers / 2.2))
                d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=color + (max(0, a),))

        radius = 12 + t * 44
        if f == 0:
            ball(14, (255, 255, 240), 255)
            ball(8, (255, 250, 200), 255)
        elif f == 1:
            paste(frame, radial_glow((128, 128), c, radius + 16, (255, 200, 60), peak=200))
            ball(radius, (255, 210, 70), 245)
            ball(radius * 0.55, (255, 250, 220), 255)
        elif f == 2:
            paste(frame, radial_glow((128, 128), c, radius + 22, (255, 130, 40), peak=170))
            ball(radius, (255, 140, 50), 225)
            ball(radius * 0.6, (255, 210, 90), 200)
            ring_r = radius + 10
            d.ellipse([c[0] - ring_r, c[1] - ring_r, c[0] + ring_r, c[1] + ring_r],
                      outline=(255, 180, 80, 150), width=4)
        else:
            ball(radius, (150, 110, 90), 130)
            ball(radius * 0.5, (90, 70, 65), 110)
            ring_r = radius + 12
            d.ellipse([c[0] - ring_r, c[1] - ring_r, c[0] + ring_r, c[1] + ring_r],
                      outline=(200, 140, 90, 80), width=3)
        # sparks flying outward
        for j, (sx, sy) in enumerate(sparks):
            dist = (14 + t * 52) * (0.55 + 0.45 * ((j * 37 % 10) / 10.0))
            px = c[0] + sx * dist
            py = c[1] + sy * dist
            sr = 2.4 * (1.0 - t * 0.7)
            alpha = int(230 * (1.0 - t * 0.85))
            if alpha > 4:
                col = (255, 240, 180) if f < 3 else (210, 160, 120)
                d.ellipse([px - sr, py - sr, px + sr, py + sr], fill=col + (alpha,))
        sheet.alpha_composite(frame, (f * 128, 0))
    sheet.save(os.path.join(ROOT, "effects", "enemy_explosion_spritesheet.png"))


# ------------------------------------------------------------------------ UI

def rounded_gradient_button(size, radius, top, bottom, border, pressed=False):
    w, h = size
    grad = v_gradient(size, top, bottom).convert("RGBA")
    mask = new_rgba(size)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=(255, 255, 255, 255))
    img = new_rgba(size)
    img.paste(grad, (0, 0), mask.split()[3])
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, outline=border + (255,), width=3)
    # gloss strip
    gloss_h = int(h * (0.30 if not pressed else 0.18))
    gm = new_rgba(size)
    gd = ImageDraw.Draw(gm)
    gd.rounded_rectangle([4, 4, w - 5, gloss_h], radius=radius - 4, fill=(255, 255, 255, 46))
    img.alpha_composite(gm)
    if pressed:  # inner shadow at the top edge sells the push
        sh = new_rgba(size)
        sd = ImageDraw.Draw(sh)
        sd.rounded_rectangle([0, 0, w - 1, 10], radius=radius, fill=(0, 0, 20, 70))
        img.alpha_composite(sh)
    return img


def make_question_panel_bg():
    w, h = 720, 360
    img = new_rgba((w, h))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=26, fill=(16, 20, 46, 236))
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=26, outline=(110, 150, 255, 210), width=4)
    d.rounded_rectangle([8, 8, w - 9, h - 9], radius=20, outline=(70, 95, 170, 120), width=2)
    img.save(os.path.join(ROOT, "ui", "question_panel_bg.png"))


def make_answer_buttons():
    normal = rounded_gradient_button(
        (320, 100), 18, (86, 138, 222), (39, 67, 126), (150, 190, 255))
    normal.save(os.path.join(ROOT, "ui", "answer_button_normal.png"))
    pressed = rounded_gradient_button(
        (320, 100), 18, (42, 70, 122), (22, 41, 75), (110, 140, 200), pressed=True)
    pressed.save(os.path.join(ROOT, "ui", "answer_button_pressed.png"))


def make_banner(name, text, top_color, bottom_color, border_color, seed_font_size=64):
    w, h = 600, 200
    img = new_rgba((w, h))
    d = ImageDraw.Draw(img)
    box = [26, 48, w - 26, h - 48]
    grad = v_gradient((box[2] - box[0], box[3] - box[1]), top_color, bottom_color).convert("RGBA")
    mask = new_rgba((box[2] - box[0], box[3] - box[1]))
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, box[2] - box[0] - 1, box[3] - box[1] - 1], radius=30, fill=(255, 255, 255, 255))
    img.paste(grad, (box[0], box[1]), mask.split()[3])
    d.rounded_rectangle(box, radius=30, outline=border_color + (255,), width=5)
    # side ribbons
    for sign, x_edge in ((-1, box[0]), (1, box[2])):
        tip = (x_edge + sign * 22, (box[1] + box[3]) // 2)
        d.polygon([(x_edge, box[1] + 18), tip, (x_edge, box[3] - 18)],
                  fill=border_color + (235,))
    font = load_font(seed_font_size)
    tb = d.textbbox((0, 0), text, font=font)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    tx = (w - tw) / 2 - tb[0]
    ty = (h - th) / 2 - tb[1]
    d.text((tx + 4, ty + 5), text, font=font, fill=(20, 16, 4, 200))
    d.text((tx, ty), text, font=font, fill=(255, 255, 255, 245))
    img.save(os.path.join(ROOT, "ui", name))


if __name__ == "__main__":
    make_background_space()
    make_starfield_overlay()
    make_game_over_bg()
    draw_player_ship()
    draw_life_icon()
    draw_heart_icon()
    draw_bullets()
    make_enemy_ships()
    make_explosion_spritesheet()
    make_question_panel_bg()
    make_answer_buttons()
    make_banner("wave_complete_banner.png", "WAVE CLEAR!",
                (255, 208, 74), (232, 144, 30), (120, 62, 10))
    make_banner("level_complete_banner.png", "LEVEL COMPLETE!",
                (74, 226, 168), (24, 148, 116), (8, 74, 58), seed_font_size=58)
    print("final art written to", ROOT)
