extends "res://tests/test_case.gd"
## The night watch on the town wall: a sentry on every tower roof looking out
## over the field; the post nearest the acropolis calls and the rest answer in
## turn; a sleeper is called again and answers late; fires and torches are lit
## only from the town's dusk. And the watchman's lantern throws its light down.

const W := preload("res://scripts/world/wall_watch.gd")
const B := preload("res://scripts/world/backdrop.gd")


func test_a_sentry_on_every_tower_looking_out() -> void:
	var ps := W.posts()
	var towers := B.wall_towers()
	check(ps.size() == towers.size() and ps.size() >= 8, "%d posts for %d towers" % [ps.size(), towers.size()])
	var ranks := {}
	for p: Dictionary in ps:
		var t: Vector3 = p.tower
		for k: String in ["stand", "fire"]:
			var at: Vector3 = p[k]
			check(is_equal_approx(at.y, t.y), "the %s of the post at %s is not on the roof (%.2f, roof %.2f)" % [k, t, at.y, t.y])
			check(absf(at.x - t.x) < B.TOWER_SIZE / 2.0 - 0.4 and absf(at.z - t.z) < B.TOWER_SIZE / 2.0 - 0.4,
					"the %s of the post at %s stands off the roof at %s" % [k, t, at])
		var stand: Vector3 = p.stand
		var fire: Vector3 = p.fire
		check(absf(stand.z) > absf(t.z) and absf(fire.z) < absf(t.z), "the sentry at %s does not stand on the field side, the fire on the town side" % t)
		var yaw: float = p.yaw
		var look := Vector3(-sin(yaw), 0, -cos(yaw))
		check(look.z * signf(t.z) > 0.99, "the sentry at %s looks into the town, not out over the field" % t)
		ranks[int(p.rank)] = true
	check(ranks.size() == ps.size() and ranks.has(0) and ranks.has(ps.size() - 1), "the posts' turns are not one each: %s" % [ranks.keys()])


## The roof the watch stands on is the roof the backdrop builds.
func test_the_towers_are_the_ones_built() -> void:
	var towers := B.wall_towers()
	check(towers.size() == 10, "%d towers on the wall" % towers.size())
	for t: Vector3 in towers:
		check(absf(absf(t.z) - B.WALL_Z) < 0.01, "a tower off the wall line at %s" % t)
		# the roof stands over the curtain on both sides, so the sentry is seen
		for dx: float in [-B.WALL_SEG, B.WALL_SEG]:
			if t.x + dx < B.WALL_X0 - 0.01:
				continue
			var curtain := maxf(Topo.terrain(t.x, t.z), Topo.terrain(t.x + dx, t.z)) + B.CURTAIN_UP
			check(t.y > curtain + 1.0, "the curtain at %s rises to %.2f, over the tower roof at %.2f" % [Vector2(t.x + dx * 0.5, t.z), curtain, t.y])
		check(t.y - Topo.terrain(t.x, t.z) < 12.0, "a tower at %s stands %.1f m tall" % [t, t.y - Topo.terrain(t.x, t.z)])


func test_the_post_by_the_acropolis_calls_and_the_rest_answer_in_turn() -> void:
	var ps := W.posts()
	var n := ps.size()
	var hill := Vector2(Topo.HILL_CENTER.x, Topo.HILL_CENTER.y)
	var first: Vector3 = ps.filter(func(p: Dictionary) -> bool: return int(p.rank) == 0)[0].tower
	for p: Dictionary in ps:
		var t: Vector3 = p.tower
		check(Vector2(t.x, t.z).distance_to(hill) >= Vector2(first.x, first.z).distance_to(hill) - 0.01,
				"the post at %s is nearer the acropolis than the one that calls" % t)
	# a round nobody sleeps in: everyone raises once, the caller first, then in rank order
	var r := 0
	check(W.sleeper(r, n) < 0, "someone sleeps in round 0")
	var last := -1.0
	for rank in n:
		var c := W.calls(r, rank, n)
		check(c.size() == 1, "post %d raises its torch %d times in a quiet round" % [rank, c.size()])
		check(c[0] > last, "post %d answers before post %d" % [rank, rank - 1])
		last = c[0]
		var up := W.relay_lift(c[0] + W.RAMP + W.HOLD * 0.5, rank, n)
		check(up > 0.99, "post %d does not hold its torch up (%.2f)" % [rank, up])
		check(W.relay_lift(c[0] - 0.1, rank, n) == 0.0, "post %d raises its torch before its turn" % rank)
		check(W.relay_lift(c[0] + W.HOLD + W.RAMP * 2.0 + 0.1, rank, n) == 0.0, "post %d never lowers its torch" % rank)
	check(last + W.HOLD + W.RAMP * 2.0 < W.RELAY_EVERY, "a round of answers runs into the next call")


func test_a_sleeper_is_called_again_and_answers_late() -> void:
	var n := W.posts().size()
	var sleepy := 0
	for r in range(0, 12):
		var s := W.sleeper(r, n)
		if s < 0:
			continue
		sleepy += 1
		check(s > 0 and s < n, "round %d: the caller itself sleeps (%d)" % [r, s])
		var called := W.calls(r, 0, n)
		check(called.size() == 2, "round %d: the caller does not call again for the sleeper" % r)
		var answers: Array[float] = []
		for rank in range(1, n):
			if rank != s:
				answers.append(W.calls(r, rank, n)[0])
		var late := W.calls(r, s, n)[0]
		check(late > called[1], "round %d: the sleeper answers before he is called again" % r)
		check(late > answers.max(), "round %d: the sleeper answers among the others" % r)
		# in his turn he is still dark
		var turn := W.RELAY_LEAD + float(s) * W.ANSWER + W.RAMP + 0.5
		check(W.relay_lift(float(r) * W.RELAY_EVERY + turn, s, n) == 0.0, "round %d: the sleeper raises his torch in his turn" % r)
		check(late + W.HOLD + W.RAMP * 2.0 < W.RELAY_EVERY, "round %d: the late answer runs into the next round" % r)
	check(sleepy >= 3 and sleepy <= 5, "%d sleepy rounds of 12" % sleepy)


func test_the_watch_lights_at_dusk_and_signals() -> void:
	var w: WallWatch = W.new()
	Engine.get_main_loop().root.add_child(w)
	w.step(DayCycle.LAMPS_ON - 0.05, 0.1)
	var dark_by_day := not w.lit and w.fires_lit() == 0
	w.step(DayCycle.LAMPS_ON, 0.1)
	var lit_at_dusk := w.lit and w.fires_lit() == w.fire_count() and w.fire_count() > 0
	var most := 0
	for k in 600:
		w.step(1.0, 0.05)
		most = maxi(most, w.raised())
	var clock := w.clock
	w.free()
	check(dark_by_day, "the watch burns its fires by day")
	check(lit_at_dusk, "the tower fires are dark at the town's dusk")
	check(most >= 1, "in %.0f s after dusk no torch went up" % clock)


func test_the_lantern_lights_the_ground_not_the_sky() -> void:
	var b: Node3D = B.new()
	var lantern: Node3D = b._lantern()
	var light: SpotLight3D = lantern.get_node("Light")
	var down := light.transform.basis * Vector3.FORWARD  # a spot shines down its -z
	check(down.y < -0.99, "the lantern shines %s, not down at his feet" % down)
	check(light.spot_angle < 80.0, "the lantern's cone is %.0f deg: it lights the walls as well" % light.spot_angle)
	check(light.spot_range >= 3.0, "the lantern lights only %.1f m" % light.spot_range)
	lantern.free()
	b.free()
