extends SceneTree
## Adds one translated line to the string table:
##   godot --headless --path . -s res://tools/new_key.gd -- --key=UI_X --en="Hi" --ru="Привет"
## Refuses empty fields, a Russian copy of the English text, and a row without
## Cyrillic, so a half-translated line never reaches the table.

const S := preload("res://tools/scaffold.gd")


func _init() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--") or not a.contains("="):
			continue
		var kv := a.substr(2).split("=", true, 1)
		args[kv[0]] = kv[1]
	var key: String = args.get("key", "")
	if key.is_empty():
		print("usage: --key=<KEY> --en=\"...\" --ru=\"...\"")
		quit(2)
		return
	var added := S.add_key(key, args.get("en", ""), args.get("ru", ""))
	if added == 0:
		print("nothing added for ", key, " (duplicate or invalid)")
		quit(1)
		return
	print("added ", key, " to ", S.CSV)
	print("next: run the import so the .translation files pick it up")
	quit(0)
