extends "res://tests/test_case.gd"
## The porters' round and the pile on the pier keep clear of the way along it;
## the wheat stops at lamplight like the rest of the town's work.

const Q := preload("res://scripts/world/grain_quay.gd")


func test_porters_walk_the_pier_or_the_shore() -> void:
	for p: Vector2 in Q.porter_points():
		var on_pier := p.x >= Topo.pier_x0() and absf(p.y - Topo.PIER_Z) <= Topo.PIER_HALF
		check(on_pier or Topo.terrain(p.x, p.y) > 0.5, "porter point %s is in the sea" % p)
		if on_pier:
			# the north half: the middle is where people walk out to the ship
			check(p.y < Topo.PIER_Z - 0.6, "porter point %s is in the pier's middle" % p)


func test_porters_climb_on_at_the_root() -> void:
	# stepping from shingle to planks: no more than a step up, or he jumps a metre
	var pts := Q.porter_points()
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var n := int(ceil(a.distance_to(b) / 0.1))
		var prev := Topo.surface(a.x, a.y)
		for k in range(1, n + 1):
			var p := a.lerp(b, float(k) / n)
			var h := Topo.surface(p.x, p.y)
			check(absf(h - prev) < 0.45, "porter steps %.2f m between %s and %s" % [absf(h - prev), a, b])
			if absf(h - prev) >= 0.45:
				return
			prev = h


func test_pile_is_off_the_middle_and_on_the_planks() -> void:
	var off := absf(Q.PILE.y - Topo.PIER_Z)
	check(off + Q.PILE_SIZE.z / 2.0 <= Topo.PIER_HALF, "the pile hangs over the pier's edge")
	check(off - Q.PILE_SIZE.z / 2.0 >= 0.6, "the pile is in the way along the pier")
	check(Q.PILE.x - Q.PILE_SIZE.x / 2.0 > Topo.pier_x0() + 2.0, "the pile is at the pier's root")
	# short of the anchor stock and of the carrier's round on the far half
	check(Q.PILE.x + Q.PILE_SIZE.x / 2.0 < 75.0, "the pile reaches the anchor stock")
	var drop: Array = Q.PORTER_ROUTE[Q.PORTER_DROP]
	check(Vector2(drop[0], drop[1]).distance_to(Q.PILE) < 1.4, "the porter puts his sack down away from the pile")


func test_work_stops_at_lamplight() -> void:
	check(Q.at_work(DayCycle.LAMPS_ON - 0.01), "the porters stop before dusk")
	check(not Q.at_work(DayCycle.LAMPS_ON), "the porters still carry after the lamps are lit")


func test_seal_errand_is_listed() -> void:
	check(Quests.LIST.has("seal"), "no seal errand")
	check(String(Quests.LIST["seal"]["giver"]) == "measurer", "the seal errand has the wrong giver")
