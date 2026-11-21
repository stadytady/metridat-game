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
		for field: String in ["title", "location", "description", "history", "narrative", "hint"]:
			var key := String(d.get(field))
			for lang in ["en", "ru"]:
				var t: Translation = load("res://data/i18n/strings.%s.translation" % lang)
				var text := String(t.get_message(key))
				var min_len := 3 if field in ["title", "location"] else (20 if field == "hint" else 40)
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


## Each find shows its own model: a model shared by two finds once put a
## standing inscribed stele in the panel of a rough block with a mason's mark.
## The two seated terracottas are the same kind of object, so they may share.
const SHARED_MODELS := {"res://scenes/interactables/models/votive.tscn": ["goddess_votive", "votive_figurine"]}


func test_each_find_has_its_own_model() -> void:
	var by_model := {}
	for f: String in DirAccess.get_files_at("res://data/discoveries"):
		if not f.ends_with(".tres"):
			continue
		var d: Discovery = load("res://data/discoveries/" + f)
		if d == null or d.model == null:
			continue
		var path := d.model.resource_path
		if not by_model.has(path):
			by_model[path] = []
		by_model[path].append(String(d.id))
	for path: String in by_model:
		var ids: Array = by_model[path]
		ids.sort()
		if ids.size() > 1:
			check(SHARED_MODELS.get(path, []) == ids, "%s shown for %s" % [path.get_file(), ids])
