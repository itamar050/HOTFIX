extends Node2D
## HOTFIX! 16-bit brawler (upgrade in progress): a night street outside Nexus Dynamics,
## Code Bro drawn with the imported sprite strips, and arenas where waves of glitched clones
## attack (the camera locks until they are down). Built in code so main.tscn stays one node.
## Step 1 of the upgrade: camera (scripts/brawl_camera.gd) and the layered street stage
## (scripts/stage_street.gd, temporary placeholder art).

const GROUND_Y := 300.0
const LEVEL_W := 2400.0
const Fighter := preload("res://scripts/fighter.gd")
const BrawlCamera := preload("res://scripts/brawl_camera.gd")
const StageStreet := preload("res://scripts/stage_street.gd")

var player: Fighter
var enemies: Array = []
## Arenas: the camera locks one screen wide from x0 while each wave (enemy count) attacks.
const ARENAS := [{"x0": 560.0, "waves": [2, 3]}, {"x0": 1440.0, "waves": [3, 4]}]
var arena := -1  ## index of the locked arena, -1 = none
var arenas_done := 0
var wave := 0
var wave_gap := 0
var lock := Vector2(30.0, LEVEL_W - 30.0)  ## x range the player can move in
var go_t := 0
var cleared := false
var last_enemy = null
var last_enemy_t := 0
var cam: BrawlCamera
var stage: Node2D
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
var enemy_label: Label
var big_label: Label


func _ready() -> void:
	demo = "--demo" in OS.get_cmdline_user_args()
	_setup_input()
	player = Fighter.new()
	player.setup(self, true, Vector2(220, GROUND_Y))
	add_child(player)
	fx = Node2D.new()
	fx.z_index = 20
	add_child(fx)
	# the camera is its own node (not a child of the player), so knockback and hit
	# reactions don't jerk the whole view around
	cam = BrawlCamera.new()
	add_child(cam)
	cam.setup(player, 0.0, LEVEL_W)
	stage = StageStreet.new()
	add_child(stage)
	stage.build(LEVEL_W, cam)
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
	# a simple autopilot for automated test runs: fight what is near, otherwise walk right
	var near = null
	for e in enemies:
		if not e.dead and (near == null or absf(e.position.x - player.position.x) < absf(near.position.x - player.position.x)):
			near = e
	var close: bool = near != null and absf(near.position.x - player.position.x) < 75.0
	match action:
		"right":
			return (not close and (near == null or near.position.x > player.position.x)) or (close and near.position.x > player.position.x and player.face < 0)
		"left":
			return (not close and near != null and near.position.x < player.position.x) or (close and near.position.x < player.position.x and player.face > 0)
		"attack":
			return edge and close and tick % 9 == 0
	return false


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
	hud.layer = 5  # above the vignette (layer 1)
	add_child(hud)
	_label("CODE BRO", 8, 4, hud, 10, Color(1, 0.88, 0.3))
	hp_bar = _bar(8, 20, 120, Color(0.29, 0.88, 0.35), hud)
	enemy_label = _label("", 512, 4, hud, 10, Color(0.8, 0.6, 1))
	clone_bar = _bar(512, 20, 120, Color(1, 0.55, 0.12), hud)
	big_label = _label("", 0, 150, hud, 24, Color(1, 0.88, 0.3))
	big_label.size = Vector2(640, 40)
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	_update_arenas()
	# fighters cannot walk through each other
	var bodies: Array = [player]
	for e in enemies:
		if not e.dead:
			bodies.append(e)
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var p1 = bodies[i]
			var p2 = bodies[j]
			var dx: float = p2.position.x - p1.position.x
			if absf(dx) < 34.0 and absf(p2.position.y - p1.position.y) < 60.0:
				var push := (34.0 - absf(dx)) * 0.5 * (1.0 if dx >= 0.0 else -1.0)
				p2.position.x += push
				p1.position.x -= push
	for e in enemies.duplicate():
		if e.gone:
			enemies.erase(e)
			e.queue_free()
	# hits set `shake` (1.5 light .. 3 heavy); the camera turns it into decaying trauma
	if shake > 0.0:
		cam.add_trauma(shake * 0.08)
		shake = 0.0
	hp_bar.size.x = 120.0 * player.hp / player.max_hp
	if last_enemy_t > 0:
		last_enemy_t -= 1
	var show_enemy: bool = last_enemy_t > 0 and is_instance_valid(last_enemy)
	enemy_label.text = "GLITCH CLONE" if show_enemy else ""
	clone_bar.visible = show_enemy
	if show_enemy:
		clone_bar.size.x = 120.0 * last_enemy.hp / last_enemy.max_hp
	ko_label.text = "KOs %d" % kos
	if go_t > 0:
		go_t -= 1
	if cleared:
		big_label.text = "STAGE CLEAR!"
	elif go_t > 0:
		big_label.text = "GO! >>" if (go_t / 12) % 2 == 0 else ""
	else:
		big_label.text = ""
	if demo and tick % 30 == 0:
		print("demo t=%d x=%d hp=%d arena=%d wave=%d enemies=%d kos=%d cleared=%s" % [tick, player.position.x, player.hp, arena, wave, enemies.size(), kos, cleared])
	if demo and (tick == 7000 or (cleared and tick % 30 == 0)):
		get_tree().quit()


## Only one enemy attacks at a time (the others wait their turn), Streets of Rage style.
func can_attack(who) -> bool:
	for e in enemies:
		if e != who and not e.dead and e.state in ["windup", "attack"]:
			return false
	return true


func _update_arenas() -> void:
	if arena < 0:
		if arenas_done < ARENAS.size() and player.position.x > ARENAS[arenas_done]["x0"] + 300.0:
			arena = arenas_done
			var x0: float = ARENAS[arena]["x0"]
			lock = Vector2(x0 + 20.0, x0 + 620.0)
			cam.set_bounds(x0, x0 + 640.0)
			wave = 0
			_spawn_wave()
		elif not cleared and arenas_done == ARENAS.size() and player.position.x > LEVEL_W - 200.0:
			cleared = true
			music.stream = load("res://assets/audio/music_clear.ogg")
			music.play()
		return
	for e in enemies:
		if not e.dead:
			return
	wave_gap += 1
	if wave_gap < 45:
		return
	wave_gap = 0
	wave += 1
	if wave < ARENAS[arena]["waves"].size():
		_spawn_wave()
		return
	# arena cleared: unlock the camera and send the player on
	arena = -1
	arenas_done += 1
	lock = Vector2(30.0, LEVEL_W - 30.0)
	cam.set_bounds(0.0, LEVEL_W)
	go_t = 150
	sfx("go")


func _spawn_wave() -> void:
	var x0: float = ARENAS[arena]["x0"]
	var n: int = ARENAS[arena]["waves"][wave]
	for i in n:
		var right := i % 2 == 0
		var x := x0 + 640.0 + 30.0 + i * 20.0 if right else x0 - 30.0 - i * 20.0
		var e := Fighter.new()
		e.setup(self, false, Vector2(x, GROUND_Y))
		e.respawns = false
		e.atk_cd = 40 + i * 25
		add_child(e)
		enemies.append(e)
	sfx("glitch")


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
