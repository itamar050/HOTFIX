"""Generate TEMPORARY placeholder art for the brawler's street stage (godot/assets/placeholder/).

These images are drawn from code so the game has a readable, layered stage while final art is
made. Replace any file with real art of the same size and name (see docs/ART_SPEC.md); the
neon/lamp positions come from godot/assets/placeholder/street_layout.gd (also written here).

Layers (back to front), all 640x360 screen space, lane = sidewalk y 266..338:
  placeholder_street_sky.png      640x360   static sky (scroll 0)
  placeholder_street_far.png      1280x240  far skyline (scroll 0.15), bottom at y 240
  placeholder_street_mid.png      1280x260  mid-rise buildings (scroll 0.45), bottom at y 262
  placeholder_street_front.png    LEVEL_Wx266  storefronts, world-locked (scroll 1)
  placeholder_street_ground.png   LEVEL_Wx94   sidewalk lane + curb + road, world-locked
  placeholder_street_fore.png     1600x60   foreground props (scroll 1.3), bottom at y 360
  placeholder_glow.png            64x64     dithered radial glow (tinted, additive)
  placeholder_vignette.png        640x360   dark corners overlay
Run: python3 tools/make_street_placeholders.py
"""
import random, os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), '..', 'godot', 'assets', 'placeholder')
LEVEL_W = 2400
LANE_TOP = 266
K = (12, 8, 22)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

# 5x7 pixel font for sign text
F5 = {
'A': ".###.#...##...#######...##...##...#", 'B': "####.#...#####.#...##...##...#####.", 'C': ".#####....#....#....#....#.....####", 'D': "####.#...##...##...##...##...#####.",
'E': "######....####.#....#....#....#####", 'F': "######....####.#....#....#....#....", 'G': ".#####....#....#.####...##...#.####", 'H': "#...##...#######...##...##...##...#",
'I': "###.#..#..#..#..#.###", 'K': "#...##..#.###..#.#..#..#.#...##...#", 'L': "#....#....#....#....#....#....#####", 'M': "#...###.###.#.##...##...##...##...#",
'N': "#...###..##.#.##..###...##...##...#", 'O': ".###.#...##...##...##...##...#.###.", 'P': "####.#...##...#####.#....#....#....", 'R': "####.#...##...#####.#.#..#..#.#...#",
'S': ".#####....#.....###.....#....#####.", 'T': "#####..#....#....#....#....#....#..", 'U': "#...##...##...##...##...##...#.###.", 'V': "#...##...##...##...#.#.#..#.#...#..",
'W': "#...##...##...##.#.##.#.###.###...#", 'Y': "#...##...#.#.#...#....#....#....#..", 'X': "#...#.#.#...#...#.#.#...##...##...#", 'Z': "#####....#...#...#...#...#....#####",
'0': ".###.#...##..###.#.###..##...#.###.", '1': "..#...##....#....#....#....#...###.", '2': ".###.#...#....#...#...#...#...#####", '4': "#...##...##...######....#....#....#",
' ': "...................................", '-': "...............#####...............", '&': ".##..#..#..##...##.#.#..#.#..#.##.#",
}
def glyph(ch):
    g = F5.get(ch, F5[' '])
    w = 3 if ch == 'I' else 5
    if ch == 'I': g = g.ljust(21, '.')
    return w, [g[i*w:(i+1)*w].ljust(w, '.') for i in range(7)]
def text(d, x, y, s, col, sc=1, shadow=None):
    for ch in s:
        w, rows = glyph(ch)
        for j, r in enumerate(rows):
            for i, c in enumerate(r):
                if c == '#':
                    if shadow: d.rectangle([x+i*sc+sc, y+j*sc+sc, x+i*sc+2*sc-1, y+j*sc+2*sc-1], fill=shadow)
                    d.rectangle([x+i*sc, y+j*sc, x+i*sc+sc-1, y+j*sc+sc-1], fill=col)
        x += (w+1)*sc
def text_w(s, sc=1): return sum((glyph(c)[0]+1)*sc for c in s) - sc

def R(d, x, y, w, h, c):
    if w > 0 and h > 0: d.rectangle([x, y, x+w-1, y+h-1], fill=c)
def mix(a, b, t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(len(a)))
def shade(c, f): return tuple(max(0, min(255, int(v*f))) for v in c[:3])
def dither_band(im, y0, y1, c0, c1, x0=0, x1=None):
    """vertical gradient c0->c1 with ordered dithering between 6 palette steps (16-bit style)"""
    x1 = im.width if x1 is None else x1
    steps = [mix(c0, c1, k/5) for k in range(6)]
    px = im.load()
    for y in range(y0, y1):
        t = (y-y0)/max(1, y1-y0-1)*5
        k = int(t); f = t-k
        for x in range(x0, x1):
            px[x, y] = steps[min(5, k+1)] + (255,) if f*16 > BAYER[y % 4][x % 4] else steps[k] + (255,)

def sky():
    im = Image.new('RGBA', (640, 360), (0, 0, 0, 255)); d = ImageDraw.Draw(im)
    dither_band(im, 0, 150, (14, 10, 38), (46, 26, 80))
    dither_band(im, 150, 260, (46, 26, 80), (122, 52, 104))
    dither_band(im, 260, 360, (122, 52, 104), (176, 84, 104))
    r = random.Random(1)
    for _ in range(70):
        x, y = r.randrange(640), r.randrange(150)
        d.point((x, y), fill=(200, 200, 255) if r.random() < .3 else (120, 110, 180))
    # moon with a dithered halo
    cx, cy = 470, 70
    px = im.load()
    for y in range(cy-40, cy+41):
        for x in range(cx-40, cx+41):
            dd = ((x-cx)**2+(y-cy)**2)**.5
            if dd < 14: px[x, y] = (236, 230, 206, 255) if dd < 13 else (190, 180, 170, 255)
            elif dd < 38 and (38-dd)/24*16 > BAYER[y % 4][x % 4] + 6:
                px[x, y] = mix(px[x, y][:3], (120, 96, 150), 0.6) + (255,)
    for (x, y, rr) in [(464, 64, 3), (474, 74, 2), (468, 77, 2)]:
        d.ellipse([x-rr, y-rr, x+rr, y+rr], fill=(206, 198, 180))
    return im

def skyline(w, h, base_col, win_cols, seed, hmin, hmax, wmin, wmax, wins=0.25, ant=True):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    r = random.Random(seed); x = -10
    while x < w:
        bw = r.randint(wmin, wmax); bh = r.randint(hmin, hmax); top = h-bh
        col = shade(base_col, r.uniform(0.85, 1.12))
        R(d, x, top, bw, bh, col)
        R(d, x, top, 2, bh, shade(col, 1.25))
        kind = r.random()
        if kind < .25:  # stepped top
            R(d, x+bw//4, top-10, bw//2, 10, col)
        elif kind < .45 and ant:  # antenna with a red light
            R(d, x+bw//2, top-24, 2, 24, col); d.point((x+bw//2, top-25), fill=(255, 60, 60))
        elif kind < .6:  # water tower
            R(d, x+6, top-14, 14, 10, shade(col, .8)); R(d, x+8, top-4, 2, 4, col); R(d, x+16, top-4, 2, 4, col)
        for yy in range(top+6, h-6, 8):
            for xx in range(x+4, x+bw-5, 6):
                if r.random() < wins:
                    R(d, xx, yy, 3, 4, r.choice(win_cols))
        x += bw + r.randint(-4, 6)
    # wrap seamlessly: copy the left edge over the right
    edge = im.crop((0, 0, 40, h)); im.paste(Image.new('RGBA', (40, h), (0, 0, 0, 0)), (w-40, 0)); im.alpha_composite(edge, (w-40, 0))
    return im

def glow(size=64):
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0)); px = im.load(); c = size/2
    for y in range(size):
        for x in range(size):
            dd = ((x+.5-c)**2+(y+.5-c)**2)**.5/c
            a = max(0.0, 1-dd)**1.6
            q = int(a*5 + (BAYER[y % 4][x % 4]/16))  # 5 dithered alpha steps
            if q > 0: px[x, y] = (255, 255, 255, min(255, q*44))
    return im

def vignette():
    im = Image.new('RGBA', (640, 360), (0, 0, 0, 0)); px = im.load()
    for y in range(360):
        for x in range(640):
            dx, dy = (x-320)/320, (y-180)/200
            a = max(0.0, (dx*dx+dy*dy)**.5 - 0.72)
            q = int(a*10 + BAYER[y % 4][x % 4]/16)
            if q > 0: px[x, y] = (8, 4, 20, min(170, q*40))
    return im

# ---------- storefront modules (world-locked front layer) ----------
SIGNS = []   # [x, y, r, g, b, size] neon glow spots for the game
LAMPS = []   # x of street lamps (light pools on the sidewalk)
def window(d, x, y, w, h, lit, r):
    R(d, x-1, y-1, w+2, h+2, K)
    if lit:
        top = r.choice([(255, 206, 120), (170, 220, 255), (255, 170, 120)])
        R(d, x, y, w, h, top); R(d, x, y+h//2, w, h-h//2, shade(top, .8))
        if r.random() < .5: R(d, x+1, y, w//3, h, shade(top, .65))  # curtain
    else:
        R(d, x, y, w, h, (30, 34, 62)); R(d, x+1, y+1, 2, h-2, (54, 60, 96))
    R(d, x-2, y+h+1, w+4, 2, (130, 124, 140))  # sill
def bricks(d, x, y, w, h, col, r):
    R(d, x, y, w, h, col)
    dark = shade(col, .78); lite = shade(col, 1.14)
    for yy in range(y+3, y+h, 6):
        R(d, x, yy, w, 1, dark)
        off = 0 if (yy//6) % 2 else 6
        for xx in range(x+off, x+w, 12): R(d, xx, yy-5, 1, 5, dark)
    for _ in range(w*h//400):
        R(d, x+r.randrange(w), y+r.randrange(h), 3, 1, lite)

def neon(d, x, y, s, col, sc=2):
    w = text_w(s, sc)
    R(d, x-4, y-4, w+8, 7*sc+8, (20, 14, 30)); R(d, x-3, y-3, w+6, 7*sc+6, (36, 26, 50))
    text(d, x, y, s, shade(col, .55), sc)
    text(d, x-1, y-1, s, col, sc)
    SIGNS.append([x+w//2, y+7*sc//2, col[0], col[1], col[2], max(48, w+40)])

def module(d, x, kind, r):
    """one building section; returns width"""
    w = {'shop': 224, 'nexus': 288, 'alley': 96, 'arcade': 256, 'noodle': 208, 'laundry': 192}[kind]
    h = r.randint(150, 214) if kind != 'alley' else 0
    top = LANE_TOP - h
    if kind == 'alley':
        R(d, x, 60, w, LANE_TOP-60, (16, 12, 30))
        for yy in range(90, LANE_TOP-30, 34):  # fire escape
            R(d, x+10, yy, w-20, 2, (70, 64, 90)); R(d, x+10, yy-12, 1, 12, (70, 64, 90)); R(d, x+w-11, yy-12, 1, 12, (70, 64, 90))
            for k in range(x+12, x+w-12, 5): R(d, k, yy-10, 1, 10, (46, 42, 64))
        R(d, x+20, LANE_TOP-30, 46, 30, K); R(d, x+21, LANE_TOP-29, 44, 28, (40, 96, 70)); R(d, x+21, LANE_TOP-29, 44, 4, (60, 130, 96))
        for k in range(3): R(d, x+70+k*6, LANE_TOP-14+k, 5, 14-k, (60, 54, 70))
        return w
    col = r.choice([(118, 56, 52), (96, 74, 70), (70, 76, 104), (92, 64, 98), (60, 92, 100)])
    if kind == 'nexus': col = (56, 66, 96)
    if kind == 'nexus':
        R(d, x, top, w, h, (46, 54, 84))
        for yy in range(top+8, LANE_TOP-70, 18):
            for xx in range(x+8, x+w-12, 22):
                R(d, xx, yy, 18, 12, (90, 140, 200) if r.random() < .55 else (36, 44, 74)); R(d, xx, yy, 18, 1, (170, 210, 240))
        R(d, x, top, w, 3, (120, 130, 170))
    else:
        bricks(d, x, top, w, h, col, r)
        R(d, x, top, w, 4, shade(col, 1.3)); R(d, x, top+4, w, 2, shade(col, .6))
        for yy in range(top+18, LANE_TOP-84, 36):
            for xx in range(x+14, x+w-26, 36):
                window(d, xx, yy, 18, 22, r.random() < .5, r)
    R(d, x, top, 1, h, K); R(d, x+w-1, top, 1, h, K)
    # ground floor: shop window, door, sign
    gy = LANE_TOP - 74
    R(d, x, gy-6, w, 80, shade(col, .55)); R(d, x, gy-6, w, 2, shade(col, .9))
    if kind == 'nexus':
        R(d, x+20, gy+6, w-40, 68, K); R(d, x+21, gy+7, w-42, 66, (110, 170, 220)); R(d, x+21, gy+7, w-42, 30, (150, 200, 240))
        for k in range(x+21, x+w-21, 40): R(d, k, gy+7, 2, 66, (60, 80, 110))
        R(d, x+w//2-24, gy+20, 48, 54, (220, 236, 250)); R(d, x+w//2-1, gy+20, 2, 54, (110, 130, 150))
        neon(d, x+w//2-text_w('NEXUS DYNAMICS', 2)//2, gy-34, 'NEXUS DYNAMICS', (120, 230, 255))
        return w
    sw = w-70
    R(d, x+10, gy+8, sw, 50, K); dither_band_img = None
    lit = r.choice([(255, 210, 140), (170, 230, 255), (255, 160, 200)])
    R(d, x+11, gy+9, sw-2, 48, lit); R(d, x+11, gy+33, sw-2, 24, shade(lit, .82))
    for k in range(4):  # shelves / silhouettes inside
        R(d, x+16+k*(sw//4), gy+40, sw//4-8, 3, shade(lit, .55))
    R(d, x+11, gy+9, 3, 48, (255, 255, 255))
    R(d, x+w-52, gy+4, 36, 70, K); R(d, x+w-51, gy+5, 34, 69, (70, 52, 44)); R(d, x+w-49, gy+8, 30, 28, shade(lit, .9)); R(d, x+w-24, gy+42, 3, 4, (230, 200, 90))
    # awning
    aw = r.choice([[(200, 50, 60), (240, 230, 220)], [(40, 130, 90), (230, 230, 210)], [(60, 80, 170), (230, 230, 240)]])
    for k in range(0, sw+10, 12):
        R(d, x+6+k, gy-2, 12, 10, aw[(k//12) % 2])
    R(d, x+6, gy+8, sw+10, 2, K)
    label, nc = {'shop': (r.choice(['PIZZA', 'COFFEE', 'DELI']), (255, 120, 80)), 'arcade': ('ARCADE', (255, 90, 230)),
                 'noodle': ('NOODLES', (255, 220, 90)), 'laundry': ('LAUNDRY', (120, 255, 170))}[kind]
    neon(d, x+12+(sw-text_w(label, 2))//2, gy-30, label, nc)
    if r.random() < .6:
        neon(d, x+w-44, gy-60, 'OPEN', (255, 80, 90), 1)
    return w

def front():
    im = Image.new('RGBA', (LEVEL_W, LANE_TOP), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    r = random.Random(7); x = 0
    order = ['shop', 'arcade', 'alley', 'noodle', 'nexus', 'laundry', 'shop', 'alley', 'arcade', 'noodle', 'shop', 'laundry', 'alley', 'shop']
    i = 0
    while x < LEVEL_W:
        w = module(d, x, order[i % len(order)], r); x += w; i += 1
    # street lamps against the buildings every ~300 px
    for lx in range(150, LEVEL_W, 310):
        R(d, lx, 120, 4, LANE_TOP-120, K); R(d, lx+1, 120, 2, LANE_TOP-120, (70, 70, 90))
        R(d, lx-10, 116, 24, 6, K); R(d, lx-9, 117, 22, 4, (255, 236, 170))
        LAMPS.append(lx+2)
        SIGNS.append([lx+2, 122, 255, 230, 160, 70])
    return im

def ground():
    H = 360 - LANE_TOP
    im = Image.new('RGBA', (LEVEL_W, H), (0, 0, 0, 255)); d = ImageDraw.Draw(im)
    r = random.Random(11)
    slab = (120, 112, 136)
    dither_band(im, 0, 72, (78, 70, 98), (128, 118, 142))
    # building base shadow
    for y in range(0, 6): R(d, 0, y, LEVEL_W, 1, mix((30, 24, 44), (78, 70, 98), y/6))
    rows = [6, 18, 32, 50, 72]  # slab rows get taller toward the viewer
    for y in rows[1:-1]: R(d, 0, y, LEVEL_W, 1, (66, 58, 84))
    for i in range(len(rows)-1):
        y0, y1 = rows[i], rows[i+1]; step = 30 + i*8
        for x in range(r.randrange(step), LEVEL_W, step):
            R(d, x, y0, 1, y1-y0, (70, 62, 88))
    for _ in range(LEVEL_W//14):  # wear, gum, cracks
        x, y = r.randrange(LEVEL_W), r.randrange(8, 70)
        R(d, x, y, r.choice([1, 2, 3]), 1, r.choice([(96, 88, 114), (150, 140, 160), (60, 54, 76)]))
    for _ in range(LEVEL_W//160):  # puddles reflecting the neon
        x, y = r.randrange(LEVEL_W-60), r.randrange(20, 60); w = r.randint(24, 56)
        d.ellipse([x, y, x+w, y+8], fill=(60, 52, 96)); d.ellipse([x+4, y+2, x+w-6, y+5], fill=(150, 90, 170))
    # curb and road
    R(d, 0, 72, LEVEL_W, 2, (190, 184, 200)); R(d, 0, 74, LEVEL_W, 4, (110, 104, 124)); R(d, 0, 78, LEVEL_W, 1, K)
    R(d, 0, 79, LEVEL_W, H-79, (34, 32, 46))
    for x in range(0, LEVEL_W, 64): R(d, x+10, 88, 30, 2, (200, 180, 90))
    for _ in range(LEVEL_W//10): d.point((r.randrange(LEVEL_W), r.randrange(80, H)), fill=(52, 50, 66))
    return im

def fore():
    im = Image.new('RGBA', (1600, 60), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    def hydrant(x):
        R(d, x, 22, 16, 38, K); R(d, x+1, 23, 14, 36, (150, 30, 40)); R(d, x-3, 34, 22, 6, K); R(d, x-2, 35, 20, 4, (180, 50, 56)); R(d, x+2, 23, 3, 36, (210, 80, 80))
    def trash(x):
        R(d, x, 14, 28, 46, K); R(d, x+1, 15, 26, 45, (50, 70, 64)); R(d, x-2, 10, 32, 6, K); R(d, x-1, 11, 30, 4, (70, 96, 88))
        for k in range(4): R(d, x+4+k*6, 18, 2, 40, (36, 52, 48))
    def meter(x):
        R(d, x+4, 20, 4, 40, K); R(d, x, 6, 12, 16, K); R(d, x+1, 7, 10, 14, (90, 96, 110)); R(d, x+3, 9, 6, 5, (180, 220, 200))
    def bollard(x):
        R(d, x, 30, 10, 30, K); R(d, x+1, 31, 8, 29, (210, 180, 60)); R(d, x+1, 38, 8, 4, K)
    for x, f in [(80, hydrant), (420, trash), (700, meter), (760, meter), (1060, bollard), (1090, bollard), (1120, bollard), (1400, trash)]:
        f(x)
    return im

if __name__ == '__main__':
    for ch, g in F5.items():
        assert len(g) == (21 if ch == 'I' else 35), (ch, len(g))
    os.makedirs(OUT, exist_ok=True)
    sky().save(f'{OUT}/placeholder_street_sky.png')
    skyline(1280, 240, (40, 30, 76), [(120, 100, 160), (210, 170, 100)], 3, 60, 200, 30, 70, 0.12).save(f'{OUT}/placeholder_street_far.png')
    skyline(1280, 260, (30, 22, 52), [(250, 200, 120), (140, 200, 255), (80, 70, 110)], 4, 90, 230, 50, 110, 0.3).save(f'{OUT}/placeholder_street_mid.png')
    front().save(f'{OUT}/placeholder_street_front.png')
    ground().save(f'{OUT}/placeholder_street_ground.png')
    fore().save(f'{OUT}/placeholder_street_fore.png')
    glow().save(f'{OUT}/placeholder_glow.png')
    vignette().save(f'{OUT}/placeholder_vignette.png')
    with open(f'{OUT}/street_layout.gd', 'w') as f:
        f.write('## Generated by tools/make_street_placeholders.py: light spots in the placeholder street.\n')
        f.write('## Replace together with placeholder_street_front.png when final art lands.\nextends RefCounted\n\n')
        f.write('const LANE_TOP := %d\nconst LEVEL_W := %d\n' % (LANE_TOP, LEVEL_W))
        f.write('## [x, y, r, g, b, size]: neon signs and lamp heads (additive glow)\nconst GLOWS := [\n')
        for s in SIGNS: f.write('\t[%d, %d, %d, %d, %d, %d],\n' % tuple(s))
        f.write(']\n## street lamps: light pools on the sidewalk\nconst LAMPS := %s\n' % LAMPS)
    print('signs', len(SIGNS), 'lamps', len(LAMPS))
