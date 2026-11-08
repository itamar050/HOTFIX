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
var frozen := 0  ## hit by an OOO note: out of office, does nothing
var move_i := 0  ## boss: index into PATTERN
var hops := 0
const PATTERN := ["review", "standup", "sprint"]
const CALLS := {"review": "CODE REVIEW!", "standup": "STANDUP!", "sprint": "SPRINT!"}


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
		"blocker":
			w = 20
			h = 14
			hp = 4
			make_sprite("blocker")
		"pm":
			w = 12
			h = 30
			hp = 3
			make_sprite("pm")
		"tl", "gl":
			w = 34
			h = 60
			hp = 30 if k == "tl" else 36
			face = -1
			st = "intro"
			make_sprite(k)
	max_hp = hp


func step() -> void:
	if inv > 0:
		inv -= 1
	blink_flash()
	if frozen > 0:
		frozen -= 1
		if flash == 0:
			spr.modulate = Color(0.65, 0.6, 1.3)
		return
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
		"jira", "blocker":
			phase += 0.08
			var c := position + Vector2(0, -7)
			var target := home
			if pl.state != "dead" and c.distance_to(ppos + Vector2(0, -16)) < (260.0 if main.lock.x > 0 else 150.0):
				target = ppos + Vector2(0, -16)
			if knock > 0:
				knock -= 1
				vel *= 0.88
			else:
				var spd := (0.8 if kind == "blocker" else 0.55) if target != home else 0.3
				vel = vel.lerp((target - c).normalized() * spd, 0.08)
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
		"gl":
			_gl_step(ppos)


## Team Leader: a fixed, learnable loop. Every attack is announced by name and has its own
## wind-up pose (the tell), then the attack, then a short recovery:
##   CODE REVIEW!  arm raised -> a fan of 5 tasks along fixed arcs (same gaps every time)
##   STANDUP!      crouch -> 2 leaps at you, each landing sends shockwaves along the floor
##   SPRINT!       lean back -> charge across the room into the wall -> dizzy (punish window)
## Below half health the same loop runs faster (shorter tells, 3 leaps, a second fan).
func _boss_step(ppos: Vector2) -> void:
	var mad := hp <= max_hp / 2
	var tell := 28 if mad else 42
	vel.y = minf(vel.y + 0.22, 6)
	match st:
		"intro":
			face = -1
			vel.x = -0.8
			anim("walk%d" % ((main.tick / 5) % 8))
			if position.x < main.lock.y - 90:
				st = "taunt"
				st_t = 0
				main.say(position + Vector2(-30, -78), "QUICK SYNC?")
		"taunt":
			vel.x = 0
			anim("idle%d" % ((main.tick / 30) % 2))
			if st_t > 80:
				_next_move()
		"walk":
			face = 1 if ppos.x > position.x else -1
			vel.x = face * (0.9 if mad else 0.6)
			anim("walk%d" % ((main.tick / 5) % 8))
			if st_t > (30 if mad else 50):
				st = PATTERN[move_i]
				move_i = (move_i + 1) % PATTERN.size()
				st_t = 0
				hops = 0
				throws = 0
				main.callout(CALLS[st], tell)
				main.sfx("warn")
		"review":
			vel.x = 0
			if st_t < tell:
				face = 1 if ppos.x > position.x else -1
				anim("throw0")
				_tell_glow()
			else:
				var k := (st_t - tell) % 40
				anim("throw1" if k < 14 else "throw0")
				if k == 0:
					for i in 5:
						main.throw_fan(position + Vector2(face * 22, -56), face, i)
					main.sfx("throw")
					throws += 1
				if k == 39 and throws >= (2 if mad else 1):
					_next_move()
		"standup":
			if st_t < tell and hops == 0:
				vel.x = 0
				anim("crouch")
				_tell_glow()
			elif st_t == tell or (hops > 0 and st_t == 1):
				face = 1 if ppos.x > position.x else -1
				vel.y = -6.2
				vel.x = clampf((ppos.x - position.x) / 54.0, -3.0, 3.0)
				main.sfx("jump")
			elif on_ground and st_t > 4:
				vel.x = 0
				anim("land")
				if st_t < 1000:
					hops += 1
					main.shockwave(position, mad)
					main.sfx("stomp")
					main.shake = 7
					st_t = 1000
				elif st_t > 1000 + (14 if mad else 22):
					if hops < (3 if mad else 2):
						st_t = 0
					else:
						_next_move()
			else:
				anim("air")
		"sprint":
			if st_t < tell:
				vel.x = 0
				face = 1 if ppos.x > position.x else -1
				anim("dash0")
				_tell_glow()
				if st_t % 6 == 0:
					main.dust(position + Vector2(-face * 16, 0))
			else:
				vel.x = face * (4.2 if mad else 3.4)
				anim("dash%d" % ((main.tick / 4) % 2))
				if main.tick % 4 == 0:
					main.dust(position + Vector2(-face * 16, 0))
				if (face < 0 and position.x <= main.lock.x + 20) or (face > 0 and position.x >= main.lock.y - 20):
					st = "dizzy"
					st_t = 0
					vel.x = -face * 1.5
					vel.y = -2.5
					main.shake = 10
					main.sfx("explode")
					main.say(position + Vector2(-12, -76), "BONK!")
		"dizzy":
			vel.x = move_toward(vel.x, 0, 0.08)
			anim("dizzy%d" % ((main.tick / 12) % 2))
			main.stars(position + Vector2(0, -64))
			if st_t > (80 if mad else 120):
				_next_move()
	move_body()
	position.x = clampf(position.x, main.lock.x + 20, main.lock.y - 20)
	spr.flip_h = face < 0


## Wind-up tell: pulse red (a hit flash is white, so the two never look alike).
func _tell_glow() -> void:
	if flash == 0:
		spr.modulate = Color(1.7, 0.6, 0.55) if (st_t / 5) % 2 == 0 else Color.WHITE


## Group Leader: the same template, a fixed loop of three named attacks with tells:
##   ALL HANDS!   arms up -> summons bugs and a JIRA ticket (capped)
##   SLIDE DECK!  arm back -> 3 slides skid along the floor at you (jump them)
##   REORG!       crouch -> jumps out of the screen, ceiling tiles fall (red marks first),
##                then he crashes down where INCOMING flashes and gets STUCK (punish window)
const GL_PATTERN := ["allhands", "slides", "reorg"]
const GL_CALLS := {"allhands": "ALL HANDS!", "slides": "SLIDE DECK!", "reorg": "REORG!"}


func _gl_step(ppos: Vector2) -> void:
	var mad := hp <= max_hp / 2
	var tell := 28 if mad else 42
	var do_move := true
	vel.y = minf(vel.y + 0.22, 7)
	match st:
		"intro":
			face = -1
			vel.x = -0.8
			anim("walk%d" % ((main.tick / 5) % 8))
			if position.x < main.lock.y - 90:
				st = "taunt"
				st_t = 0
				main.say(position + Vector2(-40, -78), "LET'S CIRCLE BACK.")
		"taunt":
			vel.x = 0
			anim("idle%d" % ((main.tick / 30) % 2))
			if st_t > 80:
				_next_move()
		"walk":
			face = 1 if ppos.x > position.x else -1
			vel.x = face * (0.8 if mad else 0.55)
			anim("walk%d" % ((main.tick / 5) % 8))
			if st_t > (30 if mad else 50):
				st = GL_PATTERN[move_i]
				move_i = (move_i + 1) % GL_PATTERN.size()
				st_t = 0
				throws = 0
				main.callout(GL_CALLS[st], tell)
				main.sfx("warn")
		"allhands":
			vel.x = 0
			anim("cast")
			if st_t < tell:
				_tell_glow()
			elif st_t == tell:
				main.summon(4 if mad else 3)
				main.shake = 4
			elif st_t > tell + 50:
				_next_move()
		"slides":
			vel.x = 0
			face = 1 if ppos.x > position.x else -1
			if st_t < tell:
				anim("throw0")
				_tell_glow()
			else:
				var k := (st_t - tell) % 40
				anim("throw1" if k < 14 else "throw0")
				if k == 0:
					main.slide(position + Vector2(face * 24, 0), face, mad)
					main.sfx("throw")
					throws += 1
				if k == 39 and throws >= (4 if mad else 3):
					_next_move()
		"reorg":
			vel.x = 0
			if st_t < tell:
				anim("crouch")
				_tell_glow()
			else:
				vel.y = -9.0
				st = "reorg_up"
				st_t = 0
				main.sfx("jump")
		"reorg_up":
			anim("air")
			vel.y = -9.0  # straight up and out of the screen
			if position.y < -30:
				st = "reorg_wait"
				st_t = 0
		"reorg_wait":
			do_move = false
			position.y = -120
			vel = Vector2.ZERO
			var n := 6 if mad else 4
			if st_t % 20 == 1 and st_t < n * 20:
				main.drop_tile(ppos.x + randf_range(-30, 30))
			if st_t > n * 20 + 20:
				position.x = clampf(ppos.x, main.lock.x + 24, main.lock.y - 24)
				main.mark_landing(position.x, 50)
				st = "reorg_fall"
				st_t = 0
		"reorg_fall":
			anim("air")
			if st_t < 50:
				do_move = false
				position.y = -120
				vel = Vector2.ZERO
			else:
				vel.y = 8.0
			if on_ground:
				st = "stuck"
				st_t = 0
				main.shockwave(position, mad)
				main.shake = 9
				main.sfx("stomp")
				main.say(position + Vector2(-40, -76), "STUCK IN A MEETING!")
		"stuck":
			vel.x = 0
			anim("stuck%d" % ((main.tick / 14) % 2))
			main.stars(position + Vector2(0, -58))
			if st_t > (80 if mad else 120):
				_next_move()
	if do_move:
		move_body()
	position.x = clampf(position.x, main.lock.x + 20, main.lock.y - 20)
	spr.flip_h = face < 0


func is_boss() -> bool:
	return kind == "tl" or kind == "gl"


func _next_move() -> void:
	st = "walk"
	st_t = 0


## Contact damage: not while dizzy (the punish window) or before the fight starts.
func harmful() -> bool:
	if dead or frozen > 0:
		return false
	if kind == "tl":
		return st in ["walk", "standup", "sprint", "review"]
	if kind == "gl":
		return position.y > 0 and st in ["walk", "allhands", "slides", "reorg", "reorg_fall"]
	return true


func hurt(dmg: int, dir: int) -> void:
	if inv > 0 or dead:
		return
	if is_boss() and st in ["dizzy", "stuck"]:
		dmg *= 2  # the punish window: learning the pattern pays off
		main.say(position + Vector2(-14, -70 - (main.tick % 3) * 4), "CRIT X2")
	hp -= dmg
	flash = 8
	inv = 10 if is_boss() else 6
	main.sfx("punch")
	if not is_boss():
		knock = 12
		vel.x = dir * 2.2
		if kind == "jira" or kind == "blocker":
			vel = Vector2(dir * 3.0, -0.5)
		elif on_ground:
			vel.y = -1.5
	if hp <= 0:
		die()


func die() -> void:
	dead = true
	gone = true
	var c := position + Vector2(0, -h / 2)
	main.pop(c, is_boss())
	var n: int = {"bug": 3, "jira": 4, "blocker": 6, "pm": 6, "tl": 30, "gl": 36}[kind]
	if main.has("bounty"):
		n = int(ceil(n * 1.5))
	if kind == "pm" and randf() < 0.35:
		main.add_item("ooo", Vector2(c.x, position.y), true)
	main.drop_coins(c, n)
	if kind == "jira":
		main.say(c + Vector2(-14, -12), "CLOSED!")
	elif kind == "blocker":
		main.say(c + Vector2(-28, -12), "BLOCKER RESOLVED!")
	elif kind == "pm":
		main.say(c + Vector2(-20, -24), "OUT OF OFFICE")
	elif kind == "tl":
		main.say(c + Vector2(-40, -40), "FINE, I'LL APPROVE IT")
	elif kind == "gl":
		main.say(c + Vector2(-40, -40), "LET'S TAKE IT OFFLINE...")
	main.sfx("enemyDie")
	if is_boss():
		main.boss_defeated()
