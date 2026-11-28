extends "res://tests/test_case.gd"
## The town answers the weather: wet lingers after the rain and dries; people
## take cover at a shower and the harbour and the steppe give way to a storm;
## nobody changes in front of the player; the puddles lie on level paving, the
## stoa shelters people on its floor, the line minder stands on the planks; and
## everything goes back once it is dry.

const W := preload("res://scripts/world/weather.gd")
const WT := preload("res://scripts/world/weather_town.gd")
const TD := preload("res://scripts/world/town_day.gd")
const HARBOUR := preload("res://scripts/world/harbour.gd")
const LIFE := preload("res://scripts/world/life.gd")
const AGORA := preload("res://scripts/world/agora.gd")


## A walk whose afternoon brings a shower (and one a storm), found by kind.
func _seed(kind: int) -> int:
	for s in range(1, 5000):
		if W.kind(s) == kind:
			return s
	return -1


func test_wet_lingers_after_the_rain_and_dries() -> void:
	var dry := _seed(W.DRY)
	for i in 101:
		check(W.wet_at(i / 100.0, dry) == 0.0, "a dry walk is wet at %.2f" % (i / 100.0))
	var s := _seed(W.SHOWER)
	var peak := -1.0
	var last_rain := -1.0
	for i in 1001:
		var h := i / 1000.0
		var r := W.rain_at(h, s)
		check(W.wet_at(h, s) >= r - 1e-5, "drier than the rain falling at %.3f" % h)
		if r >= 0.999 and peak < 0.0:
			peak = h
		if r > 0.0:
			last_rain = h
	check(peak >= 0.0 and last_rain > 0.0, "the shower walk never rains")
	# just after the last drop it is still wet; DRY_AFTER later it is dry again
	check(W.wet_at(last_rain + 0.01, s) > 0.1, "the town dries the moment the rain stops")
	check(W.wet_at(last_rain + W.DRY_AFTER + 0.01, s) == 0.0, "the town never dries")
	var prev := INF
	var h2 := last_rain
	while h2 < last_rain + W.DRY_AFTER:
		var wv := W.wet_at(h2, s)
		check(wv <= prev + 1e-5, "it gets wetter after the rain at %.3f" % h2)
		prev = wv
		h2 += 0.005


func test_thresholds() -> void:
	check(not W.sheltering(Vector2(0.2, 0.0)) and W.sheltering(Vector2(0.5, 0.0)), "people take cover at the wrong rain")
	check(not W.storm_on(Vector2(1.0, 0.0)) and W.storm_on(Vector2(1.0, 0.8)), "a shower stops the harbour, or a storm does not")
	check(WT.puddle_scale(0.0) == 0.0 and WT.puddle_scale(0.5) > 0.0 and WT.puddle_scale(1.0) > WT.puddle_scale(0.5), "puddles do not follow the wet")
	check(WT.drip_level(1.0, 1.0) == 0.0 and WT.drip_level(0.0, 0.5) > 0.0, "drips while it pours, or none after")
	check(WT.roof_level(0.0) == 0.0 and WT.roof_level(1.0) > 0.0, "the roof drums in the dry")
	check(WT.market_db(1.0) < WT.market_db(0.0) - 6.0, "the market is as loud in the rain")
	check(WT.flock_spread(1.0) < 0.6 and is_equal_approx(WT.flock_spread(0.0), 1.0), "the flock does not draw together in the storm")
	check(WT.riders_out(Vector2.ZERO) and not WT.riders_out(Vector2(1.0, 0.0)), "the riders keep riding in the rain")
	check(WT.smoke_ratio(1.0) < WT.smoke_ratio(0.0), "the rain does not beat the smoke down")
	check(LIFE.washing_out(0.0) and not LIFE.washing_out(0.5), "the washing hangs out in the wet")
	check(HARBOUR.line_sag(1.0) < HARBOUR.line_sag(0.0) and is_equal_approx(HARBOUR.line_sag(0.0), HARBOUR.MOORING_SAG), "the lines are not hauled in for a storm")


func test_puddles_lie_on_level_paving_clear_of_things() -> void:
	var stall := Rect2(17.6, 5.4, 4.8, 2.2)
	var statue := Rect2(22.1, -0.4, 1.8, 1.8)
	var bench := Rect2(26.4, -2.5, 3.2, 1.0)
	var play := Vector2(26.0, -0.8)  # the children's game
	for p: Vector3 in WT.PUDDLES:
		# (x, z, radius)
		var y := Topo.surface(p.x, p.y)
		for d: Vector2 in [Vector2(p.z, 0), Vector2(-p.z, 0), Vector2(0, p.z), Vector2(0, -p.z)]:
			check(absf(Topo.surface(p.x + d.x, p.y + d.y) - y) < 0.05, "the puddle at %s lies on a slope" % p)
		var c := Vector2(p.x, p.y)
		for r: Rect2 in [stall, statue, bench]:
			check(not r.grow(p.z).has_point(c), "the puddle at %s runs under %s" % [p, r])
		check(c.distance_to(play) > p.z + 1.2, "the puddle at %s is in the children's game" % p)


func test_the_stoa_shelters_on_its_floor() -> void:
	check(TD.SHELTER_SPOTS.size() == TD.MARKET_FOLK.size(), "not everyone crossing the square has a place under cover")
	for s: Vector2 in TD.SHELTER_SPOTS:
		check(s.x > 12.9 and s.x < 31.1 and s.y < -5.7 and s.y > -9.8, "the shelter at %s is not inside the stoa" % s)
		for i in 6:
			var col := Vector2(12.7 + i * (20.0 - 1.4) / 5.0, -5.1)
			check(s.distance_to(col) > 0.8, "the shelter at %s is in a column" % s)
	for i in TD.SHELTER_SPOTS.size():
		for j in range(i + 1, TD.SHELTER_SPOTS.size()):
			check((TD.SHELTER_SPOTS[i] as Vector2).distance_to(TD.SHELTER_SPOTS[j]) > 1.0, "two people stand in one place in the stoa")


func test_the_line_minder_stands_on_the_planks() -> void:
	var m := HARBOUR.minder_pos()
	check(Topo.on_pier(m.x, m.z, -0.2), "the line minder stands in the sea at %s" % m)
	var sk := HARBOUR.skipper_pos()
	check(Vector2(m.x, m.z).distance_to(Vector2(sk.x, sk.z)) > 0.8, "the line minder stands on the skipper")
	for r: Array in HARBOUR.CARRIER_ROUTE:
		check(Vector2(m.x, m.z).distance_to(Vector2(r[0], r[1])) > 0.5 or not W.storm_on(Vector2(1, 1)), "the minder stands in the carrier's lane")
	check(AGORA.banner_wind(1.0).y > AGORA.banner_wind(0.0).y, "the storm does not hurry the cloth")


## The swap under cover waits for the player to look away: with a camera on a
## person, nothing changes; with it turned away, it does; and the hour still
## acts at once.
func test_nobody_changes_in_front_of_the_player() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(0, 1.6, 5)
	cam.look_at(Vector3(0, 1.0, 0))
	var n := Node3D.new()
	root.add_child(n)
	n.global_position = Vector3.ZERO
	check(not W.unseen(n), "a person right in front of the camera counts as unseen")
	check(not W.duty(n, true, true) and n.visible, "a person goes under cover in front of the player")
	check(not W.settle(n, false) and n.visible, "a thing is put away in front of the player")
	W.duty(n, false, true)
	check(not n.visible, "the hour waits for the player to look away")
	W.duty(n, true, false)
	check(n.visible, "back at work by the hour, not shown")
	cam.look_at(Vector3(0, 1.0, 20))  # turned round
	check(W.unseen(n), "a person behind the camera counts as seen")
	check(W.duty(n, true, true) and not n.visible, "out of view, nobody takes cover")
	check(not W.duty(n, true, false) and n.visible, "out of view, nobody comes back out")
	check(W.settle(n, false) and not n.visible, "out of view, nothing is put away")
	n.free()
	cam.free()


## The people on the square and in the stoa are one person each: whatever the
## weather and the hour, never both at once and never one out of hours.
func test_one_person_on_the_square_or_in_the_stoa() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var a: Npc = load("res://scripts/npc/npc.gd").new()
	var b: Npc = load("res://scripts/npc/npc.gd").new()
	a.talkable = false
	b.talkable = false
	root.add_child(a)
	root.add_child(b)
	for out: bool in [true, false]:
		for cover: bool in [true, false, true]:
			TD._shelter(a, b, out, cover)
			check(not (a.visible and b.visible), "on the square and in the stoa at once")
			check(out == (a.visible or b.visible), "out of hours, or nowhere in hours (out %s cover %s)" % [out, cover])
			if out:
				check(b.visible == cover, "under cover %s, in the stoa %s" % [cover, b.visible])
	a.free()
	b.free()
