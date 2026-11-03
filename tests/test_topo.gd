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
