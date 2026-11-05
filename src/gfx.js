// gfx.js: pixel drawing helpers, the sprite cache and the skeletal "pixel rig".
//
// Art pipeline: every sprite is drawn by code into a small canvas the first time it is
// needed (pixel grids for faces/items, the rig for bodies), outlined with a 1px dark line
// and cached. Drawing a cached sprite is then a single drawImage, mirrored when flipped.
'use strict';
G.Gfx = (() => {
  const cache = new Map();

  function canvas(w, h) {
    const c = document.createElement('canvas');
    c.width = w; c.height = h;
    return c;
  }

  // Pen: integer-snapped primitives on a 2D context
  class Pen {
    constructor(ctx) { this.c = ctx; }
    rect(x, y, w, h, col) { this.c.fillStyle = col; this.c.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h)); }
    px(x, y, col) { this.c.fillStyle = col; this.c.fillRect(Math.round(x), Math.round(y), 1, 1); }
    // thick line by stamping squares along a Bresenham walk
    line(x0, y0, x1, y1, col, w = 1) {
      this.c.fillStyle = col;
      x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
      const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
      let err = dx + dy;
      const o = Math.floor(w / 2);
      for (;;) {
        this.c.fillRect(x0 - o, y0 - o, w, w);
        if (x0 === x1 && y0 === y1) break;
        const e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
      }
    }
    ellipse(cx, cy, rx, ry, col) {
      this.c.fillStyle = col;
      for (let y = -ry; y <= ry; y++) {
        const hw = Math.round(rx * Math.sqrt(Math.max(0, 1 - (y * y) / (ry * ry))));
        this.c.fillRect(Math.round(cx - hw), Math.round(cy + y), hw * 2 + 1, 1);
      }
    }
    circle(cx, cy, r, col) { this.ellipse(cx, cy, r, r, col); }
    ring(cx, cy, r, col, w = 1) {
      this.c.fillStyle = col;
      const n = Math.max(12, Math.round(r * 7));
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2;
        this.c.fillRect(Math.round(cx + Math.cos(a) * r - w / 2), Math.round(cy + Math.sin(a) * r - w / 2), w, w);
      }
    }
    // pixel grid: rows of characters, pal maps char -> color ('.' and ' ' are transparent)
    // rot = quarter turns clockwise, flip = mirror horizontally; (x, y) = top-left after rotation
    grid(rows, pal, x, y, rot = 0, flip = false, scale = 1) {
      const h = rows.length, w = rows[0].length;
      for (let j = 0; j < h; j++) {
        for (let i = 0; i < w; i++) {
          const ch = rows[j][i];
          if (ch === '.' || ch === ' ') continue;
          const col = pal[ch];
          if (!col) continue;
          let u = flip ? w - 1 - i : i, v = j;
          if (rot === 1) [u, v] = [h - 1 - v, u];
          else if (rot === 2) [u, v] = [w - 1 - u, h - 1 - v];
          else if (rot === 3) [u, v] = [v, w - 1 - u];
          this.c.fillStyle = col;
          this.c.fillRect(Math.round(x) + u * scale, Math.round(y) + v * scale, scale, scale);
        }
      }
    }
  }

  // A Pen that scales everything by k around an origin (the feet of a big, code-drawn
  // boss), so hand-placed boss art can grow without rewriting every coordinate.
  class ScaledPen extends Pen {
    constructor(ctx, ox, oy, k) { super(ctx); this.ox = ox; this.oy = oy; this.k = k; }
    tx(x) { return this.ox + (x - this.ox) * this.k; }
    ty(y) { return this.oy + (y - this.oy) * this.k; }
    rect(x, y, w, h, col) { const x0 = Math.round(this.tx(x)), y0 = Math.round(this.ty(y)); super.rect(x0, y0, Math.max(1, Math.round(this.tx(x + w)) - x0), Math.max(1, Math.round(this.ty(y + h)) - y0), col); }
    px(x, y, col) { super.rect(this.tx(x), this.ty(y), Math.max(1, Math.round(this.k)), Math.max(1, Math.round(this.k)), col); }
    line(x0, y0, x1, y1, col, w = 1) { super.line(this.tx(x0), this.ty(y0), this.tx(x1), this.ty(y1), col, Math.max(1, Math.round(w * this.k))); }
    ellipse(cx, cy, rx, ry, col) { super.ellipse(this.tx(cx), this.ty(cy), Math.round(rx * this.k), Math.round(ry * this.k), col); }
    ring(cx, cy, r, col, w = 1) { super.ring(this.tx(cx), this.ty(cy), r * this.k, col, Math.max(1, Math.round(w * this.k))); }
    grid(rows, pal, x, y, rot = 0, flip = false, scale = 1) { super.grid(rows, pal, Math.round(this.tx(x)), Math.round(this.ty(y)), rot, flip, Math.max(1, Math.round(scale * this.k))); }
  }

  // The 16-bit finishing pass, run once per cached sprite:
  //  - lighting: light comes from the upper left. Pixels on a lit edge get a highlight,
  //    pixels on the far edge (and the row above it) get shade, giving every shape 3 tones;
  //  - selective outline: the 1px outline takes a very dark tint of the color it wraps
  //    (pure ink only along the bottom, where the sprite meets the ground).
  function outline(src, color, o = {}) {
    const w = src.width, h = src.height;
    const d = src.getContext('2d').getImageData(0, 0, w, h).data;
    const out = canvas(w, h), ox = out.getContext('2d');
    const img = ox.createImageData(w, h), od = img.data;
    const ir = parseInt(color.slice(1, 3), 16), ig = parseInt(color.slice(3, 5), 16), ib = parseInt(color.slice(5, 7), 16);
    const A = (x, y) => (x < 0 || y < 0 || x >= w || y >= h ? 0 : d[(y * w + x) * 4 + 3]);
    const shade = o.shade !== false;
    const put = (i, r, g, b) => { od[i] = r; od[i + 1] = g; od[i + 2] = b; od[i + 3] = 255; };
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const i = (y * w + x) * 4;
        if (d[i + 3] > 0) {
          let r = d[i], g = d[i + 1], b = d[i + 2];
          if (shade) {
            const lit = !A(x, y - 1);
            const far = !A(x, y + 1) || !A(x + 1, y);
            const near = !A(x, y + 2) || !A(x + 2, y);
            if (lit && !far) { r += (255 - r) * 0.22; g += (255 - g) * 0.22; b += (255 - b) * 0.2; }
            else if (far) { r *= 0.72; g *= 0.7; b *= 0.8; }
            else if (near) { r *= 0.9; g *= 0.88; b *= 0.94; }
          }
          put(i, r, g, b);
        } else {
          // outline: tint from the opaque neighbors
          let n = 0, r = 0, g = 0, b = 0;
          for (const [dx, dy] of [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
            if (A(x + dx, y + dy)) { const j = ((y + dy) * w + x + dx) * 4; r += d[j]; g += d[j + 1]; b += d[j + 2]; n++; }
          }
          if (!n) continue;
          if (A(x, y - 1) && !A(x, y + 1) && o.inkBottom !== false) put(i, ir, ig, ib);
          else put(i, (r / n) * 0.22 + ir * 0.6, (g / n) * 0.22 + ig * 0.6, (b / n) * 0.26 + ib * 0.6);
        }
      }
    }
    ox.putImageData(img, 0, 0);
    return out;
  }

  // EPX on an image: 2x enlargement that rounds diagonals (for canvas-drawn sprites)
  function epxCanvas(src) {
    if (src._epx) return src._epx;
    const w = src.width, h = src.height, d = src.getContext('2d').getImageData(0, 0, w, h).data;
    const out = canvas(w * 2, h * 2), ox = out.getContext('2d'), img = ox.createImageData(w * 2, h * 2), od = img.data;
    const px = (x, y) => (x < 0 || y < 0 || x >= w || y >= h ? -1 : (y * w + x) * 4);
    const same = (i, j) => (i < 0 || j < 0 ? i === j : d[i] === d[j] && d[i + 1] === d[j + 1] && d[i + 2] === d[j + 2] && d[i + 3] === d[j + 3]);
    const put = (x, y, i) => { const o = (y * w * 2 + x) * 4; if (i < 0) return; od[o] = d[i]; od[o + 1] = d[i + 1]; od[o + 2] = d[i + 2]; od[o + 3] = d[i + 3]; };
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const P = px(x, y), A = px(x, y - 1), B = px(x + 1, y), Cc = px(x - 1, y), D = px(x, y + 1);
      let e1 = P, e2 = P, e3 = P, e4 = P;
      if (same(Cc, A) && !same(Cc, D) && !same(A, B)) e1 = A;
      if (same(A, B) && !same(A, Cc) && !same(B, D)) e2 = B;
      if (same(D, Cc) && !same(D, B) && !same(Cc, A)) e3 = Cc;
      if (same(B, D) && !same(B, A) && !same(D, Cc)) e4 = D;
      put(x * 2, y * 2, e1); put(x * 2 + 1, y * 2, e2); put(x * 2, y * 2 + 1, e3); put(x * 2 + 1, y * 2 + 1, e4);
    }
    ox.putImageData(img, 0, 0);
    src._epx = out;
    return out;
  }

  // a silhouette copy (hit flash)
  function tinted(src, color) {
    const key = '_t' + color;
    if (src[key]) return src[key];
    const c = canvas(src.width, src.height), x = c.getContext('2d');
    x.drawImage(src, 0, 0);
    x.globalCompositeOperation = 'source-in';
    x.fillStyle = color; x.fillRect(0, 0, c.width, c.height);
    c.ox = src.ox; c.oy = src.oy;
    src[key] = c;
    return c;
  }

  // sprite(key, w, h, ox, oy, drawFn(pen, ctx), outlineColor|null) -> cached canvas
  // (ox, oy) is the anchor: the point that is placed on the entity position (feet center)
  function sprite(key, w, h, ox, oy, draw, outlineColor = G.C.ink) {
    let s = cache.get(key);
    if (s) return s;
    const c = canvas(w, h);
    const x = c.getContext('2d');
    draw(new Pen(x), x);
    s = outlineColor ? outline(c, outlineColor) : c;
    s.ox = ox; s.oy = oy;
    cache.set(key, s);
    return s;
  }

  function draw(ctx, spr, x, y, flip = false, alpha = 1) {
    const ix = Math.round(x), iy = Math.round(y);
    if (alpha !== 1) ctx.globalAlpha = alpha;
    if (!flip) ctx.drawImage(spr, ix - spr.ox, iy - spr.oy);
    else {
      ctx.save(); ctx.translate(ix, iy); ctx.scale(-1, 1);
      ctx.drawImage(spr, -spr.ox, -spr.oy);
      ctx.restore();
    }
    if (alpha !== 1) ctx.globalAlpha = 1;
  }

  return { canvas, Pen, ScaledPen, outline, tinted, sprite, draw, cache, epxCanvas };
})();

// ---- the pixel rig -----------------------------------------------------------------------
// A humanoid is a hip, a torso, a head and four two-bone limbs. A pose gives angles in
// degrees, measured from straight down (0) with positive = forward (the facing direction):
//   { lean, dx, dy, bl:[thigh, shin], fl:[thigh, shin], ba:[upper, fore], fa:[upper, fore],
//     face: 'normal'|'hurt'|'shout', air: true (do not snap the feet to the ground), hy }
// Styles (art.js) give the bone lengths, colors and the head/torso/hand drawing functions.
// Sprites are always drawn facing right; the renderer mirrors them.
G.Rig = (() => {
  const D = Math.PI / 180;
  const fk = (o, a1, l1, a2, l2) => {
    const k = [o[0] + Math.sin(a1 * D) * l1, o[1] + Math.cos(a1 * D) * l1];
    return { k, e: [k[0] + Math.sin(a2 * D) * l2, k[1] + Math.cos(a2 * D) * l2] };
  };

  function draw(p, pose, st, ox, oy) {
    const s = (st.scale || 1) * G.CS;
    const L1 = st.thigh * s, L2 = st.shin * s, A1 = st.upper * s, A2 = st.fore * s, T = st.torso * s;
    const z = [0, 0];
    const bl0 = fk(z, pose.bl[0], L1, pose.bl[1], L2), fl0 = fk(z, pose.fl[0], L1, pose.fl[1], L2);
    let hipY = pose.air ? -(pose.hy ?? (L1 + L2) / s) * s : -(Math.max(bl0.e[1], fl0.e[1]) + st.footH * s);
    hipY += (pose.dy || 0) * s;
    const hip = [ox + (pose.dx || 0) * s, oy + hipY];
    const lean = pose.lean || 0;
    const dir = [Math.sin(lean * D), -Math.cos(lean * D)];
    const neck = [hip[0] + dir[0] * T, hip[1] + dir[1] * T];
    const back = [-Math.cos(lean * D), -Math.sin(lean * D)];
    const sh = [hip[0] + dir[0] * (T - 2 * s), hip[1] + dir[1] * (T - 2 * s)];
    const legB = fk([hip[0] - 1, hip[1]], pose.bl[0], L1, pose.bl[1], L2);
    const legF = fk([hip[0] + 1, hip[1]], pose.fl[0], L1, pose.fl[1], L2);
    const armB = fk([sh[0] - 1, sh[1]], pose.ba[0], A1, pose.ba[1], A2);
    const armF = fk([sh[0] + 1, sh[1]], pose.fa[0], A1, pose.fa[1], A2);
    const J = { hip, neck, sh, dir, back, lean, s, pose };

    st.arm(p, [sh[0] - 1, sh[1]], armB.k, armB.e, true, J);
    st.leg(p, [hip[0] - 1, hip[1]], legB.k, legB.e, true, J);
    if (st.behind) st.behind(p, J);
    st.torsoDraw(p, J);
    st.leg(p, [hip[0] + 1, hip[1]], legF.k, legF.e, false, J);
    // head: centered along the torso direction above the neck, rotated in quarter turns
    const q = (((Math.round(lean / 90) % 4) + 4) % 4);
    const hc = [neck[0] + dir[0] * st.headUp * s, neck[1] + dir[1] * st.headUp * s];
    st.head(p, hc, q, pose.face || 'normal', J);
    st.arm(p, [sh[0] + 1, sh[1]], armF.k, armF.e, false, J);
    if (st.front) st.front(p, J, armF);
  }

  // head grid helper: draws a grid centered on hc with quarter-turn rotation
  function headGrid(p, rows, pal, hc, q, scale = 1) {
    const w = rows[0].length * scale, h = rows.length * scale;
    const rw = q % 2 ? h : w, rh = q % 2 ? w : h;
    p.grid(rows, pal, Math.round(hc[0] - rw / 2), Math.round(hc[1] - rh / 2), q, false, scale);
  }

  // standard limb drawing: a thick segment pair plus an end cap (hand/shoe)
  // a limb segment shaded like a cylinder: base color, a highlight line on the lit side,
  // a shadow line on the far side (light from the upper left of a right-facing sprite)
  function seg(p, x0, y0, x1, y1, col, w) {
    p.line(x0, y0, x1, y1, col, w);
    if (w < 3) return;
    const dx = x1 - x0, dy = y1 - y0, L = Math.hypot(dx, dy) || 1;
    let nx = -dy / L, ny = dx / L;              // a normal of the segment
    if (nx * -0.6 + ny * -0.8 < 0) { nx = -nx; ny = -ny; } // point it toward the light
    const o = (w - 1) / 2;
    p.line(x0 + nx * o, y0 + ny * o, x1 + nx * o, y1 + ny * o, G.u.tint(col, 0.28), 1);
    p.line(x0 - nx * o, y0 - ny * o, x1 - nx * o, y1 - ny * o, G.u.tint(col, -0.32), w >= 5 ? 2 : 1);
  }
  function limb(p, a, k, e, col, w) { seg(p, a[0], a[1], k[0], k[1], col, w); seg(p, k[0], k[1], e[0], e[1], col, w); }

  // EPX / Scale2x: doubles a pixel grid and rounds its diagonals the way pixel artists
  // would, so upscaled faces keep crisp, deliberate edges instead of fat square pixels
  const epxCache = new Map();
  function epx(key, rows) {
    if (epxCache.has(key)) return epxCache.get(key);
    const h = rows.length, w = rows[0].length, out = [];
    const at = (x, y) => (x < 0 || y < 0 || x >= w || y >= h ? '.' : rows[y][x]);
    for (let y = 0; y < h; y++) {
      let r1 = '', r2 = '';
      for (let x = 0; x < w; x++) {
        const P = at(x, y), A = at(x, y - 1), B = at(x + 1, y), Cc = at(x - 1, y), D = at(x, y + 1);
        let e1 = P, e2 = P, e3 = P, e4 = P;
        if (Cc === A && Cc !== D && A !== B) e1 = A;
        if (A === B && A !== Cc && B !== D) e2 = B;
        if (D === Cc && D !== B && Cc !== A) e3 = Cc;
        if (B === D && B !== A && D !== Cc) e4 = D;
        r1 += e1 + e2; r2 += e3 + e4;
      }
      out.push(r1, r2);
    }
    epxCache.set(key, out);
    return out;
  }

  return { draw, headGrid, limb, seg, epx };
})();
