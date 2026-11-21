extends "res://tests/qa/scenario.gd"
## Captions for sounds: off by default, nothing is written; turned on in the
## middle of a shower, the HUD writes the rain over the key strip.


func fixture() -> Dictionary:
	return {"found": 6, "weather": 1, "hour": 0.38, "at": Vector2(9.0, 0.0), "look": Vector3(30.0, 2.0, 3.0)}


func run() -> void:
	var hud: Node = main().get_node("HUD")
	var was := Game.captions
	step("captions off")
	Game.captions = false
	await seconds(1.5)
	check(hud.caption_text() == "", "a caption with captions off: %s" % hud.caption_text())
	step("captions on")
	Game.captions = true
	var t0 := Time.get_ticks_msec()
	while hud.caption_text() == "" and Time.get_ticks_msec() - t0 < 5000:
		await seconds(0.2)
	check(hud.caption_text() == tr("CAP_RAIN"), "the rain is not captioned: '%s'" % hud.caption_text())
	await shot("rain_caption")
	Game.captions = was
