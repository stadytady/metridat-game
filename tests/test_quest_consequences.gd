extends "res://tests/test_case.gd"
## The errands leave a mark: each giver's round grows a new stretch once the
## errand is done (and keeps the old waypoints where props hang on them), and
## the new stretch walks clear of everything in its way; the thing returned
## shows in its place; the town's dusk lights the lamp; a talkable person with
## no body is still in reach of the ray.

const HOUSE := preload("res://scripts/world/house.gd")
const FISHING := preload("res://scripts/world/fishing.gd")
const WORKSHOP := preload("res://scripts/world/workshop.gd")
const QUAY := preload("res://scripts/world/grain_quay.gd")
const LIFE := preload("res://scripts/world/life.gd")


func _walk(route: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in route.size():
		var a := Vector2(route[i][0], route[i][1])
		var b := Vector2(route[(i + 1) % route.size()][0], route[(i + 1) % route.size()][1])
		var n := maxi(1, ceili(a.distance_to(b) / 0.1))
		for k in n:
			out.append(a.lerp(b, float(k) / n))
	return out


## Routes hold NAN facings, and NAN is never equal to itself: compare as text.
func _same(a: Array, b: Array) -> bool:
	return str(a) == str(b)


func test_rounds_grow_and_keep_their_props() -> void:
	check(_same(HOUSE.baker_route(false), HOUSE.BAKER_ROUTE), "Myrto weaves before the errand")
	check(_same(HOUSE.baker_route(true).slice(0, HOUSE.BAKER_ROUTE.size()), HOUSE.BAKER_ROUTE), "the bread's waypoints moved")
	check(HOUSE.baker_route(true)[HOUSE.LOOM_SEAT][2] == "weave", "LOOM_SEAT is not the stool")
	check(_same(FISHING.fisher_route(true).slice(0, FISHING.FISHER_ROUTE.size()), FISHING.FISHER_ROUTE), "the fish's waypoints moved")
	check(FISHING.fisher_route(true)[FISHING.FISHER_RIG][2] == "pick", "FISHER_RIG is not at the boat")
	check(_same(WORKSHOP.boy_route(true).slice(0, WORKSHOP.BOY_ROUTE.size()), WORKSHOP.BOY_ROUTE), "the logs' waypoints moved")
	check(WORKSHOP.boy_route(true)[WORKSHOP.PLAY][2] == "sit", "PLAY is not the game")
	check(_same(WORKSHOP.boy_route(false), WORKSHOP.BOY_ROUTE) and _same(FISHING.fisher_route(false), FISHING.FISHER_ROUTE), "a round grows before its errand")


## Myrto to the loom: through the workroom door, round the lamp stand, the
## spare weights and the wool basket, and sat on the weaver's stool.
func test_myrto_walks_to_the_loom_through_the_door() -> void:
	var lamp := Vector2(29.2, 24.2)
	var weights := HOUSE.LOOM_WEIGHTS
	var basket := Vector2(27.3, 24.0)
	var r := HOUSE.bounds().grow(-HOUSE.WALL_T - 0.2)
	var door := HOUSE.ROOM_DOORS[1] as float
	for p: Vector2 in _walk(HOUSE.baker_route(true)):
		check(r.has_point(p), "Myrto walks through the house wall at %s" % p)
		if absf(p.y - HOUSE.RANGE_Z) < HOUSE.WALL_T / 2.0 + 0.25:
			check(absf(p.x - door) < HOUSE.DOOR_W / 2.0 - 0.25, "Myrto walks through the rooms' wall at %s" % p)
		check(p.distance_to(lamp) > 0.35, "Myrto walks through the lamp stand at %s" % p)
		check(p.distance_to(weights) > 0.5, "Myrto walks over the spare weights at %s" % p)
		check(p.distance_to(basket) > 0.5, "Myrto walks through the wool basket at %s" % p)
	var seat: Array = HOUSE.baker_route(true)[HOUSE.LOOM_SEAT]
	check(Vector2(seat[0], seat[1]).distance_to(Vector2(29.2, 24.6)) < 0.05, "she does not sit on the weaver's stool")
	check(HOUSE.bands_woven(0) == 0 and HOUSE.bands_woven(2) == 2 and HOUSE.bands_woven(99) == HOUSE.BANDS, "the cloth does not grow by sittings")


## Glaukos at the boat: on dry shingle, clear of her hull and of the camp.
func test_glaukos_rigs_by_the_boat_on_dry_shingle() -> void:
	var boat := Transform3D(Basis(Vector3.UP, deg_to_rad(-8.0)), Vector3(FISHING.BOAT.x, 0, FISHING.BOAT.y))
	for p: Vector2 in _walk(FISHING.fisher_route(true)):
		check(Topo.terrain(p.x, p.y) > 0.4, "Glaukos walks into the surf at %s" % p)
		var local := boat.affine_inverse() * Vector3(p.x, 0, p.y)
		check(absf(local.x) > 2.2 + 0.25 or absf(local.z) > 0.65 + 0.25, "Glaukos walks through his boat at %s" % p)
		check(p.distance_to(FISHING.FIRE) > 0.9, "Glaukos walks through the fire at %s" % p)
	var ll := FISHING.LONGLINE
	var local_ll := boat.affine_inverse() * Vector3(ll.x, 0, ll.y)
	check(absf(local_ll.z) > 0.65 + 0.2 or absf(local_ll.x) > 2.2 + 0.2, "the long line's basket is in the boat")
	check(Topo.terrain(ll.x, ll.y) > 0.4, "the long line's basket is in the surf")


## The boy to the children's game: round the stall and the statue base, sat
## by the game but not on it.
func test_the_boy_runs_to_the_game_round_the_stall() -> void:
	var stall := Rect2(17.6, 5.4, 4.8, 2.2)
	var statue := Rect2(22.1, -0.4, 1.8, 1.8)
	var bench := Rect2(26.4, -2.5, 3.2, 1.0)
	for p: Vector2 in _walk(WORKSHOP.PLAY_ROUTE):
		for r: Rect2 in [stall, statue, bench]:
			check(not r.grow(0.3).has_point(p), "the boy runs through %s at %s" % [r, p])
	var seat: Array = WORKSHOP.boy_route(true)[WORKSHOP.PLAY]
	var game := Vector2(26.0, -0.8)
	var d := Vector2(seat[0], seat[1]).distance_to(game)
	check(d > 1.2 and d < 2.5, "the boy sits %.1f m from the game" % d)
	# facing the game: a figure looks along its local -z
	var yaw := deg_to_rad(seat[4])
	var look := Vector2(-sin(yaw), -cos(yaw))
	check(look.dot((game - Vector2(seat[0], seat[1])).normalized()) > 0.9, "the boy sits with his back to the game")


func test_the_seals_and_the_lamp_sit_on_their_things() -> void:
	var spots := QUAY.seal_spots()
	check(spots.size() == 9, "not every sack has its seal")
	for p: Vector3 in spots:
		var near_stack := Vector2(p.x, p.z).distance_to(QUAY.STACK) < 0.6
		var near_pile := Vector2(p.x, p.z).distance_to(QUAY.PILE) < 0.8
		check(near_stack or near_pile, "a seal lies away from the sacks at %s" % p)
	var lamp: Vector3 = LIFE.home_lamp_pos()
	var w: Vector3 = LIFE.well_pos()
	var jar := Vector2(w.x + LIFE.STORE_AT.x, w.z + LIFE.STORE_AT.z)
	check(Vector2(lamp.x, lamp.z).distance_to(jar) < 0.05, "Agathe's lamp is not on her jar")
	check(absf(lamp.y - (Topo.surface(jar.x, jar.y) + 0.91)) < 0.05, "Agathe's lamp floats or sinks: %.2f" % lamp.y)
	check(not LIFE.home_lamp_lit(false, 1.0), "the lamp burns before it is back")
	check(not LIFE.home_lamp_lit(true, DayCycle.LAMPS_ON - 0.01), "the lamp burns before dusk")
	check(LIFE.home_lamp_lit(true, DayCycle.LAMPS_ON), "the lamp does not burn with the town")


func test_errand_done_is_read_from_the_quests() -> void:
	var was := Game.quests.duplicate()
	Game.quests.clear()
	check(not Game.quest_done("lamp"), "an untouched errand counts as done")
	Game.quests["lamp"] = Quests.FOUND
	check(not Game.quest_done("lamp"), "a found but not given back errand counts as done")
	Game.quests["lamp"] = Quests.DONE
	check(Game.quest_done("lamp"), "a given back errand is not done")
	Game.quests = was


## A talkable person with no body: the player walks through, the ray still
## finds them (layer 2 only).
func test_bodiless_talkers_stay_in_reach() -> void:
	var n: Npc = load("res://scripts/npc/npc.gd").new()
	n.talkable = true
	n.solid = false
	(Engine.get_main_loop() as SceneTree).root.add_child(n)
	check(n.collision_layer == 2, "a bodiless talker is on layer %d" % n.collision_layer)
	var m: Npc = load("res://scripts/npc/npc.gd").new()
	m.talkable = false
	m.solid = false
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	check(m.collision_layer == 0, "a bodiless passer-by can be hit by the ray")
	n.free()
	m.free()
