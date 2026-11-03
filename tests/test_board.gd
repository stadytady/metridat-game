extends "res://tests/test_case.gd"


func _board(w: int, h: int, k: int, stencil: int) -> Board:
	var b := Board.new(w, h, k)
	b.stencils.fill(stencil)
	return b


func _sorted(a: PackedInt32Array) -> PackedInt32Array:
	var c := a.duplicate()
	c.sort()
	return c


func test_plus_is_clipped_at_corner() -> void:
	var b := _board(3, 3, 2, Board.Stencil.PLUS)
	check_eq(_sorted(b.affected(0)), PackedInt32Array([0, 1, 3]), "corner")
	check_eq(_sorted(b.affected(4)), PackedInt32Array([1, 3, 4, 5, 7]), "center")


func test_cross_and_ring() -> void:
	var b := _board(3, 3, 2, Board.Stencil.CROSS)
	check_eq(_sorted(b.affected(4)), PackedInt32Array([0, 2, 4, 6, 8]), "cross")
	b.stencils.fill(Board.Stencil.RING)
	check_eq(_sorted(b.affected(4)), PackedInt32Array([0, 1, 2, 3, 5, 6, 7, 8]), "ring skips center")


func test_row_and_col_span_whole_board() -> void:
	var b := _board(4, 3, 2, Board.Stencil.ROW)
	check_eq(_sorted(b.affected(5)), PackedInt32Array([4, 5, 6, 7]), "row")
	b.stencils.fill(Board.Stencil.COL)
	check_eq(_sorted(b.affected(5)), PackedInt32Array([1, 5, 9]), "col")


func test_press_cycles_colors() -> void:
	var b := _board(3, 3, 3, Board.Stencil.PLUS)
	b.press(4)
	check_eq(b.cells[4], 1, "one press")
	b.press(4)
	b.press(4)
	check(b.is_solved(), "three presses on 3 colors return to start")


func test_unpress_reverts_press() -> void:
	for k in [2, 3, 5]:
		var b := _board(4, 4, k, Board.Stencil.CROSS)
		b.press(5)
		b.press(6)
		b.unpress(6)
		b.unpress(5)
		check(b.is_solved(), "k=%d" % k)


func test_copy_is_independent() -> void:
	var b := _board(3, 3, 2, Board.Stencil.PLUS)
	var c := b.copy()
	c.press(4)
	check(b.is_solved(), "original untouched")
	check(not c.is_solved(), "copy changed")
