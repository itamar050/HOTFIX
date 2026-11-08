extends Node3D
## A 3D brawler fighter built from simple meshes on a joint hierarchy (no imported model).
## Toon shading + inverted-hull outlines. Animations are procedural poses (joint angles per
## frame), so walk cycles always alternate. Facing +x; z is depth (toward the camera = +z).

var main
var kind := "bro"  ## "bro" (player) or "goon"
var is_player := true
var vel := Vector3.ZERO
var face := 1
var state := "idle"  ## idle, walk, attack, hurt, fly, down, getup
var t := 0
var hp := 100
var max_hp := 100
var attack := ""
var combo := 0
var hit_done := false
var buffered := false
var atk_cd := 90
var flash := 0
var walk_ph := 0.0
var dead := false
var height := 0.0  ## airborne height while knocked down
var vy := 0.0

# joints
var root: Node3D
var hips: Node3D
var spine: Node3D
var head: Node3D
var sh := {}  ## shoulders "l"/"r"
var el := {}
var hp_j := {}  ## hips "l"/"r"
var kn := {}
var mats: Array = []


func setup(m, k: String, pos: Vector3) -> void:
	main = m
	kind = k
	is_player = k == "bro"
	position = pos
	face = 1 if is_player else -1
	max_hp = 100 if is_player else 60
	hp = max_hp
	_build()


# ---- materials -------------------------------------------------------------------------
func _mat(col: Color, tex: Texture2D = null, uv := Vector3.ONE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if tex:
		m.albedo_texture = tex
		m.uv1_scale = uv
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.75
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	var o := StandardMaterial3D.new()
	o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.albedo_color = Color(0.06, 0.04, 0.09)
	o.cull_mode = BaseMaterial3D.CULL_FRONT
	o.grow = true
	o.grow_amount = 0.018
	m.next_pass = o
	mats.append(m)
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _sphere(r: float, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2 if h < 0 else h
	s.radial_segments = 16
	s.rings = 8
	return s


static func plaid_tex() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		for x in 16:
			var c := Color8(160, 44, 30)
			if x % 8 < 2 or y % 8 < 2:
				c = Color8(96, 22, 16)
			if (x % 8 < 2) and (y % 8 < 2):
				c = Color8(60, 14, 10)
			if x % 8 == 5 or y % 8 == 5:
				c = Color8(220, 150, 60)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# ---- the body ---------------------------------------------------------------------------
func _build() -> void:
	var skin := _mat(Color8(240, 186, 150))
	var jeans: StandardMaterial3D
	var shirt: StandardMaterial3D
	var sleeve: StandardMaterial3D
	var shoe: StandardMaterial3D
	var hair: StandardMaterial3D
	var bulk := 1.0
	if kind == "bro":
		jeans = _mat(Color8(64, 96, 168))
		var pt := plaid_tex()
		shirt = _mat(Color.WHITE, pt, Vector3(2, 2, 1))
		sleeve = _mat(Color.WHITE, pt, Vector3(1, 2, 1))
		shoe = _mat(Color8(196, 40, 44))
		hair = _mat(Color8(104, 62, 30))
	else:
		jeans = _mat(Color8(34, 34, 44))
		shirt = _mat(Color8(34, 34, 44))
		sleeve = shirt
		shoe = _mat(Color8(20, 20, 24))
		hair = _mat(Color8(40, 30, 26))
		skin = _mat(Color8(196, 140, 108))
		bulk = 1.18
	root = _joint(self, Vector3.ZERO)
	hips = _joint(root, Vector3(0, 0.92, 0))
	_part(hips, _box(Vector3(0.34, 0.2, 0.3) * Vector3(bulk, 1, bulk)), jeans, Vector3(0, -0.02, 0))
	spine = _joint(hips, Vector3(0, 0.08, 0))
	# torso
	_part(spine, _capsule(0.2 * bulk, 0.62), shirt, Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1.05, 1, 0.78))
	if kind == "bro":
		_part(spine, _box(Vector3(0.12, 0.42, 0.04)), _mat(Color8(60, 60, 70)), Vector3(0.12, 0.27, 0.0), Vector3(0, 90, 0))  # tee
		_part(spine, _box(Vector3(0.05, 0.62, 0.36)), _mat(Color8(40, 36, 40)), Vector3(0.0, 0.3, 0), Vector3(0, 0, -38))  # strap
		_part(spine, _box(Vector3(0.28, 0.24, 0.1)), _mat(Color8(52, 48, 50)), Vector3(-0.17, 0.0, 0.2))  # bag
	else:
		_part(spine, _box(Vector3(0.1, 0.36, 0.04)), _mat(Color8(236, 236, 240)), Vector3(0.14, 0.33, 0.0), Vector3(0, 90, 0))
		_part(spine, _box(Vector3(0.05, 0.28, 0.03)), _mat(Color8(200, 30, 40)), Vector3(0.165, 0.3, 0.0), Vector3(0, 90, 0))
	# head
	var neck := _joint(spine, Vector3(0, 0.58, 0))
	head = _joint(neck, Vector3(0, 0.1, 0))
	_part(neck, _capsule(0.07, 0.16), skin, Vector3(0, 0.02, 0))
	_part(head, _sphere(0.2, 0.42), skin, Vector3(0.02, 0.14, 0))
	_part(head, _box(Vector3(0.05, 0.06, 0.05)), skin, Vector3(0.21, 0.12, 0))  # nose
	if kind == "bro":
		_part(head, _sphere(0.21, 0.3), hair, Vector3(-0.02, 0.26, 0))
		for i in 7:
			var a := float(i) / 6.0
			_part(head, _box(Vector3(0.1, 0.14, 0.1)), hair, Vector3(-0.16 + a * 0.32, 0.36 - absf(a - 0.5) * 0.08, sin(i * 2.1) * 0.1), Vector3(sin(i) * 25, 20, -40 + a * 80))
		_part(head, _box(Vector3(0.12, 0.2, 0.36)), hair, Vector3(-0.15, 0.16, 0))  # back of head
		# glasses: frames + lenses on the side the camera sees and the far side
		var frame := _mat(Color8(20, 18, 22))
		var lens := _mat(Color8(170, 220, 250))
		for z in [0.09, -0.09]:
			_part(head, _box(Vector3(0.04, 0.09, 0.12)), frame, Vector3(0.2, 0.16, z))
			_part(head, _box(Vector3(0.02, 0.06, 0.09)), lens, Vector3(0.222, 0.16, z))
		_part(head, _box(Vector3(0.3, 0.025, 0.025)), frame, Vector3(0.06, 0.18, 0.2))
		_part(head, _box(Vector3(0.3, 0.025, 0.025)), frame, Vector3(0.06, 0.18, -0.2))
	else:
		_part(head, _sphere(0.205, 0.2), hair, Vector3(-0.01, 0.24, 0))  # buzz cut
		var shades := _mat(Color8(16, 16, 20))
		_part(head, _box(Vector3(0.05, 0.08, 0.34)), shades, Vector3(0.2, 0.16, 0))
	_part(head, _box(Vector3(0.02, 0.025, 0.1)), _mat(Color8(120, 50, 50)), Vector3(0.215, 0.03, 0))  # mouth
	# arms and legs: index 0 = far side (-z), 1 = near side (+z)
	for s in ["l", "r"]:
		var z := -0.27 * bulk if s == "l" else 0.27 * bulk
		sh[s] = _joint(spine, Vector3(0, 0.5, z))
		_part(sh[s], _capsule(0.085 * bulk, 0.36), sleeve, Vector3(0, -0.14, 0))
		el[s] = _joint(sh[s], Vector3(0, -0.3, 0))
		_part(el[s], _capsule(0.07 * bulk, 0.32), skin if kind == "bro" else sleeve, Vector3(0, -0.14, 0))
		_part(el[s], _sphere(0.085 * bulk), skin, Vector3(0.0, -0.33, 0))  # fist
		var hz := -0.11 * bulk if s == "l" else 0.11 * bulk
		hp_j[s] = _joint(hips, Vector3(0, -0.08, hz))
		_part(hp_j[s], _capsule(0.1 * bulk, 0.46), jeans, Vector3(0, -0.2, 0))
		kn[s] = _joint(hp_j[s], Vector3(0, -0.42, 0))
		_part(kn[s], _capsule(0.085 * bulk, 0.44), jeans, Vector3(0, -0.2, 0))
		_part(kn[s], _box(Vector3(0.3, 0.1, 0.14)), shoe, Vector3(0.06, -0.44, 0))
		_part(kn[s], _box(Vector3(0.31, 0.035, 0.15)), _mat(Color8(236, 236, 230)), Vector3(0.06, -0.49, 0))
	# blob shadow
	var shadow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.5)
	shadow.mesh = q
	shadow.rotation_degrees = Vector3(-90, 0, 0)
	shadow.position = Vector3(0, 0.01, 0)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0.55))
	gr.set_color(1, Color(0, 0, 0, 0))
	g.gradient = gr
	sm.albedo_texture = g
	shadow.material_override = sm
	add_child(shadow)
	shadow.set_meta("shadow", true)
	set_meta("shadow_node", shadow)


# ---- poses: angles in degrees; legs/arms + = swing forward ---------------------------
func _pose(p: Dictionary, k := 0.35) -> void:
	var cur := {
		"hl": hp_j["l"].rotation_degrees.z, "hr": hp_j["r"].rotation_degrees.z,
		"kl": kn["l"].rotation_degrees.z, "kr": kn["r"].rotation_degrees.z,
		"sl": sh["l"].rotation_degrees.z, "sr": sh["r"].rotation_degrees.z,
		"el": el["l"].rotation_degrees.z, "er": el["r"].rotation_degrees.z,
		"sp": spine.rotation_degrees.z, "hd": head.rotation_degrees.z,
	}
	for key in cur:
		var v: float = lerpf(cur[key], p.get(key, 0.0), k)
		match key:
			"hl": hp_j["l"].rotation_degrees.z = v
			"hr": hp_j["r"].rotation_degrees.z = v
			"kl": kn["l"].rotation_degrees.z = v
			"kr": kn["r"].rotation_degrees.z = v
			"sl": sh["l"].rotation_degrees.z = v
			"sr": sh["r"].rotation_degrees.z = v
			"el": el["l"].rotation_degrees.z = v
			"er": el["r"].rotation_degrees.z = v
			"sp": spine.rotation_degrees.z = v
			"hd": head.rotation_degrees.z = v
	hips.position.y = lerpf(hips.position.y, p.get("y", 0.92), k)


const GUARD := {"sl": 50, "el": 110, "sr": 30, "er": 120}


func _anim() -> void:
	var p := {}
	match state:
		"idle":
			var b := sin(t * 0.08)
			p = {"hl": 14, "hr": -10, "kl": -16, "kr": -10, "sp": -6 + b, "y": 0.88 + b * 0.008}
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
	# lying down: the whole body tips over backwards
	var lie := 0.0
	if state == "fly":
		lie = clampf(t * 8.0, 0, 80)
	elif state == "down":
		lie = 85
	elif state == "getup":
		lie = maxf(0.0, 85 - t * 6.0)
	root.rotation_degrees.z = lerpf(root.rotation_degrees.z, lie, 0.4)
	root.position.y = height + (0.18 if lie > 60 else 0.0)


const ATTACKS := {
	"jab": {"len": 16, "hit": 5, "reach": 1.05, "dmg": 8, "kb": 0.06, "next": "cross"},
	"cross": {"len": 18, "hit": 6, "reach": 1.1, "dmg": 10, "kb": 0.08, "next": "kick"},
	"kick": {"len": 26, "hit": 9, "reach": 1.3, "dmg": 16, "kb": 0.16, "down": true},
	"goon": {"len": 30, "hit": 18, "reach": 1.05, "dmg": 9, "kb": 0.1},
}


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


# ---- per frame -------------------------------------------------------------------------
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
			vel.x = move_toward(vel.x, 0, 0.01)
			vel.z = 0
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
			vel.x = move_toward(vel.x, 0, 0.006)
			if t > 18:
				_go("idle")
		"fly":
			vy -= 0.012
			height += vy
			if height <= 0:
				height = 0
				_go("down")
				main.land_fx(self)
		"down":
			vel.x = move_toward(vel.x, 0, 0.01)
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
	position.z = clampf(position.z, main.lane_z.x, main.lane_z.y)
	root.rotation_degrees.y = 0.0 if face > 0 else 180.0
	_anim()
	var shadow: MeshInstance3D = get_meta("shadow_node")
	shadow.scale = Vector3.ONE * (1.0 - clampf(height, 0, 1) * 0.5)
	shadow.global_position = Vector3(global_position.x, 0.01, global_position.z)
	_flash(flash > 0)


var _flashing := false
var _base_cols := {}


func _flash(on: bool) -> void:
	if on == _flashing:
		return
	_flashing = on
	for m in mats:
		var sm := m as StandardMaterial3D
		if on:
			_base_cols[sm] = sm.albedo_color
			sm.albedo_color = Color(1, 1, 1)
			sm.emission_enabled = true
			sm.emission = Color(1, 1, 1)
		else:
			sm.albedo_color = _base_cols.get(sm, sm.albedo_color)
			sm.emission_enabled = false


func _go(s: String) -> void:
	state = s
	t = 0


func _start(a: String) -> void:
	attack = a
	hit_done = false
	buffered = false
	_go("attack")
	vel.x = face * (0.03 if a != "kick" else 0.05)
	main.sfx("whiff")


func _control() -> void:
	var ix: float = float(main.held("right")) - float(main.held("left"))
	var iz: float = float(main.held("down")) - float(main.held("up"))
	vel.x = move_toward(vel.x, ix * 0.075, 0.012)
	vel.z = move_toward(vel.z, iz * 0.05, 0.01)
	if ix != 0:
		face = int(signf(ix))
	_set_move()
	if main.pressed("attack"):
		_start("jab")


func _set_move() -> void:
	var moving := absf(vel.x) > 0.01 or absf(vel.z) > 0.01
	if moving and state == "idle":
		state = "walk"
	elif not moving and state == "walk":
		state = "idle"


func _ai() -> void:
	var p = main.player
	var dx: float = p.position.x - position.x
	var dz: float = p.position.z - position.z
	face = 1 if dx > 0 else -1
	var want_x: float = p.position.x - face * 1.0
	# approach on the player's depth line, but come in from my own lane first
	var tz: float = p.position.z if absf(dx) < 2.5 else position.z
	vel.x = move_toward(vel.x, clampf((want_x - position.x) * 0.08, -0.05, 0.05), 0.006)
	vel.z = move_toward(vel.z, clampf((tz - position.z) * 0.06, -0.035, 0.035), 0.004)
	_set_move()
	if absf(dx) < 1.25 and absf(dz) < 0.3 and atk_cd <= 0 and main.can_attack(self) and p.state in ["idle", "walk", "attack"]:
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
		vel = Vector3(dir * a["kb"] * 0.6, 0, 0)
		vy = 0.16
		height = 0.01
	else:
		_go("hurt")
		vel = Vector3(dir * a["kb"], 0, 0)
