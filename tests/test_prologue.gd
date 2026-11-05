extends "res://tests/test_case.gd"
## The prologue: the arrival point is on the pier's planks, clear of the
## skipper and the cargo; its hour is dusk, between the last find's evening
## and the night; the talk's keys exist in both languages.


func test_arrival_on_the_pier_by_the_skipper() -> void:
	var p := Prologue.arrival_point()
	check(Topo.on_pier(p.x, p.z, 0.0), "the dreamer does not land on the pier: %s" % p)
	check(is_equal_approx(p.y, Topo.PIER_H), "not on the deck: y %.2f" % p.y)
	var s: Vector3 = load("res://scripts/world/harbour.gd").skipper_pos()
	var d := Vector2(p.x - s.x, p.z - s.z).length()
	check(d > 1.2 and d < 4.0, "too far from or too close to Damon: %.1f m" % d)
	# on the land side of him, so he is seen against the ship and the sea
	check(p.x < s.x, "the dreamer stands seaward of Damon")


func test_prologue_hour_is_dusk() -> void:
	check(DayCycle.PROLOGUE > 0.7 and DayCycle.PROLOGUE < 0.95, "the prologue is not at dusk: %.2f" % DayCycle.PROLOGUE)
	var dusk := DayCycle.sample(DayCycle.PROLOGUE)
	var day := DayCycle.sample(0.0)
	check(dusk.sun_energy < day.sun_energy, "dusk is as bright as the day")


func test_prologue_hour_comes_from_the_game() -> void:
	var was := Game.prologue
	Game.prologue = true
	check(is_equal_approx(Game.time_target(), DayCycle.PROLOGUE), "Game.time_target ignores the prologue")
	Game.prologue = false
	check(not is_equal_approx(Game.time_target(), DayCycle.PROLOGUE), "the prologue's hour stays after it")
	Game.prologue = was


func test_prologue_lines_are_translated() -> void:
	var text := FileAccess.get_file_as_string("res://data/dialogues/prologue.dialogue")
	var keys := PackedStringArray()
	for line in text.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("Damon: "):
			keys.append(t.substr(7))
		elif t.begins_with("- "):
			keys.append(t.substr(2))
	check(keys.size() >= 8, "the prologue is too short: %d keys" % keys.size())
	for k in keys:
		for lang in ["en", "ru"]:
			TranslationServer.set_locale(lang)
			check(tr(k) != k, "%s has no %s text" % [k, lang])
	TranslationServer.set_locale("en")
