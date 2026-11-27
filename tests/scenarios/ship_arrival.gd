extends "res://tests/qa/scenario.gd"
## The ship comes in to the pier: sighted off the harbour, called in by the
## player on the beach, she glides alongside, her lines go ashore, the gangway
## comes down, Damon has a word about her, and the dockers bring her first jars
## ashore. The Swallow does not move.


func fixture() -> Dictionary:
	return {"found": 8, "hour": 0.4, "at": Vector2(60.6, -3.0), "look": Vector3(100.0, 2.0, -1.0), "timeout": 300}


func run() -> void:
	var arr: Arrival = main().world.find_child("Arrival", true, false)
	check(arr != null, "no arriving ship in the world")
	if arr == null:
		return
	var harbour: Node = tree().get_first_node_in_group(&"harbour")
	var swallow: Vector3 = harbour.ship().global_position
	step("a restored afternoon has her alongside")
	check(arr.stage() == Arrival.Stage.MOORED and Game.ship_in(), "past her sighting she is not alongside: stage %d" % arr.stage())
	step("she comes in off the strait")
	arr.set_clock(Arrival.SAIL_IN - 3.0)
	await frames(2)
	check(arr.stage() == Arrival.Stage.INBOUND and Game.ship_coming(), "she is not coming in: stage %d" % arr.stage())
	# her clock is game time: wait in game seconds, not on the wall (a rendering
	# CI runner steps game time far slower than the clock on the wall)
	var waited := 0.0
	while arr.stage() < Arrival.Stage.BERTHING and waited < 15.0:
		await seconds(0.5)
		waited += 0.5
	check(arr.stage() == Arrival.Stage.BERTHING, "the player on the beach does not call her in: stage %d" % arr.stage())
	await seconds(Arrival.GLIDE * 0.5)
	await shot("coming_alongside")
	waited = 0.0
	while arr.stage() < Arrival.Stage.MOORED and waited < Arrival.GLIDE:
		await seconds(0.5)
		waited += 0.5
	check(arr.stage() == Arrival.Stage.MOORED, "she never comes alongside")
	var berth := Arrival.berth()
	var at := arr.ship().global_position
	check(Vector2(at.x, at.z).distance_to(Vector2(berth.x, berth.z)) < 0.5, "she lies at %s, not at her berth" % at)
	step("lines ashore, gangway down")
	await seconds(Arrival.THROW + Arrival.TAUT + 1.0)
	check(arr.find_child("ArrivalLines", true, false).visible, "her lines are not ashore")
	await seconds(Arrival.GANGWAY_T + 4.0)
	check(arr.gangway().visible, "her gangway is not down")
	check(Game.ship_in(), "Game does not know she is in")
	await shot("alongside")
	step("Damon on the new ship")
	await walk_to(Vector2(62.0, -7.6))
	await walk_to(Vector2(Topo.pier_x0() - 1.0, Topo.PIER_Z))
	await walk_to(Vector2(Topo.pier_x1() - 7.0, Topo.PIER_Z - 0.4))
	await talk("sailor", "LOC_SAILOR_CHOICE_SHIP", 2)
	step("the dockers bring her jars ashore")
	var before := arr.stacked()
	check(arr.dockers().all(func(d: Npc) -> bool: return d.visible), "the dockers are not at work")
	waited = 0.0
	while arr.stacked() <= before and waited < 120.0:
		await seconds(1.0)
		waited += 1.0
	check(arr.stacked() > before, "no jar came ashore (%d on the beach)" % arr.stacked())
	check(harbour.ship().global_position.distance_to(swallow) < 1.0, "the Swallow moved")
