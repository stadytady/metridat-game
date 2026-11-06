class_name Prologue
extends Node
## The evening before. First the voyage in: the Swallow comes up the strait at
## dusk while a legend of the place runs under her (UI_LEGEND_*), seen first
## from the water alongside and then from her bow as the city comes up; any key
## skips it. Then a cut, and the dreamer stands on the pier and Damon, her
## skipper, talks with them (data/dialogues/prologue.dialogue).
## When the talk ends, or on Esc, the night: dark, then the town from the
## Swallow's stern under the night sky, where Damon told them to sleep; dark
## again, the same view at first light, and the camera leaves the ship, goes
## along the pier and up through the town to the hill, where it turns round
## and becomes the player's eyes: the game begins there as it always did. Any
## key skips the night and the climb. The hour is Game.prologue_hour until
## then (Game.time_target), so no district sets the light itself.

signal finished

const DIALOGUE := preload("res://data/dialogues/prologue.dialogue")
const NPC_ID := "sailor"
const DARK := 1.2  # seconds to black and back
## The night and the morning after the talk: the hours, how long each view is
## held, the climb to the hill and the turn at its end.
const NIGHT_HOUR := 1.0
const DAWN_HOUR := 0.0
const NIGHT_HOLD := 3.6
const DAWN_HOLD := 2.6
const ASCENT := 11.0
const TURN := 0.18  # the last part of the climb, turning round to the town
## Where they sleep: an eye standing on the after deck, in the ship's own frame
## (the bow is +x), looking aft over the stern rail at the town and up to the
## temple on its height (NIGHT_LOOK, world).
const STERN_EYE := Vector3(-1.5, 3.4, -0.3)
const NIGHT_LOOK := Vector3(30.0, 9.0, -14.0)
## How high over the ground the camera climbs, and how far ahead it looks.
const CLIMB_EYE := 2.6
const LOOK_AHEAD := 9.0
## Keys pressed this soon after the talk closed belong to the talk, not a skip.
const SKIP_GUARD := 0.6

## The voyage: seconds at sea, when the camera moves from alongside to the bow,
## and the legend - [key, from, to] in seconds.
const VOYAGE := 24.0
const BOW_FROM := 11.5
const LEGEND := [
	["UI_LEGEND_1", 1.0, 6.4],
	["UI_LEGEND_2", 6.9, 12.3],
	["UI_LEGEND_3", 12.8, 18.0],
	["UI_LEGEND_4", 18.5, 23.4],
]
const LEGEND_FADE := 0.6
const CUT := 0.7  # seconds to black and back between the sea and the pier
## Her course, a curve in from the open strait: far out, a bend that keeps her
## between the ships riding at anchor, and in towards the pier.
const COURSE := [Vector3(300, 0, -100), Vector3(180, 0, -70), Vector3(124, 0, -12)]

signal landed

var _voyage_t := -1.0
var _cam: Camera3D
var _legend: Label
var _skip_hint: Label
var _harbour: Node

var _fade: ColorRect
var _outro_t := -1.0
var _outro_skip := false
## Which part of the night is on: "", "night", "dawn", "climb" (the walkthrough looks).
var stage := ""
## How far along the climb the camera is, 0..1 (the shots look at it).
var climb_u := 0.0


## Where the dreamer stands: on the pier's planks by the gangway, on the land
## side of the skipper, so he is seen against the ship and the sunset.
static func arrival_point() -> Vector3:
	var s: Vector3 = load("res://scripts/world/harbour.gd").skipper_pos()
	return Vector3(s.x - 2.2, Topo.PIER_H, Topo.PIER_Z + 0.4)


## Where the Swallow is k (0..1) of the way in. She slows as she nears the
## pier: the curve's parameter runs out on an ease-out.
static func course_at(k: float) -> Vector3:
	var u := 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 1.6)
	var a: Vector3 = COURSE[0]
	var b: Vector3 = COURSE[1]
	var c: Vector3 = COURSE[2]
	return a.lerp(b, u).lerp(b.lerp(c, u), u)


## Her heading (radians about y; the model's bow is +x) along the course.
static func heading_at(k: float) -> float:
	var d := course_at(minf(k + 0.01, 1.0)) - course_at(maxf(k - 0.01, 0.0))
	return atan2(-d.z, d.x)


## Which legend line is up at t seconds into the voyage, "" between lines.
static func legend_at(t: float) -> String:
	for l: Array in LEGEND:
		if t >= float(l[1]) and t < float(l[2]):
			return l[0]
	return ""


## The way up from the stern to the hill, as control points at camera height:
## onto the pier, along it to the shore, over the beach to the gap in the east
## parapet, across the agora and up the street to the summit, ending at `eye`.
static func ascent_points(stern: Vector3, eye: Vector3) -> PackedVector3Array:
	var flat: Array[Vector2] = [
		Vector2(Topo.pier_x1() - 12.0, Topo.PIER_Z), Vector2(Topo.pier_x0() - 1.0, Topo.PIER_Z),
		Vector2(56.0, 6.0), Vector2(36.5, -7.0), Vector2(34.0, -2.0), Vector2(22.0, -0.9),
	]
	# up the street along its own bends, not across the corners of the houses
	var x := Topo.STREET[Topo.STREET.size() - 1].x
	while x > Topo.STREET[0].x:
		flat.append(Vector2(x, Topo.street_z(x)))
		x -= 4.0
	flat.append(Vector2(Topo.STREET[0].x, Topo.STREET[0].z))
	var pts := PackedVector3Array([stern])
	for p: Vector2 in flat:
		pts.append(Vector3(p.x, Topo.surface(p.x, p.y) + CLIMB_EYE, p.y))
	pts.append(eye)
	return pts


## Where the camera is u (0..1) of the way along the climb, by distance, so it
## keeps an even pace over long and short legs; never lower than a head over
## the ground between the points.
static func ascent_at(pts: PackedVector3Array, u: float) -> Vector3:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var want := clampf(u, 0.0, 1.0) * total
	for i in pts.size() - 1:
		var leg := pts[i].distance_to(pts[i + 1])
		if want <= leg or i == pts.size() - 2:
			var p := pts[i].lerp(pts[i + 1], clampf(want / maxf(leg, 0.001), 0.0, 1.0))
			if i > 0 and i < pts.size() - 2:
				p.y = maxf(p.y, Topo.surface(p.x, p.z) + 1.6)
			return p
		want -= leg
	return pts[pts.size() - 1]


static func ascent_length(pts: PackedVector3Array) -> float:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	return total


static func skipper() -> Npc:
	var tree := Engine.get_main_loop() as SceneTree
	for n in tree.get_nodes_in_group(&"npc"):
		if (n as Npc).npc_id == NPC_ID:
			return n
	return null


func begin() -> void:
	_build_overlay()
	var main := get_parent()
	var player: CharacterBody3D = main.player()
	Game.prologue = true
	Game.prologue_changed.emit(true)
	await _voyage()
	player.global_position = arrival_point() + Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	# teleported, not walked in: no zone fires, so name the place here
	Game.location_entered.emit("LOC_SHORE")
	var damon := skipper()
	if damon == null:
		push_warning("prologue: no skipper on the pier")
		await morning()
		return
	player.look_at_point(damon.global_position + Vector3(0, 1.55, 0))
	await _tween(_fade, 0.0, CUT)
	landed.emit()
	await get_tree().create_timer(0.6).timeout
	var panel: Node = main.get_node("DialoguePanel")
	panel.open(damon, DIALOGUE, "start", false)
	await panel.closed
	await morning()


## The Swallow comes in; the legend runs; dark. The player stays where the game
## put them, under the voyage's own camera, and nothing in the world listens to
## input meanwhile (ui_blocking), so the keys only skip.
func _voyage() -> void:
	var main := get_parent()
	_harbour = get_tree().get_first_node_in_group(&"harbour")
	if _harbour == null:
		push_warning("prologue: no harbour, no voyage")
		_fade.modulate.a = 1.0
		return
	Game.ui_blocking = true
	main.get_node("HUD").set_visible_ui(false)
	_cam = Camera3D.new()
	_cam.name = "VoyageCamera"
	_cam.fov = 62.0
	_cam.far = 900.0
	main.world.add_child(_cam)
	_cam.make_current()
	_voyage_t = 0.0
	_follow()
	_fade.modulate.a = 1.0
	_tween(_fade, 0.0, 1.0)
	while _voyage_t < VOYAGE:
		await get_tree().process_frame
	_voyage_t = VOYAGE
	await _tween(_fade, 1.0, CUT)
	_legend.modulate.a = 0.0
	_skip_hint.visible = false
	_harbour.moor()
	(main.player() as CharacterBody3D).camera.make_current()
	_cam.queue_free()
	main.get_node("HUD").set_visible_ui(true)
	Game.ui_blocking = false
	Game.mark_ui_closed()  # the key that skipped must not also talk to Damon


## Straight to the cut, as a key does.
func skip() -> void:
	if _voyage_t >= 0.0 and _voyage_t < VOYAGE:
		_voyage_t = VOYAGE


func voyage_running() -> bool:
	return _voyage_t >= 0.0 and _voyage_t < VOYAGE


func _process(delta: float) -> void:
	if _outro_t >= 0.0:
		_outro_t += delta
		if _outro_t > SKIP_GUARD and (Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"jump") \
				or Input.is_action_just_pressed(&"pause")):
			_outro_skip = true
		return
	if not voyage_running():
		return
	if Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"jump") \
			or Input.is_action_just_pressed(&"pause"):
		skip()
		return
	_voyage_t += delta
	_follow()


## Puts the ship on her course and the camera on her, and the legend on screen.
func _follow() -> void:
	var k := clampf(_voyage_t / VOYAGE, 0.0, 1.0)
	var p := course_at(k)
	var yaw := heading_at(k)
	_harbour.sail(p, yaw)
	var fwd := Vector3(cos(yaw), 0, -sin(yaw))
	var side := Vector3(sin(yaw), 0, cos(yaw))
	if _voyage_t < BOW_FROM:
		# off her quarter on the sunset side, keeping pace with her
		var drift := _voyage_t / BOW_FROM
		_cam.global_position = p - fwd * lerpf(13.0, 7.0, drift) + side * 11.0 + Vector3(0, lerpf(5.5, 3.5, drift), 0)
		_cam.look_at(p + fwd * 4.0 + Vector3(0, 2.2, 0), Vector3.UP)
	else:
		# over her bow, above the rail (the sheer rises to the stem), looking where
		# she goes: the harbour and the hill come up
		var ship: Node3D = _harbour.ship()
		_cam.global_position = ship.global_transform * Vector3(3.2, 3.5, 0.0)
		_cam.look_at(_cam.global_position + fwd * 10.0 + Vector3(0, -0.9, 0), Vector3.UP)
	var key := legend_at(_voyage_t)
	if not key.is_empty():
		_legend.text = tr(key)
	_legend.modulate.a = _legend_alpha(_voyage_t)


static func _legend_alpha(t: float) -> float:
	for l: Array in LEGEND:
		var a: float = l[1]
		var b: float = l[2]
		if t >= a and t < b:
			return minf(clampf((t - a) / LEGEND_FADE, 0.0, 1.0), clampf((b - t) / LEGEND_FADE, 0.0, 1.0))
	return 0.0


## The night at the stern, the dawn, the climb to the hill; then the player.
func morning() -> void:
	var main := get_parent()
	var player: CharacterBody3D = main.player()
	Game.ui_blocking = true
	_outro_t = 0.0
	_outro_skip = false
	await _ramp(_fade, 1.0, DARK)
	main.get_node("HUD").set_visible_ui(false)
	# where the climb ends: the player on the hill, looking over the town as
	# World places them at the start; the camera turns into these eyes
	player.global_position = Topo.spawn_point()
	player.velocity = Vector3.ZERO
	player.look_at_point(Vector3(20, 6, 0))
	_harbour = get_tree().get_first_node_in_group(&"harbour")
	if _harbour != null and not _outro_skip:
		_cam = Camera3D.new()
		_cam.name = "NightCamera"
		_cam.fov = 62.0
		_cam.far = 900.0
		main.world.add_child(_cam)
		_cam.make_current()
		var ship: Node3D = _harbour.ship()
		var stern: Vector3 = ship.global_transform * STERN_EYE
		var eye: Transform3D = player.camera.global_transform
		var pts := ascent_points(stern, eye.origin)
		var town := NIGHT_LOOK
		_cam.global_position = stern
		_cam.look_at(town, Vector3.UP)
		# the night aboard
		stage = "night"
		Game.prologue_hour = NIGHT_HOUR
		await _view(NIGHT_HOLD, "UI_PROLOGUE_NIGHT")
		# first light, the same view
		if not _outro_skip:
			stage = "dawn"
			Game.prologue_hour = DAWN_HOUR
			await _view(DAWN_HOLD, "UI_PROLOGUE_DAWN", false)
		# up through the waking town
		if not _outro_skip:
			stage = "climb"
			var t := 0.0
			var total := ascent_length(pts)
			var from_look := town
			while t < ASCENT and not _outro_skip:
				t += get_process_delta_time()
				var u := smoothstep(0.0, 1.0, clampf(t / ASCENT, 0.0, 1.0))
				climb_u = u
				var at := ascent_at(pts, u)
				var ahead := ascent_at(pts, u + LOOK_AHEAD / total) + Vector3(0, -0.4, 0)
				if u < 0.06:
					ahead = from_look.lerp(ahead, u / 0.06)
				var turn := clampf((u - (1.0 - TURN)) / TURN, 0.0, 1.0)
				var look := ahead.lerp(eye.origin - eye.basis.z * 10.0, smoothstep(0.0, 1.0, turn))
				_cam.global_position = at
				if at.distance_to(look) > 0.01:
					_cam.look_at(look, Vector3.UP)
				await get_tree().process_frame
		if _outro_skip:
			await _ramp(_fade, 1.0, 0.3)
	stage = ""
	Game.prologue = false
	Game.prologue_hour = DayCycle.PROLOGUE
	Game.prologue_changed.emit(false)
	player.camera.make_current()
	if _cam != null:
		_cam.queue_free()
	_legend.modulate.a = 0.0
	main.get_node("HUD").set_visible_ui(true)
	Game.location_entered.emit("LOC_HILL")
	_outro_t = -1.0
	Game.ui_blocking = false
	Game.mark_ui_closed()
	await _tween(_fade, 0.0, 0.4 if _fade.modulate.a > 0.0 else 0.01)
	finished.emit()
	queue_free()


## Up from black on the view the camera holds, the caption low over it, held,
## and (unless it runs on into the climb) back to black. Cut short by a skip.
func _view(hold: float, caption: String, close := true) -> void:
	_legend.text = tr(caption)
	await _ramp(_fade, 0.0, DARK)
	await _ramp(_legend, 1.0, LEGEND_FADE)
	var t := 0.0
	while t < hold and not _outro_skip:
		t += get_process_delta_time()
		await get_tree().process_frame
	await _ramp(_legend, 0.0, LEGEND_FADE)
	if close:
		await _ramp(_fade, 1.0, DARK)


## A fade that a skip cuts short (it jumps to the end).
func _ramp(c: CanvasItem, a: float, seconds: float) -> void:
	var from := c.modulate.a
	var t := 0.0
	while t < seconds and not _outro_skip:
		t += get_process_delta_time()
		c.modulate.a = lerpf(from, a, clampf(t / seconds, 0.0, 1.0))
		await get_tree().process_frame
	c.modulate.a = a


func _tween(c: CanvasItem, a: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", a, seconds)
	await tw.finished


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)
	# the legend sits low, over the water, like a title in an old film
	_legend = Label.new()
	_legend.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_legend.offset_top = -190.0
	_legend.offset_bottom = -70.0
	_legend.offset_left = 160.0
	_legend.offset_right = -160.0
	_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legend.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legend.add_theme_font_size_override("font_size", 28)
	_legend.add_theme_color_override("font_color", Color("#efe2c4"))
	_legend.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.9))
	_legend.add_theme_constant_override("outline_size", 8)
	_legend.modulate.a = 0.0
	layer.add_child(_legend)
	_skip_hint = Label.new()
	_skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.offset_left = -260.0
	_skip_hint.offset_top = -48.0
	_skip_hint.offset_right = -24.0
	_skip_hint.offset_bottom = -16.0
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.text = tr("UI_VOYAGE_SKIP")
	_skip_hint.add_theme_font_size_override("font_size", 16)
	_skip_hint.add_theme_color_override("font_color", Color(0.94, 0.88, 0.76, 0.6))
	layer.add_child(_skip_hint)
