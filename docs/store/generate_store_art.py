import math, random, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

OUT = '/home/user/robloxhorror/docs/store/'
os.makedirs(OUT, exist_ok=True)
FX = '/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf'
FB = '/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf'


def C(*a): return tuple(a)


def layer(size): return Image.new('RGBA', size, (0, 0, 0, 0))


def glow_ellipse(img, box, color, blur):
    l = layer(img.size); ImageDraw.Draw(l).ellipse(box, fill=color)
    img.alpha_composite(l.filter(ImageFilter.GaussianBlur(blur)))


def glow_poly(img, pts, color, blur):
    l = layer(img.size); ImageDraw.Draw(l).polygon(pts, fill=color)
    img.alpha_composite(l.filter(ImageFilter.GaussianBlur(blur)))


def vgrad(size, top, bottom):
    w, h = size; g = Image.new('RGBA', (1, h))
    for y in range(h):
        t = y / (h - 1); g.putpixel((0, y), tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,))
    return g.resize(size)


def vignette(img, strength=0.75):
    w, h = img.size
    m = Image.new('L', (w, h), 0); ImageDraw.Draw(m).ellipse([-w * 0.15, -h * 0.2, w * 1.15, h * 1.2], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(min(w, h) * 0.15))
    dark = Image.new('RGBA', (w, h), (0, 0, 0, 255)); dark.putalpha(ImageChops.invert(m).point(lambda v: int(v * strength)))
    img.alpha_composite(dark)


def grain(img, amount=10, seed=1):
    rnd = random.Random(seed); w, h = img.size
    n = Image.effect_noise((w // 2, h // 2), 40).resize((w, h)).convert('L')
    n = n.point(lambda v: int((v - 128) * amount / 40 + 128))
    g = Image.merge('RGBA', (n, n, n, Image.new('L', (w, h), 18)))
    img.alpha_composite(g)


def text(img, xy, s, size, fill, stroke=(10, 5, 20), sw=None, font=FX, anchor='la', glow=None):
    f = ImageFont.truetype(font, size); sw = sw if sw is not None else max(2, size // 12)
    if glow:
        l = layer(img.size); ImageDraw.Draw(l).text(xy, s, font=f, fill=glow, anchor=anchor, stroke_width=sw * 2, stroke_fill=glow)
        img.alpha_composite(l.filter(ImageFilter.GaussianBlur(size // 5)))
    ImageDraw.Draw(img).text(xy, s, font=f, fill=fill, anchor=anchor, stroke_width=sw, stroke_fill=stroke)


def eye(img, d, x, y, r, iris, glow=True, pupil=0.45):
    d.ellipse([x - r, y - r, x + r, y + r], fill=(245, 245, 235), outline=(20, 15, 15), width=max(2, int(r * 0.12)))
    pr = r * pupil
    if glow:
        glow_ellipse(img, [x - pr * 1.9, y - pr * 1.9, x + pr * 1.9, y + pr * 1.9], iris + (150,), pr * 0.7)
        d = ImageDraw.Draw(img)
    d.ellipse([x - pr, y - pr, x + pr, y + pr], fill=iris)
    d.ellipse([x - pr * 0.35 + pr * 0.3, y - pr * 0.35 - pr * 0.3, x + pr * 0.35 + pr * 0.3, y + pr * 0.35 - pr * 0.3], fill=(255, 255, 255))
    return d


OUTLINE = (20, 12, 12)


def bowtie(d, x, y, s, col):
    d.polygon([(x, y), (x - s, y - s * 0.6), (x - s, y + s * 0.6)], fill=col, outline=OUTLINE)
    d.polygon([(x, y), (x + s, y - s * 0.6), (x + s, y + s * 0.6)], fill=col, outline=OUTLINE)
    d.ellipse([x - s * 0.3, y - s * 0.3, x + s * 0.3, y + s * 0.3], fill=col, outline=OUTLINE)


# ------------------------------------------------------------------ mascots
def bruno(img, cx, cy, s, body=True, eyes=(255, 50, 40)):
    fur, light, dark = (140, 85, 45), (210, 165, 115), (95, 55, 30)
    d = ImageDraw.Draw(img); ow = max(3, int(s * 0.05))
    if body:
        d.rounded_rectangle([cx - s * 1.1, cy + s * 0.75, cx + s * 1.1, cy + s * 3.2], radius=s * 0.6, fill=fur, outline=OUTLINE, width=ow)
        d.ellipse([cx - s * 0.7, cy + s * 1.1, cx + s * 0.7, cy + s * 2.9], fill=light)
        for sx in (-1, 1):
            d.rounded_rectangle([cx + sx * s * 1.05 - s * 0.32, cy + s * 0.95, cx + sx * s * 1.05 + s * 0.32, cy + s * 2.9], radius=s * 0.3, fill=fur, outline=OUTLINE, width=ow)
        bowtie(d, cx, cy + s * 0.95, s * 0.35, (25, 25, 30))
    for sx in (-1, 1):
        d.ellipse([cx + sx * s * 0.78 - s * 0.38, cy - s * 1.15, cx + sx * s * 0.78 + s * 0.38, cy - s * 0.4], fill=fur, outline=OUTLINE, width=ow)
        d.ellipse([cx + sx * s * 0.78 - s * 0.2, cy - s * 0.95, cx + sx * s * 0.78 + s * 0.2, cy - s * 0.6], fill=light)
    d.ellipse([cx - s, cy - s * 0.9, cx + s, cy + s * 0.9], fill=fur, outline=OUTLINE, width=ow)
    d.ellipse([cx - s * 0.5, cy + s * 0.05, cx + s * 0.5, cy + s * 0.7], fill=light, outline=OUTLINE, width=ow)
    d.ellipse([cx - s * 0.18, cy + s * 0.08, cx + s * 0.18, cy + s * 0.3], fill=(20, 15, 15))
    # jaw with teeth
    d.rounded_rectangle([cx - s * 0.36, cy + s * 0.42, cx + s * 0.36, cy + s * 0.62], radius=s * 0.05, fill=(60, 20, 20))
    for i in range(6):
        x = cx - s * 0.32 + i * s * 0.128
        d.polygon([(x, cy + s * 0.42), (x + s * 0.11, cy + s * 0.42), (x + s * 0.055, cy + s * 0.54)], fill=(240, 235, 210))
    for sx in (-1, 1):
        d = eye(img, d, cx + sx * s * 0.4, cy - s * 0.18, s * 0.24, eyes)
    # top hat
    d.rounded_rectangle([cx - s * 0.75, cy - s * 0.98, cx + s * 0.75, cy - s * 0.82], radius=s * 0.05, fill=(20, 20, 25), outline=OUTLINE, width=ow)
    d.rectangle([cx - s * 0.45, cy - s * 1.65, cx + s * 0.45, cy - s * 0.9], fill=(20, 20, 25), outline=OUTLINE, width=ow)
    d.rectangle([cx - s * 0.45, cy - s * 1.1, cx + s * 0.45, cy - s * 0.95], fill=(150, 20, 35))


def pip(img, cx, cy, s, body=True, eyes=(0, 200, 255)):
    navy, white, orange = (30, 35, 60), (240, 240, 245), (255, 150, 30)
    d = ImageDraw.Draw(img); ow = max(3, int(s * 0.05))
    if body:
        d.ellipse([cx - s * 1.2, cy + s * 0.6, cx + s * 1.2, cy + s * 3.3], fill=navy, outline=OUTLINE, width=ow)
        d.ellipse([cx - s * 0.8, cy + s * 0.9, cx + s * 0.8, cy + s * 3.1], fill=white)
        for sx in (-1, 1):
            d.ellipse([cx + sx * s * 1.1 - s * 0.3, cy + s * 1.0, cx + sx * s * 1.1 + s * 0.3, cy + s * 2.6], fill=navy, outline=OUTLINE, width=ow)
        bowtie(d, cx, cy + s * 0.9, s * 0.35, (0, 150, 255))
    d.ellipse([cx - s, cy - s, cx + s, cy + s * 0.9], fill=navy, outline=OUTLINE, width=ow)
    d.ellipse([cx - s * 0.78, cy - s * 0.55, cx + s * 0.78, cy + s * 0.8], fill=white)
    for sx in (-1, 1):
        d = eye(img, d, cx + sx * s * 0.36, cy - s * 0.12, s * 0.3, eyes, pupil=0.4)
    d.polygon([(cx - s * 0.32, cy + s * 0.25), (cx + s * 0.32, cy + s * 0.25), (cx, cy + s * 0.62)], fill=orange, outline=OUTLINE)
    d.line([(cx - s * 0.25, cy + s * 0.38), (cx + s * 0.25, cy + s * 0.38)], fill=(150, 70, 10), width=ow)
    # party hat
    hx, hy = cx + s * 0.25, cy - s * 0.85
    hat = [(hx - s * 0.5, hy + s * 0.1), (hx + s * 0.45, hy - s * 0.05), (hx + s * 0.15, hy - s * 1.15)]
    d.polygon(hat, fill=(255, 80, 160), outline=OUTLINE)
    for k in (0.35, 0.7):
        a = (hat[0][0] + (hat[2][0] - hat[0][0]) * k, hat[0][1] + (hat[2][1] - hat[0][1]) * k)
        b = (hat[1][0] + (hat[2][0] - hat[1][0]) * k, hat[1][1] + (hat[2][1] - hat[1][1]) * k)
        d.line([a, b], fill=(255, 220, 60), width=int(s * 0.1))
    d.ellipse([hat[2][0] - s * 0.14, hat[2][1] - s * 0.14, hat[2][0] + s * 0.14, hat[2][1] + s * 0.14], fill=(255, 255, 255), outline=OUTLINE)


def maple(img, cx, cy, s, body=True):
    fur, light = (170, 120, 70), (225, 195, 150)
    antler = (235, 215, 170)
    d = ImageDraw.Draw(img); ow = max(3, int(s * 0.05))
    if body:
        d.rounded_rectangle([cx - s * 1.15, cy + s * 0.7, cx + s * 1.15, cy + s * 3.2], radius=s * 0.6, fill=fur, outline=OUTLINE, width=ow)
        d.ellipse([cx - s * 0.7, cy + s * 1.1, cx + s * 0.7, cy + s * 2.9], fill=light)
        d.rounded_rectangle([cx - s * 1.0, cy + s * 0.65, cx + s * 1.0, cy + s * 1.0], radius=s * 0.15, fill=(180, 30, 40), outline=OUTLINE, width=ow)
        d.ellipse([cx - s * 0.2, cy + s * 0.95, cx + s * 0.2, cy + s * 1.35], fill=(255, 200, 50), outline=OUTLINE, width=ow)
    for sx in (-1, 1):
        pts = [(cx + sx * s * 0.5, cy - s * 0.7), (cx + sx * s * 0.75, cy - s * 1.25), (cx + sx * s * 1.6, cy - s * 1.35), (cx + sx * s * 1.75, cy - s * 1.9),
               (cx + sx * s * 1.45, cy - s * 1.6), (cx + sx * s * 1.35, cy - s * 2.05), (cx + sx * s * 1.1, cy - s * 1.6), (cx + sx * s * 0.95, cy - s * 2.0),
               (cx + sx * s * 0.8, cy - s * 1.5), (cx + sx * s * 0.6, cy - s * 1.15)]
        d.polygon(pts, fill=antler, outline=OUTLINE)
        d.ellipse([cx + sx * s * 0.95 - s * 0.35, cy - s * 0.65, cx + sx * s * 0.95 + s * 0.35, cy - s * 0.25], fill=fur, outline=OUTLINE, width=ow)
    d.ellipse([cx - s * 0.85, cy - s * 0.95, cx + s * 0.85, cy + s * 0.5], fill=fur, outline=OUTLINE, width=ow)
    d.ellipse([cx - s * 0.7, cy - s * 0.05, cx + s * 0.7, cy + s * 0.95], fill=light, outline=OUTLINE, width=ow)
    for sx in (-1, 1):
        d.ellipse([cx + sx * s * 0.25 - s * 0.1, cy + s * 0.3, cx + sx * s * 0.25 + s * 0.1, cy + s * 0.48], fill=(60, 30, 25))
    d.arc([cx - s * 0.35, cy + s * 0.45, cx + s * 0.35, cy + s * 0.8], 20, 160, fill=(60, 30, 25), width=ow)
    # blindfold with red X stitches
    d.rounded_rectangle([cx - s * 0.95, cy - s * 0.55, cx + s * 0.95, cy - s * 0.18], radius=s * 0.08, fill=(235, 235, 225), outline=OUTLINE, width=ow)
    for sx in (-1, 1):
        x, y, r = cx + sx * s * 0.4, cy - s * 0.37, s * 0.12
        d.line([(x - r, y - r), (x + r, y + r)], fill=(170, 20, 30), width=ow * 2)
        d.line([(x - r, y + r), (x + r, y - r)], fill=(170, 20, 30), width=ow * 2)


def jinx(img, cx, cy, s, body=True):
    purple, yellow, mask = (110, 50, 160), (250, 200, 40), (245, 240, 235)
    d = ImageDraw.Draw(img); ow = max(3, int(s * 0.05))
    if body:
        d.polygon([(cx - s * 0.7, cy + s * 1.0), (cx + s * 0.7, cy + s * 1.0), (cx + s * 0.9, cy + s * 3.3), (cx - s * 0.9, cy + s * 3.3)], fill=purple, outline=OUTLINE)
        d.polygon([(cx, cy + s * 1.0), (cx + s * 0.7, cy + s * 1.0), (cx + s * 0.9, cy + s * 3.3), (cx, cy + s * 3.3)], fill=yellow, outline=OUTLINE)
        for i in range(8):
            a = math.pi * (i / 7)
            x = cx - s * 1.0 + i * s * 0.285
            d.polygon([(x, cy + s * 0.95), (x + s * 0.3, cy + s * 0.95), (x + s * 0.15, cy + s * 1.35)], fill=purple if i % 2 else yellow, outline=OUTLINE)
    # hat prongs
    for sx, col in ((-1, purple), (1, yellow)):
        pts = [(cx + sx * s * 0.2, cy - s * 0.8), (cx + sx * s * 0.75, cy - s * 0.95), (cx + sx * s * 1.35, cy - s * 1.55),
               (cx + sx * s * 1.05, cy - s * 0.7), (cx + sx * s * 0.6, cy - s * 0.55)]
        d.polygon(pts, fill=col, outline=OUTLINE)
        bx, by = cx + sx * s * 1.4, cy - s * 1.6
        d.ellipse([bx - s * 0.17, by - s * 0.17, bx + s * 0.17, by + s * 0.17], fill=yellow, outline=OUTLINE, width=ow)
    d.ellipse([cx - s * 0.8, cy - s * 1.0, cx + s * 0.8, cy + s * 0.95], fill=mask, outline=OUTLINE, width=ow)
    d.rounded_rectangle([cx - s * 0.85, cy - s * 1.0, cx + s * 0.85, cy - s * 0.7], radius=s * 0.1, fill=purple, outline=OUTLINE, width=ow)
    for sx in (-1, 1):
        x, y = cx + sx * s * 0.33, cy - s * 0.2
        d.ellipse([x - s * 0.22, y - s * 0.28, x + s * 0.22, y + s * 0.28], fill=(5, 5, 8))
        glow_ellipse(img, [x - s * 0.15, y - s * 0.15, x + s * 0.15, y + s * 0.15], (255, 255, 255, 220), s * 0.06)
        d = ImageDraw.Draw(img)
        d.ellipse([x - s * 0.06, y - s * 0.06, x + s * 0.06, y + s * 0.06], fill=(255, 255, 255))
        d.ellipse([cx + sx * s * 0.55 - s * 0.12, cy + s * 0.15 - s * 0.1, cx + sx * s * 0.55 + s * 0.12, cy + s * 0.15 + s * 0.1], fill=(255, 130, 160))
    d.chord([cx - s * 0.55, cy + s * 0.05, cx + s * 0.55, cy + s * 0.75], 0, 180, fill=(170, 15, 30), outline=OUTLINE, width=ow)
    for i in range(7):
        x = cx - s * 0.45 + i * s * 0.15
        d.polygon([(x, cy + s * 0.4), (x + s * 0.13, cy + s * 0.4), (x + s * 0.065, cy + s * 0.52)], fill=(245, 245, 235))


# ------------------------------------------------------------------ ICON (512)
S = 2048
img = vgrad((S, S), (25, 15, 50), (5, 3, 12))
for i in range(160):
    rnd = random.Random(i); x, y = rnd.uniform(0, S), rnd.uniform(0, S * 0.6); r = rnd.uniform(2, 6)
    ImageDraw.Draw(img).ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, rnd.randint(60, 200)))
glow_poly(img, [(-200, S + 200), (500, -100), (1700, -100), (S + 200, S + 200)], (255, 235, 170, 70), 120)
glow_ellipse(img, [300, 250, 1750, 1750], (0, 160, 255, 90), 250)
pip(img, 1000, 1180, 520, body=False)
grain(img, 8)
vignette(img, 0.6)
d = ImageDraw.Draw(img)
d.rounded_rectangle([330, 1700, 1718, 1930], radius=110, fill=(200, 20, 60), outline=(255, 255, 255), width=14)
text(img, (1024, 1815), "NIGHT SHIFT", 165, (255, 255, 255), stroke=(60, 0, 20), anchor='mm')
img.convert('RGB').resize((512, 512), Image.LANCZOS).save(OUT + 'icon.png')

# ------------------------------------------------------------------ THUMB helpers (1920x1080, drawn at 2x)
W, H = 3840, 2160


def corridor():
    img = vgrad((W, H), (14, 18, 26), (6, 6, 10))
    d = ImageDraw.Draw(img)
    vx, vy = W * 0.62, H * 0.47
    # ceiling, walls
    d.polygon([(0, 0), (W, 0), (vx + 420, vy - 300), (vx - 420, vy - 300)], fill=(30, 32, 38))
    d.polygon([(0, 0), (vx - 420, vy - 300), (vx - 420, vy + 250), (0, H)], fill=(36, 50, 66))
    d.polygon([(W, 0), (vx + 420, vy - 300), (vx + 420, vy + 250), (W, H)], fill=(30, 44, 60))
    # wainscot
    for side in (-1, 1):
        ex = vx + side * 420
        far_top, far_bot = vy + 120, vy + 250
        near_x = 0 if side < 0 else W
        d.polygon([(near_x, H * 0.72), (ex, far_top), (ex, far_bot), (near_x, H)], fill=(120, 30, 38))
        d.line([(near_x, H * 0.72), (ex, far_top)], fill=(225, 175, 60), width=26)
    # back wall + door
    d.rectangle([vx - 420, vy - 300, vx + 420, vy + 250], fill=(22, 28, 38))
    d.rectangle([vx - 130, vy - 140, vx + 130, vy + 250], fill=(5, 5, 8))
    d.rectangle([vx - 90, vy - 230, vx + 90, vy - 175], fill=(20, 140, 50))
    text(img, (vx, vy - 202), "EXIT", 44, (255, 255, 255), sw=0, anchor='mm', glow=(40, 255, 100, 200))
    # checkered floor
    rows = 14
    for r in range(rows):
        t0, t1 = (r / rows) ** 1.8, ((r + 1) / rows) ** 1.8
        y0 = vy + 250 + (H - vy - 250) * t0; y1 = vy + 250 + (H - vy - 250) * t1
        def xat(t, u): return (vx - 420 + (0 - (vx - 420)) * t) + ((vx + 420 + (W - (vx + 420)) * t) - (vx - 420 + (0 - (vx - 420)) * t)) * u
        cols = 10
        for c in range(cols):
            u0, u1 = c / cols, (c + 1) / cols
            col = (230, 230, 230) if (r + c) % 2 == 0 else (25, 25, 30)
            d.polygon([(xat(t0, u0), y0), (xat(t0, u1), y0), (xat(t1, u1), y1), (xat(t1, u0), y1)], fill=col)
    return img


def flashlight(img, ox, oy, tx, ty, spread=0.28):
    ang = math.atan2(ty - oy, tx - ox); L = math.hypot(tx - ox, ty - oy) * 1.4
    a1, a2 = ang - spread, ang + spread
    pts = [(ox, oy), (ox + math.cos(a1) * L, oy + math.sin(a1) * L), (ox + math.cos(a2) * L, oy + math.sin(a2) * L)]
    glow_poly(img, pts, (255, 240, 180, 120), 60)
    pts2 = [(ox, oy), (ox + math.cos(a1 + 0.08) * L, oy + math.sin(a1 + 0.08) * L), (ox + math.cos(a2 - 0.08) * L, oy + math.sin(a2 - 0.08) * L)]
    glow_poly(img, pts2, (255, 255, 230, 90), 30)
    # flashlight body
    fl = layer(img.size); fd = ImageDraw.Draw(fl)
    cx, cy = ox, oy
    fd.rounded_rectangle([cx - 700, cy - 120, cx - 80, cy + 120], radius=60, fill=(55, 60, 75), outline=(10, 10, 15), width=20)
    fd.polygon([(cx - 100, cy - 140), (cx + 60, cy - 230), (cx + 60, cy + 230), (cx - 100, cy + 140)], fill=(240, 180, 30), outline=(10, 10, 15))
    fd.ellipse([cx + 10, cy - 230, cx + 110, cy + 230], fill=(255, 255, 225), outline=(10, 10, 15), width=16)
    fd.rounded_rectangle([cx - 600, cy + 120, cx - 260, cy + 420], radius=120, fill=(230, 180, 140), outline=(10, 10, 15), width=18)  # hand
    fl = fl.rotate(-math.degrees(ang), center=(cx, cy), resample=Image.BICUBIC)
    img.alpha_composite(fl)


def finish(img, name):
    grain(img, 7, seed=len(name))
    vignette(img, 0.55)
    img.convert('RGB').resize((1920, 1080), Image.LANCZOS).save(OUT + name)


# ------------------------------------------------------------------ THUMB 1: Bruno in the hallway
img = corridor()
bx, by = 2500, 1050
glow_ellipse(img, [bx - 700, by - 800, bx + 700, by + 900], (255, 230, 160, 60), 160)
flashlight(img, 520, 1900, bx, by - 100)
bruno(img, bx, by, 380)
text(img, (140, 150), "NIGHT SHIFT", 300, (255, 90, 190), stroke=(40, 0, 30), glow=(255, 60, 180, 200))
text(img, (150, 470), "AT PIP'S", 230, (255, 230, 120), stroke=(40, 20, 0), glow=(255, 180, 40, 140))
d = ImageDraw.Draw(img)
d.rounded_rectangle([150, 780, 1500, 940], radius=80, fill=(200, 20, 50), outline=(255, 255, 255), width=10)
text(img, (825, 860), "SURVIVE UNTIL 6 AM", 95, (255, 255, 255), stroke=(60, 0, 15), anchor='mm', sw=5)
finish(img, 'thumbnail_1.png')

# ------------------------------------------------------------------ THUMB 2: the pizzeria at night
img = vgrad((W, H), (40, 20, 70), (10, 6, 25))
rnd = random.Random(7); d = ImageDraw.Draw(img)
for _ in range(400):
    x, y, r = rnd.uniform(0, W), rnd.uniform(0, H * 0.45), rnd.uniform(2, 6)
    d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, rnd.randint(70, 230)))
glow_ellipse(img, [3150, 140, 3550, 540], (255, 250, 220, 120), 80)
d = ImageDraw.Draw(img); d.ellipse([3220, 210, 3480, 470], fill=(250, 245, 225))
# ground
d.rectangle([0, 1500, W, H], fill=(32, 32, 38))
for i in range(-2, 12):
    x = 300 + i * 380
    d.polygon([(x, 1700), (x + 20, 1700), (x - 120, H), (x - 160, H)], fill=(220, 220, 190))
d.rectangle([0, 1440, W, 1520], fill=(110, 110, 115))
# building
d.rectangle([380, 620, 3460, 1460], fill=(120, 45, 40))
for y in range(640, 1460, 60):
    off = 0 if (y // 60) % 2 else 60
    for x in range(380 + off, 3460, 120):
        d.rectangle([x, y, min(x + 112, 3460), y + 54], fill=(135, 52, 45))
d.rectangle([340, 560, 3500, 640], fill=(60, 25, 25))
# windows with mascots inside
wins = [(560, 'b'), (1160, 'm'), (2440, 'p'), (3040, 'j')]
for x, who in wins:
    glow_ellipse(img, [x - 150, 820, x + 450, 1380], (255, 190, 110, 90), 80)
    d = ImageDraw.Draw(img)
    d.rectangle([x, 870, x + 300, 1330], fill=(255, 205, 140))
    sil = layer(img.size)
    {'b': bruno, 'm': maple, 'p': pip, 'j': jinx}[who](sil, x + 150, 1080, 105)
    sil_dark = Image.new('RGBA', img.size, (25, 10, 15, 255)); sil_dark.putalpha(sil.getchannel('A'))
    mask = Image.new('L', img.size, 0); ImageDraw.Draw(mask).rectangle([x, 870, x + 300, 1330], fill=255)
    sil_dark.putalpha(ImageChops.multiply(sil_dark.getchannel('A'), mask))
    img.alpha_composite(sil_dark)
    d = ImageDraw.Draw(img)
    eyecol = {'b': (255, 50, 40), 'm': (255, 255, 255), 'p': (0, 200, 255), 'j': (255, 255, 255)}[who]
    if who != 'm':
        for sx in (-1, 1):
            ex, ey = x + 150 + sx * 38, 1060
            glow_ellipse(img, [ex - 30, ey - 30, ex + 30, ey + 30], eyecol + (255,), 12)
            ImageDraw.Draw(img).ellipse([ex - 9, ey - 9, ex + 9, ey + 9], fill=eyecol)
    d = ImageDraw.Draw(img)
    d.rectangle([x, 870, x + 300, 1330], outline=(40, 20, 20), width=16)
    d.line([(x + 150, 870), (x + 150, 1330)], fill=(40, 20, 20), width=12)
# doors
d.rectangle([1700, 950, 2140, 1460], fill=(20, 30, 45)); d.rectangle([1720, 970, 2120, 1460], fill=(60, 90, 120))
d.line([(1920, 970), (1920, 1460)], fill=(20, 30, 45), width=14)
# neon sign
d.rounded_rectangle([1060, 260, 2780, 560], radius=40, fill=(20, 10, 30), outline=(0, 255, 230), width=14)
text(img, (1920, 410), "PIP'S PARTY PALACE", 170, (255, 120, 220), stroke=(90, 0, 70), anchor='mm', sw=6, glow=(255, 60, 200, 255))
glow_ellipse(img, [1000, 200, 2840, 800], (255, 60, 200, 50), 200)
# streetlamp
d = ImageDraw.Draw(img)
d.rectangle([3640, 700, 3680, 1700], fill=(40, 40, 45)); d.rectangle([3540, 680, 3720, 720], fill=(40, 40, 45))
glow_poly(img, [(3560, 720), (3300, 1700), (3850, 1700)], (255, 210, 150, 80), 60)
# player silhouettes
for px in (1500, 1660, 2250):
    dd = ImageDraw.Draw(img)
    dd.rounded_rectangle([px - 45, 1560, px + 45, 1760], radius=30, fill=(10, 8, 15))
    dd.ellipse([px - 42, 1470, px + 42, 1555], fill=(10, 8, 15))
glow_poly(img, [(1700, 1600), (1880, 1180), (2000, 1240)], (255, 240, 180, 90), 30)
text(img, (1920, 1880), "THEY WAKE UP AT MIDNIGHT", 190, (255, 255, 255), stroke=(30, 0, 30), anchor='mm', glow=(255, 40, 120, 180))
finish(img, 'thumbnail_2.png')

# ------------------------------------------------------------------ THUMB 3: one rule per mascot
img = vgrad((W, H), (30, 12, 40), (8, 4, 12))
cards = [(bruno, "BRUNO", "HUNTS BY SIGHT", (255, 60, 50)), (maple, "MAPLE", "HEARS YOU RUN", (255, 200, 60)),
         (pip, "PIP", "MOVES IN THE DARK", (0, 200, 255)), (jinx, "JINX", "MUSIC BOX!", (200, 120, 255))]
for i, (fn, name, rule, col) in enumerate(cards):
    x = 520 + i * 930
    glow_ellipse(img, [x - 420, 500, x + 420, 1500], col + (90,), 140)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x - 400, 470, x + 400, 1960], radius=60, fill=(18, 12, 26, 230), outline=col, width=14)
    fn(img, x, 980, 230, body=False) if fn is not maple else fn(img, x, 1020, 210, body=False)
    text(img, (x, 1530), name, 150, col, stroke=(10, 5, 15), anchor='mm', sw=8)
    text(img, (x, 1760), rule, 72, (255, 255, 255), stroke=(10, 5, 15), anchor='mm', sw=4)
text(img, (W / 2, 230), "EACH MASCOT HAS ONE RULE", 210, (255, 230, 120), stroke=(50, 20, 0), anchor='mm', glow=(255, 160, 40, 150))
text(img, (W / 2, 2070), "LEARN IT... OR GET CAUGHT", 110, (255, 255, 255), stroke=(40, 0, 20), anchor='mm', sw=6)
finish(img, 'thumbnail_3.png')
print('ok')
