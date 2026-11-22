extends "res://tests/test_case.gd"
## The credits page: the game, then the licences of what it ships that is not
## its own. Dialogue Manager's MIT text must be the addon's own, word for word;
## Godot's licence and its components come from the engine and must be there.

const PAUSE := preload("res://scripts/ui/pause_menu.gd")


func test_dialogue_manager_licence_is_the_addons_own() -> void:
	var own := FileAccess.get_file_as_string("res://addons/dialogue_manager/LICENSE").strip_edges()
	check(own != "", "the addon's LICENSE is missing")
	check(Licenses.DIALOGUE_MANAGER.strip_edges() == own, "the credits' Dialogue Manager licence differs from the addon's LICENSE")
	var cfg := ConfigFile.new()
	cfg.load("res://addons/dialogue_manager/plugin.cfg")
	check(Licenses.DIALOGUE_MANAGER_NAME.ends_with(String(cfg.get_value("plugin", "version", ""))), "the credits name another Dialogue Manager version")


func test_the_page_carries_every_licence() -> void:
	var menu: CanvasLayer = PAUSE.new()
	Engine.get_main_loop().root.add_child(menu)
	menu.show_keys()
	menu.show_credits()
	check(not menu._keys.visible and not menu._main.visible, "another page shows under the credits")
	var text := ""
	for l: Label in menu.find_children("*", "Label", true, false):
		text += l.text + "\n"
	check(text.contains("Permission is hereby granted"), "no MIT permission notice on the page")
	check(text.contains(Engine.get_license_text().strip_edges().split("\n")[0]), "Godot's licence is not on the page")
	check(text.contains("Nathan Hoad"), "Dialogue Manager's copyright is not on the page")
	var comps := Licenses.godot_components()
	check(comps.size() > 5, "Godot's third-party components are missing (%d)" % comps.size())
	check(text.contains(comps[0]), "Godot's components are not listed on the page")
	for name: String in Licenses.godot_component_licences():
		check(text.contains(name), "the %s licence text is not on the page" % name)
		break
	check(text.contains("UI_CREDITS_AUTHOR") or text.contains("stadytady"), "the game's own credits are missing")
	menu.free()


## CREDITS on the title opens this page alone; Back returns to the title, still
## holding the game (no captured mouse, no START), with CREDITS chosen again.
func test_the_title_opens_the_credits_and_gets_them_back() -> void:
	var menu: CanvasLayer = PAUSE.new()
	var title: CanvasLayer = load("res://scripts/ui/title_screen.gd").new()
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	root.add_child(menu)
	root.add_child(title)
	title.credits_requested.connect(menu.open_credits)
	menu.credits_closed.connect(title.back_from_credits)
	var events := []
	title.started.connect(func() -> void: events.append("started"))
	menu.closed.connect(func() -> void: events.append("closed"))
	title.open(false)
	title.finish_intro()
	title._credits.grab_focus()
	var ev := InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = true
	title._input(ev)
	check(menu.is_open() and menu._credits.visible and not menu._main.visible, "CREDITS does not show the credits page alone")
	check(title.is_open() and not title._root.visible, "the title shows through the credits or lets go of the game")
	title._input(ev)
	check(events.is_empty(), "a key behind the credits starts the walk")
	menu._credits_done()
	check(not menu.is_open() and title._root.visible, "Back does not return to the title")
	check(Game.ui_blocking and not root.get_tree().paused, "the title no longer holds the game after the credits")
	check(events.is_empty(), "closing the credits hands the game over: %s" % [events])
	check(root.get_viewport().gui_get_focus_owner() == title._credits, "CREDITS is not chosen on return")
	menu.free()
	title.free()
	Game.ui_blocking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
