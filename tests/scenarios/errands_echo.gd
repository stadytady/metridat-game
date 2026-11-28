extends "res://tests/qa/scenario.gd"
## The five errands done: Myrto weaves between breads and new cloth hangs on
## the loom, Agathe's lamp stands on her jar and burns at dusk, Glaukos rigs
## his long line at the boat, the potter's boy runs off to the children's game
## and asks the player for a throw, Nikon seals his sacks. Each has a word
## for it. A save keeps it all; a new walk (no errands) takes it all away.


func fixture() -> Dictionary:
	return {"found": 10, "hour": 0.3, "at": Vector2(12.0, 6.5), "look": Vector3(12.75, 1.0, 8.75),
			"quests": {"loom_weight": Quests.DONE, "lamp": Quests.DONE, "hook": Quests.DONE, "astragal": Quests.DONE, "seal": Quests.DONE}}


func _done(house: Node, life: Node, camp: Node, shop: Node, quay: Node) -> bool:
	return house.baker().patrol.size() == house.baker_route(true).size() and house.woven() >= 1 \
			and life.home_lamp().visible \
			and camp.fisher().patrol.size() == camp.fisher_route(true).size() and camp.longline().visible \
			and shop.boy().patrol.size() == shop.boy_route(true).size() \
			and quay.measurer().patrol.size() == 2 and quay.seals().visible


func run() -> void:
	var w: Node = main().world
	var house: Node = w.find_child("House", true, false)
	var life: Node = w.find_child("Life", true, false)
	var camp: Node = w.find_child("FishingCamp", true, false)
	var shop: Node = w.find_child("Workshop", true, false)
	var quay: Node = w.find_child("GrainQuay", true, false)
	check(house != null and life != null and camp != null and shop != null and quay != null, "a district is missing")
	if house == null or life == null or camp == null or shop == null or quay == null:
		return
	await frames(3)
	step("every errand shows")
	check(_done(house, life, camp, shop, quay), "an errand done leaves no mark")
	check(not life.home_light().visible, "Agathe's lamp burns by day")
	step("the boy asks for a game")
	await talk("turner", "LOC_BOY_CHOICE_PLAY", 1)
	var t0 := Time.get_ticks_msec()
	var panel: Node = null
	while panel == null and Time.get_ticks_msec() - t0 < 5000:
		await frames(2)
		panel = tree().current_scene.find_child("AstragalPanel", true, false)
	check(panel != null, "the boy's game does not open the knucklebones table")
	if panel != null:
		panel.close()
		await frames(3)
	step("the weaver's word")
	player().global_position = Vector3(27.3, Topo.HOUSE_H, 18.2)
	await frames(3)
	await talk("baker", "LOC_BAKER_CHOICE_LOOM", 2)
	player().global_position = Vector3(29.1, Topo.HOUSE_H, 22.9)
	look(Vector3(29.2, Topo.HOUSE_H + 1.1, 26.0))
	await frames(3)
	await shot("new_cloth")
	step("dusk lights Agathe's lamp")
	Game.time_override = DayCycle.LAMPS_ON + 0.02
	await frames(3)
	check(life.home_light().visible, "Agathe's lamp stays dark at dusk")
	var lp: Vector3 = life.home_lamp().global_position
	player().global_position = Vector3(lp.x + 1.6, Topo.surface(lp.x + 1.6, lp.z + 1.6), lp.z + 1.6)
	look(lp)
	await frames(3)
	await shot("agathe_lamp")
	player().global_position = Vector3(63.6, Topo.surface(63.6, -7.4), -7.4)
	look(Vector3(64.9, Topo.surface(64.9, -8.5) + 0.4, -8.5))
	await frames(3)
	await shot("sealed_sacks")
	Game.time_override = -1.0
	await frames(2)
	step("a save keeps it")
	var snap := SaveGame.snapshot(player().global_position, player().rotation.y)
	Game.quests.clear()
	await frames(3)
	check(house.baker().patrol.size() == house.baker_route(false).size() and house.woven() == 0 and not life.home_lamp().visible \
			and not camp.longline().visible and shop.boy().patrol.size() == shop.boy_route(false).size() \
			and quay.measurer().patrol.is_empty() and not quay.seals().visible, "a walk without errands keeps their marks")
	SaveGame.apply(snap)
	await frames(3)
	check(_done(house, life, camp, shop, quay), "a restored walk loses the marks of its errands")
