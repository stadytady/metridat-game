extends "res://tests/qa/scenario.gd"
## The player strikes staters at Sosias's anvil: asks him in the talk, takes the
## hammer once the talk closes, three blows on his mark make three crisp coins
## and earn his hand; he holds the punch (no hammer of his own) meanwhile, and
## B gives the hammer back.


func fixture() -> Dictionary:
	return {"found": 4, "hour": 0.3, "at": Vector2(-1.0, 2.6)}


func run() -> void:
	var mint: Mint = main().world.find_child("Mint", true, false)
	step("ask him")
	await walk_to(Vector2(-1.0, 6.0))
	await talk("striker", "LOC_STRIKER_CHOICE_4", 2)
	step("the hammer")
	var t := 0.0
	while mint.mint_panel == null and t < 3.0:
		await seconds(0.1)
		t += 0.1
	var panel: CanvasLayer = mint.mint_panel
	check(panel != null and panel.is_open(), "the anvil did not open after the talk")
	if panel == null:
		return
	await shot("blanks_on_the_anvil")
	var coins: Array[String] = []
	panel.struck.connect(func(q: String) -> void: coins.append(q))
	step("three blows")
	# a run before this one may have earned it already: the check must see it earned now
	Achievements.unlocked.erase("ACH_CRISP_STATER")
	var hits := mint.hits
	for i in MintGame.BLANKS:
		panel.key(false, false)
		var w := 0.0
		while MintGame.grade(MintGame.needle(panel.game.clock), MintGame.mark(panel.game.clock, i)) != MintGame.TRUE and w < 5.0:
			await frames(1)
			w += 1.0 / 60.0
		panel.key(true, true)
		await frames(2)
	await shot("three_coins")
	check(coins == ["crisp", "crisp", "crisp"], "three blows on the mark made %s" % [coins])
	check(mint.hits == hits, "Sosias kept hammering while the player struck")
	check(Achievements.is_unlocked("ACH_CRISP_STATER"), "a crisp stater did not earn Sosias's hand")
	step("give the hammer back")
	await pad_button(JOY_BUTTON_B)
	await frames(3)
	check(mint.mint_panel == null and not Game.ui_blocking, "B did not leave the anvil")
