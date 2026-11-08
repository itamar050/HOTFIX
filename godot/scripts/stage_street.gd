extends Node2D
## Stage presentation (upgrade step 1): a layered night street. Back to front:
## sky (fixed) > far skyline (0.15) > mid-rise buildings (0.45) > storefronts and the
## sidewalk lane (world-locked) > neon glow and lamp light > fighters > foreground props
## (1.3, in front of the fighters) > rain > vignette.
## ALL ART HERE IS TEMPORARY: assets/placeholder/placeholder_*.png are drawn by
## tools/make_street_placeholders.py. Replace a file with final art of the same size and
## name (docs/ART_SPEC.md); glow/lamp positions are in assets/placeholder/street_layout.gd.

const Layout = preload("res://assets/placeholder/street_layout.gd")
const DIR := "res://assets/placeholder/"

var cam: Camera2D
var glow_tex: Texture2D
var neon: Array = []  ## [Sprite2D, base Color, flicker phase]
var rain: Node2D
var t := 0


func build(level_w: float, camera: Camera2D) -> void:
	cam = camera
	glow_tex = load(DIR + "placeholder_glow.png")
	_parallax("placeholder_street_sky.png", 0.0, 0.0, -50)
	_parallax("placeholder_street_far.png", 0.15, 0.0, -45)
	_parallax("placeholder_street_mid.png", 0.45, 2.0, -40)
	# storefronts and the sidewalk are drawn once along the whole level (scroll 1)
	_world("placeholder_street_front.png", 0.0, -30)
	_world("placeholder_street_ground.png", Layout.LANE_TOP, -31)
	# neon signs and lamp heads glow (additive, integer scale so the dither stays crisp)
	for g in Layout.GLOWS:
		var col := Color8(g[2], g[3], g[4])
		var sc := maxi(1, roundi(g[5] / 64.0))
		var s := _glow(Vector2(g[0], g[1]), Vector2(sc, sc), Color(col, 0.55), -29)
		neon.append([s, Color(col, 0.55), randf() * 100.0])
	# warm light pools on the sidewalk under each street lamp
	for x in Layout.LAMPS:
		_glow(Vector2(x, Layout.LANE_TOP + 18), Vector2(3, 1), Color(1.0, 0.85, 0.55, 0.32), -29)
	# foreground street furniture passes in front of the fighters, faster than the world
	var fore := _parallax("placeholder_street_fore.png", 1.3, 300.0, 10)
	fore.modulate = Color(0.7, 0.66, 0.8)
	rain = Node2D.new()
	rain.z_index = 15
	rain.draw.connect(_draw_rain)
	add_child(rain)
	var vl := CanvasLayer.new()
	vl.layer = 1
	add_child(vl)
	var vg := TextureRect.new()
	vg.texture = load(DIR + "placeholder_vignette.png")
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vl.add_child(vg)


func _parallax(file: String, scroll: float, y: float, z: int) -> Parallax2D:
	var tex: Texture2D = load(DIR + file)
	var p := Parallax2D.new()
	p.scroll_scale = Vector2(scroll, 1.0)
	p.repeat_size = Vector2(tex.get_width(), 0)
	p.repeat_times = 3
	p.z_index = z
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = Vector2(0, y)
	p.add_child(s)
	add_child(p)
	return p


func _world(file: String, y: float, z: int) -> void:
	var s := Sprite2D.new()
	s.texture = load(DIR + file)
	s.centered = false
	s.position = Vector2(0, y)
	s.z_index = z
	add_child(s)


func _glow(pos: Vector2, sc: Vector2, col: Color, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = glow_tex
	s.position = pos
	s.scale = sc
	s.modulate = col
	s.z_index = z
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	add_child(s)
	return s


func _physics_process(_delta: float) -> void:
	t += 1
	# neon hums; now and then a sign stutters off for a few frames
	for n in neon:
		var s: Sprite2D = n[0]
		var base: Color = n[1]
		var ph: float = n[2]
		var off := fmod(t * 0.37 + ph * 13.0, 400.0) < 6.0
		s.modulate = Color(base, 0.08 if off else base.a * (0.9 + 0.1 * sin(t * 0.05 + ph)))
	if cam:
		rain.position = cam.get_screen_center_position() - Vector2(320, 180)
	rain.queue_redraw()


func _draw_rain() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var drop := Color(0.62, 0.66, 0.92, 0.55)
	for i in 110:
		var x := float((r.randi_range(0, 680) - t * 2) % 680)
		if x < 0:
			x += 680
		var y := float((r.randi_range(0, 360) + t * 9) % 380) - 20
		rain.draw_line(Vector2(x - 40, y), Vector2(x - 42, y + 7), drop)
	# splashes on the sidewalk
	for i in 8:
		var k := (t / 6 + i * 7) % 40
		if k < 3:
			var sx := float(r.randi_range(0, 640))
			var sy := float(r.randi_range(Layout.LANE_TOP + 6, 336))
			rain.draw_rect(Rect2(sx - 2, sy, 1, 1), drop)
			rain.draw_rect(Rect2(sx + 2, sy, 1, 1), drop)
			rain.draw_rect(Rect2(sx, sy - 1, 1, 1), drop)
