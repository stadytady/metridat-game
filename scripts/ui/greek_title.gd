class_name GreekTitle
extends Control
## The city's name over the start screen: ΠΑΝΤΙΚΑΠΑΙΟΝ in a thin Greek display
## face, cut from strokes rather than typed. Shrinks with the window, never grows
## past its carved size.

## The name as the city itself would have cut it.
const WORD := "ΠΑΝΤΙΚΑΠΑΙΟΝ"
const GOLD := Color("#d9a75a")
const RULE := Color("#8a6a35")
## Cap height and stroke at a 1080p window.
const HEIGHT := 104.0
const GAP := 30.0
const STROKE := 7.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(GreekType.width_of(WORD, HEIGHT, GAP), HEIGHT + 34.0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# the container sets the real width after _ready, so redraw when it does
	resized.connect(queue_redraw)
	queue_redraw()


## Fit the inscription to the width it is given, but never thicker than carved.
func _height() -> float:
	var limit := (size.x - (WORD.length() - 1) * GAP) / (WORD.length() * GreekType.WIDE)
	return clampf(minf(HEIGHT, limit), 18.0, HEIGHT)


func _draw() -> void:
	var h := _height()
	var gap := GAP * h / HEIGHT
	var stroke := maxf(2.0, STROKE * h / HEIGHT)
	var w := GreekType.width_of(WORD, h, gap)
	var x := (size.x - w) * 0.5
	var top := (size.y - h) * 0.5
	# a thin rule above and below, like the bands of a stele
	for y: float in [top - stroke * 2.4, top + h + stroke * 1.6]:
		draw_rect(Rect2(x, y, w, maxf(1.0, stroke * 0.28)), RULE)
	GreekType.draw(self, WORD, Vector2(x, top), h, gap, GOLD, stroke, stroke * 1.1)
