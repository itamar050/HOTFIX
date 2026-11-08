## Code Bro (8-bit): run, variable jump with coyote time and buffering, punch combo, air punch.
extends "res://game8/actor.gd"

const SPEED := 1.3
const GRAV := 0.22
const JUMP_V := 4.7
const FALL_MAX := 5.0

var hp := 8
var max_hp := 8
var state := "normal"  ## normal, punch, hurt, dead
var st_t := 0
var coyote := 0
var jbuf := 0
var air_jumps := 0
var land_t := 0
var walk_d := 0.0
var punch_air := false
var punch_hit: Array = []
var safe_pos := Vector2.ZERO
var god := false  ## demo autopilot: no damage


func setup(m, p: Vector2) -> void:
	main = m
	position = p
	safe_pos = p
	w = 12
	h = 30
	make_sprite("bro")


func step() -> void:
	var ix := int(main.btn("right")) - int(main.btn("left"))
	if main.pressed("jump"):
		jbuf = 7
	elif jbuf > 0:
		jbuf -= 1
	if on_ground:
		coyote = 7
		air_jumps = 1 if main.upgrades["sneakers"] > 0 else 0
	elif coyote > 0:
		coyote -= 1
	if inv > 0:
		inv -= 1
	if land_t > 0:
		land_t -= 1
	st_t += 1
	match state:
		"dead":
			vel.x = 0
		"hurt":
			vel.x = move_toward(vel.x, 0, 0.05)
			if (st_t > 16 and on_ground) or st_t > 40:
				state = "normal"
		"punch":
			if punch_air and not on_ground:
				vel.x = move_toward(vel.x, ix * SPEED, 0.12)
			else:
				vel.x = move_toward(vel.x, 0, 0.18)
			if st_t >= 3 and st_t <= 9:
				_punch_check()
			if main.pressed("punch") and st_t >= 9:
				_start_punch()
			elif st_t >= 15 or (punch_air and on_ground and st_t > 9):
				state = "normal"
		_:
			vel.x = move_toward(vel.x, ix * SPEED, 0.25 if on_ground else 0.16)
			if ix != 0:
				face = ix
			if main.pressed("punch"):
				_start_punch()
	if state != "dead" and state != "hurt" and jbuf > 0:
		if coyote > 0:
			vel.y = -JUMP_V
			coyote = 0
			jbuf = 0
			main.sfx("jump")
		elif air_jumps > 0:
			vel.y = -JUMP_V * 0.9
			air_jumps -= 1
			jbuf = 0
			main.sfx("jump")
	if not main.btn("jump") and vel.y < -1.6 and state != "hurt":
		vel.y = -1.6
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


func _start_punch() -> void:
	state = "punch"
	st_t = 0
	punch_hit = []
	punch_air = not on_ground
	main.sfx("whiff")


func punch_box() -> Rect2:
	# reaches from the chest down to the floor, so low enemies like bugs can be hit too
	return Rect2(position.x + (2 if face > 0 else -22), position.y - 30, 20, 29)


func _punch_check() -> void:
	var box := punch_box()
	for e in main.enemies:
		if e.dead or e in punch_hit:
			continue
		var r: Rect2 = e.rect()
		if box.intersects(r):
			punch_hit.append(e)
			e.hurt(1 + main.upgrades["keyboard"], face)
			main.hitstop = 3
			main.spark(Vector2(position.x + face * 18, box.position.y + 7))


func hurt(dmg: int, from_x: float, knock := true) -> void:
	if inv > 0 or state == "dead" or god:
		return
	hp -= dmg
	inv = 70
	main.sfx("hurt")
	main.shake = 4
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
	if state == "hurt" or state == "dead":
		anim("hurt")
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
