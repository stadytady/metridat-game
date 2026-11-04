extends "res://tests/test_case.gd"
## The city on the slopes, built in terraces: the terrace streets follow the
## ground, every house fronts a street and none stands on another, the stepped
## lanes run downhill, lanes never pass under a house, and about half the
## lit windows' seeds come up lit.

const B := preload("res://scripts/world/backdrop.gd")


func test_terrace_streets_follow_the_ground() -> void:
	var runs: Array = B.streets()
	check(runs.size() >= B.TERRACES_X.size(), "few streets: %d" % runs.size())
	for r in B.TERRACES_X.size():
		var run: PackedVector2Array = runs[r]
		var hs := []
		for p in run:
			hs.append(Topo.terrain(p.x, p.y))
		hs.sort()
		# a contour street: its ends stay within a couple of metres of each other in height
		check(hs[-1] - hs[0] < 3.0, "terrace street %d climbs %.1f m" % [r, hs[-1] - hs[0]])


func test_stepped_lanes_run_downhill() -> void:
	for run: PackedVector2Array in B.stairs():
		check(Topo.terrain(run[0].x, run[0].y) > Topo.terrain(run[-1].x, run[-1].y) + 5.0, "a stepped lane that does not go down: %s" % run[0])


func test_houses_front_streets_and_keep_apart() -> void:
	var houses: Array = B.plan()
	check(houses.size() > 100, "a thin city: %d houses" % houses.size())
	var runs: Array = B.streets()
	for i in houses.size():
		var hs: Dictionary = houses[i]
		var front: Vector2 = hs.pos + Vector2(sin(hs.yaw), cos(hs.yaw)) * (hs.d / 2.0)
		check(B._dist_to(runs, front) < B.LANE_HALF + 1.2, "house at %s does not front a street" % hs.pos)
		var others := houses.slice(0, i) + houses.slice(i + 1)
		check(not B.on_house(others, hs.pos.x, hs.pos.y, -0.2), "house at %s stands in another" % hs.pos)
		check(not Topo.in_house(hs.pos.x, hs.pos.y, 2.0), "house on the walk-in house's plot at %s" % hs.pos)


func test_lanes_run_clear_of_the_houses() -> void:
	var houses: Array = B.plan()
	var segs: Array = B.lanes(houses)
	check(segs.size() > 300, "few lanes: %d pieces" % segs.size())
	for s: Array in segs:
		var m: Vector2 = ((s[0] as Vector2) + (s[1] as Vector2)) / 2.0
		check(not B.on_house(houses, m.x, m.y, B.LANE_HALF - 0.05), "lane under a house at %s" % m)


func test_about_half_the_windows_are_lit() -> void:
	var lit := 0
	for s in 400:
		if Arch.window_lit(s * 7919, 0):
			lit += 1
	check(lit > 150 and lit < 250, "lit windows: %d of 400" % lit)
