extends "res://tests/qa/scenario.gd"
## The fisherman's errand from the middle of a walk: ask Glaukos, find the hook
## behind his boat on the sea side, bring it back. Starts at his camp with the
## finds before it already made, so it runs in seconds instead of the whole route.


func fixture() -> Dictionary:
	return {"found": 9, "hour": 0.45, "at": Vector2(56.0, 6.0), "look": Vector3(63.6, 1.0, 14.4)}


func run() -> void:
	step("ask")
	await walk_to(Vector2(63.6, 14.4))
	await take("hook")
	check(Game.quest_state("hook") == Quests.TAKEN, "the errand was not taken")
	step("find the hook")
	for p: Vector2 in [Vector2(64.3, 15.6), Vector2(66.4, 17.7), Vector2(68.4, 18.1)]:
		await walk_to(p)
	await pick("hook")
	step("bring it back")
	for p: Vector2 in [Vector2(66.4, 17.7), Vector2(64.3, 15.6), Vector2(63.6, 14.4)]:
		await walk_to(p)
	await give("hook")
	check(Game.quest_state("hook") == Quests.DONE, "the errand is not done: state %d" % Game.quest_state("hook"))
