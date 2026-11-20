extends "res://tests/qa/scenario.gd"
## People remember what the player found: with the lead anchor stock already
## picked up on the pier, Damon has a word about it (a choice that is not there
## before the find; test_dialogue checks that half).


func fixture() -> Dictionary:
	return {"found": ["anchor_stock"], "hour": 0.4, "at": Vector2(Topo.pier_x1() - 7.0, Topo.PIER_Z - 0.4)}


func run() -> void:
	step("ask about the anchor")
	await talk("sailor", "LOC_SAILOR_CHOICE_SAW", 3)
	check(Game.talked.get("sailor", false), "the talk with Damon did not finish")
