extends "res://tests/test_case.gd"
## The talk marker is generated, so the things worth checking are its budget and
## its cut-out shape: tiny texture, transparent corners, opaque body, unscaled
## pixels, one marker per talkable NPC.

const MAX_PX := 128


func test_texture_is_within_the_ps1_budget() -> void:
	var tex := TalkMarker.bubble_texture()
	check(tex != null, "no marker texture")
	if tex == null:
		return
	var img: Image = tex.get_image()
	check(img.get_width() <= MAX_PX and img.get_height() <= MAX_PX,
		"marker texture is %s, budget is %d px" % [img.get_size(), MAX_PX])
	check(img.get_width() == TalkMarker.SIZE, "size %d, expected %d" % [img.get_width(), TalkMarker.SIZE])


func test_bubble_is_a_cut_out() -> void:
	var img: Image = TalkMarker.bubble_texture().get_image()
	check(img.get_pixel(0, 0).a == 0.0, "corner must be transparent")
	check(img.get_pixel(15, 15).a == 0.0, "corner must be transparent")
	check(img.get_pixel(8, 4).a == 1.0, "bubble body must be opaque")
	check(img.get_pixel(1, 5).a == 1.0, "outline must be opaque")
	check(img.get_pixel(4, 13).a == 1.0, "tail must reach the second row")


func test_sprite_is_pixel_sharp_and_billboarded() -> void:
	var m := TalkMarker.new()
	check(m.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "filter is not nearest")
	check(m.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "marker does not face the camera")
	check(m.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "marker must be alpha-tested, not blended")
	check(not m.shaded, "marker would take the city light")
	check(is_equal_approx(m.pixel_size, TalkMarker.PIXEL_SIZE), "unexpected pixel size")
	m.free()
