extends Node
## 10-second cinematic, rendered in-engine through the same PS1 pipeline.
## Started by `-- --trailer`; record with Movie Maker (tools/trailer.sh):
## --write-movie + --fixed-fps make every frame exact, however slow the GPU.
##
## Four shots, each a smoothed dolly between two camera poses, joined by short
## fades through black. Letterbox and titles live inside the 640x360 viewport,
## so they get the same pixels and dither as the world.

const DURATION := 10.0
const FADE := 0.25
const VIEW := Vector2(640, 360)
const BAR := 46.0  # 2.39:1 inside 640x360

## [start, end, from_pos, to_pos, from_look, to_look, from_fov, to_fov, caption]
const SHOTS := [
	[0.0, 2.6, Vector3(205, 3.0, -38), Vector3(222, 2.2, -50), Vector3(258, 4, -68), Vector3(262, 5, -72), 50.0, 44.0,
		"The Cimmerian Bosporus, 4th century BCE"],
	[2.6, 5.2, Vector3(-4, 8.2, -0.8), Vector3(-20, 13.5, 0.4), Vector3(-45, 15.5, 0), Vector3(-70, 26, 0), 62.0, 62.0, ""],
	[5.2, 7.4, Vector3(43.5, 9.9, -16.0), Vector3(45.0, 10.2, -19.0), Vector3(46, 9.6, -23.2), Vector3(46, 10.0, -25.0), 55.0, 50.0, ""],
	[7.4, 10.0, Vector3(-82.5, 29.4, 0), Vector3(-95, 32.5, 0), Vector3(25, 4, 0), Vector3(25, 4, 0), 64.0, 70.0, ""],
]

var _t := 0.0
## --benchmark: same camera path in real time (no fixed fps), frame times recorded.
var benchmark := "--benchmark" in OS.get_cmdline_user_args()
var _frame_ms := PackedFloat32Array()
var _result: Label
var _cam: Camera3D
var _fade: ColorRect
var _caption: Label
var _title: Label
var _subtitle: Label


func _ready() -> void:
	var main := get_parent()
	main.get_node("HUD").visible = false
	var player: CharacterBody3D = main.player()
	player.set_physics_process(false)
	for n in get_tree().get_nodes_in_group(&"inspectable"):
		n.get_node("Marker").visible = false
	_cam = Camera3D.new()
	_cam.name = "TrailerCamera"
	_cam.far = 4000.0
	_cam.near = 0.1
	main.world.add_child(_cam)
	_cam.make_current()
	_build_overlay(main.viewport)
	if benchmark:
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var music := AudioStreamPlayer.new()
	music.stream = preload("res://assets/audio/trailer_theme.wav")
	music.volume_db = -3.0
	add_child(music)
	if not benchmark:
		music.play()
	_apply(0.0)


func _build_overlay(vp: SubViewport) -> void:
	var layer := CanvasLayer.new()
	vp.add_child(layer)
	for y: float in [0.0, VIEW.y - BAR]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.position = Vector2(0, y)
		bar.size = Vector2(VIEW.x, BAR)
		layer.add_child(bar)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.size = VIEW
	layer.add_child(_fade)
	_caption = _label(11, Color("#e6d6b4"), Vector2(0, VIEW.y - BAR + 17))
	_title = _label(34, Color("#f2c48c"), Vector2(0, 128))
	_title.text = "PANTICAPAEUM"
	_subtitle = _label(13, Color("#e6d6b4"), Vector2(0, 172))
	_subtitle.text = "ECHOES  OF  THE  BOSPORUS"
	for l: Label in [_caption, _title, _subtitle]:
		layer.add_child(l)
	# above the fade, so the last frame can hold the title on black
	layer.move_child(_title, -1)
	layer.move_child(_subtitle, -1)


func _label(size: int, color: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = Vector2(VIEW.x, size + 6)
	l.modulate.a = 0.0
	return l


func _process(delta: float) -> void:
	_t += delta
	if benchmark and _t > 0.5:  # skip warm-up (shader compilation)
		_frame_ms.append(delta * 1000.0)
	if _t >= DURATION:
		if benchmark:
			_finish_benchmark()
		else:
			get_tree().quit()
		return
	_apply(_t)


## Reports avg FPS, 1% low and worst frame on screen and in user://benchmark.txt.
func _finish_benchmark() -> void:
	set_process(false)
	var sorted := _frame_ms.duplicate()
	sorted.sort()
	var n := sorted.size()
	var total := 0.0
	for v in sorted:
		total += v
	var avg_ms := total / maxi(n, 1)
	var p99 := sorted[int(n * 0.99)] if n > 0 else 0.0
	var worst := sorted[n - 1] if n > 0 else 0.0
	var report := "Panticapaeum benchmark %s\n%s | %s\nframes %d  avg %.1f FPS (%.2f ms)  1%% low %.1f FPS  worst %.2f ms\n%s\n" % [
		ProjectSettings.get_setting("application/config/version"), RenderingServer.get_video_adapter_name(),
		OS.get_name(), n, 1000.0 / avg_ms, avg_ms, 1000.0 / maxf(p99, 0.001), worst,
		preload("res://scripts/ui/hud.gd").perf_text()]
	var path := "user://benchmark.txt"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(report)
		f.close()
	print(report, "written to ", ProjectSettings.globalize_path(path))
	_fade.modulate.a = 0.85
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	_result = _label(12, Color("#e6d6b4"), Vector2(0, 120))
	_result.size.y = 120
	_result.modulate.a = 1.0
	_result.text = report + "\n" + ProjectSettings.globalize_path(path)
	_fade.get_parent().add_child(_result)
	await get_tree().create_timer(6.0).timeout
	get_tree().quit()


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _apply(t: float) -> void:
	var shot: Array = SHOTS[-1]
	for s: Array in SHOTS:
		if t < s[1]:
			shot = s
			break
	var k := _ease((t - shot[0]) / (shot[1] - shot[0]))
	var pos: Vector3 = (shot[2] as Vector3).lerp(shot[3], k)
	var look: Vector3 = (shot[4] as Vector3).lerp(shot[5], k)
	_cam.global_position = pos
	_cam.look_at(look, Vector3.UP)
	_cam.fov = lerpf(shot[6], shot[7], k)

	# fades through black at every cut; longer in from black at the start
	var into: float = t - float(shot[0])
	var out: float = float(shot[1]) - t
	var a := 0.0
	if shot == SHOTS[0]:
		a = 1.0 - clampf(into / 0.8, 0.0, 1.0)
	else:
		a = 1.0 - clampf(into / FADE, 0.0, 1.0)
	if shot != SHOTS[-1]:
		a = maxf(a, 1.0 - clampf(out / FADE, 0.0, 1.0))
	else:
		a = maxf(a, clampf((t - 9.3) / 0.5, 0.0, 1.0))
	_fade.modulate.a = a

	_caption.text = shot[8]
	_caption.modulate.a = clampf(into / 0.5, 0.0, 1.0) * clampf(out / 0.4, 0.0, 1.0) if shot[8] != "" else 0.0
	_title.modulate.a = clampf((t - 8.0) / 0.7, 0.0, 1.0)
	_subtitle.modulate.a = clampf((t - 8.5) / 0.6, 0.0, 1.0)
