class_name GreekTitle
extends Control
## The city's name over the start screen: ΠΑΝΤΙΚΑΠΑΙΟΝ cut as the city would
## have cut it - even strokes, the small flared feet of 4th-century lettering,
## the lit lip and the shadow of a groove in the stone. The meander bands of the
## start screen frame it. `reveal` (0..1) lets it appear letter by letter.
## Shrinks with the window.

## The name as the city itself would have cut it.
const WORD := "ΠΑΝΤΙΚΑΠΑΙΟΝ"
const GOLD := Color("#d9a75a")
const LIGHT := Color("#f6dca4")
const SHADOW := Color(0.04, 0.03, 0.02, 0.6)
## Cap height, stroke and letter spacing at a 1080p window.
const HEIGHT := 96.0
const STROKE := 6.0
const GAP := 18.0
## The feet at the ends of strokes, as a fraction of the cap height.
const SERIF := 0.13
## Air above and below the word inside its own rect.
const AIR := 14.0

## How much of the word is cut so far: 1 is all of it.
var reveal := 1.0:
	set(v):
		reveal = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(GreekType.width_of(WORD, HEIGHT, GAP), HEIGHT + AIR * 2.0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# the container sets the real width after _ready, so redraw when it does
	resized.connect(queue_redraw)
	queue_redraw()


## Fit the inscription to the width it is given, but never thicker than carved.
func _height() -> float:
	var limit := HEIGHT * size.x / maxf(1.0, GreekType.width_of(WORD, HEIGHT, GAP))
	return clampf(minf(HEIGHT, limit), 18.0, HEIGHT)


func _draw() -> void:
	var h := _height()
	var gap := GAP * h / HEIGHT
	var stroke := maxf(2.0, STROKE * h / HEIGHT)
	var w := GreekType.width_of(WORD, h, gap)
	var x := (size.x - w) * 0.5
	var top := (size.y - h) * 0.5
	var count := ceili(reveal * WORD.length() - 0.001)
	GreekType.draw(self, WORD, Vector2(x, top), h, gap, GOLD, stroke,
			maxf(2.0, stroke * 0.55), SHADOW, SERIF, LIGHT, count)
