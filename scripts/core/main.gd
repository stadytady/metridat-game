extends Node
## Root. The world renders into a SubViewport at PS1-like internal resolution
## (~640x360), which the container scales up with nearest filtering and a
## 15-bit dither pass. UI layers are drawn at native resolution on top.

const INTERNAL_HEIGHT := 360.0

@onready var screen: SubViewportContainer = $Screen
@onready var viewport: SubViewport = $Screen/Viewport
@onready var world: Node3D = $Screen/Viewport/World


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	Game.settings_changed.connect(_apply_settings)
	_fit()
	_apply_settings()
	$HUD.bind_interactor(player().interactor)
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
		title.started.connect(func() -> void: $HUD.set_visible_ui(true))
		title.open()


func _fit() -> void:
	# Integer shrink keeps every low-res pixel the same size on screen.
	var h := get_viewport().get_visible_rect().size.y
	screen.stretch_shrink = maxi(1, roundi(h / INTERNAL_HEIGHT))
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
