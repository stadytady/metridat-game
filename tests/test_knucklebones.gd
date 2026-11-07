extends "res://tests/test_case.gd"
## Two children playing knucklebones: they sit on the square facing each other,
## the five astragals come down between them and not inside a knee, and they
## take turns - one throws while the other waits - which is the whole point of
## the thing the player will later be invited to join.

const KB := preload("res://scripts/npc/knucklebones.gd")
const LIFE := preload("res://scripts/world/life.gd")
const HOUSE := preload("res://scripts/world/house.gd")
## The agora's own furniture, as agora.gd places it: the statue base, the stall
## and the bench by the east parapet. The children must not sit in any of them.
const FURNITURE := [Vector3(1.0, 0, 0.5), Vector3(-2.0, 0, 6.5), Vector3(6.0, 0, -2.0)]


func _game() -> Knucklebones:
	var n := KB.new()
	Engine.get_main_loop().root.add_child(n)
	return n


func _bones(n: Knucklebones) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
	return out


## Where a child looks, in world space. The rig carries a child's scale, so the
## basis has to be read as a direction and not as a vector.
func _forward(body: Node3D) -> Vector3:
	return body.global_transform.basis.z.normalized()


## Arm angle of a child: how far forward the throwing shoulder is swung. The rig
## hangs off the pelvis, so the shoulder is two joints down, not a child of the body.
func _arm(body: Node3D) -> float:
	var joint: Node3D = body.get_node("pelvis/chest/r_shoulder")
	return joint.rotation_degrees.x


func test_the_children_sit_facing_each_other() -> void:
	var n := _game()
	check(n.children().size() == 2, "there are %d children, not two" % n.children().size())
	var a: Node3D = n.children()[0]
	var b: Node3D = n.children()[1]
	var to_b := (b.global_position - a.global_position).normalized()
	check((-_forward(a)).dot(to_b) > 0.9, "the first child looks away from the second")
	var to_a := (a.global_position - b.global_position).normalized()
	check((-_forward(b)).dot(to_a) > 0.9, "the second child looks away from the first")
	# small, and sitting on the stones rather than standing over them
	check(a.scale.y < 0.8, "the child is %.2f of a grown-up" % a.scale.y)
	var pelvis: Node3D = a.get_node("pelvis")
	check(absf(pelvis.position.y - Figure.SEAT["sit"]) < 0.01,
			"the sitting pelvis is at %.2f, not at the seat of the pose" % pelvis.position.y)
	check(Figure.SEAT["sit"] < 0.4, "a child sitting on the paving has the pelvis at %.2f m" % Figure.SEAT["sit"])
	n.queue_free()


func test_the_bones_come_down_between_them() -> void:
	var n := _game()
	check(_bones(n).size() == KB.BONES, "%d astragals, not five" % _bones(n).size())
	for throw_index in 4:
		var spots: Array[Vector2] = []
		for i in KB.BONES:
			var p := KB.bone_home(throw_index, i)
			check(p.y > 0.0, "a bone lies under the paving")
			check(Vector2(p.x, p.z).length() <= KB.SPREAD + 0.001,
					"a bone lands %.2f m from the middle" % Vector2(p.x, p.z).length())
			check(KB.bone_home(throw_index, i) == p, "the same throw scatters differently twice")
			spots.append(Vector2(p.x, p.z))
		for i in spots.size():
			for j in range(i + 1, spots.size()):
				check(spots[i].distance_to(spots[j]) > 0.03,
						"two bones land on top of each other at %s" % spots[i])
	n.queue_free()


func test_they_take_turns() -> void:
	var n := _game()
	n._t = KB.RELEASE
	n._process(0.0)
	var first := _arm(n.children()[0])
	var waiting := _arm(n.children()[1])
	check(first > waiting + 20.0, "the first child does not throw while the second waits (%.0f / %.0f)" % [first, waiting])
	n._t = KB.TURN + KB.RELEASE
	n._process(0.0)
	var second := _arm(n.children()[1])
	var now_waiting := _arm(n.children()[0])
	check(second > now_waiting + 20.0, "the turn does not pass to the second child (%.0f / %.0f)" % [second, now_waiting])
	check(absf(first - second) < 1.0, "the two children throw differently (%.0f / %.0f)" % [first, second])
	n.queue_free()


func test_a_bone_in_the_air_leaves_the_ground_and_lands_flat() -> void:
	var n := _game()
	n._t = KB.RELEASE + KB.FLIGHT * 0.5
	n._process(0.0)
	var up := 0
	for bone: MeshInstance3D in _bones(n):
		if bone.visible and bone.position.y > 0.06:
			up += 1
	check(up > 0, "not a bone is in the air in the middle of a throw")
	n._t = KB.RELEASE + 1.5
	n._process(0.0)
	for bone: MeshInstance3D in _bones(n):
		check(bone.visible, "a bone has gone missing once it landed")
		check(absf(bone.position.y - KB.REST_Y) < 0.02, "a landed bone floats at %.2f" % bone.position.y)
	n.queue_free()


func test_the_spot_is_on_the_square() -> void:
	var p: Vector3 = LIFE.KNUCKLEBONES
	check(Topo.in_rect(p.x, p.z, Topo.AGORA_CENTER, Topo.AGORA_HALF), "the children sit off the square at %s" % p)
	check(absf(Topo.surface(p.x, p.z) - Topo.AGORA_H) < 0.01, "the children sit on %.2f, not on the paving" % Topo.surface(p.x, p.z))
	var c := Topo.AGORA_CENTER
	for at: Vector3 in FURNITURE:
		var d := Vector2(p.x - (c.x + at.x), p.z - (c.y + at.z)).length()
		check(d > 1.6, "the children sit %.2f m from the agora's furniture at %s" % [d, at])


## A stand-in for the world's Atmosphere: only the hour is read.
func _world(hour: float) -> Node3D:
	var gs := GDScript.new()
	gs.source_code = "extends Node\nvar t := 0.0\n"
	gs.reload()
	var atm := Node.new()
	atm.set_script(gs)
	atm.name = "Atmosphere"
	atm.t = hour
	var w := Node3D.new()
	w.add_child(atm)
	Engine.get_main_loop().root.add_child(w)
	return w


func test_home_at_dusk() -> void:
	check(not KB.at_home(DayCycle.LAMPS_ON - 0.01), "home before the lamps are lit")
	check(KB.at_home(DayCycle.LAMPS_ON), "still out when the lamps are lit")
	check(KB.at_home(DayCycle.DREAM), "out on the square during the dream")


func test_the_way_home_is_flat_and_through_doors() -> void:
	var walls: Array = HOUSE.walls()
	for i in 2:
		var r := KB.home_route(i)
		var start: Vector3 = LIFE.KNUCKLEBONES + KB.seat_spots()[i]
		var pts: Array[Vector2] = [Vector2(start.x, start.z)]
		pts.append_array(r)
		for k in pts.size() - 1:
			for s in 21:
				var p := pts[k].lerp(pts[k + 1], s / 20.0)
				var h := Topo.surface(p.x, p.y)
				check(absf(h - Topo.HOUSE_H) < 0.05, "child %d walks at %.2f, not on the flat, at %s" % [i, h, p])
				for w: Array in walls:
					var c: Vector3 = w[0]
					var size: Vector3 = w[1]
					var inside := absf(p.x - c.x) < size.x / 2.0 + 0.12 and absf(p.y - c.z) < size.z / 2.0 + 0.12
					check(not inside, "child %d walks through a wall at %s" % [i, p])


func test_they_sit_by_the_hearth_clear_of_the_room() -> void:
	var b: Rect2 = HOUSE.bounds()
	var stool := HOUSE.LAMP_STOOL
	for i in 2:
		var s: Vector2 = KB.HOME_SEATS[i]
		check(s.x > b.position.x + HOUSE.WALL_T + 1.2 and s.x < HOUSE.DIVIDE_X - 0.4, "seat %d off the living room in x: %s" % [i, s])
		check(s.y > HOUSE.RANGE_Z + 0.4 and s.y < b.end.y - HOUSE.WALL_T - 0.3, "seat %d off the living room in z: %s" % [i, s])
		var d := s.distance_to(HOUSE.HEARTH)
		check(d > 0.75 and d < 1.6, "seat %d is %.2f m from the hearth" % [i, d])
		check(s.distance_to(stool) > 1.0, "seat %d crowds the lamp on the stool" % i)
		# facing the fire: the yaw points from the seat to the hearth
		var yaw := deg_to_rad(KB.seat_yaw(i))
		var look := Vector2(-sin(yaw), -cos(yaw))
		check(look.dot((HOUSE.HEARTH - s).normalized()) > 0.99, "seat %d does not face the fire" % i)
	check(KB.HOME_SEATS[0].distance_to(KB.HOME_SEATS[1]) > 0.8, "the two sit on one another")


func test_they_go_home_at_dusk_and_come_back_by_day() -> void:
	var w := _world(0.2)
	var kb: Knucklebones = KB.new()
	w.add_child(kb)
	kb._process(0.1)
	check(kb.walkers().is_empty(), "walking home in the afternoon")
	w.get_node("Atmosphere").t = DayCycle.LAMPS_ON + 0.01
	kb._process(0.1)
	check(kb.walkers().size() == 2, "%d children go home at dusk" % kb.walkers().size())
	for c in kb.children():
		check(not c.visible, "a child is still playing on the square after dusk")
	for n in kb.walkers():
		check(not n.patrol.is_empty(), "seen at dusk, a child is put home instead of walking")
		check(n.collision_layer == 0, "a child walking home blocks the footpath")
	w.get_node("Atmosphere").t = 0.1
	kb._process(0.1)
	check(kb.walkers().is_empty(), "still at home in the morning")
	for c in kb.children():
		check(c.visible, "no child back on the square in the morning")
	w.free()


func test_already_home_if_the_square_is_built_after_dusk() -> void:
	var w := _world(1.0)
	var kb: Knucklebones = KB.new()
	w.add_child(kb)
	kb._process(0.1)
	check(kb.walkers().size() == 2, "nobody at home at night")
	for i in kb.walkers().size():
		var n: Npc = kb.walkers()[i]
		check(n.patrol.is_empty(), "child %d walks home in the middle of the night" % i)
		var at := Vector2(n.global_position.x, n.global_position.z)
		check(at.distance_to(KB.HOME_SEATS[i]) < 0.01, "child %d is not at its seat: %s" % [i, at])
		check(n.pose == "sit", "child %d is not sitting at home" % i)
	w.free()

## The rules of the children's game: five bones of one to four, three throws,
## the higher sum takes the throw, and the game ends after the third.
func test_the_astragal_rules_hold() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var hand := AstragalGame.throw_bones(rng)
		check(hand.size() == AstragalGame.BONES, "a hand of %d bones" % hand.size())
		for b: int in hand:
			check(b >= 1 and b <= AstragalGame.FACES, "a bone shows %d" % b)
	var g := AstragalGame.new(99)
	var seen := 0
	while not g.over:
		var entry := g.play_throw()
		seen += 1
		check(entry.sum_mine == AstragalGame.total(entry.mine), "the sum does not match the bones")
		check(entry.sum_theirs == AstragalGame.total(entry.theirs), "their sum does not match")
		var want := "me" if entry.sum_mine > entry.sum_theirs else (
				"them" if entry.sum_theirs > entry.sum_mine else "draw")
		check(entry.winner == want, "the throw was given to the wrong hand")
	check(seen == AstragalGame.THROWS, "the game ran %d throws" % seen)
	check(g.won + g.lost <= AstragalGame.THROWS, "more throws won than played")
	check(g.winner in ["me", "them", "draw"], "no winner after three throws")
	check(g.play_throw().is_empty(), "the game went on after the third throw")
	g.restart()
	check(not g.over and g.throws.is_empty() and g.winner == "", "restart left the old game")


## The children can be played with by day, and not in the dark when they are home.
func test_the_children_can_be_played_with_by_day() -> void:
	check(Knucklebones.at_home(DayCycle.LAMPS_ON), "the children are out after the lamps are lit")
	check(not Knucklebones.at_home(0.4), "the children are home in the afternoon")
	check(tr("UI_ASTRAGAL_PLAY") != "", "the prompt to play is not translated")
	check(tr("UI_ASTRAGAL_WIN") != "" and tr("UI_ASTRAGAL_LOSE") != "", "the verdicts are not translated")
