# Cut Code Bro out of the walking video frames: pick the best-looping walk cycle, then
# GrabCut each frame with colour seeds (jeans/plaid = character, outside box = street).
import sys, os, json
import numpy as np, cv2
D, O = sys.argv[1], sys.argv[2]
os.makedirs(O, exist_ok=True)
fr = [cv2.imread(os.path.join(D, 'frame_%03d.jpg' % i)) for i in range(1, 241)]

def masks(f):
    hsv = cv2.cvtColor(f, cv2.COLOR_BGR2HSV)
    h, s, v = hsv[..., 0].astype(int), hsv[..., 1].astype(int), hsv[..., 2].astype(int)
    jeans = (h > 100) & (h < 125) & (s > 90) & (v > 60)
    plaid = ((h < 8) | (h > 170)) & (s > 120) & (v > 60)
    return jeans, plaid

xs = []
for f in fr:
    j, _ = masks(f); j[:380] = False
    xs.append(np.nonzero(j)[1].mean())
def legmask(i):
    j, _ = masks(fr[i]); cx = int(xs[i]); return j[380:700, cx - 180:cx + 180].astype(np.float32)
L = [legmask(i) for i in range(240)]
best = None
for period in (27, 28):
    for i in range(20, 240 - period - 20):
        d = np.abs(L[i] - L[i + period]).mean()
        if best is None or d < best[0]:
            best = (d, i, period)
d, start, period = best
print('loop: start frame %d, period %d frames (diff %.4f)' % (start + 1, period, d))

N = int(sys.argv[3]) if len(sys.argv) > 3 else 12
picks = [start + round(k * period / N) for k in range(N)]
def detect(i):
    f = fr[i]; H, W = f.shape[:2]
    cx = int(xs[i])
    jeans, plaid = masks(f)
    x0, x1, y0, y1 = max(0, cx - 260), min(W, cx + 260), 50, 715
    box = np.zeros((H, W), bool); box[y0:y1, x0:x1] = True
    body = ((jeans | plaid) & box).astype(np.uint8)
    body = cv2.morphologyEx(body, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    # keep only the plaid/jeans that connects to his legs (red shop signs behind him are not him)
    near_body = np.zeros((H, W), bool); near_body[y0:y1, cx - 140:cx + 140] = True
    body = (body.astype(bool) & near_body).astype(np.uint8)
    joined = cv2.dilate(body, np.ones((15, 15), np.uint8))
    n_, lab_, st_, _ = cv2.connectedComponentsWithStats(joined, 8)
    jy0, jx0 = np.nonzero(jeans & near_body & (np.arange(H)[:, None] > 450))
    seed = lab_[int(np.median(jy0)), int(np.median(jx0))]
    if seed == 0:
        seed = 1 + int(np.argmax(st_[1:, cv2.CC_STAT_AREA]))
    body = (body.astype(bool) & (lab_ == seed)).astype(np.uint8)
    py, px = np.nonzero(body & plaid.astype(np.uint8))
    ptop = int(np.percentile(py, 1))  # top of the shirt = bottom of the head
    pcx = int(np.median(px[py < ptop + 60]))
    return f, H, W, cx, jeans, plaid, x0, x1, y0, y1, box, body, ptop, pcx


det = [detect(i) for i in picks]
mt = int(np.median([d_[12] for d_ in det])); mx = int(np.median([d_[13] for d_ in det]))
info = []
for k, i in enumerate(picks):
    f, H, W, cx, jeans, plaid, x0, x1, y0, y1, box, body, ptop, pcx = det[k]
    # the head barely moves relative to the camera: distrust guesses far from the median
    if abs(ptop - mt) > 30 or abs(pcx - mx) > 25:
        print('  frame %d: head guess (%d, %d) replaced by median (%d, %d)' % (i + 1, pcx, ptop, mx, mt))
        ptop, pcx = mt, mx
    m = np.full((H, W), cv2.GC_BGD, np.uint8)
    prior = cv2.dilate(body, np.ones((61, 61), np.uint8))
    shoes = np.zeros((H, W), np.uint8); jy, jx = np.nonzero(jeans & box)
    for k_ in range(0, len(jx), 7):
        if jy[k_] > 560:
            cv2.circle(shoes, (int(jx[k_]), int(jy[k_]) + 30), 34, 1, -1)
    head = np.zeros((H, W), np.uint8)
    cv2.ellipse(head, (pcx + 12, ptop - 62), (78, 92), 0, 0, 360, 1, -1)
    prior = ((prior | shoes | head) > 0) & box
    m[box] = cv2.GC_BGD
    m[prior] = cv2.GC_PR_FGD
    near = cv2.dilate(prior.astype(np.uint8), np.ones((25, 25), np.uint8)).astype(bool) & ~prior & box
    m[near] = cv2.GC_PR_BGD
    sure = cv2.erode(body, np.ones((9, 9), np.uint8)).astype(bool)
    m[sure] = cv2.GC_FGD
    # sneakers: red uppers and bright white soles near the bottom of the jeans are him, not sidewalk
    hsv = cv2.cvtColor(f, cv2.COLOR_BGR2HSV)
    hh, ss, vv = hsv[..., 0].astype(int), hsv[..., 1].astype(int), hsv[..., 2].astype(int)
    shoe_zone = shoes.astype(bool) & box
    red = ((hh < 8) | (hh > 168)) & (ss > 110) & (vv > 70)
    white = (ss < 45) & (vv > 195)
    m[shoe_zone & (red | white)] = cv2.GC_FGD
    face = np.zeros((H, W), np.uint8)
    cv2.ellipse(face, (pcx + 20, ptop - 50), (26, 34), 0, 0, 360, 1, -1)
    m[face.astype(bool)] = cv2.GC_FGD
    bgd = np.zeros((1, 65), np.float64); fgd = np.zeros((1, 65), np.float64)
    cv2.grabCut(f, m, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    fg = ((m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD)).astype(np.uint8)
    # keep the biggest connected blob (the character), fill small holes
    n, lab, st, _ = cv2.connectedComponentsWithStats(fg, 8)
    if n > 1:
        keep = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA])); fg = (lab == keep).astype(np.uint8)
    fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    rgba = np.dstack([f, fg * 255])
    cv2.imwrite(os.path.join(O, 'cut_%02d.png' % k), rgba)
    ys, xx = np.nonzero(fg)
    info.append({'frame': i + 1, 'top': int(ys.min()), 'bottom': int(ys.max()), 'left': int(xx.min()), 'right': int(xx.max()), 'cx': cx})
    print(k, info[-1])
json.dump({'start': start + 1, 'period': period, 'frames': info}, open(os.path.join(O, 'cuts.json'), 'w'), indent=1)
