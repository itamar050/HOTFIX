extends Node2D
## HOTFIX demo, option 2: a 2D vector cartoon brawler. Smooth outlined shapes, skeletal
## (cut-out) animation, a layered vector street, a shallow depth lane. Built in code.

const Fighter2D := preload("res://fighter2d.gd")

var lane_x := Vector2(40.0, 5200.0)
var lane_y := Vector2(486.0, 640.0)
var world: Node2D
var player
var fighters: Array = []
var cam: Camera2D
var cam_x := 640.0
var shake := 0.0
var hitstop := 0
var tick := 0
var demo := false
var hud: Control
var rain: Node2D
var sparks: Array = []
var waves := [[Vector2(1250, 520), Vector2(1350, 620)], [Vector2(2300, 600), Vector2(2400, 500), Vector2(1700, 560)]]
var wave := 0
var font: Font
const K := Color(0.07, 0.05, 0.1)


func _ready() -> void:
	demo = "--demo" in OS.get_cmdline_user_args()
	font = ThemeDB.fallback_font
	var keys := {"left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D], "up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S], "attack": [KEY_X, KEY_J, KEY_SPACE]}
	for a in keys:
		InputMap.add_action(a)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	_layers()
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	player = Fighter2D.new()
	world.add_child(player)
	player.setup(self, "bro", Vector2(300, 560))
	fighters.append(player)
	_spawn_wave()
	cam = Camera2D.new()
	cam.position = Vector2(640, 360)
	add_child(cam)
	cam.make_current()
	var hl := CanvasLayer.new()
	add_child(hl)
	hud = Control.new()
	hud.size = Vector2(1280, 720)
	hud.draw.connect(_draw_hud)
	hl.add_child(hud)


# ---- the vector street, back to front ----------------------------------------------------
func _layer(scroll: float, repeat: float, draw_fn: Callable, z: int) -> Node2D:
	var p := Parallax2D.new()
	p.scroll_scale = Vector2(scroll, 1)
	if repeat > 0:
		p.repeat_size = Vector2(repeat, 0)
		p.repeat_times = 3
	p.z_index = z
	add_child(p)
	var n := Node2D.new()
	n.draw.connect(draw_fn.bind(n))
	p.add_child(n)
	return n


func _layers() -> void:
	_layer(0.0, 0, _draw_sky, -50)
	_layer(0.15, 1600, _draw_far, -45)
	_layer(0.45, 1800, _draw_mid, -40)
	var front := Node2D.new()
	front.z_index = -30
	front.draw.connect(_draw_front.bind(front))
	add_child(front)
	_layer(1.3, 2000, _draw_fore, 10)
	rain = Node2D.new()
	rain.z_index = 15
	rain.draw.connect(_draw_rain)
	add_child(rain)


func _grad(n: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	n.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _draw_sky(n: Node2D) -> void:
	_grad(n, Rect2(0, 0, 1280, 260), Color8(16, 14, 46), Color8(70, 36, 96))
	_grad(n, Rect2(0, 260, 1280, 460), Color8(70, 36, 96), Color8(200, 90, 110))
	for i in 5:
		n.draw_circle(Vector2(980, 120), 90 - i * 14, Color(1, 0.95, 0.85, 0.04 + i * 0.02))
	n.draw_circle(Vector2(980, 120), 34, Color8(244, 236, 214))
	var r := RandomNumberGenerator.new()
	r.seed = 1
	for i in 80:
		n.draw_circle(Vector2(r.randf() * 1280, r.randf() * 260), r.randf_range(0.8, 1.8), Color(1, 1, 1, r.randf_range(0.3, 0.9)))


func _skyline(n: Node2D, w: float, base: float, col: Color, seed_: int, hmin: float, hmax: float, win: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	var x := 0.0
	while x < w:
		var bw := r.randf_range(70, 150)
		var bh := r.randf_range(hmin, hmax)
		var c := col.lightened(r.randf_range(-0.05, 0.08))
		var top := base - bh
		n.draw_rect(Rect2(x, top, bw - 4, bh + 400), c)
		if r.randf() < 0.35:
			n.draw_rect(Rect2(x + bw * 0.4, top - 30, 4, 30), c)
			n.draw_circle(Vector2(x + bw * 0.4 + 2, top - 32), 3, Color8(255, 70, 70))
		var y := top + 14
		while y < base - 10:
			var xx := x + 10
			while xx < x + bw - 18:
				if r.randf() < win:
					n.draw_rect(Rect2(xx, y, 8, 11), Color8(255, 210, 130) if r.randf() < 0.7 else Color8(150, 210, 255))
				xx += 16
			y += 22
		x += bw


func _draw_far(n: Node2D) -> void:
	_skyline(n, 1600, 420, Color8(46, 34, 86), 3, 120, 300, 0.12)


func _draw_mid(n: Node2D) -> void:
	_skyline(n, 1800, 470, Color8(32, 24, 60), 4, 160, 360, 0.25)


const SHOPS := [["NOODLES", Color8(255, 220, 90), Color8(150, 60, 52)], ["ARCADE", Color8(255, 90, 230), Color8(70, 76, 120)],
	["NEXUS DYNAMICS", Color8(110, 230, 255), Color8(48, 58, 92)], ["LAUNDRY", Color8(120, 255, 170), Color8(110, 84, 78)],
	["PIZZA 24H", Color8(255, 130, 80), Color8(96, 66, 104)], ["COFFEE", Color8(255, 200, 140), Color8(60, 94, 104)]]


func _draw_front(n: Node2D) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var x := -40.0
	var i := 0
	var ground := 486.0
	while x < 5400:
		var w := r.randf_range(380, 520)
		var h := r.randf_range(300, 420)
		var shop: Array = SHOPS[i % SHOPS.size()]
		var wall: Color = shop[2]
		var top := ground - h
		n.draw_rect(Rect2(x, top, w, h), wall)
		n.draw_rect(Rect2(x, top, w, 10), wall.lightened(0.25))
		n.draw_rect(Rect2(x, top, 3, h), K)
		# upper windows
		var wy := top + 30
		while wy < ground - 200:
			var wx := x + 30
			while wx < x + w - 60:
				var lit := r.randf() < 0.5
				n.draw_rect(Rect2(wx - 3, wy - 3, 50, 64), K)
				_grad(n, Rect2(wx, wy, 44, 58), Color8(255, 214, 150) if lit else Color8(34, 38, 70), Color8(230, 150, 100) if lit else Color8(24, 26, 52))
				n.draw_rect(Rect2(wx - 6, wy + 60, 56, 6), wall.lightened(0.3))
				wx += 80
			wy += 96
		# shop front
		var gx := x + 30
		var gw := w - 150
		n.draw_rect(Rect2(gx - 4, ground - 150, gw + 8, 150), K)
		_grad(n, Rect2(gx, ground - 146, gw, 146), shop[1].lightened(0.55), shop[1].darkened(0.2))
		n.draw_rect(Rect2(gx + 12, ground - 140, 18, 134), Color(1, 1, 1, 0.35))
		n.draw_rect(Rect2(x + w - 104, ground - 170, 70, 170), K)
		n.draw_rect(Rect2(x + w - 100, ground - 166, 62, 166), wall.darkened(0.45))
		# awning
		for k in range(0, int(gw) + 20, 30):
			var c := Color8(220, 60, 70) if (k / 30) % 2 == 0 else Color8(244, 236, 226)
			n.draw_colored_polygon(PackedVector2Array([Vector2(gx - 10 + k, ground - 196), Vector2(gx + 20 + k, ground - 196), Vector2(gx + 26 + k, ground - 160), Vector2(gx - 4 + k, ground - 160)]), c)
		# neon sign with a soft glow
		var sc: Color = shop[1]
		var txt: String = shop[0]
		var fs := 44
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cx := gx + gw / 2
		for g in 6:
			n.draw_circle(Vector2(cx, ground - 236), tw * 0.5 + 40 - g * 10, Color(sc, 0.05))
		n.draw_rect(Rect2(cx - tw / 2 - 16, ground - 270, tw + 32, 60), Color8(20, 14, 30))
		n.draw_string_outline(font, Vector2(cx - tw / 2, ground - 224), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(sc, 0.35))
		n.draw_string(font, Vector2(cx - tw / 2, ground - 224), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, sc.lightened(0.35))
		# street lamp
		n.draw_rect(Rect2(x + w - 14, ground - 330, 8, 330), K)
		n.draw_rect(Rect2(x + w - 40, ground - 336, 46, 12), K)
		n.draw_rect(Rect2(x + w - 36, ground - 330, 38, 6), Color8(255, 240, 190))
		for g in 5:
			n.draw_circle(Vector2(x + w - 18, ground - 320), 70 - g * 12, Color(1, 0.9, 0.6, 0.05))
		x += w
		i += 1
	# sidewalk lane with perspective slabs, curb and road
	_grad(n, Rect2(-100, ground, 5600, 170), Color8(84, 76, 108), Color8(132, 122, 150))
	n.draw_rect(Rect2(-100, ground, 5600, 8), Color(0, 0, 0, 0.35))
	for y in [520.0, 562.0, 612.0]:
		n.draw_line(Vector2(-100, y), Vector2(5500, y), Color8(70, 62, 92), 2)
	var sx := -100.0
	while sx < 5500:
		n.draw_line(Vector2(sx, ground), Vector2(sx - 30, 656), Color8(76, 68, 98), 2)
		sx += 120
	r.seed = 11
	for k in 30:
		var px := r.randf() * 5400
		var py := r.randf_range(500, 640)
		var pw := r.randf_range(50, 130)
		n.draw_set_transform(Vector2(px, py), 0, Vector2(1, 0.22))
		n.draw_circle(Vector2.ZERO, pw * 0.5, Color8(70, 60, 110))
		n.draw_circle(Vector2(0, -2), pw * 0.36, Color8(170, 110, 190, 160))
		n.draw_set_transform(Vector2.ZERO)
	n.draw_rect(Rect2(-100, 656, 5600, 8), Color8(200, 194, 210))
	n.draw_rect(Rect2(-100, 664, 5600, 10), Color8(110, 104, 128))
	n.draw_rect(Rect2(-100, 674, 5600, 60), Color8(34, 32, 48))
	var lx := -100.0
	while lx < 5500:
		n.draw_rect(Rect2(lx, 700, 80, 5), Color8(220, 190, 80))
		lx += 200


func _draw_fore(n: Node2D) -> void:
	for x in [150.0, 1300.0]:
		n.draw_rect(Rect2(x - 3, 640, 46, 90), K)
		n.draw_rect(Rect2(x, 643, 40, 87), Color8(150, 30, 40))
		n.draw_rect(Rect2(x - 10, 668, 60, 14), K)
		n.draw_rect(Rect2(x - 7, 671, 54, 8), Color8(190, 52, 60))
	for x in [700.0, 1800.0]:
		n.draw_rect(Rect2(x - 3, 610, 76, 120), K)
		n.draw_rect(Rect2(x, 613, 70, 117), Color8(50, 72, 66))
		n.draw_rect(Rect2(x - 8, 600, 86, 16), K)
		n.draw_rect(Rect2(x - 5, 603, 80, 10), Color8(74, 100, 92))


func _draw_rain() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in 160:
		var x := float((r.randi_range(0, 1400) - tick * 3) % 1400)
		if x < 0:
			x += 1400
		var y := float((r.randi_range(0, 760) + tick * 18) % 780) - 30
		rain.draw_line(Vector2(x - 60, y), Vector2(x - 64, y + 16), Color(0.7, 0.75, 1.0, 0.4), 2)


# ---- fighters ---------------------------------------------------------------------------
func _spawn_wave() -> void:
	for p in waves[wave]:
		var g := Fighter2D.new()
		world.add_child(g)
		g.setup(self, "goon", p)
		g.atk_cd = 60 + fighters.size() * 40
		fighters.append(g)


func held(a: String) -> bool:
	return _auto.get(a, false) if demo else Input.is_action_pressed(a)


func pressed(a: String) -> bool:
	return (_auto.get(a, false) and not _auto_prev.get(a, false)) if demo else Input.is_action_just_pressed(a)


func can_attack(who) -> bool:
	for f in fighters:
		if f != who and f != player and f.state == "attack":
			return false
	return true


func try_hit(att, a: Dictionary) -> void:
	for f in fighters:
		if f == att or f.dead or f.is_player == att.is_player or f.state in ["fly", "down", "getup"]:
			continue
		var dx: float = (f.position.x - att.position.x) * att.face
		if dx > 10 and dx < a["reach"] and absf(f.position.y - att.position.y) < 30:
			f.take_hit(a, att.face)
			att.hit_done = true
			hitstop = 6 if a.get("down", false) else 4
			shake = 10.0 if a.get("down", false) else 5.0
			sparks.append([f.position + Vector2(-att.face * 20, -190 * f.scale.y), 0])


func land_fx(_f) -> void:
	shake = maxf(shake, 7.0)


func remove(f) -> void:
	fighters.erase(f)
	f.queue_free()


func _physics_process(_d: float) -> void:
	tick += 1
	if demo:
		_autopilot()
	if hitstop > 0:
		hitstop -= 1
	else:
		for f in fighters.duplicate():
			if is_instance_valid(f):
				f.step()
	var alive := 0
	for f in fighters:
		if not f.is_player:
			alive += 1
	if alive == 0 and wave < waves.size() - 1:
		wave += 1
		_spawn_wave()
	cam_x = lerpf(cam_x, player.position.x + player.face * 140.0, 0.08)
	cam_x = maxf(cam_x, 640.0)
	shake = maxf(0.0, shake - 0.6)
	cam.position = Vector2(cam_x, 360) + Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	rain.position = cam.position - Vector2(640, 360)
	for s in sparks.duplicate():
		s[1] += 1
		if s[1] > 9:
			sparks.erase(s)
	rain.queue_redraw()
	hud.queue_redraw()
	queue_redraw()
	if demo and tick % 60 == 0:
		print("demo t=%d x=%d y=%d hp=%d wave=%d foes=%d" % [tick, player.position.x, player.position.y, player.hp, wave, alive])
	if demo and tick > 1500:
		get_tree().quit()


func _draw() -> void:
	# hit sparks: a white/yellow star with an outline
	for s in sparks:
		var c: Vector2 = s[0]
		var k: int = s[1]
		var pts := PackedVector2Array()
		for i in 16:
			var rr := (30.0 + k * 5.0) * (1.0 if i % 2 == 0 else 0.42)
			pts.append(c + Vector2.from_angle(i * TAU / 16 + k * 0.1) * rr)
		draw_colored_polygon(pts, Color8(255, 230, 120) if k > 3 else Color.WHITE)
		var cl := pts.duplicate()
		cl.append(pts[0])
		draw_polyline(cl, K, 3, true)


func _draw_hud() -> void:
	hud.draw_rect(Rect2(24, 22, 324, 28), Color(0.05, 0.03, 0.1, 0.85))
	hud.draw_rect(Rect2(28, 36, 316 * player.hp / player.max_hp, 10), Color8(80, 230, 110))
	hud.draw_string(font, Vector2(30, 33), "CODE BRO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color8(255, 220, 90))
	var y := 22
	for f in fighters:
		if f.is_player:
			continue
		hud.draw_rect(Rect2(1020, y, 236, 18), Color(0.05, 0.03, 0.1, 0.85))
		hud.draw_rect(Rect2(1024, y + 9, 228 * f.hp / f.max_hp, 6), Color8(255, 150, 40))
		hud.draw_string(font, Vector2(1026, y + 8), "NEXUS SECURITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
		y += 22
	hud.draw_string(font, Vector2(24, 704), "DEMO 2: 2D VECTOR   ARROWS/WASD MOVE (UP/DOWN = DEPTH)   X/SPACE PUNCH (x3 COMBO)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.82, 0.95))


var _auto := {}
var _auto_prev := {}


func _autopilot() -> void:
	_auto_prev = _auto
	_auto = {}
	var near = null
	for f in fighters:
		if not f.is_player and not f.dead and (near == null or absf(f.position.x - player.position.x) < absf(near.position.x - player.position.x)):
			near = f
	if near == null:
		_auto["right"] = true
		return
	var dx: float = near.position.x - player.position.x
	var dy: float = near.position.y - player.position.y
	if absf(dy) > 14:
		_auto["down" if dy > 0 else "up"] = true
	if absf(dx) > 140:
		_auto["right" if dx > 0 else "left"] = true
	elif (dx > 0) != (player.face > 0):
		_auto["right" if dx > 0 else "left"] = true
	elif absf(dy) < 24:
		_auto["attack"] = tick % 10 < 5
