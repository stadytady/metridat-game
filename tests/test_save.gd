extends "res://tests/test_case.gd"
## A saved walk: written and read back as it was, put back quietly (no find
## panel, no catch of a flame), a lamp known by where it stands; the title offers
## Continue and New walk only when there is one; automation never writes.

const PATH := "user://test_save.cfg"


func _keep() -> Dictionary:
	return {"found": Game.found.duplicate(), "talked": Game.talked.duplicate(), "talks": Game.talks.duplicate(), "quests": Game.quests.duplicate()}


func _back(k: Dictionary) -> void:
	Game.found = k.found
	Game.talked = k.talked
	Game.talks = k.talks
	Game.quests = k.quests


func test_a_walk_is_written_and_read_back() -> void:
	var data := {"version": SaveGame.VERSION, "found": [&"coin_stater", &"sherd_kerch"], "talked": {"potter": true},
		"talks": {"potter": 2}, "quests": {"hook": Quests.FOUND}, "lamps": ["10,52,-3"], "pos": Vector3(4.5, 5.2, -1.0), "yaw": 1.25}
	check(SaveGame.write(data, PATH) == OK, "the save is not written")
	var back := SaveGame.read(PATH)
	check((back.pos as Vector3).is_equal_approx(data.pos) and is_equal_approx(float(back.yaw), 1.25), "the place does not come back: %s" % [back])
	check(Array(back.found).size() == 2 and int((back.quests as Dictionary)["hook"]) == Quests.FOUND, "the finds or errands do not come back: %s" % [back])
	check(SaveGame.exists(PATH), "a written save does not exist")
	# another version is not read as this one
	data.version = SaveGame.VERSION + 1
	SaveGame.write(data, PATH)
	check(SaveGame.read(PATH).is_empty(), "a save of another version is read")
	SaveGame.erase(PATH)
	check(not SaveGame.exists(PATH), "an erased save is still there")


func test_a_walk_is_put_back_quietly() -> void:
	var kept := _keep()
	var lamp: Lamp = load("res://scenes/interactables/lamp.tscn").instantiate()
	lamp.position = Vector3(1.0, 5.2, -0.3)
	Engine.get_main_loop().root.add_child(lamp)
	var panels := [0]
	var on_find := func(_d: Discovery, _n: bool) -> void: panels[0] += 1
	var lit_signals := [0]
	var on_lit := func(_l: int, _t: int) -> void: lit_signals[0] += 1
	Game.discovered.connect(on_find)
	Game.lamp_lit.connect(on_lit)
	var restored := [false]
	var on_restored := func() -> void: restored[0] = true
	Game.state_restored.connect(on_restored)
	SaveGame.apply({"found": [&"coin_stater"], "talked": {"potter": true}, "talks": {"potter": 2},
		"quests": {"hook": Quests.FOUND}, "lamps": [SaveGame.lamp_key(lamp.global_position)]})
	var ok_state: bool = Game.found.has(&"coin_stater") and Game.talked.get("potter", false) and Game.quest_state("hook") == Quests.FOUND
	var lit := lamp.lit
	var silent := not lamp.just_caught()
	Game.discovered.disconnect(on_find)
	Game.lamp_lit.disconnect(on_lit)
	Game.state_restored.disconnect(on_restored)
	lamp.free()
	_back(kept)
	check(ok_state, "the finds, talks or errands are not put back")
	check(lit and silent, "the saved lamp is not lit, or it caught with a sound")
	check(panels[0] == 0 and lit_signals[0] == 0, "putting the walk back fired %d find panels and %d lamp signals" % [panels[0], lit_signals[0]])
	check(restored[0], "nothing hears that the walk came back")


## A save naming a find this version does not have counts it for nothing.
func test_a_find_the_world_no_longer_has_does_not_count() -> void:
	var kept := _keep()
	var before := Game.found_count()
	Game.found[&"a_find_long_gone"] = true
	var after := Game.found_count()
	_back(kept)
	check(after == before, "a find the world does not have counted: %d -> %d" % [before, after])


func test_the_title_offers_continue_only_with_a_save() -> void:
	var title: CanvasLayer = load("res://scripts/ui/title_screen.gd").new()
	Engine.get_main_loop().root.add_child(title)
	title.open(false)
	var fresh: bool = title._start.text == "UI_START" and not title._new.visible
	title.open(true)
	var saved: bool = title._start.text == "UI_CONTINUE" and title._new.visible
	var which := [""]
	title.started.connect(func() -> void: which[0] = "started")
	title.continued.connect(func() -> void: which[0] = "continued")
	title.start()
	title.free()
	Game.ui_blocking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	check(fresh, "the title offers Continue with no save")
	check(saved, "the title does not offer Continue and New walk with a save")
	check(which[0] == "continued", "START on a saved walk does not continue it (%s)" % which[0])


## Arrowed onto "New walk", Enter starts over (and forgets the save): it must
## not continue the old walk.
func test_enter_on_new_walk_starts_over() -> void:
	SaveGame.write({"version": SaveGame.VERSION, "found": []}, PATH)
	var title: CanvasLayer = load("res://scripts/ui/title_screen.gd").new()
	Engine.get_main_loop().root.add_child(title)
	title.save_path = PATH
	title.open(true)
	title._new.grab_focus()
	var which := [""]
	title.started.connect(func() -> void: which[0] = "started")
	title.continued.connect(func() -> void: which[0] = "continued")
	var ev := InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = true
	title._input(ev)
	var gone := not SaveGame.exists(PATH)
	title.free()
	Game.ui_blocking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SaveGame.erase(PATH)
	check(which[0] == "started", "Enter on New walk did %s" % which[0])
	check(gone, "New walk did not forget the saved walk")


func test_automation_never_writes_a_save() -> void:
	# the player's own save (if a developer has one) is left alone: only check
	# that nothing new is written
	var before := FileAccess.get_modified_time(SaveGame.PATH) if FileAccess.file_exists(SaveGame.PATH) else -1
	var main: Node = load("res://scripts/core/main.gd").new()
	main.save_now()  # not started: as in shots, walkthrough, trailer
	var after := FileAccess.get_modified_time(SaveGame.PATH) if FileAccess.file_exists(SaveGame.PATH) else -1
	main.free()
	check(after == before, "a save was written without a walk being played")
