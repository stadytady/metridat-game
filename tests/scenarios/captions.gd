extends "res://tests/qa/scenario.gd"
## Captions for sounds: off by default, nothing is written; turned on in the
## middle of a shower, the rain is captioned. Other sounds may caption too
## (the agora is not silent), so the check is that the rain was among them and
## that the HUD wrote what was asked, not which line happened to come last.


func fixture() -> Dictionary:
	return {"found": 6, "weather": 1, "hour": 0.38, "at": Vector2(22.0, 3.0), "look": Vector3(30.0, 2.0, 3.0)}


func run() -> void:
	var hud: Node = main().get_node("HUD")
	var was := Game.captions
	step("captions off")
	Game.captions = false
	await seconds(1.5)
	check(hud.caption_text() == "", "a caption with captions off: %s" % hud.caption_text())
	step("captions on")
	var asked: Array[String] = []
	var on_caption := func(k: String) -> void: asked.append(k)
	Game.caption_requested.connect(on_caption)
	Game.captions = true
	var t0 := Time.get_ticks_msec()
	while not asked.has("CAP_RAIN") and Time.get_ticks_msec() - t0 < 5000:
		await seconds(0.2)
	check(asked.has("CAP_RAIN"), "the rain is not captioned (asked: %s)" % [asked])
	check(hud.caption_text() == tr(asked[-1]) if not asked.is_empty() else false, "the HUD does not show the last caption: '%s'" % hud.caption_text())
	Game.caption_requested.disconnect(on_caption)
	await shot("rain_caption")
	Game.captions = was
