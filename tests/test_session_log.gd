extends "res://tests/test_case.gd"
## The playtest log: one file per walk, every line flushed as it happens, the
## finds, places and lamps in it, a stop of more than half a minute noted, the
## oldest logs pruned; and the version it names is the one the README offers.

const DIR := "user://test_sessions"


func _clean() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		for f: String in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR + "/" + f)


func test_a_walk_is_written_down() -> void:
	_clean()
	var player := Node3D.new()
	Engine.get_main_loop().root.add_child(player)
	player.global_position = Vector3(10, 5, -3)
	var log := SessionLog.new()
	Engine.get_main_loop().root.add_child(log)
	log.begin("new", player, DIR)
	check(log.path.begins_with(DIR), "the log is not in its folder: " + log.path)
	Game.location_entered.emit("LOC_AGORA")
	Game.lamp_lit.emit(3, 12)
	# standing still past STILL_AFTER, then walking off
	for i in int(SessionLog.STILL_AFTER) + 2:
		log._process(1.0)
	player.global_position += Vector3(5, 0, 0)
	log._process(0.1)
	# flushed: readable before the walk ends
	var mid := FileAccess.get_file_as_string(log.path)
	check(mid.contains("\tplace\tLOC_AGORA"), "a place entered is not in the log")
	check(mid.contains("\tlamp\t3/12"), "a lamp lit is not in the log")
	check(mid.contains("\tstill\t"), "a long stop is not in the log")
	check(mid.contains("\tmoved\t"), "walking off after a stop is not in the log")
	check(mid.contains("\tpos\t"), "no position samples")
	check(mid.contains("@ 10.0, 5.0, -3.0"), "lines do not carry the player's place")
	check(mid.contains("version " + SessionLog.version()), "the log does not name the version")
	log.finish()
	var text := FileAccess.get_file_as_string(log.path)
	check(text.strip_edges().split("\n")[-1].contains("\tend\t"), "the log has no end line")
	log.free()
	player.free()
	_clean()


func test_old_logs_are_pruned() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(DIR)
	for i in SessionLog.KEEP + 5:
		var f := FileAccess.open("%s/2026-01-01_00-00-%02d.txt" % [DIR, i], FileAccess.WRITE)
		f.store_line("old")
		f.close()
	var log := SessionLog.new()
	Engine.get_main_loop().root.add_child(log)
	log.begin("new", null, DIR)
	log.finish()
	var files := DirAccess.get_files_at(DIR)
	check(files.size() == SessionLog.KEEP, "%d logs kept, not %d" % [files.size(), SessionLog.KEEP])
	check(not ("2026-01-01_00-00-00.txt" in files), "the oldest log was kept")
	log.free()
	_clean()


## The number on the title screen is the release the README links to.
func test_the_version_is_the_released_one() -> void:
	var readme := FileAccess.get_file_as_string("res://README.md")
	var re := RegEx.create_from_string("Скачать v([0-9.]+)\\]")
	var m := re.search(readme)
	check(m != null, "no download link in README")
	if m != null:
		check(SessionLog.version() == m.get_string(1), "config/version %s, README offers %s" % [SessionLog.version(), m.get_string(1)])
	var title: CanvasLayer = load("res://scripts/ui/title_screen.gd").new()
	Engine.get_main_loop().root.add_child(title)
	var label: Label = title.find_child("Version", true, false)
	check(label != null and label.text == "v" + SessionLog.version(), "the title screen does not show the version")
	title.free()
