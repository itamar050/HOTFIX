# video_sprites: sprite strips from a generated animation video

For videos of a character animated over a busy background (e.g. a Gemini clip of Code Bro
walking down a street, camera tracking him). Source frames: `art/raw/video/<anim>/`.

1. `matte.py <frames_dir> <out_dir> [N]`: finds the walk loop (the lag where the jeans/leg
   silhouette repeats; picks the start with the cleanest loop), takes N evenly spaced frames,
   and cuts the character out with OpenCV GrabCut. Seeds: jeans and plaid connected to the
   legs (definitely him), sneaker reds/whites near the jeans, the face; an oval for the head
   (median position over all frames, so a red sign behind him can't move it); far away = street.
   Writes `cut_NN.png` (RGBA, full size) + `cuts.json`.
2. `to_strip.py <cuts_dir> <out_dir> <name> [--outline]`: one fixed crop and scale for every
   frame (no jitter, the bob stays), feet on the cell ground line (160x128 cells, feet at 80,124,
   120 px tall), filled holes (glasses), hard alpha, one 40-colour palette, optional 1 px outline.

Needs `pip install opencv-python-headless`. Check the cut-outs by eye: busy backgrounds can
still leave small bits on (or cut small bits off) a frame.
