class_name TalkMarker
extends Sprite3D
## The little speech bubble over a talkable Npc's head. Drawn in code like every
## other asset here: a 16x16 cut-out image, nearest filter, no mipmaps, so it
## stays pixel-sharp and never needs a committed texture.

const SIZE := 16
## One source pixel is this many metres: 16 px ≈ 0.29 m — small enough to sit
## above the head like a thought, not a sign.
const PIXEL_SIZE := 0.018

const FILL := Color("#e6d6b4")
const LINE := Color("#3a2b18")

static var _cached: ImageTexture


static func bubble_texture() -> ImageTexture:
	if _cached == null:
		_cached = ImageTexture.create_from_image(_image())
	return _cached


static func _image() -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Bubble body: 14x11 with a one-pixel outline.
	for y in range(1, 12):
		for x in range(1, 15):
			var edge := x == 1 or x == 14 or y == 1 or y == 11
			img.set_pixel(x, y, LINE if edge else FILL)
	# Clean the corners so the outline reads as round, the way a sprite would.
	for c: Vector2i in [Vector2i(1, 1), Vector2i(14, 1), Vector2i(1, 11), Vector2i(14, 11)]:
		img.set_pixel(c.x, c.y, Color(0, 0, 0, 0))
	# Tail, two pixels down from the bottom edge.
	img.set_pixel(4, 12, LINE)
	img.set_pixel(5, 12, FILL)
	img.set_pixel(4, 13, LINE)
	# Three dots.
	for x: int in [5, 8, 11]:
		img.set_pixel(x, 5, LINE)
		img.set_pixel(x, 6, LINE)
	return img


func _init() -> void:
	texture = bubble_texture()
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	pixel_size = PIXEL_SIZE
	shaded = false
	centered = true
