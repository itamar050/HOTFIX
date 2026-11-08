extends Node2D
## A fighter drawn with the imported sprite strips (tools/import_art.py). Each strip is a
## row of equal cells; its .json gives the cell size, with the feet at (cell_w / 2, 124).
## The same script runs the player (Code Bro) and the glitched sparring clone.

const STRIPS := ["bro_sheet", "bro_idle", "bro_walk", "bro_run", "bro_punch", "bro_hook",
	"bro_kick", "bro_hurt", "bro_knockdown"]
## Animations: [strip, frame, ticks] steps; an attack's active step is marked "hit".
const ANIMS := {
	"idle": [["bro_idle", 0, 18], ["bro_idle", 1, 12], ["bro_idle", 2, 22], ["bro_idle", 3, 12]],
	"walk": [["bro_walk", 0, 6], ["bro_walk", 1, 6], ["bro_walk", 2, 6], ["bro_walk", 3, 6], ["bro_walk", 4, 6], ["bro_walk", 5, 6], ["bro_walk", 6, 6], ["bro_walk", 7, 6]],
	"run": [["bro_run", 0, 4], ["bro_run", 1, 4], ["bro_run", 2, 4], ["bro_run", 3, 4], ["bro_run", 4, 4], ["bro_run", 5, 4], ["bro_run", 6, 4], ["bro_run", 7, 4]],
	"jump": [["bro_run", 2, 999]],
	"jab_a": [["bro_punch", 0, 2], ["bro_punch", 1, 7, "hit"], ["bro_punch", 2, 6]],
	"jab_b": [["bro_punch", 3, 2], ["bro_punch", 4, 7, "hit"], ["bro_punch", 5, 6]],
	"hook": [["bro_hook", 1, 7], ["bro_hook", 2, 7, "hit"], ["bro_hook", 3, 10]],
	"kick": [["bro_kick", 0, 7], ["bro_kick", 1, 9, "hit"], ["bro_kick", 2, 12]],
	"windup": [["bro_punch", 0, 999]],
	"hurt_face": [["bro_hurt", 0, 999]],
	"hurt_gut": [["bro_hurt", 1, 999]],
	"fly": [["bro_knockdown", 0, 999]],
	"down": [["bro_knockdown", 1, 999]],
	"getup": [["bro_knockdown", 2, 9], ["bro_knockdown", 4, 9], ["bro_knockdown", 5, 9]],
}
## The attack chain: each hit that connects lets the next one start.
## box = hitbox relative to the feet when facing right (measured on the sprites).
const ATTACKS := {
	"jab_a": {"box": Rect2(22, -94, 36, 22), "dmg": 4, "kb": 2.0, "next": "jab_b"},
	"jab_b": {"box": Rect2(22, -94, 36, 22), "dmg": 4, "kb": 2.0, "next": "hook"},
	"hook": {"box": Rect2(24, -100, 42, 26), "dmg": 6, "kb": 3.0, "next": "kick", "heavy": true},
	"kick": {"box": Rect2(20, -104, 46, 34), "dmg": 9, "kb": 5.0, "knockdown": true, "heavy": true},
}
const WALK_SPEED := 3.2
const RUN_SPEED := 5.6
const GRAVITY := 0.55
const JUMP_V := -10.5
const HURT_BOX := Rect2(-18, -116, 36, 116)

var main
var is_player := true
var sprite: Sprite2D
var tex := {}
var cell := {}
var vel := Vector2.ZERO
var face := 1
var state := "idle"
var t := 0
var anim := ""
var step := 0
var step_t := 0
var hp := 100
var max_hp := 100
var flash := 0
var inv := 0
var attack := ""
var hit_done := false
var connected := false
var buffered := false
var atk_cd := 60
var running := false
var dead := false


func setup(m, player: bool, pos: Vector2) -> void:
	main = m
	is_player = player
	position = pos
	face = 1 if player else -1
	max_hp = 100 if player else 45
	hp = max_hp
	for k in STRIPS:
		tex[k] = load("res://assets/sprites/%s.png" % k)
		var meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/%s.json" % k))
		cell[k] = int(meta["cell"][0]) if meta else 160
	sprite = Sprite2D.new()
	sprite.centered = false
	add_child(sprite)
	z_index = 2 if player else 1
	play("idle")


func play(name: String) -> void:
	if anim == name:
		return
	anim = name
	step = 0
	step_t = 0
	_show()


func _show() -> void:
	var s: Array = ANIMS[anim][step]
	var k: String = s[0]
	sprite.texture = tex[k]
	sprite.hframes = int(tex[k].get_width() / cell[k])
	sprite.frame = s[1]
	sprite.offset = Vector2(-cell[k] / 2, -124)
	sprite.flip_h = face < 0


## Advance the animation. Returns true when it wraps (an attack finished).
func _anim_tick() -> bool:
	step_t += 1
	var steps: Array = ANIMS[anim]
	if step_t >= steps[step][2]:
		step_t = 0
		step += 1
		var wrapped := step >= steps.size()
		if wrapped:
			step = 0
		_show()
		return wrapped
	return false


func on_active_step() -> bool:
	var s: Array = ANIMS[anim][step]
	return s.size() > 3 and s[3] == "hit"


func world_box(r: Rect2) -> Rect2:
	if face < 0:
		r = Rect2(-r.position.x - r.size.x, r.position.y, r.size.x, r.size.y)
	return Rect2(position + r.position, r.size)


func set_state(s: String) -> void:
	state = s
	t = 0


# ---- per tick ------------------------------------------------------------------------------
func _physics_process(_delta: float) -> void:
	if main.hitstop > 0:
		return
	t += 1
	if flash > 0:
		flash -= 1
	if inv > 0:
		inv -= 1
	if atk_cd > 0:
		atk_cd -= 1
	match state:
		"hurt":
			vel.x = move_toward(vel.x, 0, 0.25)
			if t > 16:
				set_state("idle")
		"fly", "down", "getup":
			_knockdown_tick()
		_:
			if is_player:
				_player_control()
			else:
				_clone_ai()
	# physics: one floor, the level edges
	vel.y += GRAVITY
	position += vel
	var on_ground: bool = position.y >= main.GROUND_Y
	if on_ground:
		position.y = main.GROUND_Y
		vel.y = 0.0
	position.x = clampf(position.x, 30.0, main.LEVEL_W - 30.0)
	if state == "jump" and on_ground and t > 3:
		set_state("idle")
	if state == "fly" and on_ground and t > 4:
		set_state("down")
		main.sfx("enemyDie" if dead and not is_player else "land")
		main.shake = maxf(main.shake, 2.0)
	_update_anim()
	if state == "attack" and on_active_step() and not hit_done:
		_try_hit()
	var base := Color(1, 1, 1) if is_player else Color(0.55, 0.45, 1.25)
	sprite.modulate = Color(3, 3, 3) if flash > 0 else base
	if state == "windup" and (t / 3) % 2 == 0:
		sprite.modulate = Color(1.6, 0.6, 0.6)
	sprite.visible = not (inv > 0 and state in ["idle", "jump", "attack"] and (t / 3) % 2 == 0)
	if not is_player and state not in ["fly", "down"] and t % 97 < 4:
		sprite.position.x = 3  # glitch flicker
	else:
		sprite.position.x = 0
	queue_redraw()


func _update_anim() -> void:
	match state:
		"idle":
			if absf(vel.x) > 0.3:
				play("run" if running else "walk")
			else:
				play("idle")
			_anim_tick()
		"jump":
			play("jump")
		"attack":
			if _anim_tick():
				var nxt: String = ATTACKS[attack].get("next", "")
				if buffered and connected and nxt != "":
					_start_attack(nxt)
				else:
					set_state("idle")
					play("idle")
		"windup":
			play("windup")
		"hurt":
			pass
		"fly":
			play("fly")
		"down":
			play("down")
		"getup":
			play("getup")
			if _anim_tick():
				set_state("idle")
				inv = 50
				play("idle")


func _player_control() -> void:
	var dir: float = float(main.held("right")) - float(main.held("left"))
	if state == "attack":
		vel.x = move_toward(vel.x, 0, 0.4)
		if main.pressed("attack") and step >= 1:
			buffered = true
		return
	running = main.held("run") and dir != 0
	if dir != 0:
		face = int(dir)
		sprite.flip_h = face < 0
	vel.x = move_toward(vel.x, dir * (RUN_SPEED if running else WALK_SPEED), 0.5)
	if main.pressed("jump") and state != "jump":
		vel.y = JUMP_V
		set_state("jump")
		main.sfx("jump")
	if main.pressed("attack") and state == "idle":
		_start_attack("jab_a")


func _start_attack(name: String) -> void:
	set_state("attack")
	attack = name
	buffered = false
	hit_done = false
	connected = false if name == "jab_a" else connected
	anim = ""
	play(name)
	vel.x = face * (1.6 if name == "kick" else 1.0)
	main.sfx("whiff")


func _try_hit() -> void:
	var target = main.clone if is_player else main.player
	if target.state in ["fly", "down", "getup"] or target.inv > 0:
		return
	var a: Dictionary = ATTACKS[attack]
	var box := world_box(a["box"])
	if box.intersects(target.world_box(HURT_BOX)):
		hit_done = true
		connected = true
		var heavy: bool = a.get("heavy", false)
		var dmg: int = a["dmg"] if is_player else a["dmg"] + 3
		main.sfx("heavy" if heavy else "punch")
		target.take_hit(dmg, face, a["kb"], a.get("knockdown", false), attack == "hook")
		var c: Vector2 = box.intersection(target.world_box(HURT_BOX)).get_center()
		main.hit_effect(c, heavy)


func take_hit(dmg: int, dir: int, kb: float, knockdown: bool, high: bool) -> void:
	hp -= dmg
	if is_player:
		main.sfx("hurt")
	flash = 6
	face = -dir
	sprite.flip_h = face < 0
	if hp <= 0:
		hp = 0
		dead = true
		knockdown = true
	if knockdown:
		set_state("fly")
		vel = Vector2(dir * (kb + 1.0), -7.0)
		anim = ""
		play("fly")
		if dead and not is_player:
			main.kos += 1
		return
	set_state("hurt")
	vel.x = dir * kb
	anim = ""
	# a hook or a punch to the head snaps the head back; the rest double him over
	play("hurt_face" if high or randf() < 0.5 else "hurt_gut")


func _knockdown_tick() -> void:
	if state == "fly":
		return
	vel.x = move_toward(vel.x, 0, 0.35)
	if state == "down":
		if dead and t > 50:
			sprite.self_modulate.a = 1.0 - (t - 50) / 30.0
			if t > 80:
				_respawn()
		elif not dead and t > 40:
			set_state("getup")


func _respawn() -> void:
	dead = false
	main.sfx("glitch")
	hp = max_hp
	sprite.self_modulate.a = 1.0
	set_state("idle")
	inv = 60
	if not is_player:
		var side := 1 if randf() < 0.5 else -1
		position = Vector2(clampf(main.player.position.x + 260 * side, 60, main.LEVEL_W - 60), main.GROUND_Y - 200)


func _clone_ai() -> void:
	if state == "attack":
		vel.x = move_toward(vel.x, 0, 0.4)
		return
	var p = main.player
	var dx: float = p.position.x - position.x
	if state == "windup":
		vel.x = 0
		if t > 22:
			_start_attack("jab_a")
		return
	face = 1 if dx > 0 else -1
	if absf(dx) > 62:
		vel.x = move_toward(vel.x, face * 2.0, 0.2)
	elif absf(dx) < 40:
		vel.x = move_toward(vel.x, -face * 1.2, 0.2)
	else:
		vel.x = move_toward(vel.x, 0, 0.3)
		if atk_cd <= 0 and p.state in ["idle", "jump", "attack"]:
			set_state("windup")
			atk_cd = randi_range(70, 120)


func _draw() -> void:
	# a soft shadow on the floor, and hitboxes when F2 is on
	var gy: float = main.GROUND_Y - position.y
	draw_rect(Rect2(-22, gy - 3, 44, 5), Color(0, 0, 0, 0.35))
	if main.show_boxes:
		draw_rect(HURT_BOX, Color(0, 1, 0, 0.6), false)
		if state == "attack" and on_active_step():
			var b: Rect2 = ATTACKS[attack]["box"]
			if face < 0:
				b = Rect2(-b.position.x - b.size.x, b.position.y, b.size.x, b.size.y)
			draw_rect(b, Color(1, 0, 0, 0.8), false)
