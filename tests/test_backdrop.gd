extends "res://tests/test_case.gd"
## The city on the slopes, built in terraces: the terrace streets follow the
## ground, every house fronts a street and none stands on another, the stepped
## lanes run downhill, lanes never pass under a house, and about half the
## lit windows' seeds come up lit.

const B := preload("res://scripts/world/backdrop.gd")


func test_terrace_streets_follow_the_ground() -> void:
	var runs: Array = B.streets()
	check(runs.size() >= B.TERRACES_X.size(), "few streets: %d" % runs.size())
	for r in B.TERRACES_X.size():
		var run: PackedVector2Array = runs[r]
		var hs := []
		for p in run:
			hs.append(Topo.terrain(p.x, p.y))
		hs.sort()
		# a contour street: its ends stay within a couple of metres of each other in height
		check(hs[-1] - hs[0] < 3.0, "terrace street %d climbs %.1f m" % [r, hs[-1] - hs[0]])


func test_stepped_lanes_run_downhill() -> void:
	for run: PackedVector2Array in B.stairs():
		check(Topo.terrain(run[0].x, run[0].y) > Topo.terrain(run[-1].x, run[-1].y) + 5.0, "a stepped lane that does not go down: %s" % run[0])


func test_houses_front_streets_and_keep_apart() -> void:
	var houses: Array = B.plan()
	check(houses.size() > 100, "a thin city: %d houses" % houses.size())
	var runs: Array = B.streets()
	for i in houses.size():
		var hs: Dictionary = houses[i]
		var front: Vector2 = hs.pos + Vector2(sin(hs.yaw), cos(hs.yaw)) * (hs.d / 2.0)
		check(B._dist_to(runs, front) < B.LANE_HALF + 1.2, "house at %s does not front a street" % hs.pos)
		var others := houses.slice(0, i) + houses.slice(i + 1)
		check(not B.on_house(others, hs.pos.x, hs.pos.y, -0.2), "house at %s stands in another" % hs.pos)
		check(not Topo.in_house(hs.pos.x, hs.pos.y, 2.0), "house on the walk-in house's plot at %s" % hs.pos)


func test_lanes_run_clear_of_the_houses() -> void:
	var houses: Array = B.plan()
	var segs: Array = B.lanes(houses)
	check(segs.size() > 300, "few lanes: %d pieces" % segs.size())
	for s: Array in segs:
		var m: Vector2 = ((s[0] as Vector2) + (s[1] as Vector2)) / 2.0
		check(not B.on_house(houses, m.x, m.y, B.LANE_HALF - 0.05), "lane under a house at %s" % m)


func test_about_half_the_windows_are_lit() -> void:
	var lit := 0
	for s in 400:
		if Arch.window_lit(s * 7919, 0):
			lit += 1
	check(lit > 150 and lit < 250, "lit windows: %d of 400" % lit)


func test_lamps_flicker_out_of_step() -> void:
	# psx_lamp reads each window's phase from its vertex alpha
	var glow := MeshKit.new()
	for s in 40:
		Arch.house(MeshKit.new(), Transform3D(Basis(), Vector3(s * 10.0, 0, 0)), 6.0, 5.0, 4.0, {"seed": s * 7919, "windows": 2, "glow": glow})
	var mesh := glow.commit()
	check(mesh.get_surface_count() == 1, "no lit windows")
	var mat := mesh.surface_get_material(0) as ShaderMaterial
	check(mat != null and mat.shader.resource_path.ends_with("psx_lamp.gdshader"), "window glow is not lamplight")
	var phases := {}
	for c: Color in mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		phases[snappedf(c.a, 0.001)] = true
	check(phases.size() >= 20, "lamps pulse in step: %d phases" % phases.size())


## The things left by the walls: on the ground, against a house, and not in the
## walkable middle of the lane (a lane is 1.8 m wide and the goods stand in 0.42).
func test_wall_props_stand_on_the_ground_by_the_walls() -> void:
	var houses: Array = B.plan()
	var props: Array = B.wall_props(houses)
	check(props.size() > 25, "only %d things left by the walls" % props.size())
	for p: Dictionary in props:
		var at: Vector3 = p.pos
		check(absf(at.y - Topo.terrain(at.x, at.z)) < 0.01, "a %s floats at %s" % [p.kind, at])
		check(not B.on_house(houses, at.x, at.z, 0.0), "a %s stands inside a house at %s" % [p.kind, at])
		check(B._dist_to(B.streets(), Vector2(at.x, at.z)) > B.LANE_HALF - 0.35,
				"a %s blocks the lane at %s" % [p.kind, at])


## Herms at the crossings: always on the ground, never in either lane, never
## inside a wall.
func test_herms_stand_at_the_crossings() -> void:
	var houses: Array = B.plan()
	var herms: Array = B.crossing_herms(houses)
	check(herms.size() >= 8, "only %d herms at the crossings" % herms.size())
	for h: Dictionary in herms:
		var at: Vector3 = h.pos
		check(absf(at.y - Topo.terrain(at.x, at.z)) < 0.01, "a herm floats at %s" % at)
		check(not B.on_house(houses, at.x, at.z, 0.3), "a herm stands in a wall at %s" % at)
		check(B._dist_to(B.stairs(), Vector2(at.x, at.z)) > B.LANE_HALF + 0.3, "a herm blocks a stepped lane at %s" % at)
		check(B._dist_to(B.streets(), Vector2(at.x, at.z)) > B.LANE_HALF + 0.2, "a herm blocks a street at %s" % at)

## What is heard behind the walls comes from the walls: a voice stands at window
## height on a house front, there are several kinds of them, and not every house
## has one - a city where every wall sings is a haunted city.
func test_the_voices_stand_at_the_walls() -> void:
	var houses: Array = B.plan()
	var voices: Array = StreetVoices.placements(houses)
	check(voices.size() >= 8, "only %d voices in the back streets" % voices.size())
	check(voices.size() < houses.size() / 2, "%d voices for %d houses" % [voices.size(), houses.size()])
	var kinds := {}
	for v: Dictionary in voices:
		var at: Vector3 = v.pos
		var up := at.y - Topo.terrain(at.x, at.z)
		check(up > 1.0 and up < 2.2, "a %s hangs %.2f m up the wall at %s" % [v.kind, up, at])
		check(B.on_house(houses, at.x, at.z, StreetVoices.OUT + 0.4), "a %s is not at a wall (%s)" % [v.kind, at])
		check(StreetVoices.SOUNDS.has(v.kind), "a voice of kind %s has no sound" % v.kind)
		kinds[v.kind] = true
	check(kinds.size() >= 4, "only %d kinds of voice behind the walls" % kinds.size())

## The people on the terrace streets walk their own street: every point of a
## route lies on a lane (never through a house), the height is the ground's, and
## the route comes back to where it started.
func test_the_walkers_keep_to_their_streets() -> void:
	var houses: Array = B.plan()
	var routes: Array = B.walker_routes()
	check(routes.size() >= 4, "only %d walkers on the terrace streets" % routes.size())
	var lanes: Array = B.streets() + B.stairs()
	var streets := {}
	for r: Dictionary in routes:
		var points: Array[Vector3] = r.points
		check(points.size() >= 8, "%s has only %d waypoints" % [r.key, points.size()])
		if points.size() < 2:
			continue
		check(points[0].distance_to(points[-1]) < 0.6, "%s does not come back to its start" % r.key)
		var span := 0.0
		for i in points.size():
			var p := points[i]
			check(absf(p.y - Topo.surface(p.x, p.z)) < 0.05, "%s walks %.2f m off the ground at %s" % [r.key, p.y - Topo.surface(p.x, p.z), p])
			check(B._dist_to(lanes, Vector2(p.x, p.z)) < B.LANE_HALF + 0.6, "%s steps off the lane at %s" % [r.key, p])
			check(not B.on_house(houses, p.x, p.z, 0.0), "%s walks through a house at %s" % [r.key, p])
			if i > 0:
				var step := Vector2(points[i - 1].x - p.x, points[i - 1].z - p.z).length()
				check(step < 3.5, "%s jumps %.1f m in one waypoint" % [r.key, step])
				span += step
		check(span > 12.0, "%s only covers %.1f m" % [r.key, span])
		streets[snappedf(points[0].x, 1.0)] = true
	check(streets.size() >= 3, "the walkers share only %d streets" % streets.size())

## The porch scenes stand at the wall side of a lane, on the ground, in more than
## one kind, and each has somebody at it whose pose really exists.
func test_the_porches_hold_work_that_can_be_seen() -> void:
	var houses: Array = B.plan()
	var scenes: Array = B.porch_scenes(houses)
	check(scenes.size() >= 3, "only %d porch scenes" % scenes.size())
	var kinds := {}
	for s: Dictionary in scenes:
		var at: Vector3 = s.pos
		check(absf(at.y - Topo.surface(at.x, at.z)) < 0.01, "a %s stands off the ground at %s" % [s.kind, at])
		check(B.on_house(houses, at.x, at.z, B.PORCH_OUT + 0.5), "a %s stands away from its wall (%s)" % [s.kind, at])
		check(B._dist_to(B.streets(), Vector2(at.x, at.z)) > B.LANE_HALF - 0.45,
				"a %s blocks the lane at %s" % [s.kind, at])
		check(not Topo.is_reserved(at.x, at.z, 1.0), "a %s stands on the walked ground at %s" % [s.kind, at])
		kinds[s.kind] = true
	check(kinds.size() >= 5, "the porches only ever hold %d kinds of work" % kinds.size())
	check(scenes.size() >= 8, "only %d porch scenes in the back lanes" % scenes.size())
	# never down behind a terrace's retaining wall
	var walls: Array = B.terrace_walls(houses)
	check(not walls.is_empty(), "no retaining walls to keep clear of")
	for s: Dictionary in scenes:
		for p: Dictionary in B.porch_people(s):
			var d: float = B.terrace_wall_distance(walls, Vector2(p.pos.x, p.pos.z))
			check(d > 0.9, "someone at a %s sits %.2f m behind a retaining wall at %s" % [s.kind, d, p.pos])
		# beside the door, never on its threshold and steps
	for hs: Dictionary in houses:
		for s: Dictionary in scenes:
			var basis := Basis.from_euler(Vector3(0, hs.yaw, 0))
			var local: Vector3 = basis.inverse() * (s.pos - Vector3(hs.pos.x, s.pos.y, hs.pos.y))
			if absf(local.z - (hs.d / 2.0 + B.PORCH_OUT)) < 0.05 and absf(local.x) < hs.w / 2.0:
				check(absf(local.x - float(hs.opts.get("door_x", 0.0))) > 1.0, "a %s sits on a doorstep at %s" % [s.kind, s.pos])
	# the poses the scenes put people in must be real ones
	for pose: String in ["weave", "mender", "sit", "stoke", "sit_think", "think"]:
		check(Figure.POSES.has(pose), "no %s pose for the porch work" % pose)
		check(Figure.SEAT.has(pose), "the %s pose has no seat height" % pose)

## The people of the porches: on the ground at their own spot, workers turned
## to their work at the wall, the rest to the lane, the two neighbours to each
## other; whoever sits has a seat under them of the height the pose sits at.
func test_porch_people_face_their_work_and_sit_on_something() -> void:
	var houses: Array = B.plan()
	var faced_wall := 0
	for s: Dictionary in B.porch_scenes(houses):
		var out := Basis.from_euler(Vector3(0, float(s.yaw), 0)) * Vector3(0, 0, 1)
		var people: Array = B.porch_people(s)
		check(not people.is_empty(), "a %s scene with nobody at it" % s.kind)
		for p: Dictionary in people:
			var at: Vector3 = p.pos
			check(absf(at.y - Topo.surface(at.x, at.z)) < 0.01, "someone at a %s stands %.2f off the ground" % [s.kind, at.y - Topo.surface(at.x, at.z)])
			check(not B.on_house(houses, at.x, at.z, 0.0), "someone at a %s is inside a house at %s" % [s.kind, at])
			var yaw := B.face_yaw(at, p.faces)
			var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
			var want: Vector3 = (p.faces as Vector3) - at
			want.y = 0.0
			check(fwd.dot(want.normalized()) > 0.99, "someone at a %s looks away from what they face" % s.kind)
			if String(s.kind) in ["loom", "baskets", "quern"]:
				check(fwd.dot(out) < -0.9, "the %s worker has their back to the work" % s.kind)
				faced_wall += 1
			if String(s.kind) in ["child", "elder"]:
				check(fwd.dot(out) > 0.9, "the %s sits facing the wall" % s.kind)
			var sits := float(Figure.SEAT[String(p.pose)]) < 0.7 and String(p.pose) not in ["stoke", "sit"]
			check(not sits or float(p.seat) > 0.2, "a %s sits on air (pose %s, seat %.2f)" % [s.kind, p.pose, p.seat])
	check(faced_wall >= 3, "only %d workers at their work" % faced_wall)


## The distance to a retaining wall: on its face line it is nothing, a step
## off to the side it is that step, and past its end it is measured to the end.
func test_the_distance_to_a_retaining_wall() -> void:
	var walls: Array = B.terrace_walls(B.plan())
	check(walls.size() > 50, "only %d retaining walls along the terraces" % walls.size())
	var w: Dictionary = walls[0]
	var c: Vector2 = w.centre
	var t: Vector2 = w.along
	var n := Vector2(-t.y, t.x)
	var one := [w]
	check(B.terrace_wall_distance(one, c) < 0.001, "the wall's own centre is not on it")
	check(absf(B.terrace_wall_distance(one, c + n * 1.5) - 1.5) < 0.001, "1.5 m off the face reads %.2f" % B.terrace_wall_distance(one, c + n * 1.5))
	var past := c + t * (float(w.length) / 2.0 + 2.0)
	check(absf(B.terrace_wall_distance(one, past) - 2.0) < 0.001, "2 m past the end reads %.2f" % B.terrace_wall_distance(one, past))


## Each walker is someone of their own: no two look the same, some carry.
func test_the_walkers_are_neighbours_not_a_crowd() -> void:
	var looks := {}
	var loads := 0
	for r: Dictionary in B.walker_routes():
		var kind: Dictionary = B.WALKERS[int(r.kind) % B.WALKERS.size()]
		looks[str(kind.look)] = true
		if String(kind.load) != "":
			loads += 1
	check(looks.size() == B.walker_routes().size(), "%d walkers share %d looks" % [B.walker_routes().size(), looks.size()])
	check(B.walker_routes().size() >= 6, "only %d walkers on the terrace streets" % B.walker_routes().size())
	check(loads >= 3, "only %d walkers carry anything" % loads)


## The lamps of the back lanes hang on the plaster beside a door, a hand off the
## frame, at the height a lamp is carried - and there are enough of them to walk
## from one to the next, but not one on every wall.
func test_the_back_lanes_have_their_own_lamps() -> void:
	var houses: Array = B.plan()
	var lamps: Array = B.lane_lamps(houses)
	check(lamps.size() >= 6, "only %d lamps in the back lanes" % lamps.size())
	check(lamps.size() <= B.LANE_LAMPS_MAX, "%d lamps: more than the cap" % lamps.size())
	for l: Dictionary in lamps:
		var at: Vector3 = l.pos
		check(absf(at.y - Topo.surface(at.x, at.z)) < 0.01, "a lane lamp stands off the ground at %s" % at)
		check(B.on_house(houses, at.x, at.z, 0.5), "a lane lamp hangs off a wall at %s" % at)
		check(B._dist_to(B.streets(), Vector2(at.x, at.z)) > B.LANE_HALF - 0.3, "a lane lamp stands in the lane at %s" % at)

## The lane's own well: a second place to draw water, standing on the walkable
## ground of a terrace street, out of the houses, with its carrier beside it.
func test_the_lane_has_its_own_well() -> void:
	var houses: Array = B.plan()
	var spot: Dictionary = B.fountain_at(houses)
	check(not spot.is_empty(), "no free spot for the lane's well")
	if spot.is_empty():
		return
	var at: Vector3 = spot.pos
	check(absf(at.y - Topo.surface(at.x, at.z)) < 0.01, "the lane's well stands off the ground")
	check(not B.on_house(houses, at.x, at.z, 0.5), "the lane's well stands in a house at %s" % at)
	check(not Topo.is_reserved(at.x, at.z, 1.0), "the lane's well stands on the walked ground")
	check(B._dist_to(B.streets(), Vector2(at.x, at.z)) < B.LANE_HALF + 2.0, "the lane's well is not by a street at %s" % at)

## The animals of the back streets stand on the ground, out of the houses, and
## there is more than one kind of them.
func test_the_back_streets_have_their_animals() -> void:
	var houses: Array = B.plan()
	var spots: Array = B.animal_spots(houses)
	check(spots.size() >= 2, "only %d animal spots in the back streets" % spots.size())
	var kinds := {}
	for s: Dictionary in spots:
		var at: Vector3 = s.pos
		check(absf(at.y - Topo.surface(at.x, at.z)) < 0.01, "an animal stands off the ground at %s" % at)
		check(not B.on_house(houses, at.x, at.z, 0.2), "an animal stands inside a house at %s" % at)
		kinds[s.kind] = true
	check(kinds.size() >= 2, "the animals are all of one kind")


## The watchman paces a real stretch of street, on the ground, clear of walls.
func test_the_watchman_has_somewhere_to_pace() -> void:
	var houses: Array = B.plan()
	var route: Array[Vector3] = B.watch_route(houses)
	check(route.size() >= 2, "the watchman has nowhere to walk")
	for p: Vector3 in route:
		check(absf(p.y - Topo.surface(p.x, p.z)) < 0.01, "the watchman walks off the ground at %s" % p)
		check(not B.on_house(houses, p.x, p.z, 0.4), "the watchman walks through a wall at %s" % p)
	if route.size() >= 2:
		check(route[0].distance_to(route[1]) > 4.0, "the watchman paces only %.1f m" % route[0].distance_to(route[1]))
