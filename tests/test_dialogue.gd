extends "res://tests/test_case.gd"
## Every conversation in data/dialogues: it must compile, start at `start`, keep
## all of its keys translated, and carry a set of responses (the branch the
## panel renders). The walkthrough covers the runtime end of it.

const DIR := "res://data/dialogues"
const CSV := "res://data/i18n/strings.csv"


func _files() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".dialogue"):
			out.append(DIR.path_join(f))
	return out


func _csv_keys() -> Dictionary:
	var table := {}
	var f := FileAccess.open(CSV, FileAccess.READ)
	if f == null:
		check(false, "no " + CSV)
		return table
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3 and row[0] != "":
			table[row[0]] = true
	return table


func test_every_dialogue_compiles() -> void:
	var files := _files()
	check(files.size() >= 5, "only %d dialogues found" % files.size())
	for path in files:
		var res: DialogueResource = load(path)
		check(res != null, path + " did not import")
		if res == null:
			continue
		check(res.titles.has("start"), path + " cues: %s" % [res.titles.keys()])
		check(not res.lines.is_empty(), path + ": no lines compiled")


func test_keys_are_translated() -> void:
	var table := _csv_keys()
	var re := RegEx.create_from_string("(?:NPC|LOC)_[A-Z0-9_]+")
	var seen := {}
	for path in _files():
		var text := FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			var key := m.get_string()
			seen[key] = true
			check(table.has(key), "%s (%s) missing from strings.csv" % [key, path])
	check(seen.size() >= 20, "only %d keys found in the dialogues" % seen.size())


func test_every_dialogue_offers_responses() -> void:
	for path in _files():
		var res: DialogueResource = load(path)
		if res == null:
			continue
		var with_responses := 0
		for id: String in res.lines:
			var data: Dictionary = res.lines[id]
			if Array(data.get("responses", [])).size() > 0:
				with_responses += 1
		check(with_responses >= 1, path + " has no responses")


## Every `Game.has_found("<id>")` in a dialogue names a city find (not the
## dream's), and each speaker has at least one such remark.
func test_remarks_name_real_finds() -> void:
	var re := RegEx.create_from_string("Game\\.has_found\\(\"([a-z_]+)\"\\)")
	var speakers := 0
	for path in _files():
		var text := FileAccess.get_file_as_string(path)
		var hits := re.search_all(text)
		if not hits.is_empty():
			speakers += 1
		for m in hits:
			var id := m.get_string(1)
			var res_path := "res://data/discoveries/%s.tres" % id
			check(ResourceLoader.exists(res_path), "%s: no find %s" % [path, id])
			if ResourceLoader.exists(res_path):
				var d: Discovery = load(res_path)
				check(not d.epilogue, "%s: remark on the dream's find %s" % [path, id])
	check(speakers >= 10, "only %d speakers remark on finds" % speakers)


## The remark is a choice the player sees only once the find is made.
func test_remark_waits_for_the_find() -> void:
	var res: DialogueResource = load(DIR.path_join("sailor.dialogue"))
	var saved := Game.found.duplicate()
	Game.found.clear()
	check(not await _offers(res, "LOC_SAILOR_CHOICE_SAW"), "the anchor remark is offered before the anchor stock is found")
	Game.found[&"anchor_stock"] = true
	check(await _offers(res, "LOC_SAILOR_CHOICE_SAW"), "the anchor remark is not offered after the find")
	Game.found = saved


func _offers(res: DialogueResource, key: String) -> bool:
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(res, "start")
	var guard := 0
	while line != null and line.responses.is_empty() and guard < 10:
		line = await DialogueManager.get_next_dialogue_line(res, line.next_id)
		guard += 1
	if line == null:
		return false
	for r: DialogueResponse in line.responses:
		if (r.text == key or r.text == TranslationServer.translate(key)) and r.is_allowed:
			return true
	return false
