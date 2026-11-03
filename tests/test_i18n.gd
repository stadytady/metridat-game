extends "res://tests/test_case.gd"
## Localization: every key the game uses exists in both languages, placeholders
## match, Russian is actually Russian, and the imported translations work.

const CSV := "res://data/i18n/strings.csv"
const CODE_DIRS := ["res://scripts", "res://data/discoveries"]


func _table() -> Dictionary:
	var out := {}
	var f := FileAccess.open(CSV, FileAccess.READ)
	var header := f.get_csv_line()
	check(header == PackedStringArray(["keys", "en", "ru"]), "csv header is %s" % header)
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 3 or row[0] == "":
			continue
		check(not out.has(row[0]), "duplicate key " + row[0])
		out[row[0]] = {"en": row[1], "ru": row[2]}
	return out


func _used_keys() -> Dictionary:
	var re := RegEx.create_from_string("\"((?:UI|LOC|D)_[A-Z0-9_]+)\"")
	var keys := {}
	for dir: String in CODE_DIRS:
		for path in _files(dir):
			for m in re.search_all(FileAccess.get_file_as_string(path)):
				keys[m.get_string(1)] = path
	return keys


func _files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tres"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(d)))
	return out


func test_every_used_key_is_translated() -> void:
	var table := _table()
	var used := _used_keys()
	check(used.size() > 30, "found only %d keys in code and data" % used.size())
	for k: String in used:
		check(table.has(k), "%s (used in %s) missing from strings.csv" % [k, used[k]])


func test_rows_complete_and_consistent() -> void:
	var cyr := RegEx.create_from_string("[а-яА-ЯёЁ]")
	var fmt := RegEx.create_from_string("%[sd.0-9]+")
	for k: String in _table():
		var row: Dictionary = _table()[k]
		check(row.en.strip_edges() != "" and row.ru.strip_edges() != "", k + ": empty translation")
		check(row.en != row.ru, k + ": ru is a copy of en")
		check(cyr.search(row.ru) != null, k + ": ru has no Cyrillic")
		var fe := fmt.search_all(row.en).map(func(m: RegExMatch) -> String: return m.get_string())
		var fr := fmt.search_all(row.ru).map(func(m: RegExMatch) -> String: return m.get_string())
		check(fe == fr, "%s: placeholders differ en=%s ru=%s" % [k, fe, fr])


func test_imported_translations_work() -> void:
	for lang in ["en", "ru"]:
		var path := "res://data/i18n/strings.%s.translation" % lang
		check(ResourceLoader.exists(path), path + " not imported")
		if not ResourceLoader.exists(path):
			continue
		var t: Translation = load(path)
		var table := _table()
		for k: String in table:
			check(String(t.get_message(k)) == table[k][lang], "%s %s: imported text differs from csv" % [lang, k])
