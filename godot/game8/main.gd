## HOTFIX! 8-bit stage 1: Nexus HQ dev floor at night. Platforming, an arena, the Team
## Leader boss, cash pickups and the vending machine upgrade shop. Built in code.
extends Node2D

const F8 = preload("res://game8/font8.gd")
const Player8 = preload("res://game8/player.gd")
const Enemy8 = preload("res://game8/enemy.gd")

const LEVEL_W := 2840.0
const FLOOR_Y := 208.0
const PITS := [Vector2(1680, 1728)]
## props: [type, x, top]; desks/shelves are one-way platforms, cabinets are solid
const PROPS := [
	["rack90", 4, 118], ["rack68", 32, 140], ["desk", 112, 180], ["monitor", 124, 160], ["plant", 200, 178],
	["cab48", 232, 160], ["cab24", 262, 184], ["shelf", 300, 132], ["books", 312, 120], ["cooler", 374, 170],
	["desk", 450, 180], ["monitor", 500, 160], ["shelf", 520, 140], ["desk", 600, 180], ["cab48", 700, 160],
	["cab24", 730, 184], ["plant", 790, 178],
	["desk", 940, 180], ["monitor", 990, 160], ["cab48", 1060, 160], ["desk", 1140, 180], ["monitor", 1150, 160],
	["rack90", 1240, 118],
	["cab24", 1320, 184], ["cab48", 1350, 160], ["shelf", 1400, 126], ["books", 1440, 114], ["shelf", 1520, 104],
	["desk", 1580, 180], ["monitor", 1630, 160],
	["desk", 1760, 180], ["shelf", 1880, 150], ["cab48", 2000, 160], ["cab24", 2030, 184], ["desk", 2120, 180],
	["monitor", 2130, 160], ["plant", 2210, 178], ["rack90", 2290, 118], ["rack68", 2318, 140], ["door", 2380, 136],
	["vending", 2790, 144],
]
const ENEMIES := [
	["bug", 180, 208], ["jira", 320, 150], ["bug", 470, 208], ["bug", 640, 180], ["pm", 715, 160], ["jira", 820, 110],
	["bug", 1440, 126], ["jira", 1500, 84], ["jira", 1630, 140], ["bug", 1600, 208],
	["bug", 1800, 180], ["pm", 1922, 150], ["jira", 2060, 110], ["bug", 2160, 208], ["bug", 2250, 208],
]
const COINS := [[320, 128], [330, 128], [340, 128], [1540, 100], [1550, 100], [1560, 100], [1570, 100], [560, 136], [570, 136]]
const ARENA := {"x0": 880.0, "waves": [
	[["bug", 1270, 208], ["bug", 890, 208], ["jira", 1270, 110]],
	[["pm", 1075, 150], ["jira", 890, 100], ["bug", 1270, 208], ["bug", 900, 208]],
]}
const BOSS_X0 := 2440.0
const SHOP := [
	["coffee", "COFFEE", "+2 MAX HEALTH", 60, 3],
	["keyboard", "MECH KEYBOARD", "+1 PUNCH POWER", 80, 2],
	["sneakers", "NEW SNEAKERS", "DOUBLE JUMP", 100, 1],
	["magnet", "CASH MAGNET", "PULLS IN COINS", 50, 1],
]

var tick := 0
var mode := "title"  ## title, play, clear, shop, over
var mode_t := 0
var demo := false
var player
var enemies: Array = []
var solids: Array = []
var platforms: Array = []
var coins: Array = []
var notes: Array = []
var waves_fx: Array = []
var texts: Array = []
var pops: Array = []
var heals: Array = []
var lock := Vector2(0, LEVEL_W)
var arena_state := 0  ## 0 before, 1 fighting, 2 done
var wave := 0
var wave_gap := 0
var boss = null
var boss_state := 0  ## 0 before, 1 fight, 2 beaten
var go_t := 0
var cash := 0
var shown_cash := 0
var upgrades := {"coffee": 0, "keyboard": 0, "sneakers": 0, "magnet": 0}
var shop_sel := 0
var shake := 0.0
var hitstop := 0
var cam: Camera2D
var cam_x := 200.0
var world: Node2D
var fx: Node2D
var hud: Control
var rain: Node2D
var coin_tex: Texture2D
var note_tex: Texture2D
var vending_tex: Texture2D
var music: AudioStreamPlayer
var sfx_pool: Array = []
var sfx_i := 0
var _held := {}
var _prev := {}
var _auto := {}


func _ready() -> void:
	demo = "--demo" in OS.get_cmdline_user_args()
	randomize()
	_setup_input()
	coin_tex = load("res://game8/art/coin.png")
	note_tex = load("res://game8/art/note.png")
	vending_tex = load("res://game8/art/prop_vending.png")
	_build_background()
	world = Node2D.new()
	add_child(world)
	fx = Node2D.new()
	fx.z_index = 5
	fx.draw.connect(_draw_fx)
	add_child(fx)
	cam = Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	add_child(cam)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.size = Vector2(400, 240)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	layer.add_child(hud)
	music = AudioStreamPlayer.new()
	music.volume_db = -6
	add_child(music)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)
	_build_stage()
	_music("title")
	if demo:
		mode = "play"
		_music("stage1")


# ---- input -----------------------------------------------------------------------------

func _setup_input() -> void:
	var keys := {
		"left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D], "up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S],
		"jump": [KEY_Z, KEY_SPACE, KEY_K], "punch": [KEY_X, KEY_J], "start": [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE],
	}
	var pads := {"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT], "up": [JOY_BUTTON_DPAD_UP],
		"down": [JOY_BUTTON_DPAD_DOWN], "jump": [JOY_BUTTON_A], "punch": [JOY_BUTTON_X, JOY_BUTTON_B], "start": [JOY_BUTTON_START]}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.4)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
		for b in pads[a]:
			var j := InputEventJoypadButton.new()
			j.button_index = b
			InputMap.action_add_event(a, j)
	for pair in [["left", -1.0], ["right", 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = JOY_AXIS_LEFT_X
		m.axis_value = pair[1]
		InputMap.action_add_event(pair[0], m)


func _read_input() -> void:
	_prev = _held.duplicate()
	for a in ["left", "right", "up", "down", "jump", "punch", "start"]:
		_held[a] = _auto.get(a, false) if demo else Input.is_action_pressed(a)


func btn(a: String) -> bool:
	return _held.get(a, false)


func pressed(a: String) -> bool:
	return _held.get(a, false) and not _prev.get(a, false)


# ---- building ----------------------------------------------------------------------------

func _build_background() -> void:
	var far := Parallax2D.new()
	far.scroll_scale = Vector2(0.25, 0)
	far.repeat_size = Vector2(400, 0)
	far.repeat_times = 3
	far.z_index = -20
	add_child(far)
	var s := Sprite2D.new()
	s.texture = load("res://game8/art/bg_far.png")
	s.centered = false
	far.add_child(s)
	rain = Node2D.new()
	rain.draw.connect(_draw_rain)
	far.add_child(rain)
	var wall := Parallax2D.new()
	wall.scroll_scale = Vector2(1, 0)
	wall.repeat_size = Vector2(124, 0)
	wall.repeat_times = 6
	wall.z_index = -10
	add_child(wall)
	var ws := Sprite2D.new()
	ws.texture = load("res://game8/art/bg_wall.png")
	ws.centered = false
	wall.add_child(ws)
	var floor_node := Node2D.new()
	floor_node.z_index = -5
	floor_node.draw.connect(_draw_floor.bind(floor_node))
	add_child(floor_node)
	for p in PROPS:
		var sp := Sprite2D.new()
		sp.texture = load("res://game8/art/prop_%s.png" % p[0])
		sp.centered = false
		sp.position = Vector2(p[1], p[2])
		sp.z_index = -4
		add_child(sp)
		var r := Rect2(p[1], p[2], sp.texture.get_width(), FLOOR_Y - p[2])
		match p[0]:
			"cab48", "cab24":
				solids.append(r)
			"desk":
				platforms.append(Rect2(p[1], p[2], 72, 6))
			"shelf":
				platforms.append(Rect2(p[1], p[2], 84, 8))
	for i in range(0, int(LEVEL_W), 248):
		var lamp := Sprite2D.new()
		lamp.texture = load("res://game8/art/prop_lamp.png")
		lamp.centered = false
		lamp.position = Vector2(i + 90, 28)
		lamp.z_index = -9
		add_child(lamp)


var floor_t1: Texture2D = preload("res://game8/art/tile_floor.png")
var floor_t2: Texture2D = preload("res://game8/art/tile_floor2.png")


func _draw_floor(n: Node2D) -> void:
	var t1 := floor_t1
	var t2 := floor_t2
	for x in range(0, int(LEVEL_W), 16):
		if _in_pit(x + 8):
			continue
		n.draw_texture(t1, Vector2(x, FLOOR_Y))
		n.draw_texture(t2, Vector2(x, FLOOR_Y + 16))
	n.draw_rect(Rect2(0, FLOOR_Y - 1, LEVEL_W, 1), Color8(14, 10, 24))
	for p in PITS:
		n.draw_rect(Rect2(p.x, FLOOR_Y - 1, p.y - p.x, 40), Color8(6, 4, 12))
		n.draw_rect(Rect2(p.x + 10, FLOOR_Y, 2, 40), Color8(60, 60, 70))
		n.draw_rect(Rect2(p.y - 12, FLOOR_Y, 2, 40), Color8(60, 60, 70))
		F8.text(n, Vector2(p.x + 4, FLOOR_Y + 14), "SHAFT", Color8(230, 200, 60))


func _build_stage() -> void:
	for e in enemies:
		e.queue_free()
	enemies = []
	coins = []
	notes = []
	waves_fx = []
	dusts = []
	call_t = 0
	texts = []
	pops = []
	heals = [Vector2(2150, 180), Vector2(1560, 104)]
	lock = Vector2(0, LEVEL_W)
	arena_state = 0
	wave = 0
	boss = null
	boss_state = 0
	if player:
		player.queue_free()
	player = Player8.new()
	player.setup(self, Vector2(40, FLOOR_Y))
	player.god = demo
	if demo and "--boss" in OS.get_cmdline_user_args():
		player.position = Vector2(BOSS_X0 + 30, FLOOR_Y)
		arena_state = 2
		cam_x = BOSS_X0 + 200
		for e in enemies:
			e.queue_free()
		enemies = []
	player.max_hp = 8 + 2 * upgrades["coffee"]
	player.hp = player.max_hp
	world.add_child(player)
	for e in ENEMIES:
		_spawn(e[0], Vector2(e[1], e[2]))
	for c in COINS:
		coins.append({"p": Vector2(c[0], c[1]), "v": Vector2.ZERO, "t": randi() % 40, "rest": true, "life": -1})
	cam_x = 200
	mode_t = 0


func _spawn(k: String, p: Vector2):
	var e := Enemy8.new()
	e.setup(self, k, p)
	world.add_child(e)
	enemies.append(e)
	return e


# ---- physics helpers ---------------------------------------------------------------------------

func _in_pit(x: float) -> bool:
	for p in PITS:
		if x > p.x and x < p.y:
			return true
	return false


func is_safe(x: float) -> bool:
	for p in PITS:
		if x > p.x - 24 and x < p.y + 24:
			return false
	return true


## The highest surface crossed between y0 and y1 (moving down) under x range [a, b], or INF.
func ground(a: float, b: float, y0: float, y1: float) -> float:
	var best := INF
	if y0 <= FLOOR_Y and y1 >= FLOOR_Y and not (_in_pit(a) and _in_pit(b)):
		best = FLOOR_Y
	for r in solids + platforms:
		var rr: Rect2 = r
		if b > rr.position.x and a < rr.end.x and y0 <= rr.position.y + 0.01 and y1 >= rr.position.y:
			best = minf(best, rr.position.y)
	return best


# ---- the game loop ------------------------------------------------------------------------------

func _physics_process(_d: float) -> void:
	tick += 1
	mode_t += 1
	if demo:
		_autopilot()
	_read_input()
	match mode:
		"title":
			if pressed("start") or pressed("jump") or pressed("punch"):
				mode = "play"
				mode_t = 0
				sfx("select")
				_music("stage1")
		"play", "clear":
			if hitstop > 0:
				hitstop -= 1
			else:
				_play_step()
		"shop":
			_shop_step()
		"over":
			if mode_t > 60 and (pressed("start") or pressed("jump") or pressed("punch")):
				cash = cash / 2
				_build_stage()
				mode = "play"
				_music("stage1")
	if shown_cash < cash:
		shown_cash += 1 if cash - shown_cash < 20 else 5
	elif shown_cash > cash:
		shown_cash = cash
	_camera()
	fx.queue_redraw()
	hud.queue_redraw()
	rain.queue_redraw()
	if demo and tick % 60 == 0:
		print("demo t=%d mode=%s x=%d y=%d hp=%d cash=%d enemies=%d arena=%d boss=%d bosshp=%d" % [tick, mode, player.position.x,
			player.position.y, player.hp, cash, enemies.size(), arena_state, boss_state, boss.hp if boss else -1])
	if demo and tick % 600 == 0:
		var lst := []
		for e in enemies:
			if absf(e.position.x - player.position.x) < 300:
				lst.append("%s@%d,%d hp%d st=%s" % [e.kind, e.position.x, e.position.y, e.hp, e.st])
		print("  near: ", ", ".join(lst))
	if demo and (tick >= 9000 or (mode == "shop" and mode_t > 120)):
		print("demo end mode=%s cash=%d" % [mode, cash])
		get_tree().quit()


func _play_step() -> void:
	player.step()
	for e in enemies.duplicate():
		e.step()
		if e.harmful() and player.state != "dead" and e.rect().grow(-2).intersects(player.rect()):
			player.hurt(1, e.position.x)
		if e.gone:
			enemies.erase(e)
			e.queue_free()
	_step_notes()
	_step_coins()
	_step_arena()
	if go_t > 0:
		go_t -= 1
	for hp_ in heals.duplicate():
		var hv: Vector2 = hp_
		if player.rect().grow(2).has_point(hv + Vector2(0, -4)):
			heals.erase(hp_)
			player.hp = mini(player.hp + 3, player.max_hp)
			sfx("heal")
			say(hv + Vector2(-10, -16), "+COFFEE")
	if mode == "clear" and mode_t > 240:
		mode = "shop"
		mode_t = 0
		shop_sel = 0
		_music("title")
	if player.state == "dead" and player.st_t > 90 and mode == "play":
		mode = "over"
		mode_t = 0
		_music("gameover")


func _step_arena() -> void:
	var px: float = player.position.x
	if arena_state == 0 and px > ARENA["x0"] + 260:
		arena_state = 1
		lock = Vector2(ARENA["x0"], ARENA["x0"] + 400)
		wave = 0
		_spawn_wave()
	elif arena_state == 1:
		var alive := 0
		for e in enemies:
			if not e.dead and e.position.x > ARENA["x0"] - 20 and e.position.x < ARENA["x0"] + 420:
				alive += 1
		if alive == 0:
			wave_gap += 1
			if wave_gap > 40:
				wave_gap = 0
				wave += 1
				if wave < ARENA["waves"].size():
					_spawn_wave()
				else:
					arena_state = 2
					lock = Vector2(0, LEVEL_W)
					go_t = 150
					sfx("go")
	if boss_state == 0 and px > BOSS_X0 + 40:
		boss_state = 1
		lock = Vector2(BOSS_X0, LEVEL_W)
		for e in enemies:
			if not e.dead:
				e.gone = true
				pop(e.position + Vector2(0, -6), false)
		boss = _spawn("tl", Vector2(LEVEL_W - 30, FLOOR_Y))
		_music("boss")
		sfx("warn")


func _spawn_wave() -> void:
	for s in ARENA["waves"][wave]:
		_spawn(s[0], Vector2(s[1], s[2]))
	sfx("glitch")


func boss_defeated() -> void:
	boss_state = 2
	mode = "clear"
	mode_t = 0
	shake = 10
	_music("clear")
	for e in enemies:
		if e != boss and not e.dead:
			e.die()


func player_died() -> void:
	music.stop()


# ---- projectiles, coins, effects -----------------------------------------------------------------

func throw_note(from: Vector2, to: Vector2) -> void:
	var g := 0.1
	var t := clampf(absf(to.x - from.x) / 1.8, 28.0, 70.0)
	var v := Vector2((to.x - from.x) / t, (to.y - from.y - 0.5 * g * t * t) / t)
	notes.append({"p": from, "v": v, "g": g})
	sfx("throw")


func _step_notes() -> void:
	for n in notes.duplicate():
		n["v"].y += n["g"]
		n["p"] += n["v"]
		var p: Vector2 = n["p"]
		if player.state != "dead" and player.rect().grow(1).has_point(p):
			notes.erase(n)
			if player.inv == 0:
				say(player.position + Vector2(-20, -44), "NEW TASK!")
			player.hurt(1, p.x)
			continue
		if p.y > FLOOR_Y + 30 or p.x < lock.x - 20 or p.x > lock.y + 20 or (p.y > FLOOR_Y - 2 and not _in_pit(p.x)):
			notes.erase(n)
			pops.append({"p": p, "t": 0, "big": false})
	for w in waves_fx.duplicate():
		w["x"] += w["d"] * w["s"]
		w["t"] += 1
		var r := Rect2(w["x"] - 6, FLOOR_Y - 10, 12, 10)
		if player.state != "dead" and r.intersects(player.rect()):
			player.hurt(1, w["x"] - w["d"] * 10)
		if w["t"] > 140 or w["x"] < lock.x or w["x"] > lock.y:
			waves_fx.erase(w)


## CODE REVIEW fan: task i of 5 always flies along the same arc (learnable gaps).
func throw_fan(from: Vector2, dir: int, i: int) -> void:
	notes.append({"p": from, "v": Vector2(dir * (0.7 + i * 0.55), -3.2 + i * 0.25), "g": 0.1})


var call_text := ""
var call_t := 0
var dusts: Array = []
var star_at := Vector2.ZERO
var star_t := 0


func callout(s: String, frames: int) -> void:
	call_text = s
	call_t = frames + 30


func dust(at: Vector2) -> void:
	dusts.append({"p": at, "t": 0})


func stars(at: Vector2) -> void:
	star_at = at
	star_t = 2


func shockwave(at: Vector2, mad: bool) -> void:
	for d in [-1, 1]:
		waves_fx.append({"x": at.x + d * 10, "d": d, "t": 0, "s": 2.4 if mad else 1.9})


func drop_coins(at: Vector2, n: int) -> void:
	for i in n:
		coins.append({"p": at, "v": Vector2(randf_range(-1.4, 1.4), randf_range(-3.4, -1.8)), "t": randi() % 40, "rest": false, "life": 600})


func _step_coins() -> void:
	var pc: Vector2 = player.position + Vector2(0, -14)
	var magnet: bool = upgrades["magnet"] > 0
	for c in coins.duplicate():
		c["t"] += 1
		if c["life"] > 0:
			c["life"] -= 1
			if c["life"] == 0:
				coins.erase(c)
				continue
		var p: Vector2 = c["p"]
		if magnet and p.distance_to(pc) < 70 and player.state != "dead":
			c["rest"] = false
			c["v"] = (pc - p).normalized() * 3.0
			c["p"] += c["v"]
		elif not c["rest"]:
			c["v"].y += 0.2
			var y1: float = p.y + c["v"].y
			var g := ground(p.x - 2, p.x + 2, p.y + 3, y1 + 3)
			c["p"] = Vector2(p.x + c["v"].x, y1)
			if g < INF and c["v"].y > 0:
				c["p"].y = g - 3
				c["v"] = Vector2(c["v"].x * 0.6, -c["v"].y * 0.45)
				if absf(c["v"].y) < 0.7:
					c["rest"] = true
			if c["p"].y > 300:
				coins.erase(c)
				continue
		if (c["p"] as Vector2).distance_to(pc) < 14 and player.state != "dead":
			coins.erase(c)
			cash += 5
			sfx("pickup")


func spark(at: Vector2) -> void:
	pops.append({"p": at, "t": 0, "big": false})


func pop(at: Vector2, big: bool) -> void:
	pops.append({"p": at, "t": 0, "big": big})
	shake = maxf(shake, 6.0 if big else 2.0)


func say(at: Vector2, s: String) -> void:
	texts.append({"p": at, "s": s, "t": 0})


func _camera() -> void:
	var target: float = player.position.x + player.face * 30
	var lo := lock.x + 200
	var hi := lock.y - 200
	target = clampf(target, lo, hi)
	cam_x = lerpf(cam_x, target, 0.12)
	cam_x = clampf(cam_x, 200, LEVEL_W - 200)
	shake = maxf(0.0, shake - 0.4)
	var sh := Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) * 0.5
	cam.position = Vector2(roundf(cam_x), 120) + sh.round()


# ---- drawing -------------------------------------------------------------------------------------

func _draw_rain() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 70:
		var x := r.randi_range(0, 400)
		var y := float((r.randi_range(0, 160) + tick * 5) % 170) + 20
		rain.draw_line(Vector2(x, y), Vector2(x - 1, y + 3), Color8(110, 120, 190))


func _draw_fx() -> void:
	for c in coins:
		var t: int = c["t"]
		if c["life"] > 0 and c["life"] < 120 and (t / 3) % 2 == 0:
			continue
		var p: Vector2 = (c["p"] as Vector2).round()
		fx.draw_texture_rect_region(coin_tex, Rect2(p - Vector2(3, 3), Vector2(7, 7)), Rect2((t / 4) % 4 * 7, 0, 7, 7))
	for h_ in heals:
		var hv: Vector2 = h_
		var y := hv.y - 8 - ((tick / 20) % 2)
		fx.draw_rect(Rect2(hv.x - 4, y, 8, 8), Color8(14, 10, 24))
		fx.draw_rect(Rect2(hv.x - 3, y + 1, 6, 6), Color8(240, 240, 240))
		fx.draw_rect(Rect2(hv.x - 2, y + 2, 4, 2), Color8(120, 72, 40))
		fx.draw_rect(Rect2(hv.x + 3, y + 3, 2, 3), Color8(14, 10, 24))
	for n in notes:
		var p: Vector2 = (n["p"] as Vector2).round()
		fx.draw_texture_rect_region(note_tex, Rect2(p - Vector2(3, 3), Vector2(7, 7)), Rect2((tick / 4) % 2 * 7, 0, 7, 7))
	for d_ in dusts.duplicate():
		var k: int = d_["t"]
		d_["t"] = k + 1
		var dp: Vector2 = d_["p"]
		var r := 2 + k / 3
		fx.draw_rect(Rect2(dp.x - r, dp.y - r - k / 2, r * 2, r), Color8(200, 190, 220, 200 - k * 12))
		if k > 14:
			dusts.erase(d_)
	if star_t > 0:
		star_t -= 1
		for i in 3:
			var ang := tick * 0.12 + i * TAU / 3
			var sp := (star_at + Vector2(cos(ang) * 14, sin(ang) * 4)).round()
			fx.draw_rect(Rect2(sp + Vector2(-1, 0), Vector2(3, 1)), Color8(255, 230, 80))
			fx.draw_rect(Rect2(sp + Vector2(0, -1), Vector2(1, 3)), Color8(255, 230, 80))
	for w in waves_fx:
		var x: float = roundf(w["x"])
		var hh := 11 + (int(w["t"]) / 3) % 3
		fx.draw_rect(Rect2(x - 5, FLOOR_Y - hh, 10, hh), Color8(14, 10, 24))
		fx.draw_rect(Rect2(x - 4, FLOOR_Y - hh + 1, 8, hh - 1), Color8(250, 210, 90))
		fx.draw_rect(Rect2(x - 2, FLOOR_Y - hh + 2, 4, hh - 2), Color8(255, 250, 220))
	for p_ in pops.duplicate():
		var k: int = p_["t"]
		p_["t"] = k + 1
		var c: Vector2 = p_["p"]
		var n := 12 if p_["big"] else 8
		for a in n:
			var ang := a * TAU / n
			var r := 2.0 + k * (3.0 if p_["big"] else 1.6)
			var q := (c + Vector2(cos(ang), sin(ang)) * r).round()
			fx.draw_rect(Rect2(q, Vector2(2, 2)), Color8(255, 240, 120) if k % 2 else Color8(255, 255, 255))
		if k > (16 if p_["big"] else 6):
			pops.erase(p_)
	for t_ in texts.duplicate():
		var k: int = t_["t"]
		t_["t"] = k + 1
		F8.text(fx, (t_["p"] as Vector2) + Vector2(0, -k / 3), t_["s"], Color8(252, 220, 80))
		if k > 50:
			texts.erase(t_)
	if hud_debug:
		fx.draw_rect(player.rect(), Color(0, 1, 0, 0.4), false)


var hud_debug := false


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.physical_keycode == KEY_F2:
		hud_debug = not hud_debug


func _pips(x: int, y: int, n: int, full: int, col: Color) -> void:
	for i in n:
		hud.draw_rect(Rect2(x + i * 7, y, 6, 6), Color8(14, 10, 24))
		hud.draw_rect(Rect2(x + i * 7 + 1, y + 1, 4, 4), col if i < full else Color8(60, 50, 60))


func _draw_hud() -> void:
	var white := Color8(252, 252, 252)
	var gold := Color8(252, 200, 60)
	var K := Color8(14, 10, 24)
	if mode == "title":
		hud.draw_rect(Rect2(0, 0, 400, 240), Color(0.03, 0.02, 0.08, 0.55))
		F8.centered(hud, 200, 50, "HOTFIX!", Color8(250, 80, 70), 6)
		F8.centered(hud, 200, 92, "NEXUS MELTDOWN", Color8(160, 200, 252), 2)
		F8.centered(hud, 200, 116, "CLIMB THE CORPORATE LADDER. CLOSE THE TICKETS. RETIRE RICH.", white)
		if (tick / 30) % 2 == 0:
			F8.centered(hud, 200, 150, "PRESS ENTER", gold, 2)
		F8.centered(hud, 200, 190, "ARROWS/WASD MOVE   Z/SPACE JUMP   X PUNCH", white)
		F8.centered(hud, 200, 200, "GAMEPAD WORKS TOO", Color8(160, 160, 190))
		F8.centered(hud, 200, 226, "8-BIT TEST BUILD", Color8(120, 110, 160))
		return
	hud.draw_rect(Rect2(0, 0, 400, 16), K)
	F8.text(hud, Vector2(6, 2), "-BRO-", white, 1, false)
	_pips(6, 8, player.max_hp, player.hp, Color8(232, 40, 40))
	var px: int = 6 + player.max_hp * 7 + 12
	F8.text(hud, Vector2(px, 2), "CASH", white, 1, false)
	F8.text(hud, Vector2(px, 9), "$%04d" % shown_cash, gold, 1, false)
	F8.text(hud, Vector2(px + 44, 2), "STAGE 1", white, 1, false)
	F8.text(hud, Vector2(px + 44, 9), "NEXUS HQ", Color8(160, 200, 252), 1, false)
	if boss_state == 1 and boss:
		F8.text(hud, Vector2(322, 2), "-TEAM LEAD-", white, 1, false)
		var full := int(ceil(boss.hp * 8.0 / boss.max_hp))
		_pips(340, 8, 8, full, Color8(232, 160, 40))
	if call_t > 0:
		call_t -= 1
		if call_t > 30 or (call_t / 4) % 2 == 0:
			var cw := F8.width(call_text, 3) + 16
			hud.draw_rect(Rect2(200 - cw / 2, 30, cw, 25), Color8(14, 10, 24))
			hud.draw_rect(Rect2(200 - cw / 2 + 1, 31, cw - 2, 23), Color8(150, 30, 40))
			F8.centered(hud, 200, 35, call_text, Color8(255, 240, 200), 3)
	if go_t > 0 and (go_t / 12) % 2 == 0:
		F8.text(hud, Vector2(320, 110), "GO! >>", gold, 3)
	match mode:
		"clear":
			F8.centered(hud, 200, 70, "TEAM LEADER DEFEATED!", gold, 2)
			F8.centered(hud, 200, 94, "YOUR PR IS APPROVED.", white)
			F8.centered(hud, 200, 110, "CASH $%d" % shown_cash, gold, 2)
		"over":
			hud.draw_rect(Rect2(0, 16, 400, 224), Color(0, 0, 0, minf(0.7, mode_t / 60.0)))
			F8.centered(hud, 200, 90, "BURNOUT!", Color8(250, 80, 70), 4)
			F8.centered(hud, 200, 130, "YOU LOSE HALF YOUR CASH.", white)
			if mode_t > 60 and (tick / 30) % 2 == 0:
				F8.centered(hud, 200, 150, "PRESS ENTER TO TRY AGAIN", gold)
		"shop":
			_draw_shop()


func _draw_shop() -> void:
	var white := Color8(252, 252, 252)
	var gold := Color8(252, 200, 60)
	hud.draw_rect(Rect2(0, 16, 400, 224), Color8(20, 14, 36))
	F8.centered(hud, 200, 24, "BREAK ROOM VENDING MACHINE", gold, 2)
	hud.draw_texture_rect(vending_tex, Rect2(24, 56, 80, 128), false)
	for i in SHOP.size():
		var it: Array = SHOP[i]
		var y := 58 + i * 30
		var owned: int = upgrades[it[0]]
		var maxed: bool = owned >= it[4]
		var col := white if i == shop_sel else Color8(150, 150, 180)
		if i == shop_sel:
			hud.draw_rect(Rect2(124, y - 4, 256, 26), Color8(60, 40, 100))
			F8.text(hud, Vector2(128, y + 4), ">", gold, 2)
		F8.text(hud, Vector2(142, y), it[1], col, 2)
		F8.text(hud, Vector2(142, y + 13), it[2] + ("  (%d/%d)" % [owned, it[4]] if it[4] > 1 else ""), Color8(160, 200, 252))
		F8.text(hud, Vector2(330, y + 2), "SOLD" if maxed else "$%d" % it[3], Color8(120, 120, 140) if maxed else gold, 2)
	var y2 := 58 + SHOP.size() * 30
	if shop_sel == SHOP.size():
		hud.draw_rect(Rect2(124, y2 - 4, 256, 18), Color8(60, 40, 100))
		F8.text(hud, Vector2(128, y2), ">", gold, 2)
	F8.text(hud, Vector2(142, y2), "NEXT SHIFT >>", white, 2)
	F8.centered(hud, 200, 214, "UP/DOWN CHOOSE   X/ENTER BUY   CASH $%d" % cash, white)
	F8.centered(hud, 200, 226, "(STAGE 2 IS COMING: NEXT SHIFT REPLAYS STAGE 1)", Color8(120, 110, 160))


func _shop_step() -> void:
	if pressed("down"):
		shop_sel = (shop_sel + 1) % (SHOP.size() + 1)
		sfx("menu")
	if pressed("up"):
		shop_sel = (shop_sel + SHOP.size()) % (SHOP.size() + 1)
		sfx("menu")
	if pressed("punch") or pressed("start") or pressed("jump"):
		if shop_sel == SHOP.size():
			_build_stage()
			mode = "play"
			_music("stage1")
			sfx("select")
			return
		var it: Array = SHOP[shop_sel]
		if upgrades[it[0]] < it[4] and cash >= it[3]:
			cash -= it[3]
			upgrades[it[0]] += 1
			sfx("combo")
		else:
			sfx("block")


# ---- audio ---------------------------------------------------------------------------------

func _music(id: String) -> void:
	var s: AudioStream = load("res://assets/audio/music_%s.ogg" % id)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = id in ["title", "stage1", "boss"]
	music.stream = s
	music.play()


func sfx(id: String) -> void:
	var p: AudioStreamPlayer = sfx_pool[sfx_i]
	sfx_i = (sfx_i + 1) % sfx_pool.size()
	p.stream = load("res://assets/audio/sfx_%s.wav" % id)
	p.play()


# ---- demo autopilot (headless tests and recorded previews) ---------------------------------

var _stuck := 0
var _last_x := 0.0


func _autopilot() -> void:
	_auto = {}
	if mode == "shop":
		if mode_t == 20 or mode_t == 40:
			_auto["punch"] = true
		if mode_t > 60:
			_auto["up"] = mode_t % 4 < 2
		return
	if mode != "play" or player.state == "dead":
		_auto["start"] = mode_t % 20 < 10
		return
	var px: float = player.position.x
	var py: float = player.position.y
	if boss and "--boss" in OS.get_cmdline_user_args():
		var bx: float = boss.position.x
		var dizzy: bool = boss.st == "dizzy"
		var want2 := bx - 26.0 if bx > px else bx + 26.0
		if not dizzy:
			want2 = bx - 110.0 if bx > lock.x + 150 else bx + 110.0
		if absf(px - want2) > 4:
			_auto["right" if want2 > px else "left"] = true
		elif dizzy:
			if player.face != (1 if bx > px else -1):
				_auto["right" if bx > px else "left"] = true
			elif tick % 8 == 0:
				_auto["punch"] = true
		for w in waves_fx:
			if absf(w["x"] - px) < 34 and player.on_ground:
				_auto["jump"] = true
		if boss.st == "sprint" and absf(bx - px) < 70 and player.on_ground:
			_auto["jump"] = true
		if not player.on_ground and player.vel.y < 0:
			_auto["jump"] = true
		return
	var near = null
	var best_d := 1e9
	for e in enemies:
		if e.dead:
			continue
		var ddx: float = e.position.x - px
		var ey0: float = e.position.y - e.h / 2.0
		var locked := lock.x > 0
		if e.position.x < lock.x or e.position.x > lock.y or (absf(ddx) > 140 and not locked) or ey0 < py - 75 or (ddx < -30 and not locked):
			continue
		var d := absf(ddx) + absf(ey0 - py) * 0.5
		if d < best_d:
			best_d = d
			near = e
	if near:
		var er: Rect2 = near.rect()
		var dx: float = near.position.x - px
		var dir := 1 if dx > 0 else -1
		var want: float = near.position.x - dir * 18.0
		if near.position.y > py + 8:
			want = near.position.x + dir * 30.0
		var box := Rect2(px + (2 if dir > 0 else -22), py - 30, 20, 29)
		if box.intersects(er):
			if player.face != dir:
				_auto["right" if dir > 0 else "left"] = true
			elif tick % 8 == 0:
				_auto["punch"] = true
		elif absf(px - want) > 3:
			_auto["right" if want > px else "left"] = true
		if er.end.y < py - 20 and absf(dx) < 40 and player.on_ground:
			_auto["jump"] = true
	else:
		_auto["right"] = true
	if player.on_ground:
		if _in_pit(px + 30) or (absf(px - _last_x) < 0.05 and (_auto.get("right", false) or _auto.get("left", false))):
			_stuck += 1
		else:
			_stuck = 0
		if _stuck > 4 or _in_pit(px + 22):
			_auto["jump"] = true
			_stuck = 0
	elif player.vel.y < 0:
		_auto["jump"] = true
	_last_x = px
