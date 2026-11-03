extends "res://tests/test_case.gd"
## Ships come in from the strait during the day and are at anchor by night:
## afternoon at the start (the trailer's ship stays where it was framed), night
## at the anchorage, only ever closer on the way, anchorages in deep water and
## apart from each other.

const S := preload("res://scripts/world/ships.gd")


func test_afternoon_at_sea_night_at_anchor() -> void:
	for s: Array in S.SHIPS:
		var start: Vector3 = s[0]
		var anchor: Vector3 = s[3]
		check(S.position_at(start, anchor, 0.0).is_equal_approx(start), "afternoon: at its start")
		check(is_equal_approx(S.heading_at(start, s[1], anchor, 0.0), s[1]), "afternoon: on its old heading")
		check(S.position_at(start, anchor, 1.0).is_equal_approx(anchor), "night: at anchor")
		check(S.position_at(start, anchor, DayCycle.DREAM).is_equal_approx(anchor), "the dream does not move them")
		var prev := INF
		for i in 41:
			var d := S.position_at(start, anchor, i / 40.0).distance_to(anchor)
			check(d <= prev + 1e-4, "a ship moves away from its anchorage at %.2f" % (i / 40.0))
			prev = d


func test_anchorages_in_deep_water_and_apart() -> void:
	for i in S.SHIPS.size():
		var a: Vector3 = S.SHIPS[i][3]
		check(Topo.terrain(a.x, a.z) < -3.0, "anchorage %d too shallow: %.1f" % [i, Topo.terrain(a.x, a.z)])
		check(a.x > Topo.waterline_x(a.z) + 30.0, "anchorage %d too close to the beach" % i)
		for j in range(i + 1, S.SHIPS.size()):
			var b: Vector3 = S.SHIPS[j][3]
			check(a.distance_to(b) > 25.0, "anchorages %d and %d overlap" % [i, j])
