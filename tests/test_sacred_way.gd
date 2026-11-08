extends "res://tests/test_case.gd"
## The way up to the sanctuary: no brazier stands on it (one of the square's
## corner braziers fell on the foot of the stair), the stair's own torches flank
## the steps, and the cypresses along the climb start on the lowest ground under
## them, not hanging over the downhill side.

const LAMPS := preload("res://scripts/world/lamps.gd")
const AGORA := preload("res://scripts/world/agora.gd")
const SANCT := preload("res://scripts/world/sanctuary.gd")


func test_no_brazier_stands_on_the_way_up() -> void:
	for p: Vector2 in AGORA.corner_fires(Topo.AGORA_CENTER, Topo.AGORA_HALF):
		var d := Topo.sanct_way_distance(p.x, p.y)
		check(d >= Topo.SANCT_WAY_CLEAR, "a corner brazier of the square stands %.2f m from the way at %s" % [d, p])
		check(Topo.in_rect(p.x, p.y, Topo.AGORA_CENTER, Topo.AGORA_HALF), "a corner brazier slid off the paving to %s" % p)


func test_the_stair_torches_flank_the_steps() -> void:
	# beside the steps, never over them
	var s0 := Topo.SANCT_STAIR[0]
	var s1 := Topo.SANCT_STAIR[1]
	var dir := Vector2(s1.x - s0.x, s1.z - s0.z).normalized()
	var torches := LAMPS.stair_torches()
	check(torches.size() == 4, "%d stair torches" % torches.size())
	for q: Vector3 in torches:
		var across := absf(Vector2(q.x - s0.x, q.z - s0.z).cross(dir))
		check(across > Topo.SANCT_STAIR_HALF + 0.3, "a stair torch at %s stands %.2f m off the axis: on the steps" % [q, across])


func test_the_cypresses_stand_on_the_ground() -> void:
	var trees := SANCT.climb_cypresses()
	check(trees.size() == 6, "%d cypresses along the climb" % trees.size())
	for c: Dictionary in trees:
		var p: Vector3 = c.pos
		var r := SANCT.CYPRESS_SPREAD * float(c.scale)
		for k in 8:
			var a := TAU * float(k) / 8.0
			var g := Topo.terrain(p.x + cos(a) * r, p.z + sin(a) * r)
			check(p.y < g, "a cypress at %s hangs %.2f m over the ground on its downhill side" % [p, p.y - g])
