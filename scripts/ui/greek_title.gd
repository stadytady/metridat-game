class_name GreekTitle
extends Control
## The city's name cut in square capitals over the start screen: ΠΑΝΤΙΚΑΠΑΙΟΝ,
## drawn from GreekType so it is carved, not typed. Grows with the window.

## The name as the city itself would have cut it.
const WORD := "ΠΑΝΤΙΚΑΠΑΙΟΝ"
const GOLD := Color("#d9a75a")
const RULE := Color("#8a6a35")
## Letter height in pixels at a 1080p window; the rest scales with it.
const CELL := 14.0
const GAP := 10.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := GreekType.H * CELL
	custom_minimum_size = Vector2(GreekType.width_of(WORD, CELL, GAP), h + 26.0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# the container sets the real width after _ready, so redraw when it does
	resized.connect(queue_redraw)
	queue_redraw()


## Fit the inscription to the width it is given, but never thicker than the
## carved size.
func _cell() -> float:
	var limit := (size.x - (WORD.length() - 1) * GAP) / (WORD.length() * GreekType.W)
	return clampf(minf(CELL, limit), 4.0, CELL)


func _draw() -> void:
	var cell := _cell()
	var gap := GAP * cell / CELL
	var w := GreekType.width_of(WORD, cell, gap)
	var x := (size.x - w) * 0.5
	var top := (size.y - GreekType.H * cell) * 0.5
	# a thin rule above and below, like the bands of a stele
	for y: float in [top - 10.0 * cell / CELL, top + GreekType.H * cell + 6.0 * cell / CELL]:
		draw_rect(Rect2(x, y, w, maxf(1.0, cell * 0.16)), RULE)
	GreekType.draw(self, WORD, Vector2(x, top), cell, gap, GOLD, cell * 0.35)
