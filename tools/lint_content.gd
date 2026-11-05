extends SceneTree
## One pass over the content: the string table, every dialogue and every find.
## Prints one line per problem and exits non-zero if there were any, so it can sit
## in front of the tests in tools/check.sh.

const CSV := "res://data/i18n/strings.csv"
const DIALOGUES := "res://data/dialogues"
const DISCOVERIES := "res://data/discoveries"

var problems := PackedStringArray()


func _init() -> void:
	var table := _table()
	_dialogues()
	_discoveries(table)
	_keys_in_code(table)
	if problems.is_empty():
		print("lint: clean (%d keys, %d dialogues)" % [table.size(), _dialogue_count()])
		quit(0)
		return
	for p in problems:
		print("LINT: ", p)
	print("lint: %d problem(s)" % problems.size())
	quit(1)


func _table() -> Dictionary:
	var out := {}
	var f := FileAccess.open(CSV, FileAccess.READ)
	if f == null:
		problems.append("no " + CSV)
		return out
	var header := f.get_csv_line()
	if header != PackedStringArray(["keys", "en", "ru"]):
		problems.append("csv header is %s, expected keys,en,ru" % [header])
	var cyr := RegEx.create_from_string("[а-яА-ЯёЁ]")
	var fmt := RegEx.create_from_string("%[sd.0-9]+")
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 3 or row[0] == "":
			continue
		var key := row[0]
		if out.has(key):
			problems.append("duplicate key " + key)
			continue
		if row[1].strip_edges() == "" or row[2].strip_edges() == "":
			problems.append("%s: empty translation" % key)
		if row[1] == row[2]:
			problems.append("%s: ru is a copy of en" % key)
		elif cyr.search(row[2]) == null:
			problems.append("%s: ru has no Cyrillic" % key)
		var fe := fmt.search_all(row[1]).map(func(m: RegExMatch) -> String: return m.get_string())
		var fr := fmt.search_all(row[2]).map(func(m: RegExMatch) -> String: return m.get_string())
		if fe != fr:
			problems.append("%s: placeholders differ en=%s ru=%s" % [key, fe, fr])
		out[key] = true
	return out


func _dialogue_files() -> PackedStringArray:
	return _files(DIALOGUES, ".dialogue")


func _dialogue_count() -> int:
	return _dialogue_files().size()


func _dialogues() -> void:
	for path in _dialogue_files():
		var res: DialogueResource = load(path)
		if res == null:
			problems.append("%s did not compile" % path)
			continue
		if not res.titles.has("start"):
			problems.append("%s has no start cue (cues: %s)" % [path, res.titles.keys()])
		if res.lines.is_empty():
			problems.append("%s has no lines" % path)


func _discoveries(table: Dictionary) -> void:
	var re := RegEx.create_from_string("(?:NPC|LOC|D)_[A-Z0-9_]+")
	for path in _files(DISCOVERIES, ".tres"):
		var d: Discovery = load(path)
		if d == null:
			problems.append("%s did not load" % path)
			continue
		if String(d.id) != path.get_file().get_basename():
			problems.append("%s: id %s does not match the file name" % [path, d.id])
		var text := FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			var key := m.get_string()
			if not table.has(key):
				problems.append("%s: %s missing from strings.csv" % [path.get_file(), key])


## Keys the scripts ask for must exist too, or a player meets a raw key on screen.
func _keys_in_code(table: Dictionary) -> void:
	var re := RegEx.create_from_string("\"((?:UI|LOC|D)_[A-Z0-9_]+)\"")
	for path in _files("res://scripts", ".gd"):
		var text := FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			var key := m.get_string(1)
			if not table.has(key):
				problems.append("%s: %s missing from strings.csv" % [path.get_file(), key])


func _files(dir: String, suffix: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(suffix):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_files(dir.path_join(sub), suffix))
	return out
