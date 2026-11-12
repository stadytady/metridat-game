extends "res://tests/test_case.gd"
## The volume setting: 0..1 on the Master bus, mute at zero, kept in the
## settings file, and a row for it in the pause menu.


func test_volume_goes_to_the_master_bus() -> void:
	var was := Game.master_volume
	var bus := AudioServer.get_bus_index(&"Master")
	check(is_equal_approx(Game.volume_db(1.0), 0.0), "full volume is %.1f dB" % Game.volume_db(1.0))
	check(Game.volume_db(0.5) < -5.0 and Game.volume_db(0.5) > -7.0, "half volume is %.1f dB" % Game.volume_db(0.5))
	Game.master_volume = 0.5
	Game.apply_volume()
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus), Game.volume_db(0.5)) and not AudioServer.is_bus_mute(bus), "half volume does not reach the bus")
	Game.master_volume = 0.0
	Game.apply_volume()
	check(AudioServer.is_bus_mute(bus), "zero volume does not mute")
	Game.master_volume = 1.7
	Game.apply_volume()
	check(AudioServer.get_bus_volume_db(bus) <= 0.01 and not AudioServer.is_bus_mute(bus), "volume over 1 boosts the bus")
	Game.master_volume = was
	Game.apply_volume()


func test_volume_is_saved_and_has_a_row_in_the_pause_menu() -> void:
	var game := FileAccess.get_file_as_string("res://scripts/core/game.gd")
	check(game.contains('cfg.set_value("audio", "master_volume", master_volume)'), "the volume is not written to the settings")
	check(game.contains('cfg.get_value("audio", "master_volume"'), "the volume is not read from the settings")
	var menu: CanvasLayer = load("res://scripts/ui/pause_menu.gd").new()
	Engine.get_main_loop().root.add_child(menu)
	var was := Game.master_volume
	Game.master_volume = 0.35
	menu.open()
	var shown: float = menu._vol.value
	var label: String = menu._vol_label.text
	menu.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.free()
	Game.master_volume = was
	check(is_equal_approx(shown, 0.35), "the slider opens at %.2f, the volume is 0.35" % shown)
	check(label.contains("35") and not label.contains("%d"), "the volume label reads '%s'" % label)
