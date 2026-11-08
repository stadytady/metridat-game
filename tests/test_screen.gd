extends "res://tests/test_case.gd"
## The world's low-res image: 1280x720 for a 16:9 window, drawn at a scale of
## 1.5 on the 1080-unit canvas (2 at 1440p), so it needs sharp-bilinear
## sampling, not plain nearest; the trailer's full mode draws it 1:1.

const MAIN := preload("res://scripts/core/main.gd")


func test_the_world_renders_at_720_lines() -> void:
	check(MAIN.render_size(Vector2(1920, 1080), false) == Vector2i(1280, 720), "16:9 renders at %s" % MAIN.render_size(Vector2(1920, 1080), false))
	check(is_equal_approx(MAIN.render_scale(Vector2(1920, 1080), false), 1.5), "the scale on a 1080 canvas is %.2f" % MAIN.render_scale(Vector2(1920, 1080), false))
	# a wide window keeps the height and widens the picture, square pixels
	var wide := MAIN.render_size(Vector2(2520, 1080), false)
	check(wide == Vector2i(1680, 720), "21:9 renders at %s" % wide)
	# full mode (the trailer) and a window smaller than the target: never upscaled
	check(MAIN.render_size(Vector2(1920, 1080), true) == Vector2i(1920, 1080), "the trailer's full mode is not 1:1")
	check(MAIN.render_size(Vector2(1000, 600), false) == Vector2i(1000, 600), "a small window is rendered larger than itself")


## A scale of 1.5 with plain nearest gives pixel columns 1, 2, 1, 2 wide: the
## container samples linearly and the post shader keeps each low-res pixel flat.
func test_the_upscale_is_sharp_not_nearest_at_one_and_a_half() -> void:
	var scene := FileAccess.get_file_as_string("res://scenes/main.tscn")
	check(scene.contains("texture_filter = 2"), "the screen container samples nearest: uneven pixels at a scale of 1.5")
	check(not scene.contains("stretch = true"), "the screen still stretches by an integer shrink")
	var shader := FileAccess.get_file_as_string("res://assets/shaders/psx_post.gdshader")
	check(shader.contains("fwidth(px)") and shader.contains("clamp((px - seam) / d, -0.5, 0.5)"), "psx_post does not sample sharp-bilinear")
