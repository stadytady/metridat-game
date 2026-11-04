extends District
## The dream that comes in Hecate's abaton. A separate small place far off the
## map (behind the fog no one sees it): a stony path through thick fog under a
## bright moon, a figure standing ahead that is gone when you come close,
## three times, and at the end a burial mound with a stone-lined entrance
## (dromos) and an altar before it, where a bronze mirror lies. After the
## mirror: THE END, credits, and waking in the abaton.
##
## Lying down and waking happen behind a fade to black; the hour jumps to
## DayCycle.DREAM and back, the city's sounds go quiet meanwhile.

const ORIGIN := Vector3(0, 60, 2600)
const LENGTH := 78.0
const HALF_WIDTH := 6.5
const FIGURES_Z := [22.0, 44.0, 63.0]
const VANISH_DIST := 9.0
const MOUND := Vector3(0, 0, 92)
const MOUND_R := 11.0
const MOUND_H := 5.0
const ALTAR := Vector3(0, 0, 76.5)
const ALTAR_TOP := 1.03  # top of the altar's crowning slab
const MIRROR_LIFT := 0.33  # disc centre above it: the handle (0.32) stands on the slab
const MIRROR_LEAN := 70.0  # degrees from lying flat

var figures: Array[Node3D] = []
## Sound of the dream: a low drone, and a dog howling somewhere ahead in the
## fog (the dog was Hecate's animal). Only while dreaming.
var howls := 0
var _drone: AudioStreamPlayer
var _howl: AudioStreamPlayer3D
var _howl_timer: Timer
var _rng := RandomNumberGenerator.new()
var vanished := 0
var ended := false

var _fade: ColorRect
var _end: CanvasLayer
var _mirror_found := false
var _wake_at := Vector3.ZERO


## The mirror model lies face up with its handle along +z. Stood up: tipped
## about x so the face turns to +z and the handle points down, leaning back,
## then turned to face -z, back down the path.
static func mirror_basis() -> Basis:
	return Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, deg_to_rad(MIRROR_LEAN))


## The path's centre line, gently winding (local x for a local z).
static func path_x(z: float) -> float:
	return 3.0 * sin(z / 14.0) * clampf(z / 10.0, 0.0, 1.0) * clampf((ALTAR.z - z) / 12.0, 0.0, 1.0)


## Start, local to the origin: the player stands here, facing along the path.
static func start_point() -> Vector3:
	return ORIGIN + Vector3(0, 0.05, 1.0)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1225
	var kit := MeshKit.new()
	kit.xform = Transform3D(Basis.IDENTITY, ORIGIN)
	_ground(kit, rng)
	_path(kit, rng)
	_mound(kit)
	_altar(kit)
	_walls(kit)
	add_child(kit.build("Dream", &"dirt"))
	_trees(rng)
	_olives()
	_figures()
	# The mirror stands on the altar, leaning back a little, its face to the
	# path and the handle down: seen from afar, catching the moon. (Lying flat
	# it sank into the altar's top and only the marker showed.)
	# Only the model is stood up: the find's collider and marker stay upright.
	var mirror := spawn_inspectable("bronze_mirror", ORIGIN + ALTAR + Vector3(0, ALTAR_TOP, -0.08), 0.0)
	var model := mirror.get_child(0) as Node3D
	model.transform = Transform3D(mirror_basis(), Vector3(0, MIRROR_LIFT, 0))
	_altar_lamp()
	var zone := Area3D.new()
	zone.set_script(preload("res://scripts/world/zone.gd"))
	zone.title = "LOC_DREAM"
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(20, 8, 12)
	cs.shape = sh
	cs.position = ORIGIN + Vector3(0, 2, 4)
	zone.add_child(cs)
	add_child(zone)
	_sound()
	Game.dream_requested.connect(enter)
	Game.discovered.connect(func(d: Discovery, _new: bool) -> void:
		if d.epilogue:
			_mirror_found = true)
	Game.inspect_closed.connect(func() -> void:
		if _mirror_found and Game.dreaming and not ended:
			the_end())


func _ground(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	# Flat where one walks, low dark hills beyond the walls; the fog eats the rest.
	var step := 4.0
	var hill := func(x: float, z: float) -> float:
		var off := absf(x - path_x(z)) - HALF_WIDTH
		return maxf(0.0, off) * 0.18 + sin(x * 0.21 + z * 0.13) * 0.5 * clampf(off / 6.0, 0.0, 1.0)
	for iz in range(-6, 30):
		for ix in range(-12, 12):
			var x0 := ix * step
			var z0 := iz * step
			var a := Vector3(x0, hill.call(x0, z0), z0)
			var b := Vector3(x0 + step, hill.call(x0 + step, z0), z0)
			var c := Vector3(x0 + step, hill.call(x0 + step, z0 + step), z0 + step)
			var d := Vector3(x0, hill.call(x0, z0 + step), z0 + step)
			kit.color = Color.WHITE * rng.randf_range(0.75, 0.95)
			kit.color.a = 1.0
			kit.quad("grass" if rng.randf() < 0.7 else "earth", d, c, b, a)
	kit.color = Color.WHITE
	kit.add_collider(Vector3(0, -0.5, 40), Vector3(96, 1.0, 140))


func _path(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	var z := -2.0
	while z < ALTAR.z - 2.0:
		var x := path_x(z) + rng.randf_range(-0.6, 0.6)
		var r := rng.randf_range(0.35, 0.6)
		kit.blob("rock", Vector3(x, 0.02, z), Vector3(r, 0.06, r * 0.8), 0.2, rng)
		z += rng.randf_range(0.9, 1.6)
	# standing stones along both sides, like a way of graves
	z = 6.0
	while z < ALTAR.z - 6.0:
		for side: float in [-1.0, 1.0]:
			if rng.randf() < 0.55:
				var x := path_x(z) + side * rng.randf_range(3.2, 5.0)
				var h := rng.randf_range(0.8, 1.8)
				kit.blob("rock", Vector3(x, h * 0.5, z + rng.randf_range(-1, 1)), Vector3(0.35, h * 0.6, 0.3), 0.25, rng)
		z += rng.randf_range(5.0, 8.0)


## The burial mound: a low cone of earth and grass, with a dromos (stone-lined
## entrance passage) facing the path, its doorway dark.
func _mound(kit: MeshKit) -> void:
	kit.lathe("grass", PackedVector2Array([Vector2(MOUND_R, -0.2), Vector2(MOUND_R * 0.8, MOUND_H * 0.45), Vector2(MOUND_R * 0.45, MOUND_H * 0.85),
		Vector2(0.0, MOUND_H)]), 14, MOUND, 4.0, false)
	kit.add_collider(MOUND + Vector3(0, MOUND_H * 0.35, 0), Vector3(MOUND_R * 1.4, MOUND_H * 0.7, MOUND_R * 1.4))
	var front := MOUND.z - MOUND_R * 0.86
	for sx: float in [-1.0, 1.0]:
		kit.solid_box("limestone", Vector3(sx * 1.25, 1.2, front + 1.0), Vector3(0.6, 2.4, 3.2), ["bottom"])
	kit.box("limestone", Vector3(0, 2.6, front + 1.0), Vector3(3.2, 0.45, 3.2), [])
	# the dark doorway faces the path (-z): wound to face it
	kit.quad("dark", Vector3(0.95, 0.0, front + 1.8), Vector3(-0.95, 0.0, front + 1.8), Vector3(-0.95, 2.38, front + 1.8), Vector3(0.95, 2.38, front + 1.8))


func _altar(kit: MeshKit) -> void:
	kit.solid_box("limestone", ALTAR + Vector3(0, 0.08, 0), Vector3(1.8, 0.16, 1.2), ["bottom"])
	kit.solid_box("limestone", ALTAR + Vector3(0, 0.55, 0), Vector3(1.3, 0.8, 0.8), ["bottom"], {"pz": "plaster", "nz": "plaster"})
	kit.box("limestone", ALTAR + Vector3(0, 0.98, 0), Vector3(1.45, 0.1, 0.9), ["bottom"])


func _sound() -> void:
	_rng.seed = 516
	_drone = AudioStreamPlayer.new()
	_drone.name = "DreamDrone"
	_drone.stream = preload("res://assets/audio/dream_drone.wav")
	_drone.volume_db = -10.0
	add_child(_drone)
	_howl = AudioStreamPlayer3D.new()
	_howl.name = "DreamHowl"
	_howl.stream = preload("res://assets/audio/dog_howl.wav")
	_howl.unit_size = 25.0
	_howl.max_distance = 200.0
	_howl.volume_db = -6.0
	add_child(_howl)
	_howl_timer = Timer.new()
	_howl_timer.one_shot = true
	_howl_timer.timeout.connect(_howl_once)
	add_child(_howl_timer)
	Game.dream_changed.connect(func(on: bool) -> void:
		if on:
			_drone.play()
			_howl_timer.start(5.0)
		else:
			_drone.stop()
			_howl.stop()
			_howl_timer.stop())


## Somewhere off the path, ahead and to one side, never twice from the same place.
func _howl_once() -> void:
	if not Game.dreaming:
		return
	var cam := get_viewport().get_camera_3d()
	var ahead := cam.global_position.z - ORIGIN.z + _rng.randf_range(25.0, 45.0) if cam else 60.0
	_howl.global_position = ORIGIN + Vector3(_rng.randf_range(-30.0, 30.0), 2.0, ahead)
	_howl.pitch_scale = _rng.randf_range(0.9, 1.08)
	_howl.play()
	howls += 1
	_howl_timer.start(_rng.randf_range(13.0, 22.0))


## A small clay oil lamp burning beside the mirror: the polished face catches
## its glow, so the mirror shines out of the fog instead of standing dark.
func _altar_lamp() -> void:
	var at := ORIGIN + ALTAR + Vector3(0.45, ALTAR_TOP, -0.25)
	var k := MeshKit.new()
	k.lathe("clay", PackedVector2Array([Vector2(0.05, 0.0), Vector2(0.08, 0.03), Vector2(0.06, 0.07)]), 6, at, 1.0, true, "dark", true)
	k.box("clay", at + Vector3(0.09, 0.055, 0), Vector3(0.07, 0.025, 0.03), [])
	k.box("flame", at + Vector3(0.12, 0.1, 0), Vector3(0.04, 0.07, 0.04), [])
	add_child(k.build("AltarLamp"))
	var glow := OmniLight3D.new()
	glow.position = at + Vector3(0.1, 0.25, -0.35)
	glow.light_color = Color(1, 0.7, 0.4)
	glow.omni_range = 3.5
	glow.set_script(preload("res://scripts/world/flicker.gd"))
	glow.base_energy = 1.6
	glow.amount = 0.25
	add_child(glow)


## Invisible walls keep the dreamer on the path; the mound closes the end.
func _walls(kit: MeshKit) -> void:
	var z := -4.0
	while z < MOUND.z:
		for side: float in [-1.0, 1.0]:
			kit.add_collider(Vector3(path_x(z + 2.0) + side * (HALF_WIDTH + 0.5), 2.0, z + 2.0), Vector3(0.5, 4.0, 4.4))
		z += 4.0
	kit.add_collider(Vector3(0, 2.0, -4.5), Vector3(2 * HALF_WIDTH + 2.0, 4.0, 0.5))


func _trees(rng: RandomNumberGenerator) -> void:
	# dead trees and a few cypresses: dark shapes in the fog
	for i in 14:
		var z := rng.randf_range(4.0, 74.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := path_x(z) + side * rng.randf_range(8.0, 16.0)
		if i % 3 == 0:
			place("cypress", ORIGIN + Vector3(x, 0, z), rng.randf_range(0, 360), Vector3.ONE * rng.randf_range(0.9, 1.3))
		else:
			var k := MeshKit.new()
			k.xform = Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)), ORIGIN + Vector3(x, 0, z))
			var h := rng.randf_range(3.0, 5.0)
			k.box("bark", Vector3(0, h / 2.0, 0), Vector3(0.25, h, 0.25), [])
			for j in 3:
				var y := h * (0.5 + 0.15 * j)
				k.xform = k.xform * Transform3D(Basis(Vector3.UP, TAU / 3.0), Vector3.ZERO)
				k.box("bark", Vector3(0.5, y + 0.3, 0), Vector3(1.0, 0.1, 0.1), [])
			add_child(k.build("DeadTree%d" % i))


## Olive bushes by the path, low and grey in the fog. Their own seed, so the
## dead trees keep their places.
func _olives() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 16:
		var z := rng.randf_range(2.0, 70.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := path_x(z) + side * rng.randf_range(2.8, 6.0)
		var s := rng.randf_range(0.45, 0.7)
		place("olive_tree", ORIGIN + Vector3(x, 0, z), rng.randf_range(0, 360), Vector3(s * 1.3, s * 0.8, s * 1.3))


## The figure on the path: a standing person, all dark, who is there until you
## are close. A rigid Figure, not an Npc: nothing to talk to, nothing to hit.
func _figures() -> void:
	for z: float in FIGURES_Z:
		var root := Node3D.new()
		root.name = "Figure%d" % figures.size()
		root.position = ORIGIN + Vector3(path_x(z) + (0.8 if figures.size() % 2 == 0 else -0.8), 0, z)
		root.rotation.y = PI  # faces back down the path, towards the dreamer
		add_child(root)
		var joints := Figure.build(root, "dark")
		Figure.apply_pose(joints, "stand")
		var dark: Material = Mats.get_mat("dark")
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = dark
		figures.append(root)


func _process(_delta: float) -> void:
	if not Game.dreaming:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for f in figures:
		if f.visible and Vector2(f.global_position.x - cam.global_position.x, f.global_position.z - cam.global_position.z).length() < VANISH_DIST:
			f.visible = false  # gone, the PS1 way: a pop, not a fade
			vanished += 1


func _main() -> Node:
	return get_tree().root.get_node_or_null("Main")


func _overlay() -> ColorRect:
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 4
		_main().add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color.BLACK
		_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.modulate.a = 0.0
		layer.add_child(_fade)
	return _fade


func _fade_to(a: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(_overlay(), "modulate:a", a, seconds)
	await tw.finished


## Lying down: fade out, carry the player into the dream, fade in.
func enter() -> void:
	if Game.dreaming:
		return
	var main := _main()
	var player: CharacterBody3D = main.player()
	_wake_at = player.global_position
	Game.ui_blocking = true
	await _fade_to(1.0, 1.4)
	Game.dreaming = true
	Game.dream_changed.emit(true)
	for f in figures:
		f.visible = true
	vanished = 0
	ended = false
	_mirror_found = Game.found.has(&"bronze_mirror")
	player.global_position = start_point()
	player.velocity = Vector3.ZERO
	player.look_at_point(ORIGIN + Vector3(path_x(12.0), 1.6, 12.0))
	await get_tree().create_timer(0.8).timeout
	Game.ui_blocking = false
	Game.mark_ui_closed()
	await _fade_to(0.0, 2.0)


func the_end() -> void:
	ended = true
	Game.ui_blocking = true
	await _fade_to(1.0, 2.0)
	_end = preload("res://scripts/ui/end_screen.gd").new()
	_end.name = "EndScreen"
	_main().add_child(_end)
	_end.woke.connect(wake)
	_end.play()


## Waking: back on the fleece in the abaton, at night, the lamps still lit.
func wake() -> void:
	var player: CharacterBody3D = _main().player()
	Game.dreaming = false
	Game.dream_changed.emit(false)
	player.global_position = _wake_at + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	if _end:
		_end.queue_free()
		_end = null
	await get_tree().create_timer(0.5).timeout
	Game.ui_blocking = false
	Game.mark_ui_closed()
	if not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _fade_to(0.0, 2.0)
