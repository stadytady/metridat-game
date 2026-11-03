extends "res://tests/test_case.gd"
## Night omens: only at night, the wandering light keeps to deep water off the
## beach, the supper sits on the agora floor clear of the way in, and the
## figure stands on the street paving.

const O := preload("res://scripts/world/omens.gd")


func test_only_at_night() -> void:
	check(not O.is_night(0.0) and not O.is_night(0.875), "omens by day")
	check(O.is_night(1.0), "no omens at night")


func test_wisp_stays_over_the_strait() -> void:
	var shown := 0
	for i in 400:
		var t := i * 3.7
		var p := O.wisp_at(t)
		check(p.x > Topo.waterline_x(p.z) + 15.0, "light comes ashore at %s (t %.1f)" % [p, t])
		check(Topo.terrain(p.x, p.z) < 0.0, "light over land at %s" % p)
		if O.wisp_shown(t):
			shown += 1
	check(shown > 100 and shown < 380, "light never or always shown: %d/400" % shown)


func test_supper_on_the_agora_floor() -> void:
	check(Topo.in_rect(O.SUPPER.x, O.SUPPER.z, Topo.AGORA_CENTER, Topo.AGORA_HALF), "supper off the agora")
	check(absf(Topo.surface(O.SUPPER.x, O.SUPPER.z) - O.SUPPER.y) < 0.01, "supper floats or sinks")


func test_figure_on_the_street() -> void:
	var p := O.figure_point()
	check(absf(p.z - Topo.street_z(p.x)) < Topo.STREET_HALF, "figure off the paving")
	var slope := absf(Topo.street_height(p.x + 0.8) - Topo.street_height(p.x - 0.8)) / 1.6
	check(slope < Topo.STAIR_SLOPE, "figure stands on a stair")
