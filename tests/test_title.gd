extends "res://tests/test_case.gd"
## The meander on the start screen: one connected hook per 6x6 unit, on a
## rail that joins the units into one line.


func test_meander_is_one_connected_hook() -> void:
	var TS := load("res://scripts/ui/title_screen.gd")
	var cells: Array[Vector2i] = TS.meander_cells()
	var seen := {}
	for c in cells:
		check(c.x >= 0 and c.x < 6 and c.y >= 0 and c.y < 6, "cell %s outside the unit" % c)
		check(not seen.has(c), "duplicate cell %s" % c)
		seen[c] = true
	# flood fill from the first cell: every cell must be reached
	var reached := {cells[0]: true}
	var todo: Array[Vector2i] = [cells[0]]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if seen.has(n) and not reached.has(n):
				reached[n] = true
				todo.append(n)
	check(reached.size() == cells.size(), "meander breaks: %d of %d cells connected" % [reached.size(), cells.size()])
	# the rail spans the unit, so repeats join into one line
	check(seen.has(Vector2i(0, 5)) and seen.has(Vector2i(5, 5)), "rail does not span the unit")
	# a hook, not a box: the right side above the rail stays open
	for y in range(0, 5):
		check(not seen.has(Vector2i(5, y)), "hook closed at (5, %d)" % y)
