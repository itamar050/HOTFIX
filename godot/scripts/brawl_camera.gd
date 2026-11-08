extends Camera2D
## Brawler camera: follows a target with a dead zone and look-ahead in the facing direction,
## keeps the fighting lane framed at a fixed height, eases into arena locks instead of
## snapping, and shakes with decaying "trauma". The drawn position is rounded to whole
## pixels, so pixel art never shimmers while the camera moves.

const HALF_W := 320.0  ## half the 640 px view
const CENTER_Y := 180.0  ## fixed vertical framing (the lane sits in the lower third)
const DEAD_ZONE := 20.0
const LOOK_AHEAD := 40.0

var target: Node2D
var fx := 0.0  ## unsnapped camera x
var look := 0.0
var bound_l := 0.0  ## wanted bounds (level or arena)
var bound_r := 2400.0
var cur_l := 0.0  ## eased bounds
var cur_r := 2400.0
var trauma := 0.0


func setup(t: Node2D, left: float, right: float) -> void:
	target = t
	bound_l = left
	bound_r = right
	cur_l = left
	cur_r = right
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	position_smoothing_enabled = false
	fx = clampf(t.position.x, left + HALF_W, right - HALF_W)
	position = Vector2(roundf(fx), CENTER_Y)
	make_current()


## Arena locks call this; the edges slide into place over a few frames.
func set_bounds(left: float, right: float) -> void:
	bound_l = left
	bound_r = right


## 0..1; the shake grows with trauma squared, so small hits stay subtle.
func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func _physics_process(_delta: float) -> void:
	if target == null:
		return
	var face: int = target.face
	look = move_toward(look, face * LOOK_AHEAD, 1.2)
	var want: float = target.position.x + look
	var dx := want - fx
	if absf(dx) > DEAD_ZONE:
		fx += (dx - signf(dx) * DEAD_ZONE) * 0.14
	cur_l = move_toward(cur_l, bound_l, 6.0)
	cur_r = move_toward(cur_r, bound_r, 6.0)
	fx = clampf(fx, cur_l + HALF_W, cur_r - HALF_W)
	trauma = maxf(0.0, trauma - 0.03)
	var s := trauma * trauma
	offset = Vector2(roundf(randf_range(-1, 1) * 9.0 * s), roundf(randf_range(-1, 1) * 5.0 * s))
	position = Vector2(roundf(fx), CENTER_Y)
