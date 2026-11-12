extends Node
## Root. The world renders into a SubViewport at a low internal resolution
## (1280x720 for a 16:9 window), which the container scales up with a 15-bit
## dither pass and "sharp bilinear" sampling (psx_post): every low-res pixel
## stays one flat colour and only the one screen pixel on a seam is blended, so
## a scale of 1.5 does not turn into columns 1, 2, 1, 2 screen pixels wide. UI
## layers are drawn at native resolution on top.

## Height of the low-res image. The window's canvas is 1080 units tall
## (canvas_items stretch), so this is a scale of 1.5 on the canvas: 1.5 screen
## pixels per low-res pixel at 1080p, exactly 2 at 1440p and 3 at 4K.
const INTERNAL_HEIGHT := 720.0

## True once a played walk has started: automation never writes a save.
var _saving := false

## Render the world at the window's full resolution (the trailer without PS1 effects).
var native := false

@onready var screen: SubViewportContainer = $Screen
@onready var viewport: SubViewport = $Screen/Viewport
@onready var world: Node3D = $Screen/Viewport/World


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	Game.settings_changed.connect(_apply_settings)
	_fit()
	_apply_settings()
	$HUD.bind_interactor(player().interactor)
	# The way-book on Tab: quests and achievements. It sits above the other panels.
	var goals := GoalsPanel.new()
	goals.name = "GoalsPanel"
	add_child(goals)
	# Developer menu on the tilde key: the hour, and a jump to any viewpoint.
	var admin := AdminPanel.new()
	admin.name = "AdminPanel"
	add_child(admin)
	$PauseMenu.closed.connect(func() -> void: capture_mouse(true))
	# Panels with a free cursor (info, journal) hand the mouse back on close.
	# On the web, pointer lock needs a click, which the HUD asks for.
	Game.inspect_closed.connect(func() -> void:
		if not OS.has_feature("web"):
			capture_mouse(true))
	if "--trailer" in OS.get_cmdline_user_args() or "--benchmark" in OS.get_cmdline_user_args():
		var trailer: Node = load("res://scripts/core/trailer.gd").new()
		trailer.name = "Trailer"
		add_child(trailer)
	elif "--shots" in OS.get_cmdline_user_args() or "--walkthrough" in OS.get_cmdline_user_args() \
			or Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--clip=")):
		var director: Node = load("res://scripts/core/director.gd").new()
		director.name = "Director"
		add_child(director)
	else:
		# Start screen first; START captures the mouse from inside the click,
		# which is also what browsers need for pointer lock.
		var title: CanvasLayer = load("res://scripts/ui/title_screen.gd").new()
		title.name = "TitleScreen"
		add_child(title)
		$HUD.set_visible_ui(false)
		title.started.connect(func() -> void:
			$HUD.set_visible_ui(true)
			# the evening before: off the ship, a word with Damon, then morning
			var prologue := Prologue.new()
			prologue.name = "Prologue"
			add_child(prologue)
			prologue.begin()
			_start_saving())
		title.continued.connect(func() -> void:
			$HUD.set_visible_ui(true)
			_restore(SaveGame.read())
			_start_saving())
		title.open(SaveGame.exists())


## How big the world's image is for a window (canvas) of this size, and the
## scale it is drawn at: never upscaled past the window, never below 1.
static func render_scale(window: Vector2, full: bool) -> float:
	return 1.0 if full else maxf(1.0, window.y / INTERNAL_HEIGHT)


static func render_size(window: Vector2, full: bool) -> Vector2i:
	var s := render_scale(window, full)
	return Vector2i(ceili(window.x / s - 0.001), ceili(window.y / s - 0.001))


func _fit() -> void:
	var win := get_viewport().get_visible_rect().size
	var s := render_scale(win, native)
	# The container draws the viewport at its own size, scaled by s: a
	# non-integer stretch_shrink is not possible, a scale is.
	screen.stretch = false
	viewport.size = render_size(win, native)
	screen.scale = Vector2(s, s)
	RenderingServer.global_shader_parameter_set(&"psx_resolution", Vector2(viewport.size))


func _apply_settings() -> void:
	(screen.material as ShaderMaterial).set_shader_parameter(&"enabled", Game.psx_effects)
	RenderingServer.global_shader_parameter_set(&"psx_affine", 1.0 if Game.psx_effects else 0.0)
	if not Game.psx_effects:
		RenderingServer.global_shader_parameter_set(&"psx_resolution", Vector2(4096, 4096))
	else:
		_fit()


func capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func player() -> CharacterBody3D:
	return world.get_node("Player")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player().add_look(event.screen_relative)
	elif event is InputEventMouseButton and event.pressed and not Game.ui_blocking \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		capture_mouse(true)


## Puts a saved walk back: the state first (Game, lamps, markers), then the
## player where they stood.
func _restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	SaveGame.apply(data)
	var p := player()
	p.global_position = data.get("pos", p.global_position)
	p.rotation.y = float(data.get("yaw", p.rotation.y))


## From the first step of a played walk on (never in automation): save on every
## find, errand and lamp, every SaveGame.AUTOSAVE_SECONDS, and on quit.
func _start_saving() -> void:
	_saving = true
	Game.discovered.connect(func(_d: Discovery, _new: bool) -> void: save_now())
	Game.quest_changed.connect(func(_id: String, _s: int) -> void: save_now())
	Game.lamp_lit.connect(func(_l: int, _t: int) -> void: save_now())
	Game.save_requested.connect(save_now)
	var timer := Timer.new()
	timer.wait_time = SaveGame.AUTOSAVE_SECONDS
	timer.autostart = true
	timer.timeout.connect(save_now)
	add_child(timer)


## Writes the walk now, unless it is in the prologue or the dream: those are
## left and entered behind their own fades, and a walk is resumed in the city.
func save_now() -> void:
	if not _saving or Game.prologue or Game.dreaming:
		return
	var p := player()
	SaveGame.write(SaveGame.snapshot(p.global_position, p.rotation.y))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()
