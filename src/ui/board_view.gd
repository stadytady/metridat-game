class_name BoardView
extends Control
## Draws a Board and turns clicks/taps into `pressed(index)`. Hovering a cell
## outlines every cell its press would change.

signal pressed(index: int)

const GAP := 6.0

var board: Board:
	set(value):
		board = value
		hover = -1
		queue_redraw()

var hover := -1:
	set(value):
		if hover != value:
			hover = value
			queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(240, 240)
	resized.connect(queue_redraw)
	mouse_exited.connect(func() -> void: hover = -1)


func _pitch() -> float:
	return minf(size.x / board.width, size.y / board.height)


func _origin() -> Vector2:
	var p := _pitch()
	return (size - Vector2(p * board.width, p * board.height)) / 2.0


func cell_rect(i: int) -> Rect2:
	var p := _pitch()
	var pos := _origin() + Vector2(i % board.width, i / board.width) * p
	return Rect2(pos + Vector2(GAP, GAP) / 2.0, Vector2(p - GAP, p - GAP))


func cell_at(local: Vector2) -> int:
	if board == null:
		return -1
	var rel := (local - _origin()) / _pitch()
	var x := floori(rel.x)
	var y := floori(rel.y)
	if x < 0 or y < 0 or x >= board.width or y >= board.height:
		return -1
	return board.index(x, y)


func _gui_input(event: InputEvent) -> void:
	if board == null:
		return
	if event is InputEventMouseMotion:
		hover = cell_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := cell_at(event.position)
		if i >= 0:
			pressed.emit(i)
			accept_event()


func _draw() -> void:
	if board == null:
		return
	var marked := {}
	if hover >= 0:
		for j in board.affected(hover):
			marked[j] = true
	for i in board.size():
		var r := cell_rect(i)
		var c := board.cells[i]
		draw_rect(r, Palette.CELLS[c])
		if marked.has(i):
			draw_rect(r.grow(-3), Palette.HIGHLIGHT, false, 3.0)
		if i == hover:
			draw_rect(r, Palette.HOVER, false, 3.0)
		_draw_glyph(r, board.stencils[i], Palette.glyph_color(c))


func _draw_glyph(r: Rect2, stencil: int, color: Color) -> void:
	var center := r.get_center()
	var step := r.size.x * 0.17
	var dot := r.size.x * 0.05
	match stencil:
		Board.Stencil.ROW:
			draw_line(center - Vector2(step * 1.5, 0), center + Vector2(step * 1.5, 0), color, dot * 1.6)
			draw_circle(center, dot * 1.4, color)
		Board.Stencil.COL:
			draw_line(center - Vector2(0, step * 1.5), center + Vector2(0, step * 1.5), color, dot * 1.6)
			draw_circle(center, dot * 1.4, color)
		_:
			var on := {}
			for o: Vector2i in Board.offsets(stencil):
				on[o] = true
			for y in range(-1, 2):
				for x in range(-1, 2):
					var o := Vector2i(x, y)
					var pos := center + Vector2(o) * step
					if on.has(o):
						draw_circle(pos, dot, color)
					else:
						draw_circle(pos, dot * 0.35, Color(color, 0.5))
