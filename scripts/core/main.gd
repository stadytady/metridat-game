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
	if "--trailer" in OS.get_cmdline_user_args() or "--benchmark" in OS.get_cmdline_user_args():
		var trailer: Node = load("res://scripts/core/trailer.gd").new()
		trailer.name = "Trailer"
		add_child(trailer)
	elif "--shots" in OS.get_cmdline_user_args() or "--walkthrough" in OS.get_cmdline_user_args():
		var director: Node = load("res://scripts/core/director.gd").new()
		director.name = "Director"
		add_child(director)
	else:
		capture_mouse(true)


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
