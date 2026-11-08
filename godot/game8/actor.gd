## Base for everything that moves in the 8-bit game: feet-anchored position, an AABB, simple
## tile-free physics against the level's solids, floor and one-way platforms.
extends Node2D

const SD = preload("res://game8/sprite_data.gd")

var main
var vel := Vector2.ZERO
var w := 12.0
var h := 30.0
var on_ground := false
var hit_wall := false
var face := 1
var spr: Sprite2D
var frames: Array = []
var flash := 0
var inv := 0


func make_sprite(sheet: String) -> void:
	var d: Dictionary = SD.SHEETS[sheet]
	spr = Sprite2D.new()
	spr.texture = load("res://game8/art/%s.png" % sheet)
	spr.hframes = d["frames"].size()
	spr.centered = false
	spr.offset = Vector2(-int(d["w"]) / 2, -int(d["foot"]))
	frames = d["frames"]
	add_child(spr)


func anim(n: String) -> void:
	var i := frames.find(n)
	if i >= 0:
		spr.frame = i


func rect() -> Rect2:
	return Rect2(position.x - w / 2.0, position.y - h, w, h)


func move_body() -> void:
	hit_wall = false
	position.x += vel.x
	for s in main.solids:
		var r: Rect2 = s
		if rect().intersects(r):
			if vel.x > 0:
				position.x = r.position.x - w / 2.0
			elif vel.x < 0:
				position.x = r.end.x + w / 2.0
			hit_wall = true
	var prev := position.y
	position.y += vel.y
	on_ground = false
	if vel.y >= 0:
		var g: float = main.ground(position.x - w / 2.0 + 1, position.x + w / 2.0 - 1, prev, position.y)
		if g < INF:
			position.y = g
			vel.y = 0
			on_ground = true
	else:
		for s in main.solids:
			var r: Rect2 = s
			if rect().intersects(r):
				position.y = r.end.y + h
				vel.y = 0


func blink_flash() -> void:
	if flash > 0:
		flash -= 1
		spr.modulate = Color(8, 8, 8) if flash % 2 == 0 else Color.WHITE
	else:
		spr.modulate = Color.WHITE
