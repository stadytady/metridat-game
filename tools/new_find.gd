extends SceneTree
## Scaffolds a find from the command line:
##   godot --headless --path . -s res://tools/new_find.gd -- --id=olive_press \
##       --title-en="Olive press" --title-ru="Давильня" --desc-en="..." --desc-ru="..."
## Writes the Discovery resource, the Inspectable scene and the CSV rows.

const S := preload("res://tools/scaffold.gd")


func _init() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--") or not a.contains("="):
			continue
		var kv := a.substr(2).split("=", true, 1)
		args[kv[0]] = kv[1]
	var id: String = args.get("id", "")
	if id.is_empty():
		print("usage: --id=<id> [--title-en=... --title-ru=... --desc-en=... --desc-ru=... --hint-en=... --hint-ru=...]")
		quit(2)
		return
	var written := S.new_find(id, {
		"title_en": args.get("title-en", "TODO title"),
		"title_ru": args.get("title-ru", "TODO заголовок"),
		"desc_en": args.get("desc-en", "TODO description"),
		"desc_ru": args.get("desc-ru", "TODO описание"),
		"hint_en": args.get("hint-en", "TODO: where to look"),
		"hint_ru": args.get("hint-ru", "TODO: где искать"),
	})
	for path: String in written:
		print("wrote ", path)
	print("next: place it in a district (spawn_inspectable) and add it to Director._route()")
	print("note: fill D_<ID>_* and sources before committing: test_discoveries wants 40+ characters and real sources")
	quit(0 if written.size() >= 3 else 1)
