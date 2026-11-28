extends "res://tests/qa/scenario.gd"
## A shower over the town: the people crossing the square go into the stoa,
## the stall's goods are covered, the washing comes in, puddles spread on the
## paving, the rain drums on the stoa's roof and the market goes quiet; when it
## is dry again everything is back as it was. The changes wait until the player
## is not looking, so the bot steps off to the shore and back between them.


func fixture() -> Dictionary:
	return {"found": 6, "hour": 0.3, "at": Vector2(20.0, 2.0), "look": Vector3(22.0, 6.0, -8.0)}


func _away() -> void:
	# off to the shore, looking out to sea: the square and the street are behind
	player().global_position = Vector3(66.0, Topo.surface(66.0, 8.0), 8.0)
	look(Vector3(120.0, 2.0, 8.0))
	await seconds(0.5)


func _back() -> void:
	player().global_position = Vector3(20.0, Topo.AGORA_H, 2.0)
	look(Vector3(22.0, 6.0, -8.0))
	await seconds(0.5)


func run() -> void:
	var td: TownDay = main().world.find_child("TownDay", true, false)
	var wt: WeatherTown = main().world.find_child("WeatherTown", true, false)
	var life: Node = main().world.find_child("Life", true, false)
	var agora: Node = main().world.find_child("Agora", true, false)
	check(td != null and wt != null and life != null and agora != null, "a district is missing")
	if td == null or wt == null or life == null or agora == null:
		return
	var out := td.walkers().filter(func(n: Npc) -> bool: return n.visible).size()
	check(out > 0, "nobody crosses the square at this hour")
	step("the shower comes, the player looking on")
	var watched := td.walkers().filter(func(n: Npc) -> bool: return n.visible and not Weather.unseen(n))
	Game.weather_override = Weather.SHOWER
	await seconds(0.5)
	check(watched.all(func(n: Npc) -> bool: return n.visible), "people vanish from the square in front of the player")
	step("the town takes cover while nobody looks")
	await _away()
	var cover := td.sheltering().filter(func(n: Npc) -> bool: return n.visible).size()
	check(cover == out, "%d of %d people are in the stoa" % [cover, out])
	check(td.walkers().all(func(n: Npc) -> bool: return not n.visible), "someone still crosses the square in the rain")
	check(life.cloths().all(func(c: Node3D) -> bool: return not c.visible), "the washing is still out in the rain")
	check(agora.find_child("StallCover", true, false).visible, "the stall's goods are not covered")
	check(wt.puddles().all(func(p: MeshInstance3D) -> bool: return p.visible), "no puddles on the paving")
	await _back()
	check(wt.roof_players()[0].playing, "the rain does not drum on the stoa's roof")
	var market: AudioStreamPlayer3D = main().world.get_node("Ambience/Market")
	check(market.volume_db < WeatherTown.MARKET_DB - 6.0, "the market is as loud in the rain: %.1f dB" % market.volume_db)
	await shot("under_the_stoa")
	step("dry again")
	Game.weather_override = Weather.DRY
	await _away()
	await _back()
	check(td.walkers().filter(func(n: Npc) -> bool: return n.visible).size() == out, "the people do not come back out")
	check(td.sheltering().all(func(n: Npc) -> bool: return not n.visible), "someone stays in the stoa in the dry")
	check(life.cloths().all(func(c: Node3D) -> bool: return c.visible), "the washing is not hung out again")
	check(not agora.find_child("StallCover", true, false).visible, "the stall stays covered")
	check(wt.puddles().all(func(p: MeshInstance3D) -> bool: return not p.visible), "puddles in the dry")
	check(not wt.roof_players()[0].playing, "the roof drums in the dry")
	Game.weather_override = -1
