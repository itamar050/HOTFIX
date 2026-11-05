// themes.js: tilesets, props and parallax backgrounds for each stage theme.
// A theme has: sky (gradient stops), tile(pen, kind, x, y, tx, ty), props {digit: draw},
// layers [{speed, vy, build() -> canvas, anim?}], and optional overlay(ctx, cam, t).
'use strict';
G.Themes = (() => {
  const C = G.C, H = G.u.hash;

  function layerCanvas(w, h, draw) {
    const c = G.Gfx.canvas(w, h), x = c.getContext('2d');
    draw(new G.Gfx.Pen(x), x, w, h);
    return c;
  }

  // shared tile shapes -----------------------------------------------------------------
  // 2-color ordered dither (checkerboard), the 16-bit way to blend two shades
  function dith(p, x, y, w, h, c1, c2, seed = 0) {
    p.rect(x, y, w, h, c1);
    p.c.fillStyle = c2;
    for (let j = 0; j < h; j++) for (let i = (j + seed) % 2; i < w; i += 2) p.c.fillRect(x + i, y + j, 1, 1);
  }
  // a bevelled panel: light top/left edges, dark bottom/right edges
  function panel(p, x, y, w, h, base, light, dark) {
    p.rect(x, y, w, h, base);
    p.rect(x, y, w, 1, light); p.rect(x, y, 1, h, light);
    p.rect(x, y + h - 1, w, 1, dark); p.rect(x + w - 1, y, 1, h, dark);
  }
  // one row of offset bricks (8 px tall)
  function brick(p, x, y, row, base, light, dark) {
    p.rect(x, y, 16, 8, base);
    const off = (row % 2) * 8;
    for (const bx of [-8 + off, off, 8 + off]) {
      const x0 = Math.max(x, x + bx), x1 = Math.min(x + 16, x + bx + 16);
      if (x1 <= x0) continue;
      p.rect(x0, y, x1 - x0, 1, light);
      p.rect(x0, y + 7, x1 - x0, 1, dark);
      if (x + bx + 15 >= x && x + bx + 15 < x + 16) p.rect(x + bx + 15, y, 1, 8, dark);
      if (x + bx >= x && x + bx < x + 16) p.rect(x + bx, y + 1, 1, 6, light);
    }
  }
  function slope(p, x, y, dir, fill, edge, edge2, edge3) {
    for (let i = 0; i < 16; i++) {
      const top = dir > 0 ? 15 - i : i; // '/' rises to the right
      p.rect(x + i, y + top, 1, 16 - top, fill);
      for (let j = top + 4; j < 16; j++) if ((i + j) % 2 === 0 && j < top + 7) p.px(x + i, y + j, edge2);
      p.rect(x + i, y + top, 1, 1, edge);
      p.rect(x + i, y + top + 1, 1, 1, edge3 || edge);
      p.rect(x + i, y + top + 2, 1, 2, edge2);
    }
  }
  function wires(p, x, y, col, col2) {
    p.rect(x, y + 12, 16, 4, '#2a2e40');
    for (let i = 0; i < 4; i++) {
      p.line(x + 2 + i * 4, y + 12, x + i * 4, y + 6, col);
      p.line(x + i * 4, y + 6, x + 3 + i * 4, y + 2, col2);
    }
  }

  const themes = {};

  // ---- Stage 1: Nexus Dynamics HQ, open office at sunset ---------------------------------
  themes.office = {
    sky: [[0, '#2a1a5a'], [0.45, '#b0408a'], [0.8, '#ff9a4a'], [1, '#ffd27a']],
    tile(p, kind, x, y, tx, ty) {
      if (kind === 'top') {
        p.rect(x, y, 16, 16, '#343a5e');
        p.rect(x, y, 16, 1, '#f4f6ff'); p.rect(x, y + 1, 16, 2, '#c4c9e2'); p.rect(x, y + 3, 16, 1, '#8a90b8');
        dith(p, x, y + 4, 16, 5, '#5868a8', '#4a5894', tx);
        p.rect(x, y + 4, 16, 1, '#6a7ac0');
        p.rect(x, y + 9, 16, 1, '#232845');
        brick(p, x, y + 10, ty, '#343a5e', '#41487a', '#262b48');
      } else if (kind === 'fill') {
        brick(p, x, y, ty, '#343a5e', '#41487a', '#262b48');
        brick(p, x, y + 8, ty + 1, '#343a5e', '#41487a', '#262b48');
      } else if (kind === 'oneway') { // office desk
        p.rect(x, y, 16, 5, '#d89a50'); p.rect(x, y, 16, 1, '#ffe0a8'); p.rect(x, y + 1, 16, 1, '#f0b870');
        p.rect(x, y + 4, 16, 1, '#9a6430'); p.rect(x, y + 5, 16, 1, '#5e3a1a');
        if ((tx + ty) % 2) p.rect(x + 5, y + 2, 4, 1, '#c88a44');
        if (tx % 3 === 0) { p.rect(x + 2, y + 6, 3, 10, '#5a5f78'); p.rect(x + 2, y + 6, 1, 10, '#8a90a8'); }
        if (tx % 3 === 2) { p.rect(x + 11, y + 6, 3, 10, '#5a5f78'); p.rect(x + 11, y + 6, 1, 10, '#8a90a8'); }
      } else if (kind === 'slopeR' || kind === 'slopeL') slope(p, x, y, kind === 'slopeR' ? 1 : -1, '#343a5e', '#f4f6ff', '#5868a8', '#c4c9e2');
      else if (kind === 'spike') wires(p, x, y, C.yellow, '#ffffff');
    },
    props: {
      1: (p, x, y) => { // potted plant
        p.rect(x + 4, y - 9, 9, 9, '#c8643a'); p.rect(x + 4, y - 9, 9, 2, '#e88a5a');
        for (let i = 0; i < 6; i++) p.line(x + 8, y - 9, x + 2 + i * 2.5, y - 22 + Math.abs(i - 2.5) * 2, i % 2 ? C.greenD : C.green, 2);
      },
      2: (p, x, y) => { // desk with a monitor
        p.rect(x, y - 13, 30, 3, '#d89a50'); p.rect(x + 2, y - 10, 2, 10, '#5a5f78'); p.rect(x + 26, y - 10, 2, 10, '#5a5f78');
        p.rect(x + 8, y - 27, 16, 12, '#262a3a'); p.rect(x + 9, y - 26, 14, 9, '#3a8ad8');
        p.rect(x + 10, y - 25, 6, 1, '#c8f0ff'); p.rect(x + 10, y - 23, 9, 1, '#c8f0ff');
        p.rect(x + 15, y - 15, 2, 2, '#262a3a');
      },
      3: (p, x, y) => { // water cooler
        p.rect(x + 3, y - 26, 10, 10, '#7ad0ff'); p.rect(x + 2, y - 16, 12, 16, '#e8e8f0'); p.rect(x + 5, y - 12, 2, 2, C.red);
      },
      4: (p, x, y) => { // "SHIP IT" poster on the wall
        p.rect(x, y - 60, 30, 20, '#ffffff'); p.rect(x + 1, y - 59, 28, 18, C.red);
        G.Font.draw(p.c, 'SHIP', x + 4, y - 58, '#ffffff'); G.Font.draw(p.c, ' IT!', x + 3, y - 50, C.yellow);
      },
      5: (p, x, y) => { // office chair
        p.rect(x + 4, y - 22, 4, 12, '#2a2e40'); p.rect(x + 4, y - 11, 12, 3, '#2a2e40'); p.rect(x + 9, y - 8, 2, 6, '#5a5f78');
        p.rect(x + 4, y - 2, 12, 2, '#5a5f78');
      },
      6: (p, x, y) => { // filing cabinet
        p.rect(x + 1, y - 28, 14, 28, '#8a90a8'); for (let i = 0; i < 3; i++) { p.rect(x + 2, y - 27 + i * 9, 12, 8, '#a3abc4'); p.rect(x + 6, y - 24 + i * 9, 4, 1, '#3a4058'); }
      },
      7: (p, x, y) => { // motivational banner
        p.rect(x, y - 76, 64, 14, C.navy); p.rect(x + 1, y - 75, 62, 12, '#ffffff');
        G.Font.draw(p.c, 'MOVE FAST', x + 5, y - 72, C.blue);
      },
    },
    layers: [
      { speed: 0.08, vy: 0.04, y: -10, build: () => layerCanvas(320, 240, (p) => {
        p.circle(230, 120, 34, '#ffe08a');
        for (let i = 0; i < 6; i++) p.rect(190, 118 + i * 7, 80, 2 + i * 0.6, '#ff9a4a');
        for (let i = 0; i < 26; i++) {
          const w = 18 + H(i, 1) * 26, h = 50 + H(i, 2) * 110, x = i * 13 - 10;
          const col = H(i, 3) > 0.5 ? '#3a2266' : '#4a2c7a';
          p.rect(x, 240 - h, w, h, col);
          for (let wy = 240 - h + 6; wy < 236; wy += 7) for (let wx = x + 3; wx < x + w - 3; wx += 5)
            if (H(wx, wy) > 0.55) p.rect(wx, wy, 2, 3, H(wx + 1, wy) > 0.5 ? '#ffd86a' : '#ff9ad8');
        }
      }) },
      { speed: 0.45, vy: 0.3, y: -24, build: () => layerCanvas(256, 300, (p, x) => {
        p.rect(0, 0, 256, 300, '#2a2f4a');
        x.clearRect(22, 50, 96, 130); x.clearRect(150, 50, 96, 130);
        for (const wx of [22, 150]) {
          p.rect(wx - 3, 47, 102, 3, '#8a90a8'); p.rect(wx - 3, 180, 102, 4, '#8a90a8');
          p.rect(wx - 3, 47, 3, 137, '#8a90a8'); p.rect(wx + 96, 47, 3, 137, '#8a90a8');
          p.rect(wx + 47, 50, 2, 130, '#8a90a8'); p.rect(wx, 112, 96, 2, '#8a90a8');
        }
        p.rect(0, 0, 256, 30, '#1a1d30');
        for (const lx of [40, 168]) { p.rect(lx, 22, 48, 4, '#f0f8ff'); p.rect(lx - 2, 26, 52, 2, '#8a9ab8'); }
        p.rect(0, 184, 256, 116, '#23273e');
        for (let i = 0; i < 256; i += 32) p.rect(i, 184, 1, 116, '#1a1d30');
      }) },
    ],
  };

  // ---- Stage 2: the server farm -----------------------------------------------------------
  function racks(p, w, h, ledState, big) {
    const rw = big ? 44 : 26, gap = big ? 20 : 8;
    for (let x = 4; x < w; x += rw + gap) {
      const top = big ? 40 : 70;
      p.rect(x, top, rw, h - top, big ? '#1c2440' : '#121a30');
      p.rect(x + 2, top + 2, rw - 4, h - top, big ? '#141a30' : '#0c1224');
      for (let y = top + 6; y < h - 4; y += big ? 8 : 6) {
        p.rect(x + 3, y, rw - 6, big ? 5 : 3, big ? '#26304e' : '#182040');
        const r = H(x, y + ledState * 977);
        if (r > 0.35) p.rect(x + rw - 7, y + 1, 2, 2, r > 0.8 ? C.yellow : r > 0.55 ? C.green : '#3ab0ff');
        if (big && H(y, x) > 0.6) p.rect(x + 5, y + 2, 3, 1, C.cyan);
      }
    }
  }
  themes.servers = {
    sky: [[0, '#05060f'], [0.6, '#0c1430'], [1, '#14204a']],
    tile(p, kind, x, y, tx, ty) {
      if (kind === 'top') {
        p.rect(x, y, 16, 16, '#232840');
        p.rect(x, y, 16, 5, '#8a93ad'); p.rect(x, y, 16, 1, '#e4e8f6'); p.rect(x, y + 1, 16, 1, '#b8c0d8'); p.rect(x, y + 4, 16, 1, '#5a6280');
        for (let i = 0; i < 16; i += 4) { const o = ((tx + (i >> 2)) % 2) * 2; p.px(x + i + o, y + 2, '#d8def0'); p.px(x + i + o + 1, y + 3, '#5a6280'); }
        for (let i = 0; i < 16; i++) p.px(x + i, y + 5, ((i + tx * 16) >> 2) % 2 ? C.yellow : '#1a1a24');
        for (let i = 0; i < 16; i++) p.px(x + i, y + 6, ((i + 1 + tx * 16) >> 2) % 2 ? '#d8a420' : '#1a1a24');
        p.rect(x, y + 7, 16, 1, '#141828');
        panel(p, x, y + 8, 16, 8, '#2a3048', '#3a4262', '#181c30');
      } else if (kind === 'fill') {
        panel(p, x, y, 16, 16, '#262b44', '#363e5c', '#161a2c');
        if ((tx + ty) % 3 === 0) for (let i = 0; i < 3; i++) p.rect(x + 4, y + 5 + i * 3, 8, 1, '#12162a');
      } else if (kind === 'oneway') {
        p.rect(x, y, 16, 3, '#9aa3bb'); p.rect(x, y, 16, 1, '#eef0f8'); p.rect(x, y + 2, 16, 1, '#5a6280');
        for (let i = 1; i < 16; i += 3) { p.rect(x + i, y + 3, 1, 3, '#5a6078'); }
        p.rect(x, y + 5, 16, 1, '#3a4058');
      } else if (kind === 'slopeR' || kind === 'slopeL') slope(p, x, y, kind === 'slopeR' ? 1 : -1, '#262b44', '#e4e8f6', '#5a6280', '#8a93ad');
      else if (kind === 'spike') wires(p, x, y, C.cyan, '#ffffff');
    },
    props: {
      1: (p, x, y) => { // tall rack
        p.rect(x, y - 48, 30, 48, '#1c2440'); p.rect(x + 2, y - 46, 26, 45, '#0c1224');
        for (let i = 0; i < 9; i++) { p.rect(x + 3, y - 44 + i * 5, 24, 3, '#26304e'); if (H(x, i) > 0.4) p.rect(x + 23, y - 43 + i * 5, 2, 1, C.green); }
      },
      2: (p, x, y) => { // cable bundle
        for (let i = 0; i < 4; i++) p.line(x + i * 3, y, x + 6 + i * 3, y - 40, ['#ff4f4f', '#3a6cff', C.yellow, C.green][i], 1);
      },
      3: (p, x, y) => { // warning sign
        p.rect(x + 7, y - 16, 2, 16, '#5a6078');
        p.rect(x + 1, y - 30, 14, 14, C.yellow); p.rect(x + 3, y - 28, 10, 10, C.ink);
        p.rect(x + 7, y - 27, 2, 5, C.yellow); p.rect(x + 7, y - 21, 2, 2, C.yellow);
      },
      4: (p, x, y) => { // cooling unit
        p.rect(x, y - 24, 32, 24, '#8a90a8'); p.rect(x + 2, y - 22, 28, 20, '#5a6078');
        p.ring(x + 9, y - 12, 6, '#262b40', 2); p.ring(x + 23, y - 12, 6, '#262b40', 2);
      },
    },
    layers: [
      { speed: 0.15, vy: 0.05, y: 0, frames: 2, build: (f) => layerCanvas(240, 240, (p) => racks(p, 240, 240, f, false)) },
      { speed: 0.5, vy: 0.25, y: -20, frames: 2, build: (f) => layerCanvas(256, 280, (p) => {
        p.rect(0, 0, 256, 18, '#0a0e1c');
        for (let i = 0; i < 256; i += 16) p.rect(i, 18, 2, 14, '#2a3048');
        p.rect(0, 28, 256, 4, '#2a3048');
        racks(p, 256, 280, f, true);
      }) },
    ],
  };

  // ---- Stage 3: The Cloud (a digital realm) ------------------------------------------------
  themes.cloud = {
    sky: [[0, '#0a0420'], [0.5, '#2a0a50'], [1, '#5a1a7a']],
    tile(p, kind, x, y, tx, ty) {
      if (kind === 'top' || kind === 'fill') {
        p.rect(x, y, 16, 16, '#140a2c');
        p.rect(x + 1, y + 1, 14, 14, '#1c0f3c');
        p.rect(x, y, 16, 1, '#3a1c70'); p.rect(x, y, 1, 16, '#3a1c70'); p.rect(x + 15, y + 1, 1, 15, '#0c0620'); p.rect(x + 1, y + 15, 15, 1, '#0c0620');
        if (H(tx, ty) > 0.75) { p.rect(x + 5, y + 5, 6, 6, '#2a1458'); p.rect(x + 6, y + 6, 4, 4, '#3a1f78'); p.px(x + 6, y + 6, '#7a4ad8'); }
        if (kind === 'top') {
          p.rect(x, y, 16, 1, '#ffffff'); p.rect(x, y + 1, 16, 1, '#b8ffff'); p.rect(x, y + 2, 16, 1, C.cyan);
          p.rect(x, y + 3, 16, 1, '#1aa8d8'); dith(p, x, y + 4, 16, 2, '#1c0f3c', '#1a6a9a', tx);
        }
      } else if (kind === 'oneway') {
        p.rect(x, y, 16, 1, '#ffffff'); p.rect(x, y + 1, 16, 2, 'rgba(63,242,255,0.75)'); p.rect(x, y + 3, 16, 2, 'rgba(26,138,192,0.6)');
        if (tx % 2) p.rect(x + 7, y + 1, 2, 2, '#ffffff');
      } else if (kind === 'slopeR' || kind === 'slopeL') slope(p, x, y, kind === 'slopeR' ? 1 : -1, '#1c0f3c', '#ffffff', '#1aa8d8', C.cyan);
      else if (kind === 'spike') {
        for (let i = 0; i < 4; i++) { p.line(x + i * 4, y + 15, x + i * 4 + 2, y + 4, C.red, 2); p.line(x + i * 4 + 2, y + 4, x + i * 4 + 4, y + 15, C.magenta, 1); p.px(x + i * 4 + 2, y + 4, '#ffd0f0'); }
        p.rect(x, y + 14, 16, 2, '#5a0a3a');
      }
    },
    props: {
      1: (p, x, y) => { // floating cube
        p.rect(x + 2, y - 36, 12, 12, C.purpleD); p.rect(x + 3, y - 35, 10, 10, C.purple); p.rect(x + 5, y - 33, 4, 4, '#e0c8ff');
      },
      2: (p, x, y) => { // neon "</>" sign
        p.rect(x, y - 40, 32, 16, '#1a0a3a'); p.rect(x, y - 40, 32, 1, C.pink); p.rect(x, y - 25, 32, 1, C.pink);
        G.Font.draw(p.c, '</>', x + 7, y - 36, C.cyan);
      },
      3: (p, x, y) => { // antenna mast
        p.rect(x + 7, y - 40, 2, 40, '#8a90a8'); p.ring(x + 8, y - 42, 4, C.cyan, 1); p.rect(x + 7, y - 43, 2, 2, C.pink);
      },
    },
    layers: [
      { speed: 0.1, vy: 0.03, y: 0, build: () => layerCanvas(320, 240, (p) => {
        for (let i = 0; i < 90; i++) p.px(H(i, 7) * 320, H(i, 8) * 200, H(i, 9) > 0.7 ? '#ffffff' : '#9a7aff');
        for (let i = 0; i < 5; i++) {
          const cx = 30 + i * 66, cy = 60 + H(i, 4) * 70, col = i % 2 ? C.pink : C.cyan;
          for (let k = 0; k < 3; k++) p.ring(cx + (k - 1) * 12, cy - (k === 1 ? 6 : 0), 10 + (k === 1 ? 4 : 0), col, 1);
        }
        for (let i = 0; i < 320; i += 20) p.line(i, 240, 160 + (i - 160) * 0.3, 160, '#4a1a7a', 1);
        for (let j = 0; j < 5; j++) p.rect(0, 170 + j * j * 3, 320, 1, '#4a1a7a');
      }) },
      { speed: 0.4, vy: 0.2, y: 0, scrollY: 0.4, build: () => layerCanvas(256, 256, (p, x) => {
        for (let col = 0; col < 16; col++) {
          if (H(col, 11) < 0.45) continue;
          for (let r = 0; r < 18; r++) {
            const ch = H(col, r) > 0.5 ? '1' : '0';
            const bright = (r % 9) === 8;
            G.Font.draw(x, ch, col * 16 + 4, r * 14 + Math.floor(H(col, 2) * 14), bright ? '#d0fff0' : (r % 9) > 5 ? '#2ad08a' : '#146a4a');
          }
        }
      }) },
    ],
  };

  // ---- Stage 4: the Nexus core ---------------------------------------------------------------
  themes.core = {
    sky: [[0, '#0a0206'], [0.6, '#2a0612'], [1, '#5a0a1a']],
    tile(p, kind, x, y, tx, ty) {
      if (kind === 'top' || kind === 'fill') {
        panel(p, x, y, 16, 16, '#24121c', '#3a1e2c', '#140a10');
        p.px(x + 3, y + 3, '#6a3a4a'); p.px(x + 12, y + 3, '#6a3a4a'); p.px(x + 3, y + 12, '#6a3a4a'); p.px(x + 12, y + 12, '#6a3a4a');
        if (kind === 'top') {
          p.rect(x, y, 16, 5, '#5a5f78'); p.rect(x, y, 16, 1, '#e8ecf8'); p.rect(x, y + 1, 16, 1, '#a8aec4'); p.rect(x, y + 4, 16, 1, '#3a3e52');
          p.rect(x, y + 5, 16, 1, C.red); p.rect(x, y + 6, 16, 1, '#7a0a1a');
          if (tx % 2) p.rect(x + 6, y + 2, 4, 1, '#8a90a8');
        }
      } else if (kind === 'oneway') {
        p.rect(x, y, 16, 4, '#5a5f78'); p.rect(x, y, 16, 1, '#e8ecf8'); p.rect(x, y + 3, 16, 1, '#3a3e52'); p.rect(x + 2, y + 4, 12, 1, C.red);
      } else if (kind === 'slopeR' || kind === 'slopeL') slope(p, x, y, kind === 'slopeR' ? 1 : -1, '#24121c', '#e8ecf8', C.red, '#a8aec4');
      else if (kind === 'spike') {
        p.rect(x, y + 10, 16, 6, '#5a0a1a'); p.rect(x, y + 10, 16, 1, C.orange);
        for (let i = 0; i < 16; i += 2) { const hh = 6 + (H(tx * 16 + i, 1) * 5 | 0); p.rect(x + i, y + 16 - hh - 4, 2, hh, i % 4 ? C.orange : C.yellow); p.px(x + i, y + 16 - hh - 4, '#fff6c0'); }
      }
    },
    props: {
      1: (p, x, y) => { p.rect(x + 4, y - 44, 8, 44, '#3a2a34'); p.rect(x + 6, y - 44, 4, 44, '#5a3a4a'); for (let i = 0; i < 5; i++) p.rect(x + 6, y - 40 + i * 8, 4, 2, C.red); },
      2: (p, x, y) => { p.rect(x + 7, y - 16, 2, 16, '#5a6078'); p.rect(x + 1, y - 30, 14, 14, C.red); G.Font.draw(p.c, '!', x + 5, y - 27, '#ffffff'); },
      3: (p, x, y) => { p.rect(x + 2, y - 30, 12, 30, '#3a2a34'); p.ring(x + 8, y - 20, 4, C.orange, 1); },
    },
    layers: [
      { speed: 0.08, vy: 0.03, y: 0, build: () => layerCanvas(240, 240, (p) => {
        for (let r = 0; r < 12; r++) for (let c = 0; c < 10; c++) {
          const cx = c * 26 + (r % 2) * 13, cy = r * 22;
          p.ring(cx, cy, 11, H(c, r) > 0.85 ? '#7a1a2a' : '#3a0a16', 1);
        }
      }) },
      { speed: 0.45, vy: 0.2, y: -10, build: () => layerCanvas(256, 280, (p) => {
        for (let x = 10; x < 256; x += 64) {
          p.rect(x, 0, 20, 280, '#2a1620'); p.rect(x + 3, 0, 14, 280, '#3a2030');
          for (let y = 10; y < 280; y += 24) { p.rect(x + 7, y, 6, 10, C.redD); p.rect(x + 8, y + 2, 4, 6, C.orange); }
        }
        p.rect(0, 200, 256, 6, '#3a2030'); p.rect(0, 40, 256, 4, '#3a2030');
      }) },
    ],
    overlay(ctx, cam, t) {
      // pulsing core glow in the far distance
      const a = 0.12 + Math.sin(t * 0.05) * 0.06;
      const g = ctx.createRadialGradient(G.W / 2, 60, 4, G.W / 2, 60, 120);
      g.addColorStop(0, `rgba(255,60,60,${a * 2})`); g.addColorStop(1, 'rgba(255,0,0,0)');
      ctx.fillStyle = g; ctx.fillRect(0, 0, G.W, G.H);
    },
  };

  // a sky in 16 flat color bands, blended with a 4x4 ordered dither (Mega Drive / SNES style)
  const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map((v) => (v + 0.5) / 16);
  function bandedSky(stops) {
    const rgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
    const S = stops.map(([s, c]) => [s, rgb(c)]);
    const at = (t) => {
      let k = 0;
      while (k < S.length - 2 && t > S[k + 1][0]) k++;
      const [s0, c0] = S[k], [s1, c1] = S[k + 1], f = Math.min(1, Math.max(0, (t - s0) / (s1 - s0 || 1)));
      return c0.map((v, i) => v + (c1[i] - v) * f);
    };
    const c = G.Gfx.canvas(G.W, G.H), x = c.getContext('2d'), img = x.createImageData(G.W, G.H), d = img.data;
    const bands = 16;
    for (let y = 0; y < G.H; y++) {
      const f = (y / (G.H - 1)) * (bands - 1), b0 = Math.floor(f), fr = f - b0;
      const ca = at(b0 / (bands - 1)), cb = at(Math.min(bands - 1, b0 + 1) / (bands - 1));
      for (let xx = 0; xx < G.W; xx++) {
        const col = fr > BAYER[(y % 4) * 4 + (xx % 4)] ? cb : ca, i = (y * G.W + xx) * 4;
        d[i] = col[0]; d[i + 1] = col[1]; d[i + 2] = col[2]; d[i + 3] = 255;
      }
    }
    x.putImageData(img, 0, 0);
    return c;
  }

  // build (and cache) the layer canvases of a theme
  function prepare(name) {
    const th = themes[name];
    if (th.ready) return th;
    for (const L of th.layers) {
      const n = L.frames || 1;
      L.canvases = [];
      for (let f = 0; f < n; f++) L.canvases.push(L.build(f));
    }
    th.ready = true;
    return th;
  }

  // draw sky + parallax layers for a camera position
  function drawBackground(ctx, th, cam, t) {
    if (!th.skyC) th.skyC = bandedSky(th.sky);
    ctx.drawImage(th.skyC, 0, 0);
    if (th.overlay) th.overlay(ctx, cam, t);
    for (const L of th.layers) {
      const c = L.canvases[L.canvases.length > 1 ? Math.floor(t / 20) % L.canvases.length : 0];
      const w = c.width;
      let ox = -Math.floor((cam.x * L.speed) % w);
      if (ox > 0) ox -= w;
      const y = Math.round(L.y - cam.y * L.vy);
      if (L.scrollY) {
        const h = c.height, sy = Math.floor((t * L.scrollY) % h);
        for (let x = ox; x < G.W; x += w) { ctx.drawImage(c, x, y + sy - h); ctx.drawImage(c, x, y + sy); }
      } else for (let x = ox; x < G.W; x += w) ctx.drawImage(c, x, y);
    }
  }

  return { themes, prepare, drawBackground, get: (n) => prepare(n) };
})();
