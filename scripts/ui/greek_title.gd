class_name GreekTitle
extends Control
## The city's name over the start screen: ΠΑΝΤΙΚΑΠΑΙΟΝ in a thin Greek display
## face. The meander bands of the start screen frame it, so the word needs no rules
## of its own — four lines in a row read as clutter. Shrinks with the window.

## The name as the city itself would have cut it.
const WORD := "ΠΑΝΤΙΚΑΠΑΙΟΝ"
const GOLD := Color("#d9a75a")
## Cap height and stroke at a 1080p window.
const HEIGHT := 96.0
const STROKE := 7.0
const GAP := 16.0
## Air above and below the word inside its own rect.
const AIR := 14.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(GreekType.width_of(WORD, HEIGHT, GAP), HEIGHT + AIR * 2.0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# the container sets the real width after _ready, so redraw when it does
	resized.connect(queue_redraw)
	queue_redraw()


## Fit the inscription to the width it is given, but never thicker than carved.
func _height() -> float:
	var limit := (size.x - (WORD.length() - 1) * GAP) / (WORD.length() * (GreekType.WIDE + GreekType.BEARING))
	return clampf(minf(HEIGHT, limit), 18.0, HEIGHT)


func _draw() -> void:
	var h := _height()
	var gap := GAP * h / HEIGHT
	var stroke := maxf(2.0, STROKE * h / HEIGHT)
	var w := GreekType.width_of(WORD, h, gap)
	var x := (size.x - w) * 0.5
	var top := (size.y - h) * 0.5
	GreekType.draw(self, WORD, Vector2(x, top), h, gap, GOLD, stroke,
			maxf(2.0, stroke * 0.5), Color(0.04, 0.03, 0.02, 0.55))
