# Turn the cut-out video frames (RGBA, 1280x720) into a game sprite strip:
# fixed crop and scale for every frame (no jitter), feet on the cell's ground line,
# filled holes (glasses), hard alpha, a shared palette, optional 1 px dark outline.
import sys, os, json
import numpy as np, cv2
from PIL import Image
SRC, OUT, NAME = sys.argv[1], sys.argv[2], sys.argv[3]
OUTLINE = '--outline' in sys.argv
info = json.load(open(os.path.join(SRC, 'cuts.json')))
n = len(info['frames'])
CELL_W, CELL_H, AX, AY = 160, 128, 80, 124
# standing height in the video: median from top of hair to the soles
tops = sorted(f['top'] for f in info['frames']); bottoms = sorted(f['bottom'] for f in info['frames'])
ground = int(np.median(bottoms)) + 2
height = ground - tops[len(tops) // 2]
scale = 120.0 / height
cx = int(np.median([f['cx'] for f in info['frames']])) - 8
print('ground y %d, height %d px, scale %.4f, centre x %d' % (ground, height, scale, cx))
cells = []
for k in range(n):
    im = cv2.imread(os.path.join(SRC, 'cut_%02d.png' % k), cv2.IMREAD_UNCHANGED)
    a = (im[..., 3] > 127).astype(np.uint8)
    # fill holes fully enclosed by the body (the glasses lenses, gaps between arm and torso stay open)
    inv = (1 - a).copy(); h, w = a.shape
    ff = np.zeros((h + 2, w + 2), np.uint8); cv2.floodFill(inv, ff, (0, 0), 2)
    holes = (inv == 1)
    n_, lab, st, _ = cv2.connectedComponentsWithStats(holes.astype(np.uint8), 4)
    for j in range(1, n_):
        if st[j, cv2.CC_STAT_AREA] < 2500:
            a[lab == j] = 1
    rgb = cv2.cvtColor(im[..., :3], cv2.COLOR_BGR2RGB).astype(np.float32)
    # crop a window that maps exactly onto the cell, then area-average down
    sw, sh = CELL_W / scale, CELL_H / scale
    x0 = cx - AX / scale; y0 = ground - AY / scale
    M = np.float32([[scale, 0, -x0 * scale], [0, scale, -y0 * scale]])
    pre = rgb * a[..., None]
    small = cv2.warpAffine(cv2.resize(pre, None, fx=1, fy=1), M, (CELL_W, CELL_H), flags=cv2.INTER_AREA)
    sa = cv2.warpAffine(a.astype(np.float32), M, (CELL_W, CELL_H), flags=cv2.INTER_AREA)
    # INTER_AREA via warpAffine only resamples; do a proper box filter instead
    big = cv2.resize(pre, (int(round(w * scale)), int(round(h * scale))), interpolation=cv2.INTER_AREA)
    ba = cv2.resize(a.astype(np.float32), (int(round(w * scale)), int(round(h * scale))), interpolation=cv2.INTER_AREA)
    ox, oy = int(round(x0 * scale)), int(round(y0 * scale))
    small = big[oy:oy + CELL_H, ox:ox + CELL_W]; sa = ba[oy:oy + CELL_H, ox:ox + CELL_W]
    col = small / np.maximum(sa[..., None], 1e-3)
    alpha = sa > 0.5
    # thin bits sticking out behind the upper back are leftovers of signs/lamps: open them away
    opened = cv2.morphologyEx(alpha.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)).astype(bool)
    zone = np.zeros_like(alpha); zone[30:88, :AX - 10] = True
    alpha = np.where(zone, alpha & opened, alpha)
    n_, lab, st, _ = cv2.connectedComponentsWithStats(alpha.astype(np.uint8), 8)
    if n_ > 1:
        alpha = lab == 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
    cells.append((col, alpha))
# one palette for the whole strip
opaque = np.concatenate([c[al] for c, al in cells]).astype(np.uint8)
pal_img = Image.fromarray(opaque.reshape(-1, 1, 3)).quantize(colors=40, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
strip = Image.new('RGBA', (CELL_W * n, CELL_H), (0, 0, 0, 0))
OUT_COL = (34, 20, 28, 255)
for k, (c, al) in enumerate(cells):
    rgb = Image.fromarray(np.clip(c, 0, 255).astype(np.uint8))
    q = rgb.quantize(palette=pal_img, dither=Image.Dither.NONE).convert('RGB')
    arr = np.dstack([np.array(q), (al * 255).astype(np.uint8)])
    if OUTLINE:
        edge = cv2.dilate(al.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & ~al
        arr[edge] = OUT_COL
    strip.paste(Image.fromarray(arr, 'RGBA'), (k * CELL_W, 0))
os.makedirs(OUT, exist_ok=True)
strip.save(os.path.join(OUT, NAME + '.png'))
json.dump({'frames': n, 'cell': [CELL_W, CELL_H], 'anchor': [AX, AY], 'clipped': [],
           'source': 'gemini walk video (user), frames %d-%d of a %d-frame loop, cut out + downscaled by tools/video_sprites' % (info['start'], info['start'] + info['period'] - 1, info['period'])},
          open(os.path.join(OUT, NAME + '.json'), 'w'))
print('wrote', NAME, strip.size)
