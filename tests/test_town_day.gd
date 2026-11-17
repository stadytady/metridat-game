extends "res://tests/test_case.gd"
## The town's day: the square full in the morning, thin at midday with two old
## men in the stoa's shade, the party after dark; the donkeys keep to the
## street's paving; the boats stay out on the water; the dolphins circle off the
## shore, under water most of the time and out of it in short leaps.

const T := preload("res://scripts/world/town_day.gd")


func test_the_square_follows_the_day() -> void:
	var all := T.MARKET_FOLK.size()
	check(T.market_folk(0.1) == all, "the morning square has %d of %d people" % [T.market_folk(0.1), all])
	check(T.market_folk(0.45) < T.market_folk(0.1) and T.market_folk(0.45) >= 1, "midday does not thin the square: %d" % T.market_folk(0.45))
	check(T.market_folk(0.6) > T.market_folk(0.45), "the square does not fill again towards evening")
	check(T.market_folk(DayCycle.LAMPS_ON) == 0, "people cross the square at night")
	check(not T.shade_sitters(0.1) and T.shade_sitters(0.45) and T.shade_sitters(0.6) and not T.shade_sitters(0.9),
			"the old men sit at the wrong hours")
	check(not T.party_at(0.6) and T.party_at(DayCycle.LAMPS_ON) and T.party_at(1.0) and not T.party_at(DayCycle.DREAM),
			"the party keeps the wrong hours")


func test_the_donkeys_keep_to_the_street() -> void:
	for s: Vector2 in T.DONKEY_STRETCH:
		var pts := T.street_stretch(s.x, s.y)
		check(pts.size() >= 10, "a donkey's stretch is %d points" % pts.size())
		for p: Vector3 in pts:
			check(absf(p.z - Topo.street_z(p.x)) < Topo.STREET_HALF - 0.6, "the donkey leaves the paving at %s" % p)
			check(is_equal_approx(p.y, Topo.surface(p.x, p.z)), "the donkey floats at %s" % p)


func test_the_boats_and_the_dolphins_keep_to_the_sea() -> void:
	for line: Array in T.BOATS:
		for p: Vector2 in line:
			check(p.x > Sea.shore_x(p.y) + 30.0, "a boat comes near the shore at %s" % p)
	var out := 0
	var steps := 0
	var t := 0.0
	while t < 30.0:
		for i in T.DOLPHINS:
			var s: Array = T.dolphin_at(i, t)
			var pos: Vector3 = s[0]
			check(pos.x > Sea.shore_x(pos.z) + 12.0, "a dolphin swims onto the beach at %s" % pos)
			check(Vector2(pos.x, pos.z).distance_to(T.POD) < T.POD_R + 4.0, "a dolphin leaves the pod at %s" % pos)
			if s[2]:
				out += 1
				check(pos.y > -0.3, "a leaping dolphin stays under water")
			else:
				check(pos.y < -1.0, "a dolphin under water shows at the surface")
			steps += 1
		t += 0.05
	var share := float(out) / float(steps)
	check(absf(share - T.DOLPHIN_LEAP / T.DOLPHIN_BEAT) < 0.05, "dolphins are out of the water %.0f%% of the time" % (share * 100.0))


func test_the_party_is_on_the_street() -> void:
	var hf: Array = T.house_front(T.SYMPOSIUM_X)
	var front: Vector3 = hf[0]
	var toward: Vector3 = hf[1]
	var street := Vector3(T.SYMPOSIUM_X, front.y, Topo.street_z(T.SYMPOSIUM_X))
	check(absf(front.distance_to(street) - (Topo.STREET_HALF + 0.2)) < 0.05, "the party's door is not on the street's edge")
	check((street - front).normalized().dot(toward) > 0.99, "the door faces away from the street")
