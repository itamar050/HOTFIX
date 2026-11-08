## Code Bro (8-bit): run, variable jump + double jump (coyote time, buffering), punch combo,
## air punch, weapons (keyboard, OOO notes) and the skill tree abilities (dash, rage punch...).
extends "res://game8/actor.gd"

const SPEED := 1.3
const GRAV := 0.22
const JUMP_V := 4.7
const FALL_MAX := 5.0
const CHARGE := 40  ## frames of holding punch for a RAGE QUIT punch

var hp := 8
var max_hp := 8
var state := "normal"  ## normal, punch, dash, hurt, dead
var st_t := 0
var coyote := 0
var jbuf := 0
var air_jumps := 0
var land_t := 0
var walk_d := 0.0
var punch_air := false
var punch_big := false
var punch_hit: Array = []
var safe_pos := Vector2.ZERO
var god := false  ## demo autopilot: no damage
var dash_ready := true
var charge_t := 0
var weapon := ""  ## "", "keyboard", "ooo"
var w_uses := 0


func setup(m, p: Vector2) -> void:
	main = m
	position = p
	safe_pos = p
	w = 12
	h = 30
	make_sprite("bro")


func speed() -> float:
	return SPEED * (1.25 if main.has("sneakers") else 1.0)


func step() -> void:
	var ix := int(main.btn("right")) - int(main.btn("left"))
	if main.pressed("jump"):
		jbuf = 7
	elif jbuf > 0:
		jbuf -= 1
	if on_ground:
		coyote = 7
		air_jumps = 2 if main.has("triple") else 1
		dash_ready = true
	elif coyote > 0:
		coyote -= 1
	if inv > 0:
		inv -= 1
	if land_t > 0:
		land_t -= 1
	if main.has("energy") and main.tick % 900 == 0 and hp < max_hp and state != "dead":
		hp += 1
	st_t += 1
	# charged punch: hold punch, release when glowing
	if main.has("ragequit") and state == "normal" and main.btn("punch") and weapon != "ooo":
		charge_t += 1
	elif state == "normal" and charge_t >= CHARGE and not main.btn("punch"):
		charge_t = 0
		_start_punch(true)
	elif not main.btn("punch"):
		charge_t = 0
	match state:
		"dead":
			vel.x = 0
		"hurt":
			vel.x = move_toward(vel.x, 0, 0.05)
			if (st_t > 16 and on_ground) or st_t > 40:
				state = "normal"
		"dash":
			vel = Vector2(face * 3.8, 0)
			if st_t % 3 == 0:
				main.dust(position + Vector2(-face * 6, -4))
			if st_t >= 12:
				state = "normal"
				vel.x = face * speed()
		"punch":
			if punch_air and not on_ground:
				vel.x = move_toward(vel.x, ix * speed(), 0.12)
			else:
				vel.x = move_toward(vel.x, 0, 0.18)
			if st_t >= 3 and st_t <= 9 and weapon != "ooo_throw":
				_punch_check()
			if main.pressed("punch") and st_t >= 9:
				_start_punch(false)
			elif st_t >= (22 if punch_big else 15) or (punch_air and on_ground and st_t > 9):
				state = "normal"
				punch_big = false
		_:
			vel.x = move_toward(vel.x, ix * speed(), 0.25 if on_ground else 0.16)
			if ix != 0:
				face = ix
			if main.pressed("punch"):
				_start_punch(false)
	if main.pressed("dash") and main.has("dash") and dash_ready and state in ["normal", "punch"]:
		state = "dash"
		st_t = 0
		dash_ready = on_ground
		if ix != 0:
			face = ix
		main.sfx("whiff")
	if state != "dead" and state != "hurt" and state != "dash" and jbuf > 0:
		if coyote > 0:
			vel.y = -JUMP_V
			coyote = 0
			jbuf = 0
			main.sfx("jump")
		elif air_jumps > 0:
			vel.y = -JUMP_V * 0.92
			air_jumps -= 1
			jbuf = 0
			main.sfx("jump")
			main.dust(position)
	if not main.btn("jump") and vel.y < -1.6 and state != "hurt":
		vel.y = -1.6
	if state != "dash":
		var g := GRAV * (0.6 if absf(vel.y) < 0.8 and main.btn("jump") else 1.0)
		vel.y = minf(vel.y + g, FALL_MAX)
	var was_air := not on_ground
	var fall_v := vel.y
	move_body()
	if on_ground and was_air and fall_v > 2.5:
		land_t = 6
		main.sfx("land")
	if on_ground and main.is_safe(position.x):
		safe_pos = position
	position.x = clampf(position.x, main.lock.x + 6, main.lock.y - 6)
	if position.y > 280 and state != "dead":
		hurt(2, position.x, false)
		position = safe_pos + Vector2(0, -4)
		vel = Vector2.ZERO
	_animate()


func _start_punch(big: bool) -> void:
	state = "punch"
	st_t = 0
	punch_hit = []
	punch_air = not on_ground
	punch_big = big
	if weapon == "ooo" and not big:
		main.throw_ooo(position + Vector2(face * 10, -20), face)
		w_uses -= 1
		if w_uses <= 0:
			weapon = ""
		st_t = 4
		return
	if big:
		main.say(position + Vector2(-22, -44), "RAGE QUIT!")
		main.sfx("heavy")
	else:
		main.sfx("whiff")


func punch_box() -> Rect2:
	# reaches from the chest down to the floor, so low enemies like bugs can be hit too
	var reach := 20.0
	if weapon == "keyboard":
		reach = 32.0
	if punch_big:
		reach = 30.0
	return Rect2(position.x + (2.0 if face > 0 else -2.0 - reach), position.y - 30, reach, 29)


func damage() -> int:
	var d := 1 + int(main.has("kb1")) + int(main.has("kb2"))
	if weapon == "keyboard":
		d += 2
	if punch_big:
		d += 3
	return d


func _punch_check() -> void:
	var box := punch_box()
	for e in main.enemies:
		if e.dead or e in punch_hit:
			continue
		var r: Rect2 = e.rect()
		if box.intersects(r):
			punch_hit.append(e)
			e.hurt(damage(), face)
			if punch_big:
				e.knock = 20
				e.vel.x = face * 4.0
				main.shake = 6
			main.hitstop = 5 if punch_big else 3
			main.spark(Vector2(position.x + face * (30 if weapon == "keyboard" else 18), box.position.y + 8))
			if weapon == "keyboard":
				w_uses -= 1
				if w_uses <= 0:
					weapon = ""
					main.say(position + Vector2(-28, -44), "KEYBOARD BROKE!")
					main.pop(position + Vector2(face * 20, -20), false)


func hurt(dmg: int, from_x: float, knock := true) -> void:
	if inv > 0 or state == "dead" or state == "dash" or god:
		return
	hp -= dmg
	inv = 70
	main.sfx("hurt")
	main.shake = 4
	charge_t = 0
	if hp <= 0 and main.has("parachute") and not main.parachute_used:
		main.parachute_used = true
		hp = 1
		main.say(position + Vector2(-34, -50), "GOLDEN PARACHUTE!")
	if knock:
		state = "hurt"
		st_t = 0
		vel = Vector2(signf(position.x - from_x + 0.01) * 1.6, -2.4)
	if hp <= 0:
		hp = 0
		state = "dead"
		st_t = 0
		main.player_died()


func _animate() -> void:
	spr.flip_h = face < 0
	spr.visible = not (inv > 0 and state != "dead" and (main.tick / 3) % 2 == 1)
	if charge_t >= CHARGE:
		spr.modulate = Color(1.8, 1.5, 0.5) if (main.tick / 4) % 2 == 0 else Color.WHITE
	elif state == "dash":
		spr.modulate = Color(0.7, 0.9, 1.6)
	else:
		spr.modulate = Color.WHITE
	if state == "hurt" or state == "dead":
		anim("hurt")
	elif state == "dash":
		anim("airpunch" if not on_ground else "punch2")
	elif state == "punch":
		if punch_air:
			anim("airpunch")
		else:
			anim("punch0" if st_t < 3 else ("punch1" if st_t < 9 else "punch2"))
	elif not on_ground:
		anim("rise" if vel.y < 0 else "fall")
	elif land_t > 0:
		anim("land")
	elif absf(vel.x) > 0.25:
		walk_d += absf(vel.x)
		anim("walk%d" % (int(walk_d / 3.0) % 8))
	else:
		walk_d = 0
		anim("idle%d" % ((main.tick / 30) % 2))
