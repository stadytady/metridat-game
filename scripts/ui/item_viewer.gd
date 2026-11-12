class_name ItemViewer
extends SubViewportContainer
## The find, large: its own small 3D world with a fixed studio light (the
## world's hour does not reach it, so a find stays readable at night), shown
## through the same PS1 look as the game — low resolution, nearest upscale,
## 15-bit colour with dither. Turns slowly by itself; drag to turn, wheel to
## zoom, double-click to reset. Renders only while visible.

const INTERNAL := 300  # px; shown at SIZE on screen, an exact 2x
const SIZE := 600
const FOV := 32.0
const FILL := 0.92  # share of the view the model's bounding sphere fills
const SPIN := 0.35  # rad/s while nobody drags
## Tilt of the find towards the camera (positive: seen from above). Flat
## finds (coins, sherds, moulds) are seen from higher up, or they read as a line.
const PITCH := 0.35
const PITCH_FLAT := 0.95

var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D
var _model: Node3D
var _radius := 0.5
var _yaw := 0.0
var _pitch := PITCH
var _rest_pitch := PITCH
var _zoom := 1.0
var _dragging := false


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	stretch = true
	stretch_shrink = SIZE / INTERNAL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = preload("res://assets/materials/psx_post.tres")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.size = Vector2i(INTERNAL, INTERNAL)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.handle_input_locally = false
	_vp.gui_disable_input = true
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#14100c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a7a68")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffe2b8")
	key.light_energy = 1.3
	key.rotation_degrees = Vector3(-40, 35, 0)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#7f96c8")
	rim.light_energy = 0.45
	rim.rotation_degrees = Vector3(-15, 200, 0)
	_vp.add_child(rim)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.near = 0.01
	_vp.add_child(_cam)
	visibility_changed.connect(_on_visibility)
	_on_visibility()


## Bounding sphere radius that frames this AABB, and the camera distance at
## which that sphere fills `fill` of a view with vertical `fov_deg`.
static func fit_distance(aabb: AABB, fov_deg: float, fill: float) -> float:
	return distance_for(aabb.size.length() * 0.5, fov_deg, fill)


static func distance_for(radius: float, fov_deg: float, fill: float) -> float:
	return maxf(radius, 0.01) / sin(deg_to_rad(fov_deg) * 0.5) / clampf(fill, 0.05, 1.0)


## How far to tilt a find towards the camera: flat ones more, so their top
## (the coin face, the painted side of a sherd) faces the viewer.
static func rest_pitch(aabb: AABB) -> float:
	var flat := aabb.size.y < 0.4 * maxf(aabb.size.x, aabb.size.z)
	return PITCH_FLAT if flat else PITCH


## AABB of every mesh under `root`, in root's space.
static func model_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var xf := root.global_transform.affine_inverse() * mi.global_transform
		var b := xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func show_model(scene: PackedScene) -> void:
	if _model:
		# Out of the tree now: a model still waiting to be freed would count
		# in the next one's bounds.
		_pivot.remove_child(_model)
		_model.queue_free()
		_model = null
	_yaw = 0.6
	_zoom = 1.0
	if scene == null:
		return
	_model = scene.instantiate() as Node3D
	_pivot.add_child(_model)
	Mats.apply_to(_model)
	_frame.call_deferred()  # runtime-built models (model_kit) make their meshes in _ready


func _frame() -> void:
	if _model == null:
		return
	var box := model_aabb(_model)
	# Centre the model on the pivot so it turns about its own middle.
	_model.position -= box.get_center()
	_radius = maxf(box.size.length() * 0.5, 0.01)
	_rest_pitch = rest_pitch(box)
	_pitch = _rest_pitch
	_place_camera()


## Bounds of what is shown now (the walkthrough checks it is not empty).
func shown_aabb() -> AABB:
	return model_aabb(_model) if _model else AABB()


func _place_camera() -> void:
	var d := distance_for(_radius, FOV, FILL) / _zoom
	_cam.position = Vector3(0, 0, d)
	_cam.look_at(Vector3.ZERO)
	# Turn about the find's own up axis first, then tilt it towards the camera:
	# the other order tips it sideways as it turns.
	_pivot.basis = Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.UP, _yaw)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _model == null:
		return
	# the right stick turns the find as the mouse drags it
	var st := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down") if InputMap.has_action(&"look_left") else Vector2.ZERO
	if st != Vector2.ZERO:
		_yaw += st.x * 2.5 * delta
		_pitch = clampf(_pitch + st.y * 2.0 * delta, -1.2, 1.2)
	elif not _dragging:
		_yaw += SPIN * delta
	_place_camera()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.double_click:
				_yaw = 0.6
				_pitch = _rest_pitch
				_zoom = 1.0
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom * 1.1, 0.7, 2.5)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom / 1.1, 0.7, 2.5)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_yaw += mm.relative.x * 0.01
		_pitch = clampf(_pitch + mm.relative.y * 0.01, -1.2, 1.2)
		accept_event()


## The panel calls this when it opens and closes: render only while shown.
func set_active(on: bool) -> void:
	if _vp:
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on:
		_dragging = false


func _on_visibility() -> void:
	set_active(is_visible_in_tree())
