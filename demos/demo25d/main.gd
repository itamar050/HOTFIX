extends Node3D
## HOTFIX demo, option 1: a 2.5D brawler. Real 3D (toon-shaded characters built from simple
## meshes, a night street with lights), side-view camera, a shallow depth lane. Everything is
## built in code. Original characters: Code Bro and a Nexus security goon.

const Fighter3D := preload("res://fighter3d.gd")

var lane_x := Vector2(-4.0, 44.0)
var lane_z := Vector2(-1.4, 1.4)
var player
var fighters: Array = []
var cam: Camera3D
var cam_x := 0.0
var shake := 0.0
var hitstop := 0
var tick := 0
var demo := false
var hud: Control
var waves := [[Vector3(9, 0, -1.0), Vector3(10, 0, 1.0)], [Vector3(22, 0, 0.8), Vector3(23, 0, -1.2), Vector3(14, 0, 0.0)]]
var wave := 0
var sparks: Array = []
var font: Font


func _ready() -> void:
	demo = "--demo" in OS.get_cmdline_user_args()
	_input_map()
	_environment()
	_street()
	player = Fighter3D.new()
	add_child(player)
	player.setup(self, "bro", Vector3(0, 0, 0.3))
	fighters.append(player)
	_spawn_wave()
	cam = Camera3D.new()
	cam.fov = 36
	add_child(cam)
	cam.current = true
	_hud()


func _input_map() -> void:
	var keys := {"left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D], "up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S], "attack": [KEY_X, KEY_J, KEY_SPACE]}
	for a in keys:
		InputMap.add_action(a)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)


# ---- the street -------------------------------------------------------------------------
func _toon(col: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.roughness = 0.9
	if emit > 0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color8(14, 12, 40)
	sm.sky_horizon_color = Color8(150, 70, 110)
	sm.ground_horizon_color = Color8(60, 40, 70)
	sm.ground_bottom_color = Color8(20, 16, 30)
	sm.sun_angle_max = 0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color8(90, 80, 150)
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color8(40, 28, 70)
	env.fog_density = 0.004
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color8(170, 180, 255)
	moon.light_energy = 0.45
	moon.rotation_degrees = Vector3(-50, -30, 0)
	moon.shadow_enabled = true
	add_child(moon)


func _street() -> void:
	# sidewalk (the fighting lane), curb, road
	var tiles := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var c := Color8(118, 112, 132)
			if x == 0 or y == 0:
				c = Color8(84, 78, 98)
			elif (x * 7 + y * 13) % 29 == 0:
				c = Color8(132, 126, 146)
			tiles.set_pixel(x, y, c)
	var side := _toon(Color.WHITE)
	side.albedo_texture = ImageTexture.create_from_image(tiles)
	side.uv1_scale = Vector3(30, 2.5, 1)
	side.uv1_triplanar = true
	side.uv1_scale = Vector3(0.6, 0.6, 0.6)
	side.roughness = 0.35
	_box(Vector3(60, 0.2, 4.4), Vector3(20, -0.1, -0.2), side)
	_box(Vector3(60, 0.24, 0.3), Vector3(20, -0.08, 2.1), _toon(Color8(170, 164, 180)))
	_box(Vector3(60, 0.2, 8), Vector3(20, -0.14, 6.2), _toon(Color8(36, 34, 48)))
	for x in range(-8, 50, 4):
		_box(Vector3(1.6, 0.02, 0.14), Vector3(x, -0.03, 4.4), _toon(Color8(220, 190, 80), 0.3))
	# buildings along the back of the sidewalk
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var x := -10.0
	var signs := ["NOODLES", "ARCADE", "NEXUS DYNAMICS", "LAUNDRY", "PIZZA 24H", "BAR", "COFFEE"]
	var sign_cols := [Color8(255, 220, 90), Color8(255, 90, 230), Color8(110, 230, 255), Color8(120, 255, 170), Color8(255, 120, 80), Color8(255, 80, 90), Color8(255, 200, 140)]
	var i := 0
	while x < 52:
		var w := r.randf_range(5.0, 8.0)
		var h := r.randf_range(6.0, 11.0)
		var col: Color = [Color8(120, 58, 52), Color8(98, 76, 72), Color8(64, 72, 104), Color8(90, 62, 98), Color8(58, 92, 100)][r.randi() % 5]
		var b := Node3D.new()
		b.position = Vector3(x + w / 2, 0, -3.0)
		add_child(b)
		_box(Vector3(w - 0.1, h, 2), Vector3(0, h / 2, -1), _toon(col), b)
		_box(Vector3(w + 0.1, 0.3, 2.2), Vector3(0, h, -1), _toon(col.lightened(0.2)), b)
		# windows: lit (emissive) or dark
		for wy in range(3, int(h) - 1, 2):
			for wx in range(int(w / 1.4)):
				var lit := r.randf() < 0.45
				var wc: Color = [Color8(255, 210, 140), Color8(170, 220, 255), Color8(255, 170, 120)][r.randi() % 3]
				_box(Vector3(0.7, 0.9, 0.08), Vector3(-w / 2 + 0.8 + wx * 1.4, wy + 0.4, 0.02), _toon(wc, 0.9) if lit else _toon(Color8(30, 34, 60)), b)
		# shop front: lit glass, door, awning, neon sign + its coloured light
		var glass_col: Color = [Color8(255, 210, 150), Color8(170, 230, 255), Color8(255, 170, 210)][i % 3]
		_box(Vector3(w * 0.62, 1.7, 0.1), Vector3(-w * 0.12, 1.15, 0.03), _toon(glass_col, 0.45), b)
		_box(Vector3(1.0, 2.1, 0.1), Vector3(w * 0.33, 1.05, 0.03), _toon(Color8(70, 50, 40)), b)
		var aw := _box(Vector3(w * 0.7, 0.12, 0.9), Vector3(-w * 0.12, 2.2, 0.4), _toon([Color8(200, 50, 60), Color8(40, 130, 90), Color8(60, 80, 170)][i % 3]), b)
		aw.rotation_degrees.x = 18
		var sc: Color = sign_cols[i % sign_cols.size()]
		var lbl := Label3D.new()
		lbl.text = signs[i % signs.size()]
		lbl.font_size = 96
		lbl.pixel_size = 0.006
		lbl.modulate = sc * 1.25
		lbl.outline_modulate = Color(sc.r * 0.3, sc.g * 0.3, sc.b * 0.3)
		lbl.outline_size = 18
		lbl.shaded = false
		lbl.position = Vector3(-w * 0.12, 3.0, 0.1)
		b.add_child(lbl)
		var nl := OmniLight3D.new()
		nl.light_color = sc
		nl.light_energy = 1.4
		nl.omni_range = 5.0
		nl.position = Vector3(-w * 0.12, 2.8, 1.2)
		b.add_child(nl)
		x += w
		i += 1
	# street lamps with warm pools of light
	for lx in range(-2, 50, 9):
		_box(Vector3(0.14, 4.2, 0.14), Vector3(lx, 2.1, -2.1), _toon(Color8(40, 40, 52)))
		_box(Vector3(0.9, 0.12, 0.3), Vector3(lx + 0.35, 4.2, -2.1), _toon(Color8(40, 40, 52)))
		_box(Vector3(0.5, 0.06, 0.24), Vector3(lx + 0.5, 4.13, -2.1), _toon(Color8(255, 236, 170), 3.0))
		var l := OmniLight3D.new()
		l.light_color = Color8(255, 220, 160)
		l.light_energy = 1.8
		l.omni_range = 6.5
		l.position = Vector3(lx + 0.5, 3.8, -1.6)
		add_child(l)
	# props: hydrants and bins on the curb
	for px in [3.0, 17.0, 31.0]:
		_box(Vector3(0.3, 0.6, 0.3), Vector3(px, 0.3, 1.8), _toon(Color8(170, 30, 40)))
		_box(Vector3(0.5, 0.9, 0.5), Vector3(px + 6, 0.45, 1.75), _toon(Color8(50, 70, 64)))
	# a far skyline: big dark blocks with a few lit windows
	var r2 := RandomNumberGenerator.new()
	r2.seed = 9
	for k in 30:
		var fw := r2.randf_range(4, 9)
		var fh := r2.randf_range(10, 30)
		var fb := _box(Vector3(fw, fh, 4), Vector3(-30 + k * 4.5, fh / 2 - 2, -40 - r2.randf() * 10), _toon(Color8(36, 30, 70)))
		for n in 6:
			_box(Vector3(0.6, 0.8, 0.1), Vector3(r2.randf_range(-fw / 2 + 0.5, fw / 2 - 0.5), r2.randf_range(-fh / 2 + 2, fh / 2 - 1), 2.05), _toon(Color8(250, 200, 120), 1.2), fb)
	# rain
	var rain := CPUParticles3D.new()
	rain.amount = 900
	rain.lifetime = 1.2
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(14, 0.5, 6)
	rain.direction = Vector3(-0.15, -1, 0)
	rain.spread = 2
	rain.initial_velocity_min = 14
	rain.initial_velocity_max = 16
	rain.gravity = Vector3.ZERO
	var rm := BoxMesh.new()
	rm.size = Vector3(0.012, 0.35, 0.012)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(0.7, 0.75, 1.0, 0.45)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.material = rmat
	rain.mesh = rm
	rain.position = Vector3(0, 9, 1)
	rain.name = "Rain"
	add_child(rain)


# ---- fighters ---------------------------------------------------------------------------
func _spawn_wave() -> void:
	for p in waves[wave]:
		var g := Fighter3D.new()
		add_child(g)
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


## An attack connects with anyone in reach in front of the attacker, on about the same depth.
func try_hit(att, a: Dictionary) -> void:
	for f in fighters:
		if f == att or f.dead or f.is_player == att.is_player or f.state in ["fly", "down", "getup"]:
			continue
		var dx: float = (f.position.x - att.position.x) * att.face
		if dx > 0.1 and dx < a["reach"] and absf(f.position.z - att.position.z) < 0.4:
			f.take_hit(a, att.face)
			att.hit_done = true
			hitstop = 6 if a.get("down", false) else 4
			shake = 0.12 if a.get("down", false) else 0.06
			_spark(f.position + Vector3(-att.face * 0.1, 1.35, 0.2))
			sfx("hit")


func land_fx(_f) -> void:
	shake = maxf(shake, 0.08)


func remove(f) -> void:
	fighters.erase(f)
	f.queue_free()


func sfx(_n: String) -> void:
	pass  # the demo is silent


func _spark(at: Vector3) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _star_tex()
	mat.emission_enabled = true
	mat.emission = Color(1, 0.9, 0.5)
	m.material_override = mat
	m.position = at
	add_child(m)
	sparks.append([m, 0])


var _star: ImageTexture


func _star_tex() -> ImageTexture:
	if _star:
		return _star
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5)
			var a := d.angle()
			var r := 18.0 + 13.0 * pow(absf(cos(a * 4.0)), 6.0)
			if d.length() < r:
				img.set_pixel(x, y, Color(1, 1, 0.85) if d.length() < r * 0.55 else Color(1, 0.8, 0.25))
	_star = ImageTexture.create_from_image(img)
	return _star


# ---- loop ----------------------------------------------------------------------------------
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
	for s in sparks.duplicate():
		s[1] += 1
		var m: MeshInstance3D = s[0]
		m.scale = Vector3.ONE * (0.6 + s[1] * 0.12)
		if s[1] > 8:
			m.queue_free()
			sparks.erase(s)
	var alive := 0
	for f in fighters:
		if not f.is_player:
			alive += 1
	if alive == 0 and wave < waves.size() - 1:
		wave += 1
		_spawn_wave()
	# camera: side view, a little above the lane, follows with look-ahead
	cam_x = lerpf(cam_x, player.position.x + player.face * 1.2, 0.08)
	shake = maxf(0.0, shake - 0.01)
	var sh := Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0)
	cam.position = Vector3(cam_x, 2.2, 7.4) + sh
	cam.look_at(Vector3(cam_x, 1.15, 0) + sh, Vector3.UP)
	(get_node("Rain") as Node3D).position.x = cam_x
	hud.queue_redraw()
	if demo and tick % 60 == 0:
		print("demo t=%d x=%.1f z=%.1f hp=%d wave=%d foes=%d" % [tick, player.position.x, player.position.z, player.hp, wave, alive])
	if demo and tick > 1500:
		get_tree().quit()


# ---- HUD ----------------------------------------------------------------------------------
func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.size = Vector2(1280, 720)
	hud.draw.connect(_draw_hud)
	layer.add_child(hud)
	font = ThemeDB.fallback_font


func _draw_hud() -> void:
	hud.draw_rect(Rect2(24, 22, 324, 26), Color(0.05, 0.03, 0.1, 0.8))
	hud.draw_rect(Rect2(28, 34, 316 * player.hp / player.max_hp, 10), Color8(80, 230, 110))
	hud.draw_string(font, Vector2(30, 31), "CODE BRO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color8(255, 220, 90))
	var y := 22
	for f in fighters:
		if f.is_player:
			continue
		hud.draw_rect(Rect2(1280 - 260, y, 236, 18), Color(0.05, 0.03, 0.1, 0.8))
		hud.draw_rect(Rect2(1280 - 256, y + 9, 228 * f.hp / f.max_hp, 6), Color8(255, 150, 40))
		hud.draw_string(font, Vector2(1280 - 254, y + 8), "NEXUS SECURITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
		y += 22
	hud.draw_string(font, Vector2(24, 702), "DEMO 1: 2.5D   ARROWS/WASD MOVE (UP/DOWN = DEPTH)   X/SPACE PUNCH (x3 COMBO)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.82, 0.95))


# ---- demo autopilot (for recordings) ---------------------------------------------------------
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
	var dz: float = near.position.z - player.position.z
	if absf(dz) > 0.2:
		_auto["down" if dz > 0 else "up"] = true
	if absf(dx) > 0.95:
		_auto["right" if dx > 0 else "left"] = true
	elif (dx > 0) != (player.face > 0):
		_auto["right" if dx > 0 else "left"] = true
	elif absf(dz) < 0.3:
		_auto["attack"] = tick % 10 < 5
