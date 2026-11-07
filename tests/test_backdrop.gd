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
