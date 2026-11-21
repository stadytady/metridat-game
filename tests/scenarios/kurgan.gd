extends "res://tests/qa/scenario.gd"
## The Royal Kurgan out on the steppe: down from the park's end to its cut,
## a word with Xanthos, the corbel block on his pile, then in at the mouth and
## along the dromos to stand in the chamber under the dome, on its floor and not on the
## earth over it; the porter carries a block down to the pile; at dusk the
## workers go home and Xanthos stays.


func fixture() -> Dictionary:
	return {"found": 2, "hour": 0.3, "at": Vector2(-97.0, 24.0), "look": Vector3(-150.0, 26.0, 52.0)}


func run() -> void:
	var k: RoyalKurgan = main().world.find_child("RoyalKurgan", true, false)
	check(k != null, "no Royal Kurgan in the world")
	if k == null:
		return
	var c := Topo.KURGAN_CENTER
	var porter: Npc = null
	for w: Npc in k.workers():
		if w.npc_id == "kurgan_porter":
			porter = w
	check(porter != null, "no porter at the kurgan")
	var dropped := [false]
	if porter != null:
		porter.reached.connect(func(i: int) -> void:
			if i == RoyalKurgan.PORTER_DROP:
				dropped[0] = true)
	step("down the slope to the kurgan")
	check(await walk_to(Vector2(-126.0, 47.0)), "the slope down from the park does not let the player through")
	check(await walk_to(c + Vector2(25.0, -1.0)), "the player cannot reach the cut")
	await shot("kurgan_mouth")
	step("Xanthos at the mouth")
	await talk("builder")
	check(Game.talked.has("builder") or Game.talks.get("builder", 0) > 0, "Xanthos would not talk")
	step("the block on the pile")
	await walk_to(c + Vector2(24.9, 3.4))
	await inspect("corbel_block")
	check(Game.has_found("corbel_block"), "the corbel block was not found")
	step("along the dromos into the chamber")
	check(await walk_to(c + Vector2(20.0, 0.0)), "the cut is blocked")
	check(await walk_to(c + Vector2(RoyalKurgan.FACADE_X + 1.0, 0.0)), "the cut does not reach the front")
	check(await walk_to(c + Vector2(RoyalKurgan.dromos_x1() - 1.0, 0.0)), "the mouth in the front is blocked")
	check(await walk_to(c + Vector2(RoyalKurgan.CHAMBER_OUT + 0.5, 0.0)), "the dromos is blocked")
	check(await walk_to(c + Vector2(0.4, 0.3)), "the doorway into the chamber is blocked")
	var p := player().global_position
	check(RoyalKurgan.inside(p.x, p.z), "the player is not in the chamber: %s" % p)
	check(absf(p.y - Topo.KURGAN_H) < 0.4, "the player stands at %.2f, not on the chamber floor (%.2f)" % [p.y, Topo.KURGAN_H])
	look(Vector3(c.x, Topo.KURGAN_H + 8.0, c.y))
	await shot("kurgan_dome")
	step("the porter brings a block down")
	var t0 := Time.get_ticks_msec()
	while not dropped[0] and Time.get_ticks_msec() - t0 < 60000:
		await seconds(1.0)
	check(dropped[0], "the porter never brought a block to the pile")
	step("dusk")
	Game.time_override = DayCycle.LAMPS_ON + 0.05
	await seconds(1.5)
	for w: Npc in k.workers():
		check(not w.visible, "%s is still at work after dusk" % w.npc_id)
	check(k.builder().visible, "Xanthos has gone home too")
