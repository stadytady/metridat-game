extends "res://tests/test_case.gd"
## People at work instead of standing still: the potter's boy goes round the
## wheel, the woodpile and the kiln mouth without walking through any of them
## or across the path to the potter; Fedr sits down on the front row facing
## the orchestra, his hips on the stone and his feet on the floor before it.

const WORKSHOP := preload("res://scripts/world/workshop.gd")
const THEATRE := preload("res://scripts/world/theatre.gd")
const BOY_HALF := 0.15  # half the boy's width at 0.72 scale

## Things in the workshop he must walk round: [centre, radius] circles...
const ROUND_THINGS := [
	[Vector2(17.7, 9.5), 1.05],  # the kiln
	[Vector2(19.5, 8.1), 0.22],  # the chopping block
	[Vector2(13.4, 8.75), 0.34],  # the wheel
	[Vector2(13.4, 9.4), 0.35],  # the potter at it
	[Vector2(10.3, 7.2), 0.08],  # shed posts
	[Vector2(16.6, 7.2), 0.08],
]
## ...and boxes: [min corner, max corner].
const BOX_THINGS := [
	[Vector2(19.1, 9.85), Vector2(20.1, 10.75)],  # the woodpile
	[Vector2(17.35, 8.05), Vector2(18.05, 8.65)],  # the kiln's stoking channel
]
## The walkthrough's own way to the potter and the mould on the shelf.
const VISITOR_PATH := [Vector2(13.4, 4.8), Vector2(13.4, 7.0), Vector2(11.6, 7.7)]


func _route_points(step: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var r: Array = WORKSHOP.BOY_ROUTE
	for i in r.size():
		var a := Vector2(r[i][0], r[i][1])
		var b := Vector2(r[(i + 1) % r.size()][0], r[(i + 1) % r.size()][1])
		var n := maxi(1, ceili(a.distance_to(b) / step))
		for k in n:
			out.append(a.lerp(b, float(k) / n))
	return out


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func test_the_boy_walks_round_things_not_through_them() -> void:
	for p: Vector2 in _route_points(0.1):
		for c: Array in ROUND_THINGS:
			var at: Vector2 = c[0]
			# his home by the wheel is the one place he is meant to be close to it
			if p.distance_to(WORKSHOP.BOY_HOME) < 0.05:
				continue
			check(p.distance_to(at) > float(c[1]) + BOY_HALF, "the boy walks through %s at %s" % [at, p])
		for b: Array in BOX_THINGS:
			var lo: Vector2 = b[0] - Vector2(BOY_HALF, BOY_HALF)
			var hi: Vector2 = b[1] + Vector2(BOY_HALF, BOY_HALF)
			check(not (p.x > lo.x and p.x < hi.x and p.y > lo.y and p.y < hi.y), "the boy walks into %s at %s" % [b, p])
		for i in VISITOR_PATH.size() - 1:
			var d := _seg_dist(p, VISITOR_PATH[i], VISITOR_PATH[i + 1])
			check(d > 0.6, "the boy crosses the way to the potter at %s (%.2f m)" % [p, d])


## Ninety seconds of his day in 0.1 s ticks: he works the wheel, fetches the
## wood, carries it with his arms full, feeds the kiln, and does it again.
func test_the_boy_goes_round_and_round() -> void:
	var boy: Npc = load("res://scripts/npc/npc.gd").new()
	boy.npc_id = "turner"
	boy.pose = "turner"
	boy.figure_scale = 0.72
	boy.talkable = false
	boy.position = Vector3(WORKSHOP.BOY_HOME.x, 0, WORKSHOP.BOY_HOME.y)
	WORKSHOP.set_round(boy)
	var seen: Array[int] = []
	boy.reached.connect(func(i: int) -> void:
		seen.append(i)
		if i == WORKSHOP.PICK:
			boy.carrying = true
		elif i == WORKSHOP.STOKE:
			boy.carrying = false)
	Engine.get_main_loop().root.add_child(boy)
	var carried_walking := false
	var poses := {}
	for k in 900:
		boy._process(0.1)
		poses[boy.pose_now()] = true
		if boy.carrying and boy.pose_now() == "carry":
			carried_walking = true
	var picks := seen.count(WORKSHOP.PICK)
	var stokes := seen.count(WORKSHOP.STOKE)
	check(picks >= 2 and stokes >= 2, "in 90 s he fetched wood %d times and fed the kiln %d" % [picks, stokes])
	# always the woodpile before the kiln
	var last_pick := -1
	for j in seen.size():
		if seen[j] == WORKSHOP.PICK:
			last_pick = j
		elif seen[j] == WORKSHOP.STOKE:
			check(last_pick >= 0, "he feeds the kiln with nothing in his arms")
	check(carried_walking, "he never walks with his arms full")
	for p: String in ["turner", "pick", "stoke", "walk"]:
		check(poses.has(p), "he never takes the %s pose" % p)
	boy.queue_free()


## Fedr's seat is the front edge of the lowest tier, and he faces the orchestra.
func test_fedr_sits_on_the_front_row_facing_the_orchestra() -> void:
	var seat: Vector2 = THEATRE.ACTOR_SEAT
	var r := seat.distance_to(THEATRE.CENTER)
	check(r > THEATRE.INNER_R and r < THEATRE.INNER_R + THEATRE.TIER_DEPTH * 0.5,
			"his seat is %.2f m from the centre, not on the front of the first tier" % r)
	var yaw := deg_to_rad(-90.0)
	var looks := Vector2(-sin(yaw), -cos(yaw))
	check(looks.dot((THEATRE.CENTER - seat).normalized()) > 0.95, "he sits with his back to the orchestra")


## Sitting on a seat 0.28 m high: the hips on the stone, the feet on the floor
## in front of it, not in the tier.
func test_sit_think_puts_hips_on_the_seat_and_feet_on_the_floor() -> void:
	var root := Node3D.new()
	Engine.get_main_loop().root.add_child(root)
	root.position = Vector3(THEATRE.ACTOR_SEAT.x, 0, THEATRE.ACTOR_SEAT.y)
	root.rotation.y = deg_to_rad(-90.0)
	var joints := Figure.build(root, "chiton")
	Figure.apply_pose(joints, "sit_think")
	for side: String in ["l", "r"]:
		var hip: Node3D = joints[side + "_hip"]
		check(absf(hip.global_position.y - THEATRE.TIER_RISE) < 0.07,
				"the %s hip is at %.2f m, the seat at %.2f" % [side, hip.global_position.y, THEATRE.TIER_RISE])
		var knee: Node3D = joints[side + "_knee"]
		var foot := knee.global_transform * Vector3(0, -0.44, 0)
		check(foot.y > -0.03 and foot.y < 0.15, "the %s foot hangs at %.2f m" % [side, foot.y])
		var fr := Vector2(foot.x, foot.z).distance_to(THEATRE.CENTER)
		check(fr < THEATRE.INNER_R - 0.05, "the %s foot is in the tier (%.2f m from the centre)" % [side, fr])
		check(knee.global_position.y > THEATRE.TIER_RISE, "the %s knee is below the seat" % side)
	root.queue_free()


const LIFE := preload("res://scripts/world/life.gd")
const HOUSE := preload("res://scripts/world/house.gd")


func _round_points(pts: Array[Vector2], step: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var n := maxi(1, ceili(a.distance_to(b) / step))
		for k in n:
			out.append(a.lerp(b, float(k) / n))
	return out


func _carrier_points() -> Array[Vector2]:
	var w: Vector3 = LIFE.well_pos()
	var pts: Array[Vector2] = []
	for r: Array in LIFE.CARRIER_ROUTE:
		pts.append(Vector2(w.x + float(r[0]), w.z + float(r[1])))
	return pts


## Her round stays on the forecourt's paving, off the street, and goes round
## the well-head, its frame, the jar by the curb, the storage jar and the bench.
func test_the_water_carrier_walks_round_things() -> void:
	var w: Vector3 = LIFE.well_pos()
	var well := Vector2(w.x, w.z)
	var hydria := Vector2(w.x + LIFE.HYDRIA_AT.x, w.z + LIFE.HYDRIA_AT.z)
	var store := Vector2(w.x + LIFE.STORE_AT.x, w.z + LIFE.STORE_AT.z)
	for p: Vector2 in _round_points(_carrier_points(), 0.1):
		check(Topo.in_forecourt(p.x, p.y, 0.0), "the water carrier leaves the paving at %s" % p)
		check(absf(p.y - Topo.street_z(p.x)) > 1.4, "the water carrier walks in the street at %s" % p)
		check(p.distance_to(well) > 0.62 + 0.2, "she walks through the well-head at %s" % p)
		for sx: float in [-0.78, 0.78]:
			check(p.distance_to(well + Vector2(sx, 0)) > 0.3, "she walks through the well frame at %s" % p)
		check(p.distance_to(hydria) > 0.45, "she walks over the jar by the curb at %s" % p)
		check(p.distance_to(store) > 0.6, "she walks into the storage jar at %s" % p)
		check(not Rect2(4.5, -10.05, 3.0, 0.9).has_point(p), "she walks into the bench at %s" % p)


## Ninety seconds of her day: she lifts the jar, pours it, sets it down, in
## that order, walks the paving with it on her head, at the paving's height.
func test_the_water_carrier_goes_and_comes_back() -> void:
	var w: Vector3 = LIFE.well_pos()
	var woman: Npc = load("res://scripts/npc/npc.gd").new()
	woman.npc_id = "water_carrier"
	woman.pose = "draw"
	woman.talkable = false
	woman.position = w + Vector3(0, 0, 1.0)
	LIFE.set_carrier_round(woman, w)
	var seen: Array[int] = []
	woman.reached.connect(func(i: int) -> void:
		seen.append(i)
		if i == LIFE.CARRIER_LIFT:
			woman.carrying = true
		elif i == LIFE.CARRIER_SET_DOWN:
			woman.carrying = false)
	Engine.get_main_loop().root.add_child(woman)
	var on_head := false
	var worst := 0.0
	for k in 900:
		woman._process(0.1)
		if woman.pose_now() == "head_carry":
			on_head = true
			var p := woman.global_position
			worst = maxf(worst, absf(p.y - Topo.surface(p.x, p.z)))
	var order: Array[int] = seen.filter(func(i: int) -> bool:
		return i in [LIFE.CARRIER_LIFT, LIFE.CARRIER_POUR, LIFE.CARRIER_SET_DOWN])
	check(order.count(LIFE.CARRIER_POUR) >= 2, "in 90 s she poured %d times" % order.count(LIFE.CARRIER_POUR))
	for j in order.size():
		var want: int = [LIFE.CARRIER_LIFT, LIFE.CARRIER_POUR, LIFE.CARRIER_SET_DOWN][j % 3]
		check(order[j] == want, "she does things out of order: %s" % [order])
	check(on_head, "she never walks with the jar on her head")
	check(worst < 0.02, "she walks %.2f m off the paving" % worst)
	woman.queue_free()


## Myrto gets up with the bread and lays it on the board, and kneels again;
## her two steps go round the oven and do not stand in the board.
func test_myrto_lays_the_bread_on_the_board() -> void:
	var oven := HOUSE.OVEN
	for r: Array in HOUSE.BAKER_ROUTE:
		var p := Vector2(r[0], r[1])
		check(absf(p.x - oven.x) > 0.45 + 0.2 or absf(p.y - oven.y) > 0.45 + 0.2, "Myrto stands in the oven at %s" % p)
		check(not Rect2(28.7, 19.22, 0.7, 0.46).has_point(p), "Myrto stands in the board at %s" % p)
	var b: Npc = load("res://scripts/npc/npc.gd").new()
	b.npc_id = "baker"
	b.pose = "baker"
	b.talkable = false
	b.position = Vector3(HOUSE.BAKER_ROUTE[0][0], 0, HOUSE.BAKER_ROUTE[0][1])
	HOUSE.set_baker_round(b)
	var events: Array[String] = []
	b.departed.connect(func(i: int) -> void: events.append("up%d" % i))
	b.reached.connect(func(i: int) -> void: events.append("at%d" % i))
	Engine.get_main_loop().root.add_child(b)
	for k in 900:
		b._process(0.1)
	check(events.count("at1") >= 3, "in 90 s she laid %d breads" % events.count("at1"))
	for j in events.size():
		if events[j] == "at1":
			check(j > 0 and events[j - 1] == "up0", "she reaches the board without getting up from the oven: %s" % [events])
	b.queue_free()
