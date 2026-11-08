extends Node2D
## HOTFIX! Godot test slice: stage 1 with the new background art, Code Bro drawn with the
## imported sprite strips, and a glitched clone to spar with. Everything is built in code
## so main.tscn stays a single node.

const GROUND_Y := 300.0
const LEVEL_W := 2400.0
const Fighter := preload("res://scripts/fighter.gd")

var player: Fighter
var clone: Fighter
var cam: Camera2D
var fx: Node2D
var hitstop := 0
var shake := 0.0
var kos := 0
var tick := 0
var demo := false
var show_boxes := false

var hp_bar: ColorRect
var clone_bar: ColorRect
var ko_label: Label


func _ready() -> void:
	demo = "--demo" in OS.get_cmdline_user_args()
	_setup_input()
	_build_background()
	player = Fighter.new()
	player.setup(self, true, Vector2(220, GROUND_Y))
	add_child(player)
	clone = Fighter.new()
	clone.setup(self, false, Vector2(520, GROUND_Y))
	add_child(clone)
	fx = Node2D.new()
	fx.z_index = 20
	add_child(fx)
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = int(LEVEL_W)
	cam.limit_top = 0
	cam.limit_bottom = 360
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	player.add_child(cam)
	_build_hud()
	_build_audio()


# ---- input: keyboard and gamepad ------------------------------------------------------
func _setup_input() -> void:
	var keys := {
		"left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D], "up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S],
		"jump": [KEY_Z, KEY_SPACE, KEY_K], "attack": [KEY_X, KEY_J], "run": [KEY_SHIFT, KEY_V], "debug": [KEY_F2],
	}
	var pad := {"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "up": JOY_BUTTON_DPAD_UP,
		"down": JOY_BUTTON_DPAD_DOWN, "jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "run": JOY_BUTTON_RIGHT_SHOULDER}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.4)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		if pad.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = pad[action]
			InputMap.action_add_event(action, jb)
	for dir in [["left", -1.0], ["right", 1.0]]:
		var jm := InputEventJoypadMotion.new()
		jm.axis = JOY_AXIS_LEFT_X
		jm.axis_value = dir[1]
		InputMap.action_add_event(dir[0], jm)


## Input for the player. In --demo mode (used for automated screenshots) a script plays.
func held(action: String) -> bool:
	if demo:
		return _demo(action, false)
	return Input.is_action_pressed(action)


func pressed(action: String) -> bool:
	if demo:
		return _demo(action, true)
	return Input.is_action_just_pressed(action)


func _demo(action: String, edge: bool) -> bool:
	var t := tick
	match action:
		"right":
			return (t > 20 and t < 75) or (t > 330 and t < 360)
		"run":
			return t > 20 and t < 60
		"attack":
			return edge and t > 90 and t < 300 and t % 10 == 0
		"jump":
			return edge and (t == 365)
	return false


# ---- the stage ---------------------------------------------------------------------------
func _layer(path: String, scroll: float, y: float, z: int, tint := Color.WHITE) -> void:
	_layer_tex(load(path), scroll, y, z, tint)


func _layer_tex(tex: Texture2D, scroll: float, y: float, z: int, tint := Color.WHITE) -> void:
	var p := Parallax2D.new()
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = Vector2(0, y)
	s.modulate = tint
	p.add_child(s)
	p.scroll_scale = Vector2(scroll, 1.0)
	p.repeat_size = Vector2(tex.get_width(), 0)
	p.repeat_times = maxi(4, int(ceil(700.0 / tex.get_width())) + 2)
	p.z_index = z
	add_child(p)


func _build_background() -> void:
	# depth: the further back a layer is, the darker and cooler it is drawn
	_layer("res://assets/sprites/stage1_far.png", 0.35, 0.0, -20, Color(0.72, 0.72, 0.88))
	# the floor runs from just under the cubicles to below the screen; feet stand 100 px into it
	var floor_top := GROUND_Y - 100.0
	# the back wall: cubicles in front of big windows (transparent, the skyline shows through)
	var wall_tex: Texture2D = load("res://assets/sprites/stage1_wall.png")
	_layer("res://assets/sprites/stage1_wall.png", 0.75, floor_top + 4.0 - wall_tex.get_height(), -15, Color(0.86, 0.86, 0.96))
	_layer("res://assets/sprites/stage1_floor.png", 1.0, floor_top, -10)
	# a soft contact shadow where the wall meets the floor, so they read as one room
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0.05, 0.6))
	grad.set_color(1, Color(0, 0, 0.05, 0.0))
	var shadow := GradientTexture2D.new()
	shadow.gradient = grad
	shadow.width = 64
	shadow.height = 22
	shadow.fill_from = Vector2(0, 0)
	shadow.fill_to = Vector2(0, 1)
	_layer_tex(shadow, 1.0, floor_top, -9)


# ---- HUD -------------------------------------------------------------------------------
func _bar(x: float, y: float, w: float, col: Color, parent: Node) -> ColorRect:
	var back := ColorRect.new()
	back.color = Color(0.07, 0.05, 0.11)
	back.position = Vector2(x - 1, y - 1)
	back.size = Vector2(w + 2, 8)
	parent.add_child(back)
	var bar := ColorRect.new()
	bar.color = col
	bar.position = Vector2(x, y)
	bar.size = Vector2(w, 6)
	parent.add_child(bar)
	return bar


func _label(text: String, x: float, y: float, parent: Node, size := 10, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(x, y)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0.07, 0.05, 0.11))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	return l


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	_label("CODE BRO", 8, 4, hud, 10, Color(1, 0.88, 0.3))
	hp_bar = _bar(8, 20, 120, Color(0.29, 0.88, 0.35), hud)
	_label("GLITCH CLONE", 512, 4, hud, 10, Color(0.8, 0.6, 1))
	clone_bar = _bar(512, 20, 120, Color(1, 0.55, 0.12), hud)
	ko_label = _label("KOs 0", 300, 4, hud, 10)
	_label("TEST BUILD  -  ARROWS/WASD MOVE   SHIFT RUN   Z JUMP   X ATTACK (x4 COMBO)   F2 HITBOXES", 8, 344, hud, 8, Color(0.75, 0.78, 0.9))


# ---- audio (recorded from the web version's synth by tools/record_audio.js) ---------------
var music: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_streams := {}
const SFX := ["punch", "heavy", "whiff", "hurt", "jump", "land", "enemyDie", "glitch", "combo", "go"]


func _build_audio() -> void:
	music = AudioStreamPlayer.new()
	var song: AudioStreamOggVorbis = load("res://assets/audio/music_stage1.ogg")
	song.loop = true
	music.stream = song
	music.volume_db = -6.0
	add_child(music)
	music.play()
	for n in SFX:
		sfx_streams[n] = load("res://assets/audio/sfx_%s.wav" % n)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -2.0
		add_child(p)
		sfx_players.append(p)


## Play a sound effect on a free player (8 can overlap).
func sfx(name: String) -> void:
	if not sfx_streams.has(name):
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = sfx_streams[name]
			p.pitch_scale = randf_range(0.95, 1.05)
			p.play()
			return


# ---- game loop -------------------------------------------------------------------------
func _physics_process(_delta: float) -> void:
	tick += 1
	if Input.is_action_just_pressed("debug"):
		show_boxes = not show_boxes
	if hitstop > 0:
		hitstop -= 1
	# fighters cannot walk through each other
	if player.state != "ko" and clone.state != "ko":
		var dx: float = clone.position.x - player.position.x
		if absf(dx) < 34.0 and absf(clone.position.y - player.position.y) < 60.0:
			var push := (34.0 - absf(dx)) * 0.5 * (1.0 if dx >= 0.0 else -1.0)
			clone.position.x += push
			player.position.x -= push
	shake = maxf(0.0, shake - 0.5)
	cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	hp_bar.size.x = 120.0 * player.hp / player.max_hp
	clone_bar.size.x = 120.0 * clone.hp / clone.max_hp
	ko_label.text = "KOs %d" % kos
	if demo and tick % 10 == 0:
		print("demo t=%d bro=%s/%s clone=%s hp=%d" % [tick, player.state, player.anim, clone.state, clone.hp])
	if demo and tick == 420:
		get_tree().quit()


func hit_effect(pos: Vector2, heavy: bool) -> void:
	hitstop = 6 if heavy else 4
	shake = 3.0 if heavy else 1.5
	var s := Spark.new()
	s.position = pos
	fx.add_child(s)


## A hit spark: a white/yellow star that grows and fades in a few frames.
class Spark extends Node2D:
	var t := 0

	func _physics_process(_delta: float) -> void:
		t += 1
		queue_redraw()
		if t > 9:
			queue_free()

	func _draw() -> void:
		var r := 4.0 + t * 1.6
		var col := Color.WHITE if t < 4 else Color(1, 0.85, 0.3)
		for i in 8:
			var a := i * PI / 4.0
			var len := r if i % 2 == 0 else r * 0.55
			draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * len, col, 2.0 if i % 2 == 0 else 1.0)
