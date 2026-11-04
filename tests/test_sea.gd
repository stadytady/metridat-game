extends "res://tests/test_case.gd"
## The CPU copy of the waves: calm on the beach, bounded, moving with the
## clock; and a hull floated on it keeps its deck above the water.


func test_waves_calm_on_the_beach_and_bounded() -> void:
	var max_h := 0.0
	for i in 200:
		var t := i * 0.37
		check(absf(Sea.height_at(Topo.waterline_x(0.0) - 2.0, 0.0, t)) < 0.001, "waves on the sand")
		max_h = maxf(max_h, absf(Sea.height_at(Topo.waterline_x(10.0) + 20.0, 10.0, t)))
	check(max_h > 0.3, "no waves in the shallows: %.2f" % max_h)
	check(max_h < 1.08 * 1.7 * 1.25 + 0.01, "waves higher than the shader can make: %.2f" % max_h)
	check(Sea.height_at(120.0, 0.0, 1.0) != Sea.height_at(120.0, 0.0, 2.0), "the sea stands still")


func test_floating_hull_keeps_its_deck_dry() -> void:
	# a ship of scale 1: keel at WATERLINE (-1), deck at 1.25, hull 7 m either way of midships
	for p: Vector3 in [Vector3(85.0, 0, -10.9), Vector3(128.0, 0, 10.0), Vector3(240.0, 0, -55.0)]:
		for i in 120:
			var t := i * 0.53
			var f := Sea.float_pose(p, 0.0, 7.0, 2.2, t)
			var deck := -1.0 + f.x + 2.25
			for dx: float in [-7.0, 0.0, 7.0]:
				# the deck tilts with the pitch along the hull
				var deck_here := deck + tan(f.z) * dx
				check(Sea.height_at(p.x + dx, p.z, t) < deck_here - 0.3, "water over the deck at %s t %.1f" % [p + Vector3(dx, 0, 0), t])
