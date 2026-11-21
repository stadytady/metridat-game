extends "res://tests/test_case.gd"
## Comfort settings: camera sway can be turned off, every UI text follows the
## text size (and redraws when it changes), captions come only when asked for,
## near enough and not over and over; the settings survive a restart.

const PATH := "user://test_accessibility.cfg"
const PLAYER := preload("res://scripts/player/player.gd")


func _with_settings(body: Callable) -> void:
	var was := [Game.settings_path, Game.head_bob, Game.captions, Game.text_scale]
	Game.settings_path = PATH
	body.call()
	Game.settings_path = was[0]
	Game.head_bob = was[1]
	Game.captions = was[2]
	Game.text_scale = was[3]
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_settings_survive_a_restart() -> void:
	_with_settings(func() -> void:
		Game.head_bob = false
		Game.captions = true
		Game.text_scale = 1.3
		Game.save_settings()
		Game.head_bob = true
		Game.captions = false
		Game.text_scale = 1.0
		Game.load_settings()
		check(not Game.head_bob, "camera sway came back on after a restart")
		check(Game.captions, "captions went off after a restart")
		check(is_equal_approx(Game.text_scale, 1.3), "text size not kept: %.2f" % Game.text_scale))


func test_camera_sway_turns_off() -> void:
	var was := Game.head_bob
	Game.head_bob = true
	check(PLAYER.camera_motion() == 1.0, "no sway with sway on")
	Game.head_bob = false
	check(PLAYER.camera_motion() == 0.0, "the camera still sways with sway off")
	Game.head_bob = was


func test_text_follows_the_size() -> void:
	var was := Game.text_scale
	Game.text_scale = 1.0
	var l := UiStyle.label("UI_PAUSED", 30)
	var b := UiStyle.button("UI_RESUME")
	var holder := Control.new()
	holder.add_child(l)
	holder.add_child(b)
	check(l.get_theme_font_size("font_size") == 30, "a label is not drawn at its size")
	Game.text_scale = 1.4
	UiStyle.rescale(holder)
	check(l.get_theme_font_size("font_size") == 42, "a label did not grow with the text size: %d" % l.get_theme_font_size("font_size"))
	check(b.get_theme_font_size("font_size") == roundi(26 * 1.4), "a button did not grow with the text size")
	var fresh := UiStyle.label("UI_PAUSED", 20)
	check(fresh.get_theme_font_size("font_size") == 28, "a new label ignores the text size")
	fresh.free()
	holder.free()
	Game.text_scale = was


func test_ui_sizes_go_through_the_style() -> void:
	# a font size set by hand would not follow the text size setting
	for dir: String in ["res://scripts/ui", "res://scripts/core"]:
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd") or f == "ui_style.gd" or f == "trailer.gd":
				continue
			var text := FileAccess.get_file_as_string(dir.path_join(f))
			check(not text.contains("add_theme_font_size_override"), "%s sets a font size outside UiStyle.font()" % f)


func test_captions_only_when_asked_near_and_not_repeated() -> void:
	var was := Game.captions
	var heard: Array[String] = []
	var on_caption := func(k: String) -> void: heard.append(k)
	Game.caption_requested.connect(on_caption)
	var here := Vector3(10, 0, 10)
	Game.captions = false
	check(not Game.caption("CAP_TEST_A", here, 5.0, 7000, here), "a caption with captions off")
	Game.captions = true
	check(Game.caption("CAP_TEST_A", here + Vector3(3, 0, 0), 5.0, 7000, here), "no caption close by")
	check(not Game.caption("CAP_TEST_A", here, 5.0, 7000, here), "the same caption again at once")
	check(Game.caption("CAP_TEST_B", here, 5.0, 7000, here), "another sound's caption is held back")
	check(not Game.caption("CAP_TEST_C", here + Vector3(30, 0, 0), 5.0, 7000, here), "a caption from far off")
	check(heard == ["CAP_TEST_A", "CAP_TEST_B"], "heard %s" % [heard])
	Game.caption_requested.disconnect(on_caption)
	Game.captions = was


func test_every_caption_is_translated() -> void:
	var csv := FileAccess.get_file_as_string("res://data/i18n/strings.csv")
	var keys: Array[String] = ["CAP_STRIKE", "CAP_SYMPOSIUM", "CAP_CHORUS", "CAP_RAIN"]
	for kind: String in StreetVoices.SOUNDS:
		keys.append(StreetVoices.caption_key(kind))
	for k in keys:
		check(csv.contains("\n" + k + ","), "caption %s has no text" % k)
