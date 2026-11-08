extends Node2D
## A 2D vector cartoon fighter: outlined shapes on a bone hierarchy (cut-out animation).
## The poses are joint angles per frame (same scheme as the 2.5D demo), so walks always
## alternate. Position = feet; y is depth in the lane; the world node y-sorts fighters.

const Part := preload("res://part.gd")

var main
var kind := "bro"
var is_player := true
var vel := Vector2.ZERO
var face := 1
var state := "idle"
var t := 0
var hp := 100
var max_hp := 100
var attack := ""
var hit_done := false
var buffered := false
var atk_cd := 90
var flash := 0
var walk_ph := 0.0
var dead := false
var height := 0.0
var vy := 0.0

var root: Node2D
var hips: Node2D
var spine: Node2D
var head: Node2D
var sh := {}
var el := {}
var hj := {}
var kn := {}
var parts: Array = []


func setup(m, k: String, pos: Vector2) -> void:
	main = m
	kind = k
	is_player = k == "bro"
	position = pos
	face = 1 if is_player else -1
	max_hp = 100 if is_player else 60
	hp = max_hp
	_build()


static var _plaid: ImageTexture


static func plaid() -> ImageTexture:
	if _plaid:
		return _plaid
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		for x in 16:
			var c := Color8(176, 48, 34)
			if x % 8 < 2 or y % 8 < 2:
				c = Color8(110, 26, 18)
			if x % 8 < 2 and y % 8 < 2:
				c = Color8(70, 16, 12)
			if x % 8 == 5 or y % 8 == 5:
				c = Color8(232, 164, 70)
			img.set_pixel(x, y, c)
	_plaid = ImageTexture.create_from_image(img)
	return _plaid


func _sc(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * k)
	return out


func _node(parent: Node2D, pos: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node2D, shapes: Array, shade := 1.0) -> Node2D:
	var p := Part.new()
	p.shapes = shapes
	p.shade = shade
	p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	parent.add_child(p)
	parts.append(p)
	return p


func _build() -> void:
	var bro := kind == "bro"
	var skin := Color8(244, 190, 152) if bro else Color8(196, 140, 108)
	var jeans := Color8(64, 100, 176) if bro else Color8(36, 36, 48)
	var shirt := Color8(176, 48, 34) if bro else Color8(36, 36, 48)
	var shoe := Color8(204, 44, 48) if bro else Color8(24, 24, 28)
	var hair := Color8(110, 64, 32) if bro else Color8(44, 34, 30)
	var b := 1.0 if bro else 1.14
	root = _node(self, Vector2.ZERO)
	hips = _node(root, Vector2(0, -122 * b))
	# limbs: "l" = far side (darker, behind), "r" = near side
	for s in ["l", "r"]:
		var shade := 0.72 if s == "l" else 1.0
		hj[s] = _node(hips, Vector2(-2 if s == "l" else 2, 0))
		if s == "r":
			hips.move_child(hj[s], hips.get_child_count() - 1)
		_part(hj[s], [["cap", Vector2(0, 0), Vector2(0, 58 * b), 16 * b, jeans]], shade)
		kn[s] = _node(hj[s], Vector2(0, 58 * b))
		_part(kn[s], [["cap", Vector2(0, 0), Vector2(0, 54 * b), 14 * b, jeans],
			["poly", _sc(PackedVector2Array([Vector2(-14, 50), Vector2(20, 50), Vector2(34, 60), Vector2(33, 70), Vector2(-15, 70)]), b), shoe],
			["line", Vector2(-14, 68) * b, Vector2(32, 68) * b, 4, Color8(240, 238, 230)]], shade)
	spine = _node(hips, Vector2(0, -6))
	hips.move_child(spine, 1)  # draw order: far leg, spine (arms, torso, head), near leg
	# far arm (behind the torso)
	_arm("l", 0.72, b, shirt, skin)
	# torso
	var torso := _sc(PackedVector2Array([Vector2(-30, -94), Vector2(26, -96), Vector2(34, -60), Vector2(28, 0), Vector2(-28, 0), Vector2(-36, -60)]), b)
	if bro:
		_part(spine, [["poly", torso, Color.WHITE, plaid()],
			["poly", PackedVector2Array([Vector2(10, -92), Vector2(24, -92), Vector2(26, -4), Vector2(14, -4)]), Color8(64, 64, 76)],
			["line", Vector2(-26, -90), Vector2(24, -8), 6, Color8(34, 30, 34)],
			["poly", PackedVector2Array([Vector2(-58, -36), Vector2(-24, -38), Vector2(-22, -4), Vector2(-56, -2)]), Color8(56, 52, 54)],
			["line", Vector2(-56, -28), Vector2(-24, -30), 3, Color8(80, 76, 78)]])
	else:
		_part(spine, [["poly", torso, shirt],
			["poly", _sc(PackedVector2Array([Vector2(12, -100), Vector2(30, -100), Vector2(22, -60)]), b), Color8(236, 236, 240)],
			["poly", _sc(PackedVector2Array([Vector2(20, -96), Vector2(26, -96), Vector2(27, -58), Vector2(22, -54)]), b), Color8(200, 30, 40)]])
	# head
	var neck := _node(spine, Vector2(0, -98 * b))
	head = _node(neck, Vector2(0, -4))
	_part(neck, [["cap", Vector2(2, 6), Vector2(4, -10), 10, skin]])
	var hs: Array = [["circle", Vector2(6, -38), 36.0, skin], ["circle", Vector2(-10, -36), 8.0, skin],
		["poly", PackedVector2Array([Vector2(40, -40), Vector2(50, -30), Vector2(40, -26)]), skin],
		["line", Vector2(30, -14), Vector2(40, -16), 3, Color8(130, 60, 60)]]
	if bro:
		hs.append(["poly", PackedVector2Array([Vector2(-32, -30), Vector2(-36, -56), Vector2(-26, -66), Vector2(-30, -84), Vector2(-12, -74),
			Vector2(-6, -92), Vector2(8, -76), Vector2(20, -90), Vector2(26, -72), Vector2(42, -78), Vector2(38, -60), Vector2(46, -54),
			Vector2(30, -52), Vector2(14, -58), Vector2(-6, -52), Vector2(-16, -40)]), hair])
		hs.append(["poly", PackedVector2Array([Vector2(18, -48), Vector2(44, -48), Vector2(44, -34), Vector2(18, -34)]), Color8(190, 228, 250)])
		hs.append(["line", Vector2(16, -48), Vector2(46, -48), 4, Color8(24, 20, 26)])
		hs.append(["line", Vector2(16, -34), Vector2(46, -34), 4, Color8(24, 20, 26)])
		hs.append(["line", Vector2(17, -48), Vector2(17, -34), 4, Color8(24, 20, 26)])
		hs.append(["line", Vector2(45, -48), Vector2(45, -34), 4, Color8(24, 20, 26)])
		hs.append(["line", Vector2(16, -44), Vector2(-6, -42), 3, Color8(24, 20, 26)])
		hs.append(["circle", Vector2(34, -41), 3.5, Color8(30, 24, 30)])
		hs.append(["line", Vector2(26, -54), Vector2(40, -55), 3, Color8(90, 50, 26)])
	else:
		hs.append(["poly", PackedVector2Array([Vector2(-28, -50), Vector2(-14, -70), Vector2(12, -74), Vector2(34, -64), Vector2(40, -54), Vector2(10, -60), Vector2(-20, -56)]), hair])
		hs.append(["poly", PackedVector2Array([Vector2(14, -48), Vector2(46, -48), Vector2(44, -36), Vector2(16, -36)]), Color8(18, 18, 24)])
		hs.append(["line", Vector2(14, -46), Vector2(-8, -44), 4, Color8(18, 18, 24)])
	_part(head, hs)
	# near arm (in front)
	_arm("r", 1.0, b, shirt, skin)


func _arm(s: String, shade: float, b: float, shirt: Color, skin: Color) -> void:
	sh[s] = _node(spine, Vector2(-4 if s == "l" else 0, -86 * b))
	_part(sh[s], [["cap", Vector2(0, 0), Vector2(0, 46 * b), 15 * b, shirt],
		["cap", Vector2(0, 40 * b), Vector2(0, 46 * b), 16 * b, shirt.darkened(0.25)]], shade)
	el[s] = _node(sh[s], Vector2(0, 46 * b))
	_part(el[s], [["cap", Vector2(0, 0), Vector2(0, 38 * b), 11 * b, skin if kind == "bro" else shirt],
		["circle", Vector2(0, 46 * b), 14.0 * b, skin]], shade)


# ---- poses (degrees, + = swing forward), same numbers as the 2.5D demo ---------------------
func _rot(n: Node2D, deg: float, k: float) -> void:
	n.rotation = lerp_angle(n.rotation, -deg_to_rad(deg), k)


func _pose(p: Dictionary, k: float) -> void:
	_rot(hj["l"], p.get("hl", 0.0), k)
	_rot(hj["r"], p.get("hr", 0.0), k)
	_rot(kn["l"], p.get("kl", 0.0), k)
	_rot(kn["r"], p.get("kr", 0.0), k)
	_rot(sh["l"], p.get("sl", 0.0), k)
	_rot(sh["r"], p.get("sr", 0.0), k)
	_rot(el["l"], p.get("el", 0.0), k)
	_rot(el["r"], p.get("er", 0.0), k)
	_rot(spine, p.get("sp", 0.0), k)
	_rot(head, p.get("hd", 0.0), k)
	var by: float = (p.get("y", 0.92) - 0.92) * 140.0
	hips.position.y = lerpf(hips.position.y, -122.0 * (1.0 if kind == "bro" else 1.14) - by, k)


const GUARD := {"sl": 50, "el": 110, "sr": 30, "er": 120}
const ATTACKS := {
	"jab": {"len": 16, "hit": 5, "reach": 150.0, "dmg": 8, "kb": 7.0, "next": "cross"},
	"cross": {"len": 18, "hit": 6, "reach": 160.0, "dmg": 10, "kb": 9.0, "next": "kick"},
	"kick": {"len": 26, "hit": 9, "reach": 185.0, "dmg": 16, "kb": 14.0, "down": true},
	"goon": {"len": 30, "hit": 18, "reach": 150.0, "dmg": 9, "kb": 10.0},
}


func _anim() -> void:
	var p := {}
	match state:
		"idle":
			var bb := sin(t * 0.08)
			p = {"hl": 14, "hr": -10, "kl": -16, "kr": -10, "sp": -6 + bb, "y": 0.88 + bb * 0.008}
			p.merge(GUARD)
		"walk":
			walk_ph += 0.16
			var s := sin(walk_ph)
			var c := cos(walk_ph)
			p = {"hl": 30 * s, "hr": -30 * s, "kl": -max(0.0, -c) * 55 - 5, "kr": -max(0.0, c) * 55 - 5,
				"sl": 50 - 14 * s, "el": 105, "sr": 30 + 14 * s, "er": 115, "sp": -8, "y": 0.9 + absf(c) * 0.03}
		"attack":
			p = _attack_pose()
		"hurt":
			p = {"hl": -6, "hr": 10, "kl": -20, "kr": -10, "sl": -20, "el": 40, "sr": -30, "er": 40, "sp": 22, "hd": 18, "y": 0.86}
		"fly", "down":
			p = {"hl": 30, "hr": 10, "kl": -30, "kr": -10, "sl": 160, "el": 20, "sr": 140, "er": 30, "sp": 10, "hd": 10}
		"getup":
			p = {"hl": 70, "hr": 20, "kl": -100, "kr": -60, "sl": 20, "el": 40, "sr": 10, "er": 40, "sp": -30, "y": 0.62}
	_pose(p, 0.5 if state == "attack" else 0.3)
	var lie := 0.0
	if state == "fly":
		lie = clampf(t * 8.0, 0, 80)
	elif state == "down":
		lie = 85
	elif state == "getup":
		lie = maxf(0.0, 85 - t * 6.0)
	root.rotation = lerpf(root.rotation, -deg_to_rad(lie), 0.4)
	root.position.y = -height - (26.0 if lie > 60 else 0.0)


func _attack_pose() -> Dictionary:
	var a: Dictionary = ATTACKS[attack]
	var hit: int = a["hit"]
	var out := t >= hit - 2 and t < hit + 5
	match attack:
		"jab":
			return {"hl": 16, "hr": -12, "kl": -14, "kr": -8, "sl": 88 if out else 50, "el": 5 if out else 110, "sr": 30, "er": 120, "sp": -14 if out else -6}
		"cross":
			return {"hl": 20, "hr": -18, "kl": -12, "kr": -6, "sl": 40, "el": 120, "sr": 92 if out else 20, "er": 4 if out else 120, "sp": -20 if out else -4, "y": 0.86}
		"kick":
			var up := t >= hit - 3 and t < hit + 8
			return {"hl": -8, "hr": 92 if up else 40, "kl": -12, "kr": -6 if up else -80, "sl": 60, "el": 100, "sr": -30, "er": 60, "sp": 14 if up else 0}
		"goon":
			var wind := t < hit - 4
			return {"hl": 16, "hr": -12, "kl": -14, "kr": -8, "sl": 40, "el": 100, "sr": -40 if wind else 95, "er": 90 if wind else 5, "sp": 10 if wind else -18}
	return {}


# ---- per frame (same rules as the 2.5D demo, in pixels) ------------------------------------
func step() -> void:
	t += 1
	if flash > 0:
		flash -= 1
	if atk_cd > 0:
		atk_cd -= 1
	match state:
		"idle", "walk":
			if is_player:
				_control()
			else:
				_ai()
		"attack":
			vel.x = move_toward(vel.x, 0, 0.6)
			vel.y = 0
			if is_player and main.pressed("attack") and t > 4:
				buffered = true
			var a: Dictionary = ATTACKS[attack]
			if t == a["hit"]:
				main.try_hit(self, a)
			if t >= a["len"]:
				if buffered and hit_done and a.has("next"):
					_start(a["next"])
				else:
					_go("idle")
		"hurt":
			vel.x = move_toward(vel.x, 0, 0.5)
			if t > 18:
				_go("idle")
		"fly":
			vy -= 0.9
			height += vy
			if height <= 0:
				height = 0
				_go("down")
				main.land_fx(self)
		"down":
			vel.x = move_toward(vel.x, 0, 0.6)
			if t > 50:
				if dead:
					visible = (t / 3) % 2 == 0
					if t > 80:
						main.remove(self)
				else:
					_go("getup")
		"getup":
			if t > 16:
				_go("idle")
	position += vel
	position.x = clampf(position.x, main.lane_x.x, main.lane_x.y)
	position.y = clampf(position.y, main.lane_y.x, main.lane_y.y)
	root.scale.x = face
	# a touch of perspective: nearer to the camera = slightly bigger
	scale = Vector2.ONE * (0.9 + 0.16 * (position.y - main.lane_y.x) / (main.lane_y.y - main.lane_y.x))
	_anim()
	modulate = Color(3, 3, 3) if flash > 0 else Color.WHITE
	queue_redraw()


func _draw() -> void:
	var s := 1.0 - clampf(height / 200.0, 0, 0.5)
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.28))
	draw_circle(Vector2.ZERO, 54 * s, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)


func _go(s: String) -> void:
	state = s
	t = 0


func _start(a: String) -> void:
	attack = a
	hit_done = false
	buffered = false
	_go("attack")
	vel.x = face * (2.0 if a != "kick" else 3.0)


func _control() -> void:
	var ix: float = float(main.held("right")) - float(main.held("left"))
	var iy: float = float(main.held("down")) - float(main.held("up"))
	vel.x = move_toward(vel.x, ix * 5.0, 0.8)
	vel.y = move_toward(vel.y, iy * 3.0, 0.6)
	if ix != 0:
		face = int(signf(ix))
	_set_move()
	if main.pressed("attack"):
		_start("jab")


func _set_move() -> void:
	var moving := absf(vel.x) > 0.6 or absf(vel.y) > 0.6
	if moving and state == "idle":
		state = "walk"
	elif not moving and state == "walk":
		state = "idle"


func _ai() -> void:
	var p = main.player
	var dx: float = p.position.x - position.x
	var dy: float = p.position.y - position.y
	face = 1 if dx > 0 else -1
	var want_x: float = p.position.x - face * 140.0
	var ty: float = p.position.y if absf(dx) < 360.0 else position.y
	vel.x = move_toward(vel.x, clampf((want_x - position.x) * 0.08, -3.4, 3.4), 0.4)
	vel.y = move_toward(vel.y, clampf((ty - position.y) * 0.06, -2.2, 2.2), 0.3)
	_set_move()
	if absf(dx) < 175.0 and absf(dy) < 26.0 and atk_cd <= 0 and main.can_attack(self) and p.state in ["idle", "walk", "attack"]:
		atk_cd = randi_range(80, 140)
		_start("goon")


func take_hit(a: Dictionary, dir: int) -> void:
	hp -= a["dmg"]
	flash = 5
	face = -dir
	if hp <= 0:
		hp = 0
		dead = true
	if dead or a.get("down", false):
		_go("fly")
		vel = Vector2(dir * a["kb"] * 0.6, 0)
		vy = 11.0
		height = 1.0
	else:
		_go("hurt")
		vel = Vector2(dir * a["kb"], 0)
