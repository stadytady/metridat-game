extends "res://tests/qa/scenario.gd"
## A day in town in a minute: a full square in the morning, a thin one at
## midday with two old men in the stoa's shade, then dusk - the donkeys gone
## from the street, a party behind a door on the Street of Jars with light,
## voices and a guest wandering with his lamp; and dolphins leaping out on the
## strait.


func fixture() -> Dictionary:
	return {"found": 1, "hour": 0.1, "at": Vector2(18.2, 0.0), "timeout": 200.0}


func _visible(nodes: Array) -> int:
	return nodes.filter(func(n: Node3D) -> bool: return n.visible).size()


func _wait_hour(atm: Node, past: float) -> void:
	var t := 0.0
	while float(atm.t) < past and t < 60.0:
		await seconds(0.5)
		t += 0.5


func run() -> void:
	var world: Node = main().world
	var town: TownDay = world.get_node("TownDay")
	var atm: Node = world.get_node("Atmosphere")
	step("a busy morning")
	await seconds(1.0)
	check(_visible(town._walkers) == TownDay.MARKET_FOLK.size(), "%d people cross the morning square" % _visible(town._walkers))
	check(_visible(town._sitters) == 0, "the old men sit out the busy morning")
	var donkey: Rider = town.get_node("Donkey0")
	var from := donkey.global_position
	await seconds(4.0)
	check(donkey.visible and donkey.global_position.distance_to(from) > 1.5, "the donkey stands still in the morning")
	check(absf(donkey.global_position.y - Topo.surface(donkey.global_position.x, donkey.global_position.z)) < 0.05, "the donkey walks off the paving")
	step("midday")
	Game.time_override = 0.46
	await _wait_hour(atm, 0.4)
	await seconds(0.5)
	check(_visible(town._walkers) == 1, "%d people cross the square at midday" % _visible(town._walkers))
	check(_visible(town._sitters) == 2, "the old men are not in the stoa's shade at midday")
	await view("stoa_shade")
	await shot("midday_shade")
	step("the party after dark")
	Game.time_override = 1.0
	await _wait_hour(atm, DayCycle.LAMPS_ON + 0.01)
	await seconds(0.5)
	check(town.night and town._party_light.visible and town._party_sound.playing, "no party after dark: light %s, voices %s" % [town._party_light.visible, town._party_sound.playing])
	check(town.guest().visible, "no guest wandering with his lamp")
	check(not donkey.visible, "the donkeys are still on the street at night")
	check(_visible(town._walkers) == 0 and _visible(town._sitters) == 0, "the square is not empty at night")
	await view("symposium")
	await shot("symposium")
	step("dolphins on the strait")
	await view("strait")
	var leapt := false
	var t := 0.0
	while t < 6.0:
		for d: Node3D in town._dolphins:
			if d.visible:
				leapt = true
		if leapt:
			break
		await frames(2)
		t += 2.0 / 60.0
	check(leapt, "no dolphin leapt in 6 s")
	await shot("strait")
