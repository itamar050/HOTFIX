#!/usr/bin/env python3
"""import_art.py: turn AI-generated sprite strips into clean game sprites.

For every art/raw/<character>_<animation>.(png|webp) with a magenta background:
  1. key out the magenta (and the pink fringe that compression leaves around edges);
  2. split the strip into frames at the empty columns between them;
  3. scale each frame so the character is the game's height, choosing the most common
     color in each block (no blur), which snaps "fake" pixel art onto a real pixel grid;
  4. reduce every frame of a character to one shared palette;
  5. line the frames up: feet on one baseline, body centered (center of the legs);
  6. write art/sprites/<character>_<animation>.png (a strip of fixed-size cells) and a
     .json with the frame count, cell size and anchor, plus previews and a report.

Backgrounds (stageN_*) are scaled to the game's 640x360 and snapped the same way.

Usage: python3 tools/import_art.py [--height 120] [--preview]
"""
import argparse
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, 'art', 'raw')
OUT = os.path.join(ROOT, 'art', 'sprites')
PREVIEW = os.path.join(ROOT, 'art', 'preview')
GAME_W, GAME_H = 640, 360
CONFIG = {}
CELL_W, CELL_H = 160, 128  # sprite cell; anchor (feet center) at (CELL_W / 2, CELL_H - 4)


def key_magenta(rgb):
    """Alpha mask: False where the pixel is the magenta background or its fringe."""
    r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
    # magenta-ness: red and blue high and close together, green low
    mag = (np.minimum(r, b) - g)
    bg = (mag > 120) & (np.abs(r - b) < 70)
    return ~bg


def despill(rgb, alpha):
    """Pull the remaining pink tint off edge pixels (pixels next to the background)."""
    out = rgb.astype(int).copy()
    edge = alpha & ~(np.roll(alpha, 1, 0) & np.roll(alpha, -1, 0) & np.roll(alpha, 1, 1) & np.roll(alpha, -1, 1))
    r, g, b = out[..., 0], out[..., 1], out[..., 2]
    pink = edge & (np.minimum(r, b) - g > 40)
    m = np.minimum(r, b)[pink] - g[pink]
    out[..., 0][pink] -= m // 2
    out[..., 2][pink] -= m // 2
    return np.clip(out, 0, 255).astype(np.uint8)


def erode_fringe(rgb, alpha, passes=2):
    """Remove pink-tinted pixels on the silhouette edge (the anti-aliased blend between
    the art and the magenta background); the art's own dark outline is underneath."""
    r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
    pinkish = (np.minimum(r, b) - g > 28) & (r > 90) & (b > 70)
    a = alpha.copy()
    for _ in range(passes):
        edge = a & ~(np.roll(a, 1, 0) & np.roll(a, -1, 0) & np.roll(a, 1, 1) & np.roll(a, -1, 1))
        a &= ~(edge & pinkish)
    return a


def label_frames(alpha, step=4, min_share=0.08):
    """Find the figures as connected blobs (on a 1/step grid, so a fist reaching into
    the next frame's space still belongs to its own figure). Returns per-frame full-size
    masks, ordered left to right. Small detached bits join the nearest figure."""
    h, w = alpha.shape
    gh, gw = (h + step - 1) // step, (w + step - 1) // step
    pad = np.zeros((gh * step, gw * step), bool)
    pad[:h, :w] = alpha
    grid = pad.reshape(gh, step, gw, step).any(axis=(1, 3))
    lab = np.zeros(grid.shape, np.int32)
    n = 0
    for sy, sx in zip(*np.nonzero(grid)):
        if lab[sy, sx]:
            continue
        n += 1
        stack = [(sy, sx)]
        lab[sy, sx] = n
        while stack:
            y, x = stack.pop()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < gh and 0 <= xx < gw and grid[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = n
                    stack.append((yy, xx))
    sizes = np.bincount(lab.ravel())[1:]
    big = [i + 1 for i, s in enumerate(sizes) if s >= min_share * sizes.max()]
    centers = {i: np.nonzero(lab == i)[1].mean() for i in range(1, n + 1)}
    owner = {i: i if i in big else min(big, key=lambda b: abs(centers[b] - centers[i])) for i in range(1, n + 1)}
    full = np.repeat(np.repeat(lab, step, 0), step, 1)[:h, :w]
    masks = []
    for b in sorted(big, key=lambda b: centers[b]):
        ids = [i for i in owner if owner[i] == b]
        masks.append(np.isin(full, ids) & alpha)
    return masks


def mode_downsample(rgb, alpha, scale):
    """Downscale by `scale` (< 1): each output pixel takes the most common opaque color of
    its source block, or stays transparent when the block is mostly background."""
    h, w = alpha.shape
    oh, ow = max(1, round(h * scale)), max(1, round(w * scale))
    out = np.zeros((oh, ow, 4), np.uint8)
    ys = np.linspace(0, h, oh + 1).astype(int)
    xs = np.linspace(0, w, ow + 1).astype(int)
    q = (rgb // 8).astype(np.int32)
    code = (q[..., 0] << 10) | (q[..., 1] << 5) | q[..., 2]
    for j in range(oh):
        for i in range(ow):
            a = alpha[ys[j]:ys[j + 1], xs[i]:xs[i + 1]]
            if a.size == 0 or a.mean() < 0.5:
                continue
            c = code[ys[j]:ys[j + 1], xs[i]:xs[i + 1]][a]
            vals, counts = np.unique(c, return_counts=True)
            top = vals[counts.argmax()]
            pix = rgb[ys[j]:ys[j + 1], xs[i]:xs[i + 1]][a][c == top]
            out[j, i, :3] = pix.mean(0)
            out[j, i, 3] = 255
    return out


def quantize_all(frames, colors):
    """One shared palette for all frames of a character (keeps colors consistent)."""
    opaque = np.concatenate([f[f[..., 3] > 0][:, :3] for f in frames])
    side = int(np.ceil(np.sqrt(len(opaque))))
    pad = np.zeros((side * side, 3), np.uint8)
    pad[:len(opaque)] = opaque
    pal_img = Image.fromarray(pad.reshape(side, side, 3)).quantize(colors, method=Image.Quantize.MEDIANCUT)
    out = []
    for f in frames:
        rgb = Image.fromarray(f[..., :3]).quantize(palette=pal_img, dither=Image.Dither.NONE).convert('RGB')
        g = np.dstack([np.asarray(rgb), f[..., 3]])
        out.append(g)
    return out, len(pal_img.getpalette()) // 3


def outline_fix(f):
    """Make sure the silhouette has a dark 1px outline (downscaling can thin it)."""
    a = f[..., 3] > 0
    edge = a & ~(np.roll(a, 1, 0) & np.roll(a, -1, 0) & np.roll(a, 1, 1) & np.roll(a, -1, 1))
    lum = f[..., :3].astype(int).sum(2)
    bright = edge & (lum > 200)
    f = f.copy()
    f[..., :3][bright] = (f[..., :3][bright].astype(int) * 0.45).astype(np.uint8)
    return f


def anchor(f):
    """Feet anchor: x = center of the opaque pixels in the bottom 30% (the legs), y = bottom."""
    a = f[..., 3] > 0
    h = a.shape[0]
    low = a[int(h * 0.7):]
    ys, xs = np.nonzero(low)
    ax = xs.mean() if len(xs) else a.shape[1] / 2
    return ax, h


def import_strip(path, target_h, report, all_frames):
    name = os.path.splitext(os.path.basename(path))[0]
    rgb = np.asarray(Image.open(path).convert('RGB'))
    alpha = key_magenta(rgb)
    alpha = erode_fringe(rgb, alpha)
    rgb = despill(rgb, alpha)
    masks = label_frames(alpha)
    boxes = []
    for m in masks:
        ys, xs = np.nonzero(m)
        boxes.append((xs.min(), xs.max() + 1, ys.min(), ys.max() + 1, m))
    heights = [int(b[3] - b[2]) for b in boxes]
    med = float(np.median(heights)) if heights else 1
    # Scale reference: the source height of the character standing upright. Taken from
    # art/raw/import.json ("standing_px"), or else the first frame is a standing
    # reference pose: it is measured and dropped.
    cfg = CONFIG.get(name, {})
    if 'standing_px' in cfg:
        ref = cfg['standing_px']
    elif boxes and not cfg.get('no_ref'):
        ref = heights[0]
        boxes, heights = boxes[1:], heights[1:]
    else:
        ref = med
    scale = target_h / ref
    frames = []
    for x0, x1, y0, y1, m in boxes:
        frames.append(mode_downsample(rgb[y0:y1, x0:x1], m[y0:y1, x0:x1], scale))
    bottoms = [b[3] for b in boxes]
    report[name] = {
        'frames': len(frames), 'source_heights': heights, 'standing_ref_px': int(ref), 'scale': round(scale, 3),
        'baseline_spread_px': int(max(bottoms) - min(bottoms)) if bottoms else 0,
        'height_spread_pct': round(100 * (max(heights) - min(heights)) / med, 1) if heights else 0,
    }
    all_frames[name] = frames


def write_strip(name, frames):
    cells = Image.new('RGBA', (CELL_W * len(frames), CELL_H), (0, 0, 0, 0))
    meta = {'frames': len(frames), 'cell': [CELL_W, CELL_H], 'anchor': [CELL_W // 2, CELL_H - 4], 'clipped': []}
    for i, f in enumerate(frames):
        ax, ay = anchor(f)
        ox = int(round(CELL_W / 2 - ax)) + i * CELL_W
        oy = int((CELL_H - 4) - ay)
        if ox < i * CELL_W or ox + f.shape[1] > (i + 1) * CELL_W or oy < 0:
            meta['clipped'].append(i)
        cells.alpha_composite(Image.fromarray(f, 'RGBA'), (max(i * CELL_W, ox), max(0, oy)),
                              (max(0, i * CELL_W - ox), max(0, -oy)))
    cells.save(os.path.join(OUT, name + '.png'))
    with open(os.path.join(OUT, name + '.json'), 'w') as fh:
        json.dump(meta, fh)
    return cells


def import_background(path, report):
    name = os.path.splitext(os.path.basename(path))[0]
    im = Image.open(path).convert('RGB')
    cfg = CONFIG.get(name, {})
    if 'crop' in cfg:  # e.g. pillar center to pillar center, so the layer loops seamlessly
        im = im.crop(tuple(cfg['crop']))
    rgb = np.asarray(im)
    if 'scale' in cfg:
        scale = cfg['scale']
    elif name.endswith('_floor'):  # floor strips keep their aspect ratio at the game's width
        scale = GAME_W * 2 / im.width
    else:
        scale = GAME_H / im.height
    out = mode_downsample(rgb, np.ones(rgb.shape[:2], bool), scale)
    img = Image.fromarray(out, 'RGBA').convert('RGB')
    img.save(os.path.join(OUT, name + '.png'))
    # how well does it tile horizontally? compare the left and right edge columns
    a = np.asarray(img).astype(int)
    seam = float(np.abs(a[:, 0] - a[:, -1]).mean())
    report[name] = {'size': list(img.size), 'scale': round(scale, 3), 'seam_difference': round(seam, 1)}
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--height', type=int, default=120, help='standing character height in game pixels')
    ap.add_argument('--colors', type=int, default=48, help='palette size per character')
    ap.add_argument('--preview', action='store_true', help='write previews to art/preview')
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    cfg_path = os.path.join(RAW, 'import.json')
    if os.path.exists(cfg_path):
        CONFIG.update(json.load(open(cfg_path)))
    report, chars = {}, {}
    files = sorted(glob.glob(os.path.join(RAW, '*.png')) + glob.glob(os.path.join(RAW, '*.webp')))
    if not files:
        sys.exit('no images in art/raw')
    for path in files:
        name = os.path.splitext(os.path.basename(path))[0]
        if name.startswith('stage'):
            import_background(path, report)
        else:
            import_strip(path, args.height, report, chars)
    # one palette per character
    by_char = {}
    for name, frames in chars.items():
        by_char.setdefault(name.split('_')[0], []).append(name)
    strips = {}
    for char, names in by_char.items():
        flat = [f for n in names for f in chars[n]]
        q, ncol = quantize_all(flat, args.colors)
        k = 0
        for n in names:
            fr = [outline_fix(f) for f in q[k:k + len(chars[n])]]
            k += len(chars[n])
            strips[n] = write_strip(n, fr)
            report[n]['palette'] = ncol
            report[n]['clipped_frames'] = json.load(open(os.path.join(OUT, n + '.json')))['clipped']
    with open(os.path.join(OUT, 'report.json'), 'w') as fh:
        json.dump(report, fh, indent=1)
    print(json.dumps(report, indent=1))
    if args.preview:
        os.makedirs(PREVIEW, exist_ok=True)
        for n, im in strips.items():
            im.resize((im.width * 3, im.height * 3), Image.NEAREST).save(os.path.join(PREVIEW, n + '_x3.png'))
            frames = [im.crop((i * CELL_W, 0, (i + 1) * CELL_W, CELL_H)) for i in range(im.width // CELL_W)]
            bg = [Image.new('RGBA', (CELL_W, CELL_H), (40, 36, 60, 255)) for _ in frames]
            gif = [Image.alpha_composite(b, f).resize((CELL_W * 3, CELL_H * 3), Image.NEAREST).convert('P') for b, f in zip(bg, frames)]
            gif[0].save(os.path.join(PREVIEW, n + '.gif'), save_all=True, append_images=gif[1:], duration=110, loop=0)


if __name__ == '__main__':
    main()
