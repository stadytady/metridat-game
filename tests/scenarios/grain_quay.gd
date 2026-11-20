extends "res://tests/qa/scenario.gd"
## The wheat for the Swallow: the porters carry sacks from the measurer's stack
## to the pile on the pier; Nikon asks after his seal ring, the agreement lies
## on his crate, the ring up the path, back to him with it.


func fixture() -> Dictionary:
	return {"found": 10, "hour": 0.5, "at": Vector2(56.0, 6.0), "look": Vector3(63.0, 2.0, -9.0)}


func run() -> void:
	var quay: GrainQuay = main().world.find_child("GrainQuay", true, false)
	check(quay != null, "no grain quay in the world")
	if quay == null:
		return
	step("the porters carry")
	var dropped := {}
	for p: Npc in quay.porters():
		var start := p.name.trim_prefix("Porter").to_int()
		var first: int = GrainQuay.PORTERS[start][1]
		p.reached.connect(func(k: int) -> void:
			if posmod(k + first, GrainQuay.PORTER_ROUTE.size()) == GrainQuay.PORTER_DROP:
				dropped[p.name] = true)
	await walk_to(Vector2(60.6, -3.0))
	await walk_to(Vector2(62.0, -7.6))
	await shot("the_heap")
	step("ask Nikon")
	await take("seal")
	check(Game.quest_state("seal") == Quests.TAKEN, "the errand was not taken")
	step("the agreement on the crate")
	await walk_to(Vector2(61.9, -8.8))
	await inspect("loan_contract")
	check(Game.has_found("loan_contract"), "the loan agreement was not found")
	step("the ring up the path")
	await walk_to(Vector2(62.0, -7.6))
	await walk_to(Vector2(60.9, -4.9))
	await pick("seal")
	await walk_to(Vector2(62.0, -7.6))
	await give("seal")
	check(Game.quest_state("seal") == Quests.DONE, "the errand is not done: state %d" % Game.quest_state("seal"))
	var t0 := Time.get_ticks_msec()
	while dropped.is_empty() and Time.get_ticks_msec() - t0 < 40000:
		await seconds(1.0)
	check(not dropped.is_empty(), "no porter put a sack on the pile")
