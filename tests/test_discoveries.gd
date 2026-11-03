extends "res://tests/test_case.gd"
## Content checks: every find has all fields, history and fiction are kept
## apart, and every data file has a scene that uses it.


func _all() -> Array[Discovery]:
	var out: Array[Discovery] = []
	for f in DirAccess.get_files_at("res://data/discoveries"):
		if f.ends_with(".tres"):
			out.append(load("res://data/discoveries/" + f))
	return out


func test_at_least_five() -> void:
	check(_all().size() >= 5, "need at least 5 discoveries, have %d" % _all().size())


func test_fields_complete() -> void:
	var ids := {}
	for d in _all():
		var label := String(d.id)
		check(not ids.has(d.id), "duplicate id " + label)
		ids[d.id] = true
		check(d.resource_path.get_file().get_basename() == label, "file name must match id: " + d.resource_path)
		# Text fields are translation keys; the texts themselves are checked in both languages.
		for field: String in ["title", "location", "description", "history", "narrative"]:
			var key := String(d.get(field))
			for lang in ["en", "ru"]:
				var t: Translation = load("res://data/i18n/strings.%s.translation" % lang)
				var text := String(t.get_message(key))
				var min_len := 3 if field in ["title", "location"] else 40
				check(text.length() >= min_len, "%s.%s (%s) missing or too short in %s" % [label, field, key, lang])
		check(String(d.sources).length() > 40, label + ".sources is missing or too short")
		check(d.history != d.narrative, label + ": history and narrative must differ")


func test_each_has_scene() -> void:
	for d in _all():
		var path := "res://scenes/interactables/%s.tscn" % d.id
		check(ResourceLoader.exists(path), "missing scene " + path)
		if ResourceLoader.exists(path):
			var n: Node = load(path).instantiate()
			check(n is Inspectable, path + " root is not Inspectable")
			if n is Inspectable:
				check((n as Inspectable).discovery.id == d.id, path + " points at another discovery")
			n.free()
