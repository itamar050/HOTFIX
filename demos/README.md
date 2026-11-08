# Style demos

Two small, separate Godot 4.4 projects made to compare art directions for the brawler. Both
are built entirely in code (no imported art) with original characters: Code Bro and a Nexus
security goon. Same controls and fight rules in both.

- `demo25d/`: option 1, 2.5D. 3D characters made of simple meshes on a joint hierarchy,
  toon shading and outlines, a night street with lights, rain and fog, side-view camera.
  A real model (e.g. a rigged Code Bro .glb) would replace `fighter3d.gd`'s mesh building.
- `vector2d/`: option 2, 2D vector cartoon. Outlined shapes on bones (cut-out animation),
  a layered vector street.

Run: open the folder's `project.godot` in Godot 4.4.1 and press F5. Autoplay for
recordings: `godot --path demos/<name> -- --demo`.
