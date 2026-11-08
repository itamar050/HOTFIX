extends Node2D
## One body part of a cut-out character: a list of vector shapes drawn with a dark outline.
## Shapes: ["cap", a, b, r, col] capsule, ["circle", c, r, col], ["poly", pts, col, tex]
## (tex: optional pattern texture), ["line", a, b, w, col] (detail lines, no outline).

const OUTLINE := Color(0.07, 0.05, 0.1)
const OW := 3.0
var shapes: Array = []
var shade := 1.0  ## far-side limbs are drawn darker


func _draw() -> void:
	for s in shapes:  # outlines first, so overlapping shapes of one part merge cleanly
		match s[0]:
			"cap":
				draw_circle(s[1], s[3] + OW, OUTLINE)
				draw_circle(s[2], s[3] + OW, OUTLINE)
				draw_line(s[1], s[2], OUTLINE, (s[3] + OW) * 2.0)
			"circle":
				draw_circle(s[1], s[2] + OW, OUTLINE)
			"poly":
				var pts: PackedVector2Array = s[1]
				var closed := pts.duplicate()
				closed.append(pts[0])
				draw_polyline(closed, OUTLINE, OW * 2.0, true)
	for s in shapes:
		match s[0]:
			"cap":
				var c := _c(s[4])
				draw_circle(s[1], s[3], c)
				draw_circle(s[2], s[3], c)
				draw_line(s[1], s[2], c, s[3] * 2.0)
			"circle":
				draw_circle(s[1], s[2], _c(s[3]))
			"poly":
				var pts: PackedVector2Array = s[1]
				if s.size() > 3 and s[3] != null:
					var uvs := PackedVector2Array()
					for p in pts:
						uvs.append(p / 48.0)
					draw_colored_polygon(pts, _c(s[2]), uvs, s[3])
				else:
					draw_colored_polygon(pts, _c(s[2]))
			"line":
				draw_line(s[1], s[2], _c(s[4]), s[3], true)


func _c(col: Color) -> Color:
	return Color(col.r * shade, col.g * shade, col.b * shade * 1.05, col.a)
