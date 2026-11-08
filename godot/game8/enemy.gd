## 8-bit enemies: bug (patrols), JIRA ticket (floats toward you), PM (throws tasks) and the
## stage 1 boss, the Team Leader (chase, task volleys, leap with shockwaves).
extends "res://game8/actor.gd"

var kind := ""
var hp := 2
var max_hp := 2
var dead := false
var gone := false
var st := "idle"
var st_t := 0
var knock := 0
var home := Vector2.ZERO
var phase := 0.0
var throws := 0


func setup(m, k: String, p: Vector2) -> void:
	main = m
	kind = k
	position = p
	home = p
	phase = randf() * TAU
	match k:
		"bug":
			w = 14
			h = 10
			hp = 2
			face = -1
			make_sprite("bug")
		"jira":
			w = 20
			h = 14
			hp = 2
			make_sprite("jira")
		"pm":
			w = 12
			h = 30
			hp = 3
			make_sprite("pm")
		"tl":
			w = 18
			h = 40
			hp = 24
			face = -1
			st = "intro"
			make_sprite("tl")
	max_hp = hp


func step() -> void:
	if inv > 0:
		inv -= 1
	blink_flash()
	st_t += 1
	var pl = main.player
	var ppos: Vector2 = pl.position
	match kind:
		"bug":
			if knock > 0:
				knock -= 1
				vel.x *= 0.9
			else:
				vel.x = face * 0.45
			vel.y = minf(vel.y + 0.22, 5)
			move_body()
			var at_lock: bool = main.lock.x > 0 and (position.x < main.lock.x + 8 and face < 0 or position.x > main.lock.y - 8 and face > 0)
			if knock == 0 and (hit_wall or at_lock or (on_ground and main.ground(position.x + face * 9 - 1, position.x + face * 9 + 1, position.y - 1, position.y + 3) == INF)):
				face = -face
			spr.flip_h = face < 0
			spr.frame = (main.tick / 8) % 2
		"jira":
			phase += 0.08
			var c := position + Vector2(0, -7)
			var target := home
			if pl.state != "dead" and c.distance_to(ppos + Vector2(0, -16)) < (260.0 if main.lock.x > 0 else 150.0):
				target = ppos + Vector2(0, -16)
			if knock > 0:
				knock -= 1
				vel *= 0.88
			else:
				vel = vel.lerp((target - c).normalized() * (0.55 if target != home else 0.3), 0.08)
				if target == home and c.distance_to(home) < 3:
					vel = Vector2.ZERO
			position += vel + Vector2(0, sin(phase) * 0.3)
		"pm":
			if knock > 0:
				knock -= 1
				vel.x *= 0.9
			else:
				vel.x = 0
			vel.y = minf(vel.y + 0.22, 5)
			move_body()
			face = 1 if ppos.x > position.x else -1
			spr.flip_h = face < 0
			var dx := absf(ppos.x - position.x)
			if knock > 0:
				anim("hurt")
			elif st == "throw":
				anim("throw0" if st_t < 12 else "throw1")
				if st_t == 12:
					main.throw_note(position + Vector2(face * 8, -24), ppos + Vector2(0, -16))
				if st_t > 26:
					st = "idle"
					st_t = 0
			else:
				anim("idle%d" % ((main.tick / 30) % 2))
				if st_t > 80 and dx < 230 and pl.state != "dead":
					st = "throw"
					st_t = 0
		"tl":
			_boss_step(ppos)


func _boss_step(ppos: Vector2) -> void:
	var mad := hp <= max_hp / 2
	vel.y = minf(vel.y + 0.22, 6)
	match st:
		"intro":
			face = -1
			vel.x = -0.8
			anim("walk%d" % ((main.tick / 4) % 8))
			if position.x < main.lock.y - 70:
				st = "taunt"
				st_t = 0
				main.say(position + Vector2(-30, -58), "QUICK SYNC?")
		"taunt":
			vel.x = 0
			anim("idle%d" % ((main.tick / 30) % 2))
			if st_t > 70:
				st = "chase"
				st_t = 0
		"chase":
			face = 1 if ppos.x > position.x else -1
			vel.x = face * (1.0 if mad else 0.7)
			anim("walk%d" % ((main.tick / 4) % 8))
			if st_t > (70 if mad else 100):
				st = "leap" if throws >= 1 else "throw"
				st_t = 0
		"throw":
			vel.x = 0
			face = 1 if ppos.x > position.x else -1
			var k := st_t % 30
			anim("throw0" if k < 12 else "throw1")
			if k == 12:
				for i in 3:
					main.throw_note(position + Vector2(face * 10, -34), ppos + Vector2(face * (i - 1) * 34, -10))
			if st_t >= (90 if mad else 60):
				throws += 1
				st = "chase"
				st_t = 0
		"leap":
			if st_t < 18:
				vel.x = 0
				anim("crouch")
			elif st_t == 18:
				vel.y = -5.6
				vel.x = clampf((ppos.x - position.x) / 48.0, -2.6, 2.6)
				main.sfx("jump")
			elif on_ground and st_t > 22:
				st = "land"
				st_t = 0
				vel.x = 0
				main.shockwave(position, mad)
				main.sfx("stomp")
				main.shake = 6
			else:
				anim("air")
		"land":
			vel.x = 0
			anim("land")
			if st_t > (30 if mad else 45):
				throws = 0
				st = "chase"
				st_t = 0
	move_body()
	position.x = clampf(position.x, main.lock.x + 12, main.lock.y - 12)
	spr.flip_h = face < 0


func hurt(dmg: int, dir: int) -> void:
	if inv > 0 or dead:
		return
	hp -= dmg
	flash = 8
	inv = 10 if kind == "tl" else 6
	main.sfx("punch")
	if kind != "tl":
		knock = 12
		vel.x = dir * 2.2
		if kind == "jira":
			vel = Vector2(dir * 3.0, -0.5)
		elif on_ground:
			vel.y = -1.5
	if hp <= 0:
		die()


func die() -> void:
	dead = true
	gone = true
	var c := position + Vector2(0, -h / 2)
	main.pop(c, kind == "tl")
	var n: int = {"bug": 3, "jira": 4, "pm": 6, "tl": 30}[kind]
	main.drop_coins(c, n)
	if kind == "jira":
		main.say(c + Vector2(-14, -12), "CLOSED!")
	elif kind == "pm":
		main.say(c + Vector2(-20, -24), "OUT OF OFFICE")
	main.sfx("enemyDie")
	if kind == "tl":
		main.boss_defeated()
