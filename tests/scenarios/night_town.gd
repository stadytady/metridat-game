extends "res://tests/qa/scenario.gd"
## Dusk falls while the player stands on the square: every light the town keeps
## (wall lamps, the square's braziers, the tower fires on the wall) catches from
## the one threshold, the striker puts his hammer down, and the children who
## were playing walk home to Myrto's hearth and sit.


func fixture() -> Dictionary:
	return {"found": 10, "lamps": "all", "hour": 1.0, "at": Vector2(20.0, 2.4), "timeout": 150.0}


func run() -> void:
	step("lights catch")
	await seconds(2.0)
	var world: Node = main().world
	var dark := tree().get_nodes_in_group(&"wall_lamp").filter(func(w: Node) -> bool: return not w.lit).size()
	check(dark == 0, "%d wall lamps dark after dusk" % dark)
	var fires := tree().get_nodes_in_group(&"night_fire")
	check(fires.size() >= 10 and fires.all(func(f: Node) -> bool: return f.lit), "the square's braziers are not all lit")
	var watch: WallWatch = world.find_child("WallWatch", true, false)
	check(watch != null and watch.fires_lit() == watch.fire_count() and watch.fire_count() >= 8, "a tower fire on the wall is dark")
	var mint: Mint = world.find_child("Mint", true, false)
	check(mint != null and not mint.working(), "the striker still swings after dusk")
	step("children walk home")
	var kb: Knucklebones = world.find_child("Knucklebones", true, false)
	var seated := 0
	var t := 0.0
	var frames_left := 3
	while t < 90.0:
		seated = kb.walkers().filter(func(n: Npc) -> bool: return n.pose_now() == "sit").size()
		if seated == 2:
			break
		# a few frames of them on the way, from beside the path
		if frames_left > 0 and int(t) % 4 == 0 and not kb.walkers().is_empty():
			frames_left -= 1
			var n: Npc = kb.walkers()[0]
			var side := n.global_basis.x.normalized() * 3.5
			var at := Vector2(n.global_position.x + side.x, n.global_position.z + side.z)
			player().global_position = Vector3(at.x, Topo.surface(at.x, at.y) + 0.05, at.y)
			await look(n.global_position + Vector3(0, 0.6, 0))
			await shot("children_on_the_way_%02d" % int(t))
		await seconds(1.0)
		t += 1.0
	check(seated == 2, "after %.0f s %d of 2 children sit at the hearth" % [t, seated])
	for i in kb.walkers().size():
		var n: Npc = kb.walkers()[i]
		check(not n.patrol.is_empty(), "child %d was put home, not walked there" % i)
	await view("agora")
	await shot("square_at_night")
