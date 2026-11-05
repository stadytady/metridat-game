extends "res://tests/test_case.gd"
## The pier: its deck stands clear of the sand and goes out over the water,
## the waterline walls go round it instead of across it, and the moored
## ship's hull keeps clear of the planks.

const N := preload("res://scripts/world/nature.gd")
const HB := preload("res://scripts/world/harbour.gd")


func test_deck_clears_the_sand_and_reaches_the_water() -> void:
	var x := Topo.pier_x0()
	while x <= Topo.pier_x1():
		for dz: float in [-Topo.PIER_HALF, 0.0, Topo.PIER_HALF]:
			check(Topo.terrain(x, Topo.PIER_Z + dz) < Topo.PIER_H - 0.2, "sand through the deck at x %.1f" % x)
		check(absf(Topo.surface(x, Topo.PIER_Z) - Topo.PIER_H) < 0.01, "deck height at x %.1f" % x)
		x += 0.5
	check(Topo.pier_x1() > Topo.waterline_x(Topo.PIER_Z) + 10.0, "the pier does not reach deep water")
	# psx_water: four waves, 1.08 m of amplitude, x1.7 shoaling, x1.25 choppy crests
	check(Topo.PIER_H > 1.08 * 1.7 * 1.25, "surf crests wash over the deck")
	check(Topo.terrain(Topo.pier_x0() - 1.0, Topo.PIER_Z) < Topo.PIER_H + 0.3, "a step up onto the pier the player cannot take")


func test_walls_go_round_the_pier() -> void:
	var inner := Rect2(Topo.pier_x0() + 0.2, Topo.PIER_Z - Topo.PIER_HALF + 0.2, Topo.pier_x1() - Topo.pier_x0() - 0.4, Topo.PIER_HALF * 2.0 - 0.4)
	var end_wall := false
	for w: Array in N.boundary_walls():
		var a: Vector3 = w[0]
		var b: Vector3 = w[1]
		for i in 41:
			var p := a.lerp(b, i / 40.0)
			check(not inner.has_point(Vector2(p.x, p.z)), "a wall crosses the pier at %s" % p)
		if absf(a.x - b.x) < 0.01 and a.x > Topo.pier_x1() and minf(a.z, b.z) < inner.position.y and maxf(a.z, b.z) > inner.end.y:
			end_wall = true
	check(end_wall, "no wall closes the end of the pier")


func test_ship_clear_of_the_deck() -> void:
	var s := HB.ship_pos()
	check(s.z + 2.45 < Topo.PIER_Z - Topo.PIER_HALF, "the hull rides over the planks")
	check(s.x + 8.0 <= Topo.pier_x1() + 0.5 and s.x - 8.0 > Topo.waterline_x(Topo.PIER_Z), "the ship is not alongside the pier in the water")


## Two things at once: the laid deck is dry and the hull is really in the sea.
## The model's own floor sits at its bottom, so the deck is what DECK_Y lays.
func test_ship_sits_in_the_water_with_a_dry_deck() -> void:
	var p := HB.ship_pos()
	var heave := Sea.float_pose(p, 0.0, 7.0, 2.2).x
	var water := Topo.SEA_LEVEL + Sea.height_at(p.x, p.z)
	var deck := p.y + HB.DECK_Y + heave
	var keel := p.y + HB.HULL_BOTTOM + heave
	check(deck > water + 0.25, "the sea runs over the deck: deck %.2f, water %.2f" % [deck, water])
	check(keel < water - 0.25, "the hull floats on top of the sea: keel %.2f, water %.2f" % [keel, water])
