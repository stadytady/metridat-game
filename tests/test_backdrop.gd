extends "res://tests/test_case.gd"
## The city around: its lanes run clear of every house, the houses stay off
## the reserved centre, and about half the lit windows' seeds come up lit.

const B := preload("res://scripts/world/backdrop.gd")


func test_lanes_run_clear_of_the_houses() -> void:
	var houses: Array = B.plan()
	check(houses.size() > 100, "a thin city: %d houses" % houses.size())
	var segs: Array = B.lanes(houses)
	check(segs.size() > 300, "few lanes: %d pieces" % segs.size())
	for s: Array in segs:
		for f: float in [0.0, 0.5, 1.0]:
			var p: Vector2 = (s[0] as Vector2).lerp(s[1], f)
			check(not B.on_house(houses, p.x, p.y, B.LANE_HALF), "lane under a house at %s" % p)
	# every house was nudged off the lane lines
	for hs: Dictionary in houses:
		for lz: float in B.LANES_Z:
			check(not B.on_house([hs], hs.pos.x, lz, B.LANE_HALF), "house at %s straddles the lane z=%.1f" % [hs.pos, lz])


func test_houses_keep_off_the_centre() -> void:
	for hs: Dictionary in B.plan():
		check(not Topo.in_house(hs.pos.x, hs.pos.y, 2.0), "house on the walk-in house's plot at %s" % hs.pos)


func test_about_half_the_windows_are_lit() -> void:
	var lit := 0
	for s in 400:
		if Arch.window_lit(s * 7919, 0):
			lit += 1
	check(lit > 150 and lit < 250, "lit windows: %d of 400" % lit)
