extends "res://tests/test_case.gd"
## The summit theatre: the seats stay on the terrace clear of the parapet and
## of the walk, each tier is a step a player can climb, and the mask stand
## keeps out of the way.

const T := preload("res://scripts/world/theatre.gd")


func _corners(b: Array) -> Array[Vector3]:
	var size: Vector3 = b[2]
	var basis := Basis(Vector3.UP, b[1])
	var out: Array[Vector3] = []
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			out.append(b[0] + basis * Vector3(size.x * sx, 0, size.z * sz))
	return out


func test_seats_on_the_terrace_inside_the_parapet() -> void:
	var blocks: Array = T.seat_blocks()
	check(blocks.size() >= T.TIERS * 8, "too few seat blocks: %d" % blocks.size())
	for b: Array in blocks:
		for p in _corners(b):
			# the parapet runs 0.3 inside the terrace edge and is 0.55 thick
			check(Topo.in_rect(p.x, p.z, Topo.HILL_CENTER, Topo.HILL_HALF - Vector2(1.0, 1.0)), "seat at %s over the parapet" % p)


func test_tiers_are_steps() -> void:
	check(T.TIER_RISE <= 0.3, "a tier is a wall, not a step: %.2f" % T.TIER_RISE)
	var heights := {}
	for b: Array in T.seat_blocks():
		heights[snappedf((b[2] as Vector3).y, 0.01)] = true
	check(heights.size() == T.TIERS, "tiers: %d heights" % heights.size())


func test_clear_of_the_walk() -> void:
	var c := Topo.HILL_CENTER
	var walk: Array[Vector2] = [Vector2(Topo.spawn_point().x, Topo.spawn_point().z), Vector2(c.x + 3.0, -4.6),
			Vector2(c.x + 3.0, -6.2), Vector2(c.x + Topo.HILL_HALF.x - 1.0, 0.0)]
	for b: Array in T.seat_blocks():
		for p in _corners(b):
			for w in walk:
				check(Vector2(p.x, p.z).distance_to(w) > 2.0, "seat at %s in the way at %s" % [p, w])
	for w in walk:
		check(T.STAND.distance_to(w) > 2.0, "mask stand in the way at %s" % w)
