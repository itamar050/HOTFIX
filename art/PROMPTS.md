# Art prompts for Nano Banana

How to make the game's art with Nano Banana (Gemini image generation) so that it can go
straight into the Godot version. Read **How it works** once, then copy the prompts.

## How it works

- **Target look:** detailed 16-bit beat 'em up pixel art (Streets of Rage 2, Final Fight).
  The game will run at **640x360**, with characters about **100 px tall**.
- **Save every image as PNG** (not WebP or JPG): compression smears the edges pink.
- **Every animation strip starts with a standing reference pose** (the character standing
  upright and relaxed, exactly as in the character sheet). The importer measures it to get
  the scale right (a crouched fighting stance would otherwise come out too big) and then
  drops it.
- **Big figures, few per image:** Nano Banana makes images about 1024 px wide, so the
  more figures in a row, the smaller each gets. Put **at most 4 figures per image** (the
  reference plus 3 frames) and ask for a **16:9 image** with the figures filling its
  height: that gives about 500 px per figure. For longer animations, split the frames over
  several images named `_a`, `_b`, `_c` (e.g. `bro_run_a.png` = reference + frames 1-3,
  `bro_run_b.png` = reference + frames 4-6); the importer joins them in order. Below about
  240 px per figure the importer flags the strip as too small.
- **Idle animations are not generated.** AI idle strips redraw the whole figure every
  frame, so they shimmer. `tools/breathe.py` builds the breathing loop from one approved
  guard frame instead.
- **One animation per image, at most 6 frames plus the reference,** in one horizontal row. More frames make the
  character drift (different face, colors, size).
- **Flat magenta background (#FF00FF)** with nothing else on it. Nano Banana cannot make
  real transparency; the importer turns the magenta into transparency.
- **No shadows, ground, text, labels, frame numbers, UI, sparks or motion trails** in
  character images. The game draws effects itself.
- **Side view, facing right,** for every character frame. The game mirrors them.
- Do not worry about exact pixel sizes. The importer finds each frame, scales it to the
  game's size, snaps it to a clean pixel grid and lines up the feet.

### Consistency: the reference images

1. Make the **character sheet** of each character first (prompt A). Regenerate until you
   love it. This is that character's "bible".
2. For every other prompt of that character, **attach two images**: the character sheet and
   a style reference (one of your concept images, or the first good sheet). Then paste the
   prompt.
3. If a frame drifts (wrong colors, different face, much bigger or smaller), ask Nano Banana
   to fix only that frame ("Keep everything; redraw frame 3 so the jacket is grey like the
   reference"), or regenerate.

### File names and where to put them

Name each file `<character>_<animation>.png` (e.g. `bro_walk.png`, `firewall_attack.png`,
`stage1_far.png`) and put them in `art/raw/` in the HOTFIX repository (GitHub: Add file >
Upload files), or send them to Claude in chat.

---

## Style block (pasted into every prompt below)

> STYLE: high-quality 16-bit pixel art sprite in the style of Streets of Rage 2 and Final
> Fight, detailed shading with 3 to 4 tones per color, 1-pixel dark outlines, crisp hard
> pixels, no anti-aliasing, no blur, no gradients, limited palette. Full body, side view,
> facing right. Flat solid magenta background #FF00FF filling the whole image. No shadow, no
> floor, no text, no labels, no numbers, no UI, no effects, no motion lines.

---

## A. Character sheet (one per character, first)

> Character sheet of [CHARACTER DESCRIPTION]. Show the same character 4 times in one
> horizontal row, evenly spaced, same size, standing on the same invisible baseline:
> 1) idle fighting stance, 2) neutral standing pose, 3) walking mid-stride, 4) punching.
> [STYLE]

## B. Animation strip (one per animation)

> Using the attached character sheet as the exact character design (same face, hair,
> clothes, colors and proportions), draw one horizontal row of [N+1] figures. Figure 1 is a
> reference: the character standing upright and relaxed, arms at the sides, exactly as in
> the character sheet. Figures 2 to [N+1] are the [N]-frame animation of [ANIMATION
> DESCRIPTION], in time order from left to right. Same scale for every figure, feet on the
> same invisible baseline (except airborne frames). Leave a wide empty gap of magenta
> between figures: no fist, foot, hair or bag may reach into the next figure's space.
> [STYLE]

---

## Characters

Paste the description into `[CHARACTER DESCRIPTION]`.

### Heroes
- **bro (Code Bro, Alex):** a fit young male software engineer, messy brown hair, thin
  black rectangular glasses with clear lenses and the eyes clearly visible behind them,
  light stubble, open red-and-brown plaid flannel shirt with sleeves
  rolled to the elbows over a dark grey t-shirt, blue jeans, white sneakers with red
  details, a slim black laptop bag strap across the chest.
- **girl (Code Girl):** an athletic young female software engineer, auburn hair in a high
  ponytail, green gaming headset with a glowing green visor band, grey tech jacket over a
  dark green tank top, olive cargo pants with thigh pockets, brown combat boots,
  fingerless black gloves.

### Enemies
- **glitchbot:** a street thug in a grey-green hoodie with the hood up, the face replaced by
  a black LED screen showing two glowing magenta X eyes, dark jeans, worn sneakers, holding
  a short metal pipe.
- **blob:** a round green virus creature the size of a large dog, glossy slime body with
  spiky protein bumps, two angry cartoon eyes, no limbs. (Animations: idle wobble 4,
  hop 4, squash on landing 2, hurt 2, dissolve 4.)
- **manager:** an angry balding middle manager, grey comb-over, glasses, thick mustache,
  blue-grey suit with a red tie, a pot belly, holding a clipboard.
- **drone:** a hovering security drone, round grey metal body, one red camera eye, a
  rotor on top, a small gun underneath. (Animations: hover 4, aim 2, hurt 2, explode 4.)
- **firewall:** a huge punk brute with a tall red mohawk, scarred angry face, black leather
  jacket with metal studs, ripped dark jeans, heavy boots, holding a large rectangular
  shield made of burning orange flames and glowing grid lines.

### Bosses
- **chad (Chad Brockman, VP of Synergy):** a tall smug corporate executive, slicked-back
  blond hair, mirrored sunglasses, square jaw, expensive navy suit, gold tie, a glowing red
  wireless headset.
- **rack (RACK-9000):** a sentient server rack robot on tank treads, tall grey metal
  cabinet, a face screen with two glowing cyan eyes, rows of blinking drive bays, two
  cable-whip arms, side vents that glow red when overheating.
- **spag (SPAGHETTI.EXE):** a floating tangled mass of yellow spaghetti noodles and
  glitchy code fragments with a big goofy angry face, two meatball eyebrows, dangling
  noodle tentacles.
- **nexus (N.E.X.U.S.):** a giant floating mechanical eye, white eyeball with a red-purple
  iris, surrounded by a ring of 8 glowing cyan shield segments, cables trailing below.

---

## Animation list

Frame counts are the most each strip needs; fewer is fine. "Hold" frames (lying down,
crouch) are single images: put them side by side in one row.

**Heroes (bro and girl), 17 strips each:**

| File | Frames | Animation description |
|------|--------|------------------------|
| `walk` | 6 | walk cycle where the legs alternate, one pose per frame: 1) right foot forward touching the ground, left arm forward; 2) weight down on the right leg; 3) left leg passing the right leg; 4) left foot forward touching the ground, right arm forward; 5) weight down on the left leg; 6) right leg passing the left leg. Frames 1 and 4 must show different legs in front. |
| `run` | 6 | sprint cycle, leaning forward, legs alternating like the walk (frames 1-3 right leg leading, 4-6 left leg leading), arms pumping opposite to the legs |
| `jump` | 3 | jump: takeoff crouch, rising with knees up, falling with arms out |
| `punch` | 6 | jab-jab: frames 1-3 a quick left jab and return, frames 4-6 a quick right jab and return |
| `hook` | 3 | a big swinging hook punch: wind-up, impact, follow-through |
| `kick` | 3 | a high front kick: chamber the knee, full extension at head height, recover |
| `uppercut` | 3 | crouch, rising uppercut with the arm straight up, landing |
| `airkick` | 2 | mid-air flying side kick, then mid-air dive kick angled down |
| `lowkick` | 3 | crouching low kick at ankle height: crouch, leg extended along the floor, recover |
| `sweep` | 3 | spinning leg sweep close to the floor |
| `dash` | 2 | dash forward low and fast; dash shoulder charge |
| `grab` | 4 | grab an enemy, knee strike, lift, throw over the shoulder (enemy not shown) |
| `hurt` | 2 | recoil from a hit to the face; recoil from a hit to the stomach |
| `knockdown` | 4 | knocked off the feet flying backward, lying flat on the back, getting up on one knee, standing |
| `special` | 4 | a special move: gathering power, both arms raised releasing a glowing energy burst (the burst is the only allowed effect, in green for girl and cyan for bro), landing |
| `misc` | 3 | crouching guard pose, victory pose with a fist raised, defeated lying face down |

**Regular enemies (glitchbot, manager, firewall), 8 strips each:**
`idle` 4, `walk` 6, `attack` 4 (their signature attack: glitchbot pipe swing, manager
throwing the clipboard, firewall shield bash), `windup` 2 (the telegraph before the attack,
exaggerated), `hurt` 2, `knockdown` 4 (as for heroes), `held` 2 (being grabbed, held by the
collar, dazed), `special` 2 (glitchbot: glitching/teleporting; manager: angry shouting;
firewall: shield up blocking).

**Bosses, about 8 strips each:** `idle` 4, `move` 6, two or three `attack` strips of 4 that
match their attacks (chad: charge, buzzword throw, jump slam; rack: cable whip, raising its
arms, laser charge and overheat; spag: spitting orbs, tentacle stab, swooping dive and
tangled on the floor; nexus: shield ring spinning, shield opening, beam charge), `hurt` 2,
`defeated` 4.

**Portraits (one per character):**
> A close-up pixel art portrait of the head and shoulders of the attached character, facing
> slightly toward the viewer, for a dialogue box. [STYLE, but replace "Full body, side
> view, facing right" with "Head and shoulders portrait"]

Plus **priya** (a cheerful young female intern, dark hair in a bun, yellow cardigan, teal
pants, blue ID badge on a lanyard) and **gus** (a grumpy old sysadmin, green beanie, big
grey-brown beard, red plaid flannel shirt, jeans, holding a coffee mug): character sheet,
`idle` 4, `talk` 4, portrait.

---

## Backgrounds

Each stage is drawn in layers so it can scroll with depth. Generate each layer as its own
image at **16:9**, in the same style. Attach your stage concept image as a reference.

> STYLE: high-quality 16-bit pixel art background in the style of Streets of Rage 2, detailed,
> crisp hard pixels, no anti-aliasing, no blur, no characters, no people, no text, no UI.

1. **far layer** (`stageN_far.png`): the distant view, e.g. *"night city skyline through
   huge office windows, neon signs, rain"*. To loop: *"the image must begin and end exactly
   in the middle of a wide dark vertical pillar, so copies placed side by side join
   inside the pillar."* (Stage 1's first far layer works by cropping pillar to pillar.)
2. **back wall** (`stageN_wall.png`): the room behind the action, *"seen straight on, flat
   orthographic side view like a 2D side-scrolling game, the floor line at the very bottom
   of the image, the floor itself not shown"*. Make 3 to 5 of these per stage for variety
   (stage 1: cubicle rows with monitors; a break room with a broken vending machine and a
   coffee machine; a corridor with posters; a glass meeting room; the executive lounge).
3. **floor strip** (`stageN_floor.png`): *"a seamless horizontally tiling strip of floor
   seen from the side and slightly above, [carpet with scattered papers / metal grating with
   cables / glowing data grid], with the bottom of the wall (baseboard) along the top edge.
   A shallow strip: the floor should look about as deep as a person is tall, 8:1 wide
   image."* Objects on it should be small next to a person (a sheet of paper about the size
   of a shoe).
4. **props** (`stageN_props.png`): *"a row of separate objects on a flat magenta #FF00FF
   background, evenly spaced: [office chair, potted plant, water cooler, desk with a CRT
   monitor, printer, filing cabinet, cardboard box]"*. Desks and crates double as platforms
   and breakables.

Stages: 1 *the disrupted office* (night, rain, neon city outside), 2 *the server farm*
(dark, blue LED racks, cable trays, a glowing blue core at the end), 3 *the cloud* (a
digital realm: purple neon grid, floating data cubes, binary rain), 4 *the core* (red
emergency lighting, pipes, hex panels, a giant reactor).

---

## Checklist

- [ ] bro: sheet, 17 strips, portrait
- [ ] girl: sheet, 17 strips, portrait
- [ ] glitchbot, manager, firewall: sheet, 8 strips, portrait each
- [ ] blob, drone: sheet, their strips
- [ ] chad, rack, spag, nexus: sheet, strips, portrait each
- [ ] priya, gus: sheet, idle, talk, portrait
- [ ] stages 1 to 4: far, 3 to 5 walls, floor, props

Start small: **bro's sheet, `idle`, `walk` and `punch`**, plus **stage 1 far + one wall +
floor**. Upload those first so the import pipeline can be tuned before you make the rest.
