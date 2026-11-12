extends "res://tests/qa/scenario.gd"
## Up the steps into the coin striker's room, a word with Sosias over the anvil:
## no blows while he talks, the hammer back to work when the talk ends.


func fixture() -> Dictionary:
	return {"found": 4, "hour": 0.3, "at": Vector2(-1.0, 2.6)}


func run() -> void:
	var mint: Mint = main().world.find_child("Mint", true, false)
	step("he works")
	var before := mint.hits
	await seconds(3.0)
	check(mint.hits > before, "no blows in 3 s by day")
	step("in at the door")
	await walk_to(Vector2(-1.0, 6.0))
	await shot("at_the_anvil")
	step("talk")
	await talk("striker", "", 2)
	check(Game.talked.get("striker", false), "the talk with the striker did not finish")
	step("back to work")
	before = mint.hits
	await seconds(4.0)
	check(mint.hits > before, "the hammer stays down after the talk")
