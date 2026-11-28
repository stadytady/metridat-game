extends "res://tests/qa/scenario.gd"
## A storm over the harbour and the steppe: the carrier, the porters and the
## dockers go under cover, the splicer gets up to mind the Swallow's stern line,
## her lines are hauled in, the net comes off the rack, the flock draws
## together and the riders leave the track; dry again, all of it goes back.


func fixture() -> Dictionary:
	return {"found": 8, "hour": 0.4, "at": Vector2(22.0, 2.0), "look": Vector3(0.0, 6.0, 0.0)}


func _away() -> void:
	# on the agora, looking up the street: the shore and the steppe are out of view
	player().global_position = Vector3(22.0, Topo.AGORA_H, 2.0)
	look(Vector3(0.0, 6.0, 0.0))
	await seconds(0.5)


func run() -> void:
	var harbour: Node = tree().get_first_node_in_group(&"harbour")
	var quay: GrainQuay = main().world.find_child("GrainQuay", true, false)
	var arr: Arrival = main().world.find_child("Arrival", true, false)
	var camp: Node = main().world.find_child("FishingCamp", true, false)
	var steppe: Node = main().world.find_child("Steppe", true, false)
	var scy: Node = main().world.find_child("Scythians", true, false)
	check(harbour != null and quay != null and arr != null and camp != null and steppe != null and scy != null, "a district is missing")
	if harbour == null or quay == null or arr == null or camp == null or steppe == null or scy == null:
		return
	var sheep: Array = steppe.get_children().filter(func(c: Node) -> bool: return c is Sheep)
	var roam: Array = sheep.map(func(s: Sheep) -> float: return s.radius)
	check(arr.dockers().all(func(d: Npc) -> bool: return d.visible), "the dockers are not at work before the storm")
	step("the storm comes")
	Game.weather_override = Weather.STORM
	await _away()
	check(not harbour.carrier().visible, "the carrier still carries in the storm")
	check(not harbour.splicer().visible and harbour.minder().visible, "nobody minds the line in the storm")
	check(quay.porters().all(func(p: Npc) -> bool: return not p.visible), "the porters still carry in the storm")
	check(arr.dockers().all(func(d: Npc) -> bool: return not d.visible), "the dockers still carry in the storm")
	check(not camp.net().visible, "the net is still on the rack in the storm")
	var tighter := true
	for i in sheep.size():
		tighter = tighter and (sheep[i] as Sheep).radius < float(roam[i]) * 0.6
	check(tighter, "the flock does not draw together")
	check(scy.get_children().filter(func(c: Node) -> bool: return c is Rider and c.visible).is_empty(), "the riders stay out in the storm")
	step("on the pier in the storm")
	player().global_position = Vector3(60.6, Topo.surface(60.6, -3.0), -3.0)
	await seconds(0.2)
	await walk_to(Vector2(62.0, -7.6))
	await walk_to(Vector2(Topo.pier_x0() - 1.0, Topo.PIER_Z))
	await walk_to(Vector2(78.0, Topo.PIER_Z))
	look(harbour.minder().global_position + Vector3(0, 1.0, 0))
	await seconds(0.3)
	check(harbour.minder().visible, "the line minder vanished in front of the player")
	await shot("minding_the_line")
	step("dry again")
	Game.weather_override = Weather.DRY
	await seconds(0.5)
	check(harbour.minder().visible, "the minder vanishes while the player watches")
	await _away()
	check(harbour.carrier().visible and harbour.splicer().visible and not harbour.minder().visible, "the harbour does not go back to work")
	check(quay.porters().all(func(p: Npc) -> bool: return p.visible), "the porters do not come back")
	check(arr.dockers().all(func(d: Npc) -> bool: return d.visible), "the dockers do not come back")
	check(camp.net().visible, "the net is not hung out again")
	var back := true
	for i in sheep.size():
		back = back and is_equal_approx((sheep[i] as Sheep).radius, float(roam[i]))
	check(back, "the flock stays huddled in the dry")
	check(scy.get_children().filter(func(c: Node) -> bool: return c is Rider and not c.visible).is_empty(), "the riders do not come back")
	Game.weather_override = -1
