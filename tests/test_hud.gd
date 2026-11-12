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
