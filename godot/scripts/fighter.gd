extends Node2D
## A fighter drawn with the imported sprite strips. Each strip is a row of 160x128 cells
## with the feet at (80, 124), as written by tools/import_art.py. The same script runs the
## player (Code Bro) and the glitched sparring clone (same sprites, tinted, simple AI).

const CELL := Vector2(160, 128)
const ANCHOR := Vector2(80, 124)
const STRIPS := {
	"sheet": "res://assets/sprites/bro_sheet.png",
	"walk": "res://assets/sprites/bro_walk.png",
	"punch": "res://assets/sprites/bro_punch.png",
}
## Animations: [strip, frame, ticks] steps. Attacks mark their active step with "hit".
const ANIMS := {
	"idle": [["sheet", 0, 34], ["punch", 3, 34]],
	"walk": [["walk", 0, 7], ["walk", 1, 7], ["walk", 2, 7], ["walk", 3, 7], ["walk", 4, 7], ["walk", 5, 7]],
	"jump": [["walk", 3, 99]],
	"jab_a": [["punch", 0, 2], ["punch", 1, 7, "hit"], ["punch", 2, 6]],
	"jab_b": [["punch", 3, 2], ["punch", 4, 7, "hit"], ["punch", 5, 6]],
	"windup": [["punch", 0, 99]],
	"hurt": [["sheet", 1, 99]],
	"ko": [["sheet", 1, 999]],
}
const WALK_SPEED := 3.2
const GRAVITY := 0.55
const JUMP_V := -10.5
## hitbox of a jab relative to the feet (facing right): the fist at +52, chest height
const JAB_BOX := Rect2(22, -94, 36, 22)
const HURT_BOX := Rect2(-18, -116, 36, 116)

var main
var is_player := true
var sprite: Sprite2D
var textures := {}
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
var chain := 0
var hit_done := false
var buffered := false
var atk_cd := 60
var respawn_t := 0


func setup(m, player: bool, pos: Vector2) -> void:
	main = m
	is_player = player
	position = pos
	face = 1 if player else -1
	max_hp = 100 if player else 40
	hp = max_hp
	for k in STRIPS:
		textures[k] = load(STRIPS[k])
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = -ANCHOR
	add_child(sprite)
	z_index = 2 if player else 1
	if not player:
		sprite.modulate = Color(0.55, 0.45, 1.25)
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
	var tex: Texture2D = textures[s[0]]
	sprite.texture = tex
	sprite.hframes = int(tex.get_width() / CELL.x)
	sprite.frame = s[1]
	sprite.flip_h = face < 0


func _anim_tick() -> bool:
	## advance the animation; returns true when a non-looping attack finished
	step_t += 1
	var steps: Array = ANIMS[anim]
	if step_t >= steps[step][2]:
		step_t = 0
		step += 1
		if step >= steps.size():
			step = 0
			if anim.begins_with("jab"):
				return true
		_show()
	return false


func on_active_step() -> bool:
	var s: Array = ANIMS[anim][step]
	return s.size() > 3 and s[3] == "hit"


func world_box(r: Rect2) -> Rect2:
	if face < 0:
		r = Rect2(-r.position.x - r.size.x, r.position.y, r.size.x, r.size.y)
	return Rect2(position + r.position, r.size)


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
		state = "idle"
	_update_anim(on_ground)
	if state == "jab" and on_active_step() and not hit_done:
		_try_hit()
	# hit flash and blinking
	var base := Color(1, 1, 1) if is_player else Color(0.55, 0.45, 1.25)
	sprite.modulate = Color(3, 3, 3) if flash > 0 else base
	if state == "windup" and (t / 3) % 2 == 0:
		sprite.modulate = Color(1.6, 0.6, 0.6)
	sprite.visible = not (inv > 0 and state != "ko" and (t / 3) % 2 == 0)
	if not is_player and state != "ko" and t % 97 < 4:
		sprite.position.x = 3  # glitch flicker
	else:
		sprite.position.x = 0
	queue_redraw()


func _update_anim(on_ground: bool) -> void:
	match state:
		"idle":
			play("walk" if absf(vel.x) > 0.3 else "idle")
		"jump":
			play("jump")
		"jab":
			if _anim_tick():
				if buffered and is_player:
					_start_jab()
				else:
					state = "idle"
					play("idle")
			return
		"windup":
			play("windup")
		"hurt":
			play("hurt")
		"ko":
			play("ko")
	if state == "idle" or state == "jump":
		_anim_tick()


func _player_control() -> void:
	if state == "ko":
		_ko_tick()
		return
	if state == "hurt":
		vel.x = move_toward(vel.x, 0, 0.25)
		if t > 14:
			state = "idle"
		return
	var dir: float = float(main.held("right")) - float(main.held("left"))
	if state == "jab":
		vel.x = move_toward(vel.x, 0, 0.4)
		if main.pressed("attack") and step >= 1:
			buffered = true
		return
	if dir != 0:
		face = int(dir)
		sprite.flip_h = face < 0
	vel.x = move_toward(vel.x, dir * WALK_SPEED, 0.5)
	if main.pressed("jump") and state != "jump":
		vel.y = JUMP_V
		state = "jump"
		t = 0
	if main.pressed("attack") and state == "idle":
		_start_jab()


func _start_jab() -> void:
	state = "jab"
	buffered = false
	hit_done = false
	anim = ""
	play("jab_a" if chain % 2 == 0 else "jab_b")
	chain += 1
	vel.x = face * 1.0


func _try_hit() -> void:
	var target = main.clone if is_player else main.player
	if target.state == "ko" or target.inv > 0:
		return
	var box := world_box(JAB_BOX)
	if box.intersects(target.world_box(HURT_BOX)):
		hit_done = true
		var heavy := chain % 3 == 0
		target.take_hit(4 if is_player else 7, face, heavy)
		var c: Vector2 = box.intersection(target.world_box(HURT_BOX)).get_center()
		main.hit_effect(c, heavy)


func take_hit(dmg: int, dir: int, heavy: bool) -> void:
	hp -= dmg
	flash = 6
	face = -dir
	if hp <= 0:
		hp = 0
		state = "ko"
		t = 0
		vel = Vector2(dir * 4.0, -6.0)
		if not is_player:
			main.kos += 1
		return
	state = "hurt"
	t = 0
	vel.x = dir * (3.5 if heavy else 2.2)
	inv = 8 if is_player else 0


func _ko_tick() -> void:
	# fly back, fall over, fade out, then come back for more
	sprite.rotation = move_toward(sprite.rotation, -PI / 2 * face, 0.12)
	if position.y >= main.GROUND_Y:
		vel.x = move_toward(vel.x, 0, 0.3)
	if t > 60:
		sprite.self_modulate.a = 1.0 - (t - 60) / 30.0
	if t > 90:
		sprite.rotation = 0
		sprite.self_modulate.a = 1.0
		hp = max_hp
		state = "idle"
		inv = 60
		if not is_player:
			position = Vector2(main.player.position.x + 260 * (1 if randf() < 0.5 else -1), main.GROUND_Y - 200)
			position.x = clampf(position.x, 60, main.LEVEL_W - 60)


func _clone_ai() -> void:
	if state == "ko":
		_ko_tick()
		return
	if state == "hurt":
		vel.x = move_toward(vel.x, 0, 0.2)
		if t > 18:
			state = "idle"
			atk_cd = maxi(atk_cd, 30)
		return
	if state == "jab":
		vel.x = move_toward(vel.x, 0, 0.4)
		return
	var p = main.player
	var dx: float = p.position.x - position.x
	if state == "windup":
		vel.x = 0
		if t > 22:
			_start_jab()
		return
	face = 1 if dx > 0 else -1
	if absf(dx) > 62:
		vel.x = move_toward(vel.x, face * 2.0, 0.2)
	elif absf(dx) < 40:
		vel.x = move_toward(vel.x, -face * 1.2, 0.2)
	else:
		vel.x = move_toward(vel.x, 0, 0.3)
		if atk_cd <= 0 and p.state != "ko":
			state = "windup"
			t = 0
			atk_cd = randi_range(70, 120)


func _draw() -> void:
	# a soft shadow on the floor, and hitboxes when F2 is on
	var gy: float = main.GROUND_Y - position.y
	draw_rect(Rect2(-22, gy - 3, 44, 5), Color(0, 0, 0, 0.35))
	if main.show_boxes:
		draw_rect(Rect2(HURT_BOX.position * Vector2(1, 1), HURT_BOX.size), Color(0, 1, 0, 0.6), false)
		if state == "jab" and on_active_step():
			var b := JAB_BOX
			if face < 0:
				b = Rect2(-b.position.x - b.size.x, b.position.y, b.size.x, b.size.y)
			draw_rect(b, Color(1, 0, 0, 0.8), false)
