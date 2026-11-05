#!/usr/bin/env python3
"""breathe.py: build an idle "breathing" loop from one sprite frame, the classic way.

AI-generated idle strips redraw the whole figure every frame, so they shimmer. Instead
we take one approved frame and move everything above the waist up by 1 px (and the head
by another pixel) for the middle frames, which reads as calm breathing and never boils.

Usage: python3 tools/breathe.py bro_punch 0 bro_idle [--waist 62]
  -> art/sprites/bro_idle.png + .json (4 frames, same cell and anchor as the source)
"""
import argparse
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, 'art', 'sprites')


def lift(cell, y_from, dy):
    """Move every row above y_from up by dy pixels (rows below stay put)."""
    out = cell.copy()
    out[:y_from - dy] = cell[dy:y_from]
    # rows y_from-dy .. y_from-1 keep the original pixels, so no gap opens at the cut
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('strip')
    ap.add_argument('frame', type=int)
    ap.add_argument('out')
    ap.add_argument('--waist', type=int, default=62, help='rows above this (from the cell top) breathe')
    ap.add_argument('--neck', type=int, default=30, help='rows above this move one more pixel')
    a = ap.parse_args()
    meta = json.load(open(os.path.join(SPRITES, a.strip + '.json')))
    cw, ch = meta['cell']
    src = np.asarray(Image.open(os.path.join(SPRITES, a.strip + '.png')).convert('RGBA'))
    base = src[:, a.frame * cw:(a.frame + 1) * cw]
    up1 = lift(base, a.waist, 1)
    up2 = lift(up1, a.neck, 1)
    frames = [base, up1, up2, up1]
    Image.fromarray(np.hstack(frames), 'RGBA').save(os.path.join(SPRITES, a.out + '.png'))
    json.dump({'frames': 4, 'cell': [cw, ch], 'anchor': meta['anchor'], 'clipped': [],
               'source': '%s frame %d (breathe.py)' % (a.strip, a.frame)}, open(os.path.join(SPRITES, a.out + '.json'), 'w'))
    print('wrote', a.out, '(4 frames from', a.strip, 'frame', a.frame, ')')


if __name__ == '__main__':
    main()
