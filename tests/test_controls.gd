extends "res://tests/test_case.gd"
## The controls: a moved key swaps with whoever had it and survives a restart;
## the fixed keys stay fixed; every action is on the pad too; texts name the
## key of the device in hand; the right stick aims finely and turns round; the
## pause menu takes a new key and the field of view.

const CSV := "res://data/i18n/strings.csv"
const TEST_SETTINGS := "user://test_settings.cfg"


func _event_key(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.pressed = true
	return ev


func test_a_moved_key_swaps_and_no_key_does_two_things() -> void:
	var b := Keys.rebind({}, &"interact", KEY_J)
	check(int(b.get(&"interact", -1)) == KEY_J and int(b.get(&"journal", -1)) == KEY_E, "E and J did not swap: %s" % [b])
	var used := {}
	for a: StringName in Keys.DEFAULT_KEYS:
		var k := int(b.get(a, Keys.DEFAULT_KEYS[a]))
		check(not used.has(k), "%s and %s share a key" % [a, used.get(k)])
		used[k] = a
	for k: Key in [KEY_ESCAPE, KEY_UP, KEY_QUOTELEFT, KEY_F3]:
		check(Keys.rebind({}, &"jump", k).is_empty(), "jump took the fixed key %s" % OS.get_keycode_string(k))


func test_the_input_map_follows_the_keys_and_keeps_the_pad() -> void:
	Keys.setup({&"interact": KEY_F})
	var on_f := InputMap.event_is_action(_event_key(KEY_F), &"interact")
	var on_e := InputMap.event_is_action(_event_key(KEY_E), &"interact")
	var arrows := InputMap.event_is_action(_event_key(KEY_UP), &"move_forward")
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	var pad_a := InputMap.event_is_action(a, &"interact")
	var keys_on_interact := InputMap.action_get_events(&"interact").filter(func(e: InputEvent) -> bool: return e is InputEventKey).size()
	Keys.setup(Game.key_binds)
	check(on_f and not on_e, "interact moved to F: F %s, E %s" % [on_f, on_e])
	check(keys_on_interact == 1, "interact has %d keys after a move" % keys_on_interact)
	check(arrows, "the arrows stopped walking")
	check(pad_a, "the pad's A stopped using")


func test_every_action_is_on_the_pad() -> void:
	for a: StringName in Keys.DEFAULT_KEYS.keys() + [&"pause", &"back"]:
		var pad := InputMap.action_get_events(a).any(func(e: InputEvent) -> bool:
			return e is InputEventJoypadButton or e is InputEventJoypadMotion)
		check(pad, "%s has no button on the pad" % a)
	for a: StringName in [&"look_left", &"look_right", &"look_up", &"look_down"]:
		check(InputMap.has_action(a) and InputMap.action_get_events(a).any(func(e: InputEvent) -> bool: return e is InputEventJoypadMotion),
				"%s is not on the right stick" % a)
	for a: StringName in [&"ui_accept", &"ui_up", &"ui_down"]:
		check(InputMap.action_get_events(a).any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton),
				"the menus cannot be walked with the pad: %s" % a)


func test_texts_name_the_key_in_hand() -> void:
	check(Keys.fill("[{use}] x [{back}]", {}, false) == "[E] x [ESC]", Keys.fill("[{use}] x [{back}]", {}, false))
	check(Keys.fill("[{use}] x [{back}]", {}, true) == "[A] x [B]", Keys.fill("[{use}] x [{back}]", {}, true))
	check(Keys.fill("[{use}]", {&"interact": KEY_F}, false) == "[F]", "a moved key is not named")
	# no text still says E or Esc in so many words, and every placeholder is known
	var f := FileAccess.open(CSV, FileAccess.READ)
	var re := RegEx.create_from_string("\\{[a-z]+\\}")
	while f != null and not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 3 or not row[0].begins_with("UI_") or row[0] == "UI_HINT" or row[0] == "UI_ADMIN_KEYS":
			continue
		for t: String in [row[1], row[2]]:
			check(not ("[E]" in t or "[ESC]" in t or "[J]" in t or "[TAB]" in t), "%s still names a key outright: %s" % [row[0], t])
			for m in re.search_all(t):
				check(Keys.TOKENS.has(m.get_string()), "%s has an unknown placeholder %s" % [row[0], m.get_string()])


func test_a_label_follows_the_device() -> void:
	var was := Game.pad
	var l := Label.new()
	Game.set_pad(false)
	Keys.bind(l, "UI_DIALOGUE_KEYS")
	var keys := l.text
	Game.set_pad(true)
	var pads := l.text
	Game.set_pad(was)
	l.free()
	check("[E]" in keys and "[ESC]" in keys, "on the keyboard the hint reads %s" % keys)
	check("[A]" in pads and "[B]" in pads, "with the pad the hint reads %s" % pads)


func test_the_stick_aims_finely_and_turns_round() -> void:
	const P := preload("res://scripts/player/player.gd")
	check(P.stick_look(Vector2.ZERO, 1.0, 0.016) == Vector2.ZERO, "a resting stick turns")
	var full := P.stick_look(Vector2(1, 0), 1.0, 1.0).x
	var half := P.stick_look(Vector2(0.5, 0), 1.0, 1.0).x
	check(is_equal_approx(full, P.STICK_TURN), "full tilt turns %.2f rad/s" % full)
	check(half < full * 0.3, "half tilt turns %.2f of full: no fine aim" % (half / full))
	check(P.stick_look(Vector2(1, 0), 2.0, 1.0).x > full * 1.9, "the sensitivity does not reach the stick")


## The settings file keeps a moved key and the field of view, and a broken file
## (a key on Esc) does not take Esc.
func test_keys_and_fov_survive_a_restart() -> void:
	var kept := {"path": Game.settings_path, "binds": Game.key_binds.duplicate(), "fov": Game.fov}
	Game.settings_path = TEST_SETTINGS
	Game.key_binds = Keys.rebind({}, &"jump", KEY_C)
	Game.fov = 90.0
	Game.save_settings()
	Game.key_binds = {}
	Game.fov = 72.0
	Game.load_settings()
	var jump := Game.key_for(&"jump")
	var fov := Game.fov
	var cfg := ConfigFile.new()
	cfg.load(TEST_SETTINGS)
	cfg.set_value("keys", "interact", KEY_ESCAPE)
	cfg.save(TEST_SETTINGS)
	Game.load_settings()
	var interact := Game.key_for(&"interact")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	Game.settings_path = kept.path
	Game.key_binds = kept.binds
	Game.fov = kept.fov
	Keys.setup(Game.key_binds)
	Game.load_settings()
	check(jump == KEY_C, "jump came back on %s" % OS.get_keycode_string(jump))
	check(is_equal_approx(fov, 90.0), "the field of view came back as %.0f" % fov)
	check(interact == KEY_E, "a settings file put interact on %s" % OS.get_keycode_string(interact))


func test_the_pause_menu_takes_a_new_key() -> void:
	var kept := {"path": Game.settings_path, "binds": Game.key_binds.duplicate()}
	Game.settings_path = TEST_SETTINGS
	var menu: CanvasLayer = load("res://scripts/ui/pause_menu.gd").new()
	Engine.get_main_loop().root.add_child(menu)
	menu.show_keys()
	menu.listen(&"interact")
	var asking: String = menu._key_buttons[&"interact"].text
	# a fixed key is not taken, Esc keeps the old one
	menu._input(_event_key(KEY_UP))
	var still_waiting: bool = menu.waiting == &"interact"
	menu._input(_event_key(KEY_ESCAPE))
	var kept_e: bool = Game.key_for(&"interact") == KEY_E and menu.waiting == &""
	menu.listen(&"interact")
	menu._input(_event_key(KEY_G))
	var moved := Game.key_for(&"interact") == KEY_G
	var shown: String = menu._key_buttons[&"interact"].text
	menu.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	Game.settings_path = kept.path
	Game.key_binds = kept.binds
	Keys.setup(Game.key_binds)
	Game.load_settings()
	check(asking == tr("UI_PRESS_KEY"), "the button does not ask for a key: %s" % asking)
	check(still_waiting, "the menu took the arrow key or stopped listening")
	check(kept_e, "Esc did not keep E")
	check(moved and shown == "G", "the key did not move to G (button %s)" % shown)
