extends "res://tests/test_case.gd"
## The fisherman's camp: Glaukos guts a fish at his board for about seventy
## seconds, fetches another from the catch and sits down again; the drying net
## hangs over its bar like cloth, not down to the shingle like a fence; and
## his lost hook lies where the boat hides it from the camp.

const FISHING := preload("res://scripts/world/fishing.gd")
const NPC := preload("res://scripts/npc/npc.gd")
## Where the walkthrough stands at the camp (director.gd): talking, at the sinkers.
const CAMP_STANDS := [Vector2(63.6, 14.4), Vector2(64.6, 13.0)]


## Things with colliders he must walk round: [centre, half size], the seat
## stone excepted (he sits on it).
func _things() -> Array:
	var out := [[FISHING.SINKERS, Vector2(0.25, 0.25)]]
	for c: Vector2 in FISHING.CATCH:
		out.append([c, Vector2(0.3, 0.3)])
	return out


func test_his_steps_go_round_the_baskets() -> void:
	var a := Vector2(FISHING.FISHER_ROUTE[0][0], FISHING.FISHER_ROUTE[0][1])
	var b := Vector2(FISHING.FISHER_ROUTE[1][0], FISHING.FISHER_ROUTE[1][1])
	check(a == FISHING.SEAT, "he does not gut at his stone but at %s" % a)
	for s in 21:
		var p := a.lerp(b, s / 20.0)
		for t: Array in _things():
			var c: Vector2 = t[0]
			var h: Vector2 = t[1]
			var inside := absf(p.x - c.x) < h.x + 0.15 and absf(p.y - c.y) < h.y + 0.15
			check(not inside, "he walks through the basket at %s (at %s)" % [c, p])
	# at the basket he faces it
	var yaw := deg_to_rad(float(FISHING.FISHER_ROUTE[1][4]))
	var look := Vector2(-sin(yaw), -cos(yaw))
	var to: Vector2 = (FISHING.CATCH[0] as Vector2) - b
	check(look.dot(to.normalized()) > 0.95, "he bends over the sand, not the catch basket")
	check(b.distance_to(FISHING.CATCH[0]) < 0.9, "he reaches into a basket %.2f m away" % b.distance_to(FISHING.CATCH[0]))


func test_he_guts_seventy_seconds_then_fetches_another() -> void:
	var f: Npc = NPC.new()
	f.npc_id = "fisher"
	f.pose = "gut"
	f.talkable = false
	f.position = Vector3(FISHING.FISHER_ROUTE[0][0], 0, FISHING.FISHER_ROUTE[0][1])
	FISHING.set_fisher_round(f)
	var events: Array[String] = []
	var times: Array[float] = []
	var t := [0.0]
	f.departed.connect(func(i: int) -> void:
		events.append("up%d" % i)
		times.append(t[0]))
	f.reached.connect(func(i: int) -> void:
		events.append("at%d" % i)
		times.append(t[0]))
	Engine.get_main_loop().root.add_child(f)
	for k in 2400:
		t[0] += 0.1
		f._process(0.1)
	var fetched := events.count("at1")
	check(fetched >= 2 and fetched <= 4, "in 240 s he fetched %d fish" % fetched)
	for j in events.size():
		if events[j] == "up0" and j > 0 and events[j - 1] == "at0":
			var gutting := times[j] - times[j - 1]
			check(gutting > 65.0 and gutting < 75.0, "he gutted one fish for %.0f s" % gutting)
		if events[j] == "at1":
			check(j > 0 and events[j - 1] == "up0", "he reaches the catch without getting up from the board: %s" % [events])
	check(f.seated() or events.back() != "at0", "he sits at the board standing")
	f.free()


func test_a_fish_goes_from_basket_to_hand_to_board_to_the_gutted() -> void:
	var camp: Node3D = FISHING.new()
	Engine.get_main_loop().root.add_child(camp)
	var f: Npc = camp.fisher()
	check(camp._board_fish.visible and not camp._hand_fish.visible, "he starts with no fish on the board")
	check(camp.gutted_count() == 0, "gutted fish before he has gutted one")
	var saw_in_hand := false
	for k in 1700:
		f._process(0.1)
		if camp._hand_fish.visible:
			saw_in_hand = true
			check(not camp._board_fish.visible, "a fish on the board and another in the hand")
	check(saw_in_hand, "he never carries a fish back from the catch")
	check(camp.gutted_count() >= 2, "in 170 s %d fish went to the gutted basket" % camp.gutted_count())
	camp.free()


func test_the_net_hangs_over_the_bar_not_to_the_shingle() -> void:
	var a: Vector2 = FISHING.RACK[0]
	var b: Vector2 = FISHING.RACK[1]
	var bar := FISHING.rack_bar_y()
	for p: Vector2 in [a, b]:
		check(bar - FISHING.ground(p) > 1.5, "the bar is only %.2f m over a pole's foot" % (bar - FISHING.ground(p)))
	check(FISHING.net_drop(0.5) > FISHING.net_drop(0.0) + 0.1, "the net's foot does not sag between the poles")
	for s in 11:
		var u := s / 10.0
		var p := a.lerp(b, u)
		var gap := bar - FISHING.net_drop(u) - FISHING.ground(p)
		check(gap > 0.4, "the net reaches down to %.2f m over the shingle at %s, like a fence" % [gap, p])


## Boat's footprint (as _boat() lays it): centre, half length and beam, yaw.
func _boat_hits(p: Vector2, q: Vector2) -> bool:
	var basis := Basis(Vector3.UP, deg_to_rad(-8.0))
	var inv := basis.inverse()
	for s in 41:
		var w := p.lerp(q, s / 40.0)
		var l := inv * Vector3(w.x - FISHING.BOAT.x, 0, w.y - FISHING.BOAT.y)
		if absf(l.x) < 2.2 and absf(l.z) < 0.65:
			return true
	return false


func test_the_hook_lies_behind_the_boat() -> void:
	var h := FISHING.LOST_HOOK
	check(Topo.terrain(h.x, h.y) > Topo.SEA_LEVEL + 0.8, "the hook lies in the surf")
	check(not _boat_hits(h, h), "the hook lies under the hull")
	for st: Vector2 in CAMP_STANDS:
		check(_boat_hits(st, h), "the hook is seen from the camp at %s, past the boat" % st)
	check(h.distance_to(FISHING.BOAT) < 1.6, "the hook is %.1f m from the boat, not by it" % h.distance_to(FISHING.BOAT))
