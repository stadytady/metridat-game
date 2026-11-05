extends CharacterBody3D
## First-person controller. Look input arrives via add_look() from Main, since
## the world lives in a low-res SubViewport that does not get input events.

@export var walk_speed := 3.4
@export var sprint_speed := 6.0
@export var jump_velocity := 4.3
@export var ground_accel := 12.0
@export var air_accel := 2.5
## Exponential smoothing of the camera; higher is snappier.
@export var look_smoothing := 22.0
@export var bob_amount := 0.035
@export var stride := 1.7
## Ledges up to this height (curbs, steps, thresholds) are climbed automatically.
@export var step_height := 0.4

const CAPSULE_RADIUS := 0.32

const STEPS := {
	&"stone": [preload("res://assets/audio/step_stone_0.wav"), preload("res://assets/audio/step_stone_1.wav"),
			preload("res://assets/audio/step_stone_2.wav"), preload("res://assets/audio/step_stone_3.wav")],
	&"dirt": [preload("res://assets/audio/step_dirt_0.wav"), preload("res://assets/audio/step_dirt_1.wav"),
			preload("res://assets/audio/step_dirt_2.wav"), preload("res://assets/audio/step_dirt_3.wav")],
}

## Footstep sounds started (tests check the audio wiring with it).
var steps_played := 0
## Test hook: when set, replaces keyboard movement (x = strafe, y = back).
var bot_move := Vector2.ZERO
var bot_enabled := false

var _yaw := 0.0
var _pitch := 0.0
var _yaw_target := 0.0
var _pitch_target := 0.0
var _bob := 0.0
var _step_dist := 0.0
var _surface: StringName = &"dirt"
var _spawn: Transform3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interactor: RayCast3D = $Head/Camera3D/Interactor
@onready var footsteps: AudioStreamPlayer3D = $Footsteps

var _cam_base_y := 0.0


func _ready() -> void:
	_yaw = rotation.y
	_yaw_target = _yaw
	_spawn = global_transform
	_cam_base_y = camera.position.y
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(48.0)
	interactor.add_exception(self)
	# So the dog and the pacing actor can see who is walking about.
	add_to_group(&"player")


func add_look(relative: Vector2) -> void:
	if Game.ui_blocking:
		return
	var s := Game.mouse_sensitivity * 0.0022
	_yaw_target -= relative.x * s
	_pitch_target -= relative.y * s * (-1.0 if Game.invert_y else 1.0)
	_pitch_target = clampf(_pitch_target, deg_to_rad(-85), deg_to_rad(85))


## Points the camera at a world position immediately (tests, cutscene hooks).
func look_at_point(p: Vector3) -> void:
	var d := p - camera.global_position
	_yaw_target = atan2(-d.x, -d.z)
	_pitch_target = atan2(d.y, Vector2(d.x, d.z).length())
	_yaw = _yaw_target
	_pitch = _pitch_target
	rotation.y = _yaw
	head.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	var k := 1.0 - exp(-look_smoothing * delta)
	_yaw = lerp_angle(_yaw, _yaw_target, k)
	_pitch = lerpf(_pitch, _pitch_target, k)
	rotation.y = _yaw
	head.rotation.x = _pitch

	var input := Vector2.ZERO
	if bot_enabled:
		input = bot_move
	elif not Game.ui_blocking:
		input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var sprint := Input.is_action_pressed(&"sprint") and not Game.ui_blocking
	var speed := sprint_speed if sprint else walk_speed
	var dir := transform.basis * Vector3(input.x, 0, input.y)
	dir.y = 0
	dir = dir.normalized() * minf(input.length(), 1.0)

	if is_on_floor():
		if Input.is_action_just_pressed(&"jump") and not Game.ui_blocking:
			velocity.y = jump_velocity
	else:
		velocity.y -= _gravity * delta
	var a := ground_accel if is_on_floor() else air_accel
	var target := dir * speed
	var kh := 1.0 - exp(-a * delta)
	velocity.x = lerpf(velocity.x, target.x, kh)
	velocity.z = lerpf(velocity.z, target.z, kh)
	if dir != Vector3.ZERO:
		_step_up(dir * maxf(Vector2(velocity.x, velocity.z).length() * delta, 0.08))
	move_and_slide()
	_track_surface()
	_bob_and_steps(delta, sprint)

	if global_position.y < -15.0:
		respawn()


## CharacterBody3D cannot climb a vertical edge on its own. If the way ahead
## is blocked, probe one capsule radius forward from step_height higher; if
## there is floor there, lift the body onto it and let move_and_slide carry on.
## Walls taller than step_height stay walls.
func _step_up(motion: Vector3) -> void:
	if not is_on_floor() or not test_move(global_transform, motion):
		return
	var up := Vector3.UP * step_height
	if test_move(global_transform, up):
		return
	var raised := global_transform.translated(up)
	# Probe far enough that the capsule's bottom is over the ledge, not its edge.
	var probe := motion.normalized() * (CAPSULE_RADIUS + 0.1)
	if test_move(raised, probe):
		return
	var col := KinematicCollision3D.new()
	if not test_move(raised.translated(probe), -up * 1.25, col) or col.get_normal().y < 0.7:
		return
	var lift := step_height + col.get_travel().y
	if lift > 0.01:
		global_position.y += lift + 0.01


func respawn() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO


func _track_surface() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y > 0.6:
			var col := c.get_collider()
			if col and col.has_meta(&"surface"):
				_surface = col.get_meta(&"surface")
			return


func _bob_and_steps(delta: float, sprint: bool) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and hspeed > 0.6
	if moving:
		_bob += delta * hspeed * 2.2
		_step_dist += hspeed * delta
		var s := stride * (1.25 if sprint else 1.0)
		if _step_dist >= s:
			_step_dist = 0.0
			var set_: Array = STEPS.get(_surface, STEPS[&"dirt"])
			footsteps.stream = set_[randi() % set_.size()]
			footsteps.pitch_scale = randf_range(0.9, 1.1)
			footsteps.play()
			steps_played += 1
	var amp := bob_amount * clampf(hspeed / walk_speed, 0.0, 1.6) if moving else 0.0
	var target_y := _cam_base_y + sin(_bob * 2.0) * amp
	camera.position.y = lerpf(camera.position.y, target_y, 1.0 - exp(-14.0 * delta))
	var fov := 78.0 if sprint and moving else 72.0
	camera.fov = lerpf(camera.fov, fov, 1.0 - exp(-6.0 * delta))
