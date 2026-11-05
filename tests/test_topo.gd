extends "res://tests/test_case.gd"
## Layout invariants: walkable surfaces line up, nothing sits in the sea.


func test_street_is_continuous_and_walkable() -> void:
	for i in Topo.STREET.size() - 1:
		var a := Topo.STREET[i]
		var b := Topo.STREET[i + 1]
		var slope := absf(b.y - a.y) / Vector2(b.x - a.x, b.z - a.z).length()
		check(slope < tan(deg_to_rad(40.0)), "street segment %d too steep for the controller: %.2f" % [i, slope])
		check(b.x > a.x, "street must run west to east (segment %d)" % i)


func test_terrain_sits_below_paving() -> void:
	# Terrain must not poke through paved areas.
	for x in range(int(Topo.STREET[0].x), int(Topo.STREET[-1].x)):
		var z := Topo.street_z(x)
		check(Topo.terrain(x, z) <= Topo.street_height(x) + 0.01, "terrain above street at x=%d" % x)
	for p: Vector2 in [Topo.AGORA_CENTER, Topo.SANCT_CENTER, Topo.HILL_CENTER]:
		check(Topo.terrain(p.x, p.y) < Topo.surface(p.x, p.y), "terrain above paving at %s" % p)


func test_key_places_are_above_sea() -> void:
	for p: Vector2 in [Topo.AGORA_CENTER, Topo.SANCT_CENTER, Topo.HILL_CENTER]:
		check(Topo.surface(p.x, p.y) > 3.0, "%s too low" % p)
	check(Topo.terrain(120, 0) < Topo.SEA_LEVEL, "sea side must be under water")


func test_hill_overlooks_city() -> void:
	var sp := Topo.spawn_point()
	check(sp.y - Topo.AGORA_H > 15.0, "hilltop must stand well above the agora")


func test_waterline_is_where_land_meets_sea() -> void:
	# The sea shader foams along it, so it must sit on the real coast.
	for z in range(-200, 201, 25):
		var x := Topo.waterline_x(z)
		check(x > 30.0 and x < 200.0, "no waterline found at z=%d" % z)
		check(absf(Topo.terrain(x, z) - Topo.SEA_LEVEL) < 0.1, "terrain at waterline z=%d is %.2f" % [z, Topo.terrain(x, z)])
		check(Topo.terrain(x - 2.0, z) > Topo.SEA_LEVEL, "land side is wet at z=%d" % z)


func test_forecourt_meets_the_street_and_the_agora_flush() -> void:
	# at the agora's west edge the forecourt is the agora's height
	check(absf(Topo.forecourt_height(Topo.AGORA_CENTER.x - Topo.AGORA_HALF.x) - Topo.AGORA_H) < 0.01, "a step from the forecourt up to the agora")
	# along the street's edge it is the street's height at every x
	var x := Topo.FORECOURTS[0].position.x
	while x <= Topo.FORECOURTS[0].end.x:
		var edge := Topo.street_z(x) - Topo.STREET_HALF - 0.05
		check(absf(Topo.surface(x, edge) - Topo.street_height(x)) < 0.01, "a step from the street to the forecourt at x %.1f" % x)
		x += 0.5


func test_forecourt_paving_stands_above_the_earth() -> void:
	for r: Rect2 in Topo.FORECOURTS:
		for i in 7:
			for j in 7:
				# a hair inside the edges: 5.8 + 3.2 is not quite 9.0 in floats
				var x := r.position.x + 0.01 + (r.size.x - 0.02) * i / 6.0
				var z := r.position.y + 0.01 + (r.size.y - 0.02) * j / 6.0
				check(Topo.in_forecourt(x, z), "not in the forecourt at %.1f, %.1f" % [x, z])
				check(Topo.terrain(x, z) < Topo.surface(x, z) - 0.1, "the earth breaks through the forecourt at %.1f, %.1f" % [x, z])
