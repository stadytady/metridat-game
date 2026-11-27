extends "res://tests/test_case.gd"
## The ship that comes in to the pier: she goes through every stage in order and
## ends alongside, always in water deep enough for her keel and clear of the
## Swallow and the ships riding at anchor; her lines and gangway land on the
## pier; the dockers keep to the planks and the beach, off the cargo, the
## carrier's lane, the skipper and the way along the middle; and work stops at
## lamplight.

const A := preload("res://scripts/world/arrival.gd")
const HARBOUR := preload("res://scripts/world/harbour.gd")
const SHIPS := preload("res://scripts/world/ships.gd")


func _clock() -> Array:
	# sighted at 0, called in on the stand-off a minute after she gets there
	var c := A.SAIL_IN + 60.0
	var out := []
	var s := -5.0
	while s < c + A.UNLOAD_AT + 30.0:
		out.append([s, A.pose(s, c)])
		s += 0.5
	return out


func test_she_goes_through_every_stage_in_order() -> void:
	var last := -1
	var seen := {}
	for e: Array in _clock():
		var st: int = e[1].stage
		check(st >= last, "the stage goes back from %d to %d at %.1f s" % [last, st, e[0]])
		last = st
		seen[st] = true
	for st: int in [A.Stage.HIDDEN, A.Stage.INBOUND, A.Stage.LYING_TO, A.Stage.BERTHING, A.Stage.MOORED]:
		check(seen.has(st), "she never reaches stage %d" % st)
	var end: Dictionary = A.pose(A.SAIL_IN + 1000.0, A.SAIL_IN)
	check(end.stage == A.Stage.MOORED and (end.pos as Vector3).is_equal_approx(A.berth()), "she does not end at her berth")
	check(end.furl == 1.0 and end.lines == 1.0 and end.taut == 1.0 and end.gangway == 1.0 and end.unload > 0.0,
			"alongside, her sail is not furled or her lines and gangway not in place: %s" % end)
	# never called: she lies off and does not creep in
	check(A.pose(A.SAIL_IN + 500.0, -1.0).stage == A.Stage.LYING_TO, "uncalled, she comes in anyway")


## No jump from one half second to the next: she sails, she does not teleport.
func test_she_moves_smoothly_and_slows_to_the_berth() -> void:
	var prev: Dictionary = {}
	for e: Array in _clock():
		var p: Dictionary = e[1]
		if not prev.is_empty() and prev.stage != A.Stage.HIDDEN:
			var d := (p.pos as Vector3).distance_to(prev.pos)
			check(d < 2.5, "she jumps %.2f m at %.1f s" % [d, e[0]])
			check(absf(angle_difference(deg_to_rad(p.yaw), deg_to_rad(prev.yaw))) < 0.05, "she spins at %.1f s" % e[0])
			check(p.furl >= prev.furl - 1e-5, "her sail is set again at %.1f s" % e[0])
		prev = p
	# the last second of the glide is a crawl
	var c := A.SAIL_IN
	var a: Vector3 = A.pose(c + A.GLIDE - 1.0, c).pos
	check(a.distance_to(A.berth()) < 0.1, "she comes alongside at speed (%.2f m in the last second)" % a.distance_to(A.berth()))


## Her keel, bow and stern stay over water deeper than she draws all the way
## in, and at the berth her side is off the pier's edge.
func test_she_keeps_to_deep_water() -> void:
	var c := A.SAIL_IN + 10.0
	var s := 0.0
	while s < c + A.GLIDE + 1.0:
		var p: Dictionary = A.pose(s, c)
		var pos: Vector3 = p.pos
		var yaw := deg_to_rad(p.yaw)
		var fwd := Vector3(cos(yaw), 0, -sin(yaw))
		for k: float in [-7.5, 0.0, 7.5]:
			var q := pos + fwd * k
			check(Topo.terrain(q.x, q.z) < A.WATERLINE - 0.3, "she runs aground at %s (%.1f s)" % [q, s])
		s += 2.0
	var inner := A.berth().z - A.ship_hull_half_beam(0.0)
	check(inner > Topo.PIER_Z + Topo.PIER_HALF + 0.8, "her side is against the pier: %.2f" % inner)
	check(A.berth().z - HARBOUR.ship_pos().z > 4.0 * A.ship_hull_half_beam(0.0), "she lies on the Swallow")


## Her way in passes no ship at anchor closer than a hull and a half.
func test_she_keeps_clear_of_the_anchorage() -> void:
	var c := A.SAIL_IN
	var s := 0.0
	while s < c + A.GLIDE:
		var pos: Vector3 = A.pose(s, c).pos
		for sh: Array in SHIPS.SHIPS:
			var anchor: Vector3 = sh[3]
			var d := Vector2(pos.x, pos.z).distance_to(Vector2(anchor.x, anchor.z))
			check(d > 13.0, "she passes %.1f m from the ship at anchor at %s" % [d, anchor])
		s += 2.0


func test_lines_and_gangway_land_on_the_pier() -> void:
	for e: Array in A.line_ends():
		var b: Vector3 = e[0]
		check(Topo.on_pier(b.x, b.z, 0.0), "a bollard is off the pier at %s" % b)
	var g: Array = A.gangway_ends()
	var foot: Vector3 = g[0]
	check(Topo.on_pier(foot.x, foot.z, 0.0), "the gangway comes down off the planks at %s" % foot)
	check((g[1] as Vector3).z > Topo.PIER_Z + Topo.PIER_HALF, "the gangway's ship end is not over her side")
	check(foot.z > Topo.PIER_Z, "her gangway comes down on the Swallow's side")
	check(A.events(-INF, A.GLIDE + 1.0).has("hail"), "no hail as she comes in")
	check(A.events(A.GLIDE, A.GLIDE + 4.0).count("line") == 2, "the lines land without a sound")
	check(A.events(A.GLIDE + 4.0, A.GLIDE + 5.0).is_empty(), "a line lands twice")


func _route() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var pts := A.docker_points()
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var n := maxi(1, ceili(a.distance_to(b) / 0.1))
		for k in n:
			out.append(a.lerp(b, float(k) / n))
	return out


## The dockers walk the planks or dry beach, step on at the root, and keep off
## everything on the pier: the cargo and the coil, the Swallow's carrier and her
## skipper, the splicer, and the middle the walk out keeps.
func test_the_dockers_keep_their_lane() -> void:
	var carrier: Array[Vector2] = []
	for r: Array in HARBOUR.CARRIER_ROUTE:
		carrier.append(Vector2(r[0], r[1]))
	var sk := HARBOUR.skipper_pos()
	var base := HARBOUR.ship_pos().x - 2.0
	var south := Topo.PIER_Z + Topo.PIER_HALF
	var cargo := Rect2(base - 3.05, south - 0.7, 5.1, 0.7)  # sacks (to -0.69) and the rack (-0.65)
	var stuff := [Vector2(base - 5.7, south - 0.35), Vector2(base + 1.95, south - 0.32), Vector2(base + 2.85, south - 0.32)]
	var splicer := Vector2(HARBOUR.ship_pos().x + 1.5, south - 0.1)
	var prev := -1.0
	for p: Vector2 in _route():
		var on_pier := Topo.on_pier(p.x, p.y, -0.2)
		check(on_pier or Topo.terrain(p.x, p.y) > 0.5, "a docker walks into the sea at %s" % p)
		var h := Topo.surface(p.x, p.y)
		if prev >= 0.0:
			check(absf(h - prev) < 0.45, "a docker steps %.2f m at %s" % [absf(h - prev), p])
		prev = h
		check(not cargo.grow(0.25).has_point(p), "a docker walks into the cargo at %s" % p)
		for o: Vector2 in stuff:
			check(p.distance_to(o) > 0.55, "a docker walks into the coil or a jar at %s" % p)
		check(p.distance_to(splicer) > 0.6, "a docker walks through the splicer at %s" % p)
		check(p.distance_to(Vector2(sk.x, sk.z)) > 0.55, "a docker walks through the skipper at %s" % p)
		if on_pier:
			# south of the centre line the walk out to the skipper follows
			check(p.y > Topo.PIER_Z + 0.25, "a docker walks the pier's middle at %s" % p)
			for c: Vector2 in carrier:
				check(absf(p.y - c.y) > 0.5 or absf(p.x - c.x) > 0.5, "a docker shares the carrier's lane at %s" % p)
	# the stack is on dry beach, where the drop point is
	var drop: Array = A.DOCKER_ROUTE[A.DOCKER_DROP]
	check(Vector2(drop[0], drop[1]).distance_to(A.STACK) < 1.0, "the dockers put the jars down away from the stack")
	for o: Vector2 in A.STACK_SPOTS:
		var q: Vector2 = A.STACK + o
		check(Topo.terrain(q.x, q.y) > 0.5 and not Topo.on_pier(q.x, q.y, 0.3), "a jar is stacked in the sea or on the pier at %s" % q)


func test_work_stops_at_lamplight() -> void:
	check(not A.at_work(0.3, -1.0), "the dockers work before she is unloading")
	check(A.at_work(DayCycle.LAMPS_ON - 0.01, 5.0), "the dockers stop before dusk")
	check(not A.at_work(DayCycle.LAMPS_ON, 5.0), "the dockers still carry after the lamps are lit")
	check(A.stacked_by(-1.0) == 0 and A.stacked_by(1e6) == A.STACK_SPOTS.size(), "the stack is not laid out by the clock")
	check(A.BERTH_BY < DayCycle.LAMPS_ON and A.INBOUND_FROM < A.BERTH_BY, "she may still be out at dusk")


## Ten minutes of the dockers' work with the real Npc: jars taken and put down
## in turn, and the stack grows on the beach.
func test_the_dockers_carry_jars_ashore() -> void:
	var c: Npc = load("res://scripts/npc/npc.gd").new()
	c.talkable = false
	c.solid = false
	c.follow_ground = true
	var r: Array = A.DOCKER_ROUTE[0]
	c.position = Vector3(r[0], Topo.surface(r[0], r[1]), r[1])
	A.set_docker_round(c, 0)
	var seen: Array[int] = []
	c.reached.connect(func(i: int) -> void:
		if i == A.DOCKER_TAKE or i == A.DOCKER_DROP:
			seen.append(i))
	Engine.get_main_loop().root.add_child(c)
	for k in 6000:
		c._process(0.1)
	check(seen.count(A.DOCKER_DROP) >= 4, "in ten minutes he brought %d jars ashore" % seen.count(A.DOCKER_DROP))
	for j in seen.size():
		check(seen[j] == (A.DOCKER_TAKE if j % 2 == 0 else A.DOCKER_DROP), "he puts down what he never took: %s" % [seen])
	c.queue_free()
