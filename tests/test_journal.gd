extends "res://tests/test_case.gd"
## The journal shows its list, not just a title over an empty box (the scroll
## that keeps it on screen folded the rows to nothing), and stays on the screen
## however many finds the city has.

const J := preload("res://scripts/ui/journal_panel.gd")


func _registry(n: int) -> Dictionary:
	var reg := {}
	for i in n:
		var d := Discovery.new()
		d.id = StringName("probe_%02d" % i)
		d.title = "D_PROBE_TITLE"
		d.location = "LOC_AGORA"
		d.hint = "D_PROBE_HINT"
		reg[d.id] = d
	return reg


func test_the_list_is_shown_and_stays_on_screen() -> void:
	var kept_reg := Game.registry
	var kept_found := Game.found
	var kept_block := Game.ui_blocking
	var j: CanvasLayer = J.new()
	Engine.get_main_loop().root.add_child(j)
	for n: int in [3, 40]:
		Game.registry = _registry(n)
		Game.found = {Game.registry.keys()[0]: true}
		j.open()
		var scroll: ScrollContainer = j._scroll
		var first: Control = j._rows.get_child(0)
		var shown := scroll.size.y
		var panel: Rect2 = j._panel.get_global_rect()
		var screen := Rect2(Vector2.ZERO, UiStyle.screen(j))
		j.close(false)
		check(shown >= first.get_combined_minimum_size().y, "with %d finds the list is %.0f high: not even one row shows" % [n, shown])
		check(screen.encloses(panel), "with %d finds the journal leaves the screen: %s on %s" % [n, panel, screen.size])
		if n == 3:
			check(shown >= j._rows.get_combined_minimum_size().y - 1.0, "three finds do not all show: %.0f of %.0f" % [shown, j._rows.get_combined_minimum_size().y])
	j.free()
	Game.registry = kept_reg
	Game.found = kept_found
	Game.ui_blocking = kept_block
