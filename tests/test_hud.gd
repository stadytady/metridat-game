extends "res://tests/test_case.gd"
## The place-name toast can be put out at once: the shots jump between places
## faster than it fades, and a frame carried the name of the place before.


func test_the_toast_goes_out_at_once() -> void:
	var hud: CanvasLayer = load("res://scenes/ui/hud.tscn").instantiate()
	Engine.get_main_loop().root.add_child(hud)
	hud.show_toast("LOC_HILL")
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().create_timer(0.6).timeout
	var shown: float = hud._toast.modulate.a
	hud.clear_toast()
	await Engine.get_main_loop().create_timer(0.6).timeout
	var after: float = hud._toast.modulate.a
	var key: String = hud._toast_key
	hud.free()
	check(shown > 0.5, "the toast did not come up (%.2f)" % shown)
	check(after == 0.0 and key == "", "the toast is still up after clear_toast (%.2f, '%s')" % [after, key])



## Panels centre on the real canvas: taller on 16:10 (Steam Deck), wider on
## 21:9. A literal 1920x1080 put the find panel left of centre on an
## ultrawide and the dialogue in the middle of a Deck's screen, so no UI script
## may lay out against those numbers outside a comment: UiStyle.screen() is
## the size.
func test_no_panel_lays_out_on_a_literal_1080p() -> void:
	var re := RegEx.create_from_string("\\b(1920|1080)\\b")
	for f: String in DirAccess.get_files_at("res://scripts/ui"):
		if not f.ends_with(".gd") or f == "ui_style.gd":
			continue
		var n := 0
		for line: String in FileAccess.get_file_as_string("res://scripts/ui/" + f).split("\n"):
			n += 1
			var code := line.split("#")[0]
			if re.search(code) != null:
				check(false, "%s:%d lays out on a literal 1080p canvas: %s" % [f, n, line.strip_edges()])
