extends Node
## 25-second cinematic, rendered in-engine through the same PS1 pipeline.
## Started by `-- --trailer`; record with Movie Maker (tools/trailer.sh):
## --write-movie + --fixed-fps make every frame exact, however slow the GPU.
##
## Afternoon to night, as the game goes: the strait, the street, the potter's
## yard, the fisherman at sunset, the way to the sanctuary at dusk, the lit
## street and the hill at night. Each shot sets its own hour (the atmosphere
## snaps to it) and, after dusk, the lamps are lit. Camera moves are
## Catmull-Rom splines through three points at constant speed (eased only into
## the first and out of the last shot) with a slow handheld drift. Cuts are
## dissolves. Letterbox and titles live inside the 640x360 viewport. Shot
## boundaries follow the score (night falls at 16.6 s, the hit lands at 19.6 s).

const DURATION := 25.0
const DISSOLVE := 0.5
const VIEW := Vector2(640, 360)
const BAR := 46.0  # 2.39:1 inside 640x360
const TITLE_AT := 21.6
const FADE_OUT := [24.2, 24.8]

## start, end, hour (0 afternoon .. 1 night), camera path, look-at path, fov from/to, caption
const SHOTS := [
	{"t": [0.0, 3.2], "hour": 0.0, "fov": [40.0, 37.0], "caption": "The Cimmerian Bosporus, 4th century BCE",
		"pos": [Vector3(236, 2.2, -60), Vector3(239, 2.6, -52), Vector3(243, 3.0, -46)],
		"look": [Vector3(260, 4.5, -70), Vector3(260.5, 4.8, -70), Vector3(261, 5.0, -70)]},
	{"t": [3.2, 5.8], "hour": 0.08, "fov": [58.0, 56.0], "caption": "",
		"pos": [Vector3(-2, 7.8, -0.6), Vector3(-9, 9.0, -0.9), Vector3(-16, 11.8, 0.2)],
		"look": [Vector3(-30, 13.5, 1.5), Vector3(-45, 16.5, 0.5), Vector3(-60, 21.5, 1.0)]},
	# low over the agora paving into the potter's yard: the hens scatter
	{"t": [5.8, 8.6], "hour": 0.2, "fov": [54.0, 50.0], "caption": "",
		"pos": [Vector3(20.5, 5.55, 2.6), Vector3(18.4, 5.5, 3.5), Vector3(16.9, 5.6, 4.3)],
		"look": [Vector3(15.0, 5.25, 5.6), Vector3(14.4, 5.45, 7.2), Vector3(13.6, 5.8, 9.2)]},
	# arc around the wheel, the kiln smoking behind
	{"t": [8.6, 11.2], "hour": 0.3, "fov": [42.0, 40.0], "caption": "",
		"pos": [Vector3(11.6, 6.05, 6.2), Vector3(12.8, 6.0, 5.8), Vector3(14.2, 6.0, 6.1)],
		"look": [Vector3(13.2, 5.9, 9.0), Vector3(13.4, 5.88, 9.0), Vector3(13.7, 5.88, 9.1)]},
	# down the beach at sunset towards the fisherman and his boat
	{"t": [11.2, 14.0], "hour": 0.62, "fov": [50.0, 46.0], "caption": "",
		"pos": [Vector3(60.5, 4.6, 18.4), Vector3(62.2, 4.1, 17.6), Vector3(63.4, 3.8, 16.8)],
		"look": [Vector3(65.6, 2.6, 14.8), Vector3(66.2, 2.4, 15.0), Vector3(67.2, 2.0, 15.6)]},
	# dusk: across the agora to the gateway and up the stair to the altar fire
	{"t": [14.0, 16.6], "hour": 0.8, "lamps": true, "fov": [52.0, 48.0], "caption": "",
		"pos": [Vector3(29.0, 6.6, 3.5), Vector3(31.4, 6.8, -2.0), Vector3(33.0, 7.4, -6.2)],
		"look": [Vector3(35.5, 7.4, -12.0), Vector3(37.0, 8.8, -15.5), Vector3(40.5, 10.6, -20.0)]},
	# night: up the street between the lit lamps
	{"t": [16.6, 19.6], "hour": 1.0, "lamps": true, "fov": [56.0, 54.0], "caption": "",
		"pos": [Vector3(-6, 8.5, -0.8), Vector3(-13, 10.6, -0.4), Vector3(-20, 12.6, 0.6)],
		"look": [Vector3(-35, 15.2, 1.2), Vector3(-50, 19.0, -0.5), Vector3(-65, 23.4, 1.0)]},
	# night on the hill: between the columns, the city and the strait below
	{"t": [19.6, 25.0], "hour": 1.0, "lamps": true, "fov": [56.0, 62.0], "caption": "",
		"pos": [Vector3(-89, 30.0, 0.4), Vector3(-85.5, 30.2, 0.1), Vector3(-81.0, 30.6, 0.0)],
		"look": [Vector3(-20, 18, 0), Vector3(-5, 14, 0), Vector3(10, 11, 0)]},
]

var _t := 0.0
## --benchmark: same camera path in real time (no fixed fps), frame times recorded.
var benchmark := "--benchmark" in OS.get_cmdline_user_args()
var _frame_ms := PackedFloat32Array()
var _result: Label
var _cam: Camera3D
var _fade: ColorRect
var _ghost: TextureRect
var _shot := -1
var _cut_t := -10.0
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
	# Frozen last frame of the previous shot, faded out for the dissolve.
	_ghost = TextureRect.new()
	_ghost.size = VIEW
	_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ghost.modulate.a = 0.0
	layer.add_child(_ghost)
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
	_title = _label(34, Color("#f2c48c"), Vector2(0, 62))
	_title.text = "PANTICAPAEUM"
	_subtitle = _label(13, Color("#e6d6b4"), Vector2(0, 104))
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


## The shot's hour, snapped (time_override); after dusk every lamp is lit.
func _set_time(shot: Dictionary) -> void:
	Game.time_override = shot.hour
	if shot.get("lamps", false):
		for lamp: Lamp in Game.lamps:
			lamp.interact()


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Uniform Catmull-Rom through three points, ends clamped.
static func _spline(p: Array, u: float) -> Vector3:
	var pts: Array = [p[0]] + p + [p[-1]]
	var seg := clampi(int(u * 2.0), 0, 1)
	var f := u * 2.0 - seg
	var p0: Vector3 = pts[seg]
	var p1: Vector3 = pts[seg + 1]
	var p2: Vector3 = pts[seg + 2]
	var p3: Vector3 = pts[seg + 3]
	return 0.5 * (2.0 * p1 + (p2 - p0) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
			+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * f * f * f)


func _apply(t: float) -> void:
	var idx := SHOTS.size() - 1
	for i in SHOTS.size():
		if t < SHOTS[i].t[1]:
			idx = i
			break
	if idx != _shot:
		if _shot >= 0:
			# The viewport still holds the outgoing shot's last frame.
			var img := get_parent().viewport.get_texture().get_image() as Image
			if img:  # null under the headless dummy renderer
				_ghost.texture = ImageTexture.create_from_image(img)
				_cut_t = t
		_shot = idx
		_set_time(SHOTS[idx])
	var shot: Dictionary = SHOTS[idx]
	var t0: float = shot.t[0]
	var t1: float = shot.t[1]
	var u := clampf((t - t0) / (t1 - t0), 0.0, 1.0)
	# Constant speed inside the film; ease only into the first and out of the last shot.
	if idx == 0:
		u = lerpf(u * u, u, u)  # starts at rest, reaches full speed by the cut
	elif idx == SHOTS.size() - 1:
		u = lerpf(u, 1.0 - (1.0 - u) * (1.0 - u), u)  # full speed in, comes to rest
	var drift := Vector3(sin(t * 0.9) * 0.05, sin(t * 1.3 + 1.0) * 0.035, cos(t * 0.7) * 0.04)
	_cam.global_position = _spline(shot.pos, u) + drift
	_cam.look_at(_spline(shot.look, u), Vector3.UP)
	_cam.rotate_object_local(Vector3.FORWARD, deg_to_rad(sin(t * 0.6) * 0.35))
	_cam.fov = lerpf(shot.fov[0], shot.fov[1], u)

	_ghost.modulate.a = 1.0 - clampf((t - _cut_t) / DISSOLVE, 0.0, 1.0)
	var fade := 1.0 - clampf(t / 1.0, 0.0, 1.0)
	fade = maxf(fade, clampf((t - FADE_OUT[0]) / (FADE_OUT[1] - FADE_OUT[0]), 0.0, 1.0))
	_fade.modulate.a = fade

	var into := t - t0
	var out := t1 - t
	_caption.text = shot.caption
	_caption.modulate.a = clampf(into / 0.5, 0.0, 1.0) * clampf((out - 0.2) / 0.4, 0.0, 1.0) if shot.caption != "" else 0.0
	_title.modulate.a = clampf((t - TITLE_AT) / 0.8, 0.0, 1.0)
	_subtitle.modulate.a = clampf((t - TITLE_AT - 0.6) / 0.6, 0.0, 1.0)
