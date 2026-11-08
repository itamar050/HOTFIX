# Brawler art spec: replacing the placeholders

The brawler (`godot/main.tscn`) renders at **640x360**, scaled by whole numbers (2x = 1280x720,
3x = 1920x1080), nearest-neighbour filtering, positions snapped to pixels. Draw everything at
1x (one art pixel = one game pixel). No anti-aliased edges, no blur.

## Stage layers (temporary: `godot/assets/placeholder/`)

Drawn by `tools/make_street_placeholders.py`. To replace one, save final art with the **same
file name and size** over the placeholder (then reopen the project so Godot re-imports it).
Transparent areas must be real alpha (PNG).

| File | Size | Scroll | Notes |
|---|---|---|---|
| `placeholder_street_sky.png` | 640x360 | fixed | sky, moon, distant glow |
| `placeholder_street_far.png` | 1280x240 | 0.15 | far skyline, loops horizontally (left/right edges must match) |
| `placeholder_street_mid.png` | 1280x260 | 0.45 | mid-rise buildings, loops, drawn 2 px down |
| `placeholder_street_front.png` | 2400x266 | 1.0 | storefronts the fighters walk past; bottom edge = back of the sidewalk (y 266) |
| `placeholder_street_ground.png` | 2400x94 | 1.0 | sidewalk lane (y 266..338 on screen), curb at 338, road below |
| `placeholder_street_fore.png` | 1600x60 | 1.3 | props in front of the fighters (keep them low and sparse), loops |
| `placeholder_glow.png` | 64x64 | - | white dithered glow, tinted per light |
| `placeholder_vignette.png` | 640x360 | screen | dark corners |

Neon signs and lamps glow from `godot/assets/placeholder/street_layout.gd` (`GLOWS`: x, y,
colour, size; `LAMPS`: x of each light pool). If the new storefront art moves the signs, edit
those numbers (or stop using the generator and keep the file by hand).

Once a layer is final, move it out of `placeholder/` and drop the `placeholder_` prefix, and
change the path in `godot/scripts/stage_street.gd`.

## Characters

- About **120 px tall** standing (a third of the screen), feet at the bottom centre of each cell.
- One horizontal strip per animation, equal cells (160x128; wider poses in 32 px steps), plus
  a `.json` with the cell size (`tools/import_art.py` writes both from raw art).
- Needed per fighter: idle (4+ frames), walk (8), run (8), 3-4 attack steps (windup/hit/recover),
  hurt high + hurt low, knockdown (fly, down, get up), jump. Enemies the same minus run.
- Clear silhouettes: a dark outline (not pure black), 3-4 shades per material, light from the
  upper left, a consistent palette per character (max ~48 colours).

Current state: Code Bro's idle, punch, hook, kick, hurt and knockdown are real 16-bit art (AI
generated, approved). His walk is a placeholder rig and the run is low-res. Enemies are tinted
copies of Code Bro (placeholder).
