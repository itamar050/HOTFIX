# pixel8: 8-bit sprites drawn in code

Mock-up generators for the 8-bit (Shovel Knight-style) direction. Run from this folder.

- `bro.py`: palette letters + Code Bro head/torso grids (12 px wide, hand placed).
- `rig8.py`: limbs from joint angles (`pose(back_leg, front_leg, back_arm, front_arm)`,
  angles in degrees, + = forward), 1 px outline. Frames: walk0-7 (feet don't slide at
  1.07 px per tick with a frame every 2 ticks), idle0-1, punch0-2, crouch, rise, fall, land.
- `cast.py`: other characters on the same rig (swap head/torso/palette): PM.
- `props.py`: bug, JIRA ticket, sticky-note task, coin.
- `scene.py` / `scene3.py`: 400x240 stage 1 screen + animated GIFs (`mock.gif`, `mock3.gif`).
- `bro2.py`: the first hand-drawn leg grids (rejected walk), kept only because scene.py imports its frame code.
