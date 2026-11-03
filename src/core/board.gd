class_name Board
extends RefCounted
## Grid of colored cells. Pressing a cell advances every cell covered by its
## stencil by one color (mod `colors`). The board is solved when all cells are 0.
## Presses commute, so a solution is just "how many times to press each cell".

enum Stencil { PLUS, CROSS, RING, ROW, COL }

const _OFFSETS := {
	Stencil.PLUS: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)],
	Stencil.CROSS: [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)],
	# RING deliberately skips the center: the cell can only be fixed from outside.
	Stencil.RING: [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
	],
}

var width: int
var height: int
var colors: int
var cells: PackedInt32Array
var stencils: PackedInt32Array


func _init(w: int = 3, h: int = 3, k: int = 2) -> void:
	assert(w > 0 and h > 0 and k >= 2)
	width = w
	height = h
	colors = k
	cells.resize(w * h)
	stencils.resize(w * h)


## 3x3 neighbourhood offsets for local stencils; empty for ROW/COL.
static func offsets(stencil: int) -> Array:
	return _OFFSETS.get(stencil, [])


func size() -> int:
	return width * height


func index(x: int, y: int) -> int:
	return y * width + x


func affected(i: int) -> PackedInt32Array:
	var x := i % width
	var y := i / width
	var out := PackedInt32Array()
	match stencils[i]:
		Stencil.ROW:
			for xx in width:
				out.append(index(xx, y))
		Stencil.COL:
			for yy in height:
				out.append(index(x, yy))
		_:
			for o: Vector2i in _OFFSETS[stencils[i]]:
				var px := x + o.x
				var py := y + o.y
				if px >= 0 and px < width and py >= 0 and py < height:
					out.append(index(px, py))
	return out


func press(i: int, times: int = 1) -> void:
	for j in affected(i):
		cells[j] = posmod(cells[j] + times, colors)


## Undoes one press: colors-1 presses are the inverse of one press.
func unpress(i: int) -> void:
	press(i, colors - 1)


func is_solved() -> bool:
	for c in cells:
		if c != 0:
			return false
	return true


func copy() -> Board:
	var b := Board.new(width, height, colors)
	b.cells = cells.duplicate()
	b.stencils = stencils.duplicate()
	return b
