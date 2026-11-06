#!/usr/bin/env python3
"""rig_walk.py: animate a walk and a run cycle from one approved side-view frame.

AI image tools cannot draw a walk cycle where the legs alternate, so we rig the art like
a cut-out puppet (as Spine or Flash animation does):
  - the source figure is cut into torso (+head, bag), one leg and one arm;
  - each leg is a thigh and a shin (+shoe), each arm an upper arm and a forearm (+hand);
  - BOTH legs are made from the fully visible near leg (the far one is mostly hidden
    behind it in a side view); the copy behind the body is drawn darker;
  - every frame poses the parts by rotation at 4x the game resolution, then shrinks the
    result 4x by taking the most common color of each 4x4 block, which keeps rotated
    pixel art crisp (a cheap RotSprite).
The near leg always stays in front; "alternating" means it is forward in half of the
cycle and behind in the other half, with the far (darker) leg forward.

Usage: python3 tools/rig_walk.py            -> art/sprites/bro_walk.png/.json, bro_run.png/.json
       python3 tools/rig_walk.py --preview  -> also art/preview/bro_rig_*.png
Parameters (joints, cut lines) are in RIGS below, in the source's 2x-game-size pixels.
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, 'art', 'sprites')
K = 2  # work at 4x game size: the source is 2x, upscaled 2x more

RIGS = {
    'bro': {
        'source': 'art/raw/bro_walk.png', 'figure': 0,  # the standing reference: straight legs and arms
        'height2x': 240,   # standing height at 2x game size
        'hip': (56, 138), 'knee': (57, 185), 'ankle': (60, 222),  # the near leg (right in the image)
        'leg_x': 45,                                       # the near leg is everything right of this, below the hip
        'shoulder': (72, 97), 'elbow': (74, 124), 'hand': (75, 150),  # the template arm (front, free hanging)
        'arm_box': (64, 92, 87, 160),                      # x0, y0, x1, y1 of the template arm
        'front_arm_box': (0, 92, 30, 160),                 # the other arm, painted on the torso: removed
        'near_shoulder': (72, 97),                         # where the near arm attaches
        'hand_x': 69,                                      # below the hip, the hand is right of this; the jeans left
        'far_offset': (-7, -1),                            # far hip sits a little behind the near one
        'far_shoulder': (20, 97),                          # the far arm hangs from the back shoulder
        'far_shade': 0.72,
    },
}


def load_source(rig):
    rgb = np.asarray(Image.open(os.path.join(ROOT, rig['source'])).convert('RGB'))
    a = ia.erode_fringe(rgb, ia.key_magenta(rgb))
    rgb = ia.despill(rgb, a)
    masks = ia.label_frames(a)
    ref = int(np.ptp(np.nonzero(masks[0])[0]) + 1)
    m = masks[rig['figure']]
    ys, xs = np.nonzero(m)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    src = ia.mode_downsample(rgb[y0:y1, x0:x1], m[y0:y1, x0:x1], rig['height2x'] / ref)
    return src  # RGBA at 2x game size


def split_line_x(points, y):
    """x of a polyline (list of (x, y), increasing y) at height y."""
    for (xa, ya), (xb, yb) in zip(points, points[1:]):
        if ya <= y <= yb:
            return xa + (xb - xa) * (y - ya) / max(1, yb - ya)
    return points[-1][0] if y > points[-1][1] else points[0][0]


def angle_of(a, b):
    """angle of segment a->b from straight down, positive = forward (+x)."""
    return math.degrees(math.atan2(b[0] - a[0], b[1] - a[1]))


def cut_parts(src, rig):
    h, w = src.shape[:2]
    alpha = src[..., 3] > 0
    yy, xx = np.mgrid[0:h, 0:w]
    hx, hy = rig['hip']
    below = yy >= hy - 2
    x0, y0, x1, y1 = rig['arm_box']
    in_arm_box = (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
    hand_zone = in_arm_box & (xx >= rig['hand_x'])  # the hanging hand, below the hip
    near_leg = alpha & below & (xx >= rig['leg_x']) & ~hand_zone
    # thigh / shin: cut perpendicular to the thigh at the knee
    kx, ky = rig['knee']
    tdir = np.array([kx - hx, ky - hy], float)
    tdir /= np.linalg.norm(tdir)
    side = (xx - kx) * tdir[0] + (yy - ky) * tdir[1]
    shin = near_leg & (side > 0)
    thigh = near_leg & (side <= 0)
    arm = alpha & in_arm_box & ~(below & (xx < rig['hand_x']))  # no jeans in the arm
    ex, ey = rig['elbow']
    sx, sy = rig['shoulder']
    adir = np.array([ex - sx, ey - sy], float)
    adir /= np.linalg.norm(adir)
    aside = (xx - ex) * adir[0] + (yy - ey) * adir[1]
    fore = arm & (aside > 0)
    upper = arm & (aside <= 0)
    fx0, fy0, fx1, fy1 = rig['front_arm_box']
    front_arm = alpha & (xx >= fx0) & (xx < fx1) & (yy >= fy0) & (yy < fy1)
    torso = alpha & ~below & ~arm & ~front_arm
    # the waist rows just above the hip stay with the torso; the rest of the leg area goes
    def layer(mask):
        out = np.zeros_like(src)
        out[mask] = src[mask]
        return out
    return {'torso': layer(torso), 'thigh': layer(thigh), 'shin': layer(shin), 'upper': layer(upper), 'fore': layer(fore)}


def up(img, k=K):
    return np.repeat(np.repeat(img, k, 0), k, 1)


def shade(img, f):
    out = img.copy()
    out[..., :3] = (out[..., :3].astype(float) * f).astype(np.uint8)
    return out


def place(canvas, part, pivot_src, angle, pivot_dst):
    """Rotate `part` (full-size RGBA, 4x) by `angle` degrees forward around pivot_src and
    composite it so that pivot_src lands on pivot_dst."""
    im = Image.fromarray(part, 'RGBA')
    rot = im.rotate(angle, resample=Image.NEAREST, center=pivot_src)
    dx, dy = int(round(pivot_dst[0] - pivot_src[0])), int(round(pivot_dst[1] - pivot_src[1]))
    canvas.alpha_composite(rot, (max(0, dx), max(0, dy)), (max(0, -dx), max(0, -dy)))


def rotate_point(p, c, deg):
    """rotate point p around c by deg forward (screen counterclockwise, as PIL does)."""
    a = math.radians(deg)
    x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * math.cos(a) + y * math.sin(a), c[1] - x * math.sin(a) + y * math.cos(a))


def pose_frame(parts, rig, p):
    """p: dict with angles (degrees, from straight down, + = forward): thigh_n, shin_n,
    thigh_f, shin_f, arm_n, fore_n, arm_f, fore_f, lean, bob."""
    s = 2 * K  # source px (2x) -> work px (4x)
    def S(pt):
        return (pt[0] * K, pt[1] * K)
    hip, knee, ankle = S(rig['hip']), S(rig['knee']), S(rig['ankle'])
    sh, el = S(rig['shoulder']), S(rig['elbow'])
    t0, s0 = angle_of(rig['hip'], rig['knee']), angle_of(rig['knee'], rig['ankle'])
    u0, f0 = angle_of(rig['shoulder'], rig['elbow']), angle_of(rig['elbow'], rig['hand'])
    L_t = math.dist(hip, knee)
    L_s = math.dist(knee, ankle)
    # render straight into the game cell (160x128, feet at y 124, hip at x 80), at 4x
    W, H = ia.CELL_W * 2 * K, ia.CELL_H * 2 * K
    cv = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    base_x = W / 2
    # feet on the ground: hip height from the lowest foot
    def foot_y(tth, tsh):
        return math.cos(math.radians(tth)) * L_t + math.cos(math.radians(tsh)) * L_s
    drop = max(foot_y(p['thigh_n'], p['shin_n']), foot_y(p['thigh_f'], p['shin_f']))
    ground = (ia.CELL_H - 4) * 2 * K
    hip_dst = (base_x, ground - drop - 2 * K + p.get('bob', 0) * K)
    off = (hip_dst[0] - hip[0], hip_dst[1] - hip[1])
    def T(pt):
        return (pt[0] + off[0], pt[1] + off[1])
    lean = p.get('lean', 0)
    far_off = (rig['far_offset'][0] * K, rig['far_offset'][1] * K)
    near_sh = rotate_point(T(S(rig['near_shoulder'])), hip_dst, lean)
    far_sh = rotate_point(T(S(rig['far_shoulder'])), hip_dst, lean)
    far_hip = (hip_dst[0] + far_off[0], hip_dst[1] + far_off[1])

    def leg(thigh_deg, shin_deg, dark):
        th = shade(parts['thigh'], rig['far_shade']) if dark else parts['thigh']
        shn = shade(parts['shin'], rig['far_shade']) if dark else parts['shin']
        h0 = far_hip if dark else hip_dst
        place(cv, th, hip, thigh_deg - t0, h0)
        knee_dst = rotate_point((knee[0] - hip[0] + h0[0], knee[1] - hip[1] + h0[1]), h0, thigh_deg - t0)
        place(cv, shn, knee, shin_deg - s0, knee_dst)

    def arm(shoulder_dst, up_deg, fore_deg, dark):
        ua = shade(parts['upper'], rig['far_shade']) if dark else parts['upper']
        fa = shade(parts['fore'], rig['far_shade']) if dark else parts['fore']
        place(cv, ua, sh, up_deg - u0, shoulder_dst)
        elbow_dst = (shoulder_dst[0] + (el[0] - sh[0]), shoulder_dst[1] + (el[1] - sh[1]))
        elbow_dst = rotate_point(elbow_dst, shoulder_dst, up_deg - u0)
        place(cv, fa, el, fore_deg - f0, elbow_dst)

    arm(far_sh, p['arm_f'], p['fore_f'], True)
    leg(p['thigh_f'], p['shin_f'], True)
    place(cv, parts['torso'], hip, lean, hip_dst)
    leg(p['thigh_n'], p['shin_n'], False)
    arm(near_sh, p['arm_n'], p['fore_n'], False)
    big = np.asarray(cv)
    # shrink 4x -> game size by block majority color (crisp, no blur)
    a = big[..., 3] > 0
    small = ia.mode_downsample(big[..., :3], a, 1 / (2 * K))
    return small


def cycle(kind, i, n):
    ph = 2 * math.pi * i / n
    if kind == 'walk':
        amp_t, amp_a, bend, lean = 24, 20, 32, 2
    else:  # run
        amp_t, amp_a, bend, lean = 40, 36, 70, 9
    def legpose(phase):
        th = amp_t * math.sin(phase)
        # the knee bends most while the leg swings forward (and when it pushes off, a little)
        b = bend * max(0.0, math.cos(phase)) + 6
        return th, th - b
    tn, sn = legpose(ph)
    tf, sf = legpose(ph + math.pi)
    an = -amp_a * math.sin(ph)
    af = amp_a * math.sin(ph)
    fb = 20 if kind == 'walk' else 60  # forearm bend
    return {'thigh_n': tn, 'shin_n': sn, 'thigh_f': tf, 'shin_f': sf,
            'arm_n': an, 'fore_n': an + fb, 'arm_f': af, 'fore_f': af + fb, 'lean': lean,
            'bob': -abs(math.cos(ph)) * (2 if kind == 'walk' else 4)}


def build(char, kind, frames, preview):
    rig = RIGS[char]
    src = load_source(rig)
    parts = {k: up(v) for k, v in cut_parts(src, rig).items()}
    out = [pose_frame(parts, rig, cycle(kind, i, frames)) for i in range(frames)]
    q, _ = ia.quantize_all(out, 48)
    q = [ia.outline_fix(f) for f in q]
    name = '%s_%s' % (char, kind)
    Image.fromarray(np.hstack(q), 'RGBA').save(os.path.join(SPRITES, name + '.png'))
    meta = {'frames': frames, 'cell': [ia.CELL_W, ia.CELL_H], 'anchor': [ia.CELL_W // 2, ia.CELL_H - 4], 'clipped': [],
            'source': 'rig_walk.py (%s figure %d)' % (rig['source'], rig['figure'])}
    json.dump(meta, open(os.path.join(SPRITES, name + '.json'), 'w'))
    print('wrote', name, frames, 'frames, cell', meta['cell'], 'clipped', meta['clipped'])
    if preview:
        os.makedirs(os.path.join(ROOT, 'art', 'preview'), exist_ok=True)
        im = Image.open(os.path.join(SPRITES, name + '.png'))
        bg = Image.new('RGBA', im.size, (60, 52, 90, 255))
        bg.alpha_composite(im)
        bg.resize((im.width * 3, im.height * 3), Image.NEAREST).save(os.path.join(ROOT, 'art', 'preview', 'bro_rig_%s.png' % kind))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--preview', action='store_true')
    a = ap.parse_args()
    build('bro', 'walk', 8, a.preview)
    build('bro', 'run', 8, a.preview)


if __name__ == '__main__':
    main()
