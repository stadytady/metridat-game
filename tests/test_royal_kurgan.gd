extends "res://tests/test_case.gd"
## The Royal Kurgan on the steppe: the chamber keeps the real one's size and
## closes in a stepped dome, the dromos is 2.8 m wide and closes over the
## walker's head; the terrace is level under it; the earth never lies in the
## passage or the chamber, and the dome stands out of it; the edge of the map
## lets the player reach it; the porter keeps off the mound and the stone; and
## the kurgan does not crowd the steppe's own mounds, the flock or the town wall.

const K := preload("res://scripts/world/royal_kurgan.gd")
const STEPPE := preload("res://scripts/world/steppe.gd")
const NATURE := preload("res://scripts/world/nature.gd")


func test_the_chamber_is_the_real_size_and_closes() -> void:
	check(absf(K.CHAMBER_HALF * 2.0 - 4.39) < 0.06, "the chamber is %.2f m across, the real one 4.39" % (K.CHAMBER_HALF * 2.0))
	check(absf(K.chamber_height() - 8.84) < 0.1, "the dome is %.2f m high, the real one 8.84" % K.chamber_height())
	var prev := INF
	for i in K.CHAMBER_COURSES:
		var w := K.chamber_half(i)
		check(w <= prev + 1e-5, "course %d opens out again" % i)
		check(K.CHAMBER_OUT >= w + 0.5, "course %d is thinner than a block" % i)
		prev = w
	check(K.chamber_half(K.CHAMBER_COURSES - 1) <= 0.3, "the dome does not close: %.2f m open" % K.chamber_half(K.CHAMBER_COURSES - 1))
	# a corbel: no course reaches out more than a block can carry
	for i in range(1, K.CHAMBER_COURSES):
		check(K.chamber_half(i - 1) - K.chamber_half(i) <= 0.2, "course %d oversails by %.2f m" % [i, K.chamber_half(i - 1) - K.chamber_half(i)])
	check(K.DOOR_COURSES * K.COURSE > 2.0, "the doorway is too low to walk through")


func test_the_dromos_is_wide_and_closes_overhead() -> void:
	check(absf(K.DROMOS_HALF * 2.0 - 2.8) < 0.01, "the dromos is %.2f m wide, the real one 2.8" % (K.DROMOS_HALF * 2.0))
	var n := K.dromos_courses()
	check(K.dromos_half(n - 1) <= 0.3, "the dromos stays open overhead")
	# head room: at 1.9 m the walls have not closed in past a walker's shoulders
	check(K.dromos_half(int(1.9 / K.COURSE)) >= 0.9, "the dromos is too narrow at head height")
	check(K.dromos_height() > 6.0, "the dromos is not the tall narrow passage it should be")
	for i in range(1, n):
		check(K.dromos_half(i - 1) - K.dromos_half(i) <= 0.2, "dromos course %d oversails too far" % i)
	check(K.DROMOS_HALF > K.DOOR_HALF, "the doorway is wider than the dromos")


func test_the_terrace_is_level_under_the_tomb() -> void:
	var c := Topo.KURGAN_CENTER
	for p: Vector2 in [c, c + Vector2(K.FACADE_X, 0), c + Vector2(K.MOUND_R, 0), c + Vector2(-K.CHAMBER_OUT, K.CHAMBER_OUT), c + Vector2(K.MOUND_R * 0.7, -K.MOUND_R * 0.7)]:
		check(is_equal_approx(Topo.terrain(p.x, p.y), Topo.KURGAN_H), "the terrace is not level at %s: %.2f" % [p, Topo.terrain(p.x, p.y)])
	check(K.MOUND_R + 0.5 < Topo.KURGAN_PAD.x, "the mound and its cut run off the terrace")
	check(absf(Topo.natural(c.x, c.y) - Topo.KURGAN_H) < 1.5, "the terrace is cut %.1f m from the slope" % (Topo.natural(c.x, c.y) - Topo.KURGAN_H))


func test_the_earth_covers_the_tomb_and_opens_at_the_cut() -> void:
	var c := Topo.KURGAN_CENTER
	# the dromos and the chamber lie under the mound, its earth clear of their roofs
	var x := K.dromos_x0()
	while x <= K.dromos_x1():
		for dz: float in [-K.DROMOS_OUT, 0.0, K.DROMOS_OUT]:
			check(K.earth_height(c.x + x, c.y + dz) > K.dromos_height() + 0.2, "the dromos roof shows at %.1f, %.1f" % [x, dz])
		x += 0.5
	for dx: float in [-K.CHAMBER_OUT, 0.0, K.CHAMBER_OUT]:
		for dz: float in [-K.CHAMBER_OUT, 0.0, K.CHAMBER_OUT]:
			check(K.earth_height(c.x + dx, c.y + dz) > K.chamber_height() + 0.5, "the dome shows through the mound")
			check(K.inside(c.x + dx * 0.7, c.y + dz * 0.7), "the chamber is not inside")
	# the cut: an open floor from the front to the foot, low walls, steep banks
	x = K.FACADE_X
	while x <= K.MOUND_R:
		for dz: float in [-K.CUT_HALF + 0.05, 0.0, K.CUT_HALF - 0.05]:
			check(K.earth_height(c.x + x, c.y + dz) == 0.0, "earth in the cut at %.1f, %.1f" % [x, dz])
		check(K.earth_height(c.x + x, c.y + K.CUT_HALF + 0.5) <= K.CUT_WALL + 1.01, "the bank tops the cut wall at %.1f" % x)
		x += 0.5
	# the front reaches up to the mound's surface, over the mouth's full height
	check(K.facade_top() > K.dromos_height(), "the mouth is taller than the front it is in")
	check(K.earth_height(c.x - K.MOUND_R - 0.5, c.y) == 0.0, "the mound runs past its foot")
	check(K.MOUND_H > 10.0, "the mound is a hump, not a kurgan")
	check(K.covers(c.x, c.y) and K.covers(c.x + K.FACADE_X + 1.0, c.y), "the steppe's grass grows through the kurgan")


func test_the_map_reaches_the_kurgan() -> void:
	var walls: Array = NATURE.boundary_walls()
	var c := Topo.KURGAN_CENTER
	var footprint := Rect2(c.x - K.MOUND_R - 1.0, c.y - K.MOUND_R - 1.0, K.MOUND_R * 2.0 + 2.0, K.MOUND_R * 2.0 + 2.0).merge(
			Rect2(K.quarry_center() - K.quarry_half(), K.quarry_half() * 2.0))
	check(NATURE.POCKET_X < footprint.position.x and NATURE.POCKET_Z < footprint.position.y, "the map's edge cuts the kurgan off")
	for w: Array in walls:
		var a: Vector3 = w[0]
		var b: Vector3 = w[1]
		for t in 21:
			var p := a.lerp(b, t / 20.0)
			check(not footprint.grow(-0.5).has_point(Vector2(p.x, p.z)), "an edge wall runs through the kurgan at %s" % p)


func test_the_porter_keeps_off_the_mound() -> void:
	var pts: Array[Vector2] = K.porter_points()
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		for t in 11:
			var p := a.lerp(b, t / 10.0)
			check(K.earth_height(p.x, p.y) < 0.3, "the porter walks over the mound at %s" % p)
			check(not K.over_stone(Rect2(p - Vector2(0.3, 0.3), Vector2(0.6, 0.6))), "the porter walks through stone at %s" % p)
	var pile := Topo.KURGAN_CENTER + K.PILE
	check(pts[K.PORTER_DROP].distance_to(pile) < 1.6, "the porter puts his block down away from the pile")
	check(pts[K.PORTER_TAKE].distance_to(K.QUARRY) < 3.0, "the porter takes his block away from the quarry")


func test_it_keeps_clear_of_the_steppe_and_the_town() -> void:
	var c := Topo.KURGAN_CENTER
	for k: Array in STEPPE.KURGANS:
		var d := Vector2(k[0], k[1]).distance_to(c)
		check(d > K.MOUND_R + float(k[2]) + 1.0, "the Royal Kurgan sits on the mound at %s" % Vector2(k[0], k[1]))
	check(STEPPE.PASTURE.distance_to(c) > STEPPE.ROAM + K.MOUND_R, "the flock grazes over the mound")
	var q := K.quarry_center() + K.quarry_half()
	check(q.y < load("res://scripts/world/backdrop.gd").WALL_Z - 4.0, "the quarry runs into the town wall")
	check(K.quarry_center().x + K.quarry_half().x < load("res://scripts/world/park.gd").WALK_FROM - 4.0, "the quarry is in the park")


func test_the_workers_go_home_with_the_lamps() -> void:
	check(K.at_work(DayCycle.LAMPS_ON - 0.01), "the workers leave before dusk")
	check(not K.at_work(DayCycle.LAMPS_ON), "the workers stay out after dusk")
