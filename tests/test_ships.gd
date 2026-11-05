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


## Anchored hulls sit in the sea with their laid decks above it, like the moored one.
func test_decks_stay_above_the_water() -> void:
	for s: Array in S.SHIPS:
		var a: Vector3 = s[3]
		var k := float(s[2])
		var water := Topo.SEA_LEVEL + Sea.height_at(a.x, a.z)
		var heave := Sea.float_pose(a, 0.0, 7.0 * k, 2.2 * k).x
		var deck := (S.WATERLINE + S.DECK_Y) * k + heave
		var keel := (S.WATERLINE + S.HULL_BOTTOM) * k + heave
		check(deck > water + 0.25 * k, "anchored ship deck under water: %.2f vs %.2f" % [deck, water])
		check(keel < water - 0.25 * k, "anchored ship floats on top: keel %.2f vs %.2f" % [keel, water])


func test_anchorages_in_deep_water_and_apart() -> void:
	for i in S.SHIPS.size():
		var a: Vector3 = S.SHIPS[i][3]
		check(Topo.terrain(a.x, a.z) < -3.0, "anchorage %d too shallow: %.1f" % [i, Topo.terrain(a.x, a.z)])
		check(a.x > Topo.waterline_x(a.z) + 30.0, "anchorage %d too close to the beach" % i)
		for j in range(i + 1, S.SHIPS.size()):
			var b: Vector3 = S.SHIPS[j][3]
			check(a.distance_to(b) > 25.0, "anchorages %d and %d overlap" % [i, j])


## The deck follows the hull: no strip of it hangs over a gunwale or past the stern.
func test_the_deck_stays_inside_the_hull() -> void:
	var ships := preload("res://scripts/world/ships.gd")
	check(ships.DECK_END < 8.5, "the deck runs past the hull's tip: %.2f" % ships.DECK_END)
	var x := 0.0
	while x <= ships.DECK_END:
		var deck := ships.deck_half_beam(x)
		var hull := ships.hull_half_beam(x)
		check(deck < hull, "at %.1f m the deck is %.2f wide, the hull %.2f" % [x, deck, hull])
		check(deck > hull - 0.45, "at %.1f m the deck leaves a %.2f m gap" % [x, hull - deck])
		x += 0.5