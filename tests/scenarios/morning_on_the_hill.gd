extends "res://tests/qa/scenario.gd"
## Morning on the hill: the priest pours at Apollo's altar while its fire burns
## and its smoke rises; when the day has moved on the fire is let die and he
## stands by. Out on the steppe the Scythian horsemen ride their track.


func fixture() -> Dictionary:
	return {"found": 0, "hour": 0.1, "at": Vector2(-85.6, -2.2), "look": Vector3(-83.6, Topo.HILL_PLATFORM_TOP + 1.0, -6.0)}


func run() -> void:
	var world: Node = main().world
	var altar: Altar = world.get_node("Altar")
	var sc: Scythians = world.get_node("Scythians")
	step("the morning offering")
	await seconds(1.0)
	check(altar.burning, "no fire on the altar in the morning")
	check(altar.priest().pose == "pour", "the priest does not pour at the fire (%s)" % altar.priest().pose)
	await shot("morning_offering")
	step("horsemen on the steppe")
	var r: Rider = sc.get_node("Horseman0")
	var from := r.global_position
	await seconds(5.0)
	check(r.global_position.distance_to(from) > 3.0, "the horseman stood still for 5 s")
	check(absf(r.global_position.y - Topo.terrain(r.global_position.x, r.global_position.z)) < 0.05, "the horseman rides off the ground")
	# from beside the track, a few lengths off, looking at him
	var side := Vector2(r.global_position.x - 7.0, r.global_position.z - 3.0)  # downhill of the track: the rise to the hill behind him, not between
	player().global_position = Vector3(side.x, Topo.terrain(side.x, side.y) + 0.05, side.y)
	await look(r.global_position + Vector3(0, 1.4, 0))
	await shot("horseman")
	step("the fire is let die")
	Game.time_override = 0.5
	var t := 0.0
	while altar.burning and t < 40.0:
		await seconds(0.5)
		t += 0.5
	check(not altar.burning, "the altar still burns at midday")
	check(altar.priest().pose == "stand", "the priest still pours at a dead fire")
