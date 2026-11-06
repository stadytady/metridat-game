class_name Npc
extends StaticBody3D
## A person in the city. Talk with E: the DialoguePanel walks `dialogue`, so a
## conversation can branch. A talkable Npc carries a speech bubble over the
## head, and the head turns to the player when they come close.
##
## With `patrol` set, the same person paces between local points instead of
## standing still, and stops to face whoever comes up to them.

## How close the player has to be for a pacing Npc to stop and turn.
const ATTENTION := 6.0
## Distance covered by one stride, so the step matches the walk speed.
const STRIDE := 1.1

@export var npc_id := ""
@export var name_key := ""
## A Dialogue Manager resource; every talkable NPC needs one.
@export var dialogue: DialogueResource
@export var dialogue_start := "start"
@export var pose := "stand"
@export var body_mat := "chiton"
## Overrides Figure.look_for(npc_id) when set.
@export var look := {}
@export var figure_scale := 1.0
@export var talkable := true

## Local offsets from the spawn that this person walks between, in order.
@export var patrol := PackedVector3Array()
@export var patrol_speed := 0.55
@export var patrol_pause := 2.6
## Pose taken at each waypoint, cycled: the actor thinks, then rehearses.
@export var patrol_poses := PackedStringArray(["think", "declaim"])
## Seconds at each waypoint, in order; missing entries take patrol_pause. A
## zero walks straight on: a corner to turn on the way somewhere.
@export var patrol_pauses := PackedFloat32Array()
## Which way to face at each waypoint (yaw in degrees, as rotation.y); NAN or a
## missing entry keeps the heading he arrived with. Sitting down needs it.
@export var patrol_faces := PackedFloat32Array()
## Background folk keep walking past the player instead of stopping to face them.
@export var stops_for_player := true

## Emitted on arriving at a waypoint, before its pause: the scene hangs props
## on it (an armful of logs picked up here, put down there).
signal reached(index: int)
## Emitted when the pause at a waypoint runs out and he sets off again (at
## once for a zero pause): the bread comes off the oven wall here.
signal departed(index: int)

var joints := {}
## Walking with the arms full: the arms stay in the carry pose, only the legs stride.
var carrying := false
## The pose the arms keep while carrying: hugging a load, or a jar on the head.
@export var carry_pose := "carry"
## Walk on the ground's own height (Topo.surface) instead of the spawn's: for a
## round over paving that falls with the street.
@export var follow_ground := false
var marker: TalkMarker
var _t := 0.0
var _head_yaw := 0.0
var _marker_y := 0.0

var _home := Vector3.ZERO
var _waypoint := 0
var _pause_left := 0.0
var _stride := 0.0
var _face := 0.0
var _pose_now := ""
var _step: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 3
	add_to_group(&"npc")
	var body := Node3D.new()
	body.name = "Body"
	body.scale = Vector3.ONE * figure_scale
	add_child(body)
	# a look of their own: named people from Figure.LOOKS, passers-by by place
	var key := npc_id if not npc_id.is_empty() else "%d,%d" % [roundi(position.x * 10.0), roundi(position.z * 10.0)]
	joints = Figure.build(body, body_mat, look if not look.is_empty() else Figure.look_for(key))
	Figure.apply_pose(joints, pose)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 1.3 if pose != "stand" else 1.75, 0.7) * figure_scale
	cs.shape = shape
	cs.position.y = shape.size.y / 2.0
	add_child(cs)
	_t = randf() * 10.0
	_pose_now = pose
	_home = position
	_face = rotation.y
	if not patrol.is_empty():
		# sandals on stone, one per step, for anyone who walks
		_step = AudioStreamPlayer3D.new()
		_step.stream = preload("res://assets/audio/sandals.wav")
		_step.volume_db = -23.0
		_step.unit_size = 1.0
		_step.max_distance = 10.0
		_step.position.y = 0.1
		add_child(_step)
	if talkable:
		marker = TalkMarker.new()
		marker.name = "TalkMarker"
		_marker_y = (1.75 if pose == "stand" else 1.25) * figure_scale + 0.14
		marker.position.y = _marker_y
		add_child(marker)


func can_interact() -> bool:
	return talkable


func get_prompt() -> String:
	return tr("UI_TALK") % tr(name_key)


func interact() -> void:
	Game.dialogue_requested.emit(self)


func _process(delta: float) -> void:
	_t += delta
	var walking := _pace(delta)
	var extra := Figure.step_motion(_stride) if walking else Figure.motion(_pose_now, _t)
	if walking and carrying:
		_pose_now = carry_pose
		extra.erase("l_shoulder")
		extra.erase("r_shoulder")
	# Turn the head to a nearby player, within what a neck allows.
	var cam := get_viewport().get_camera_3d()
	var want := 0.0
	if cam and talkable:
		var to := global_transform.affine_inverse() * cam.global_position
		if to.length() < 5.0:
			want = clampf(rad_to_deg(atan2(-to.x, -to.z)), -60.0, 60.0)
	_head_yaw = lerpf(_head_yaw, want, 1.0 - exp(-4.0 * delta))
	extra["head"] = extra.get("head", Vector3.ZERO) + Vector3(0, _head_yaw, 0)
	Figure.apply_pose(joints, _pose_now, extra)
	_update_marker()


## Walk the patrol, unless the player has come up: then stand, face them and let
## the current pose (thinking, declaiming, plain standing) play out. Returns
## true while actually walking, which is when the step motion drives the legs.
func _pace(delta: float) -> bool:
	if patrol.is_empty() or Game.ui_blocking:
		return false
	var player := _player()
	if stops_for_player and player != null and global_position.distance_to(player.global_position) < ATTENTION:
		# Someone sitting down only turns the head: swinging the whole seated
		# body round would put the legs through the seat. Nor does anyone turn
		# their back on the work they are facing at a waypoint.
		var busy := _pause_left > 0.0 and not is_nan(face_at(_waypoint))
		if not seated() and not busy:
			_face_towards(global_position.direction_to(player.global_position), delta)
		# stopped mid-stride: stand, or keep holding the load, never drop into
		# the home pose (a baker would kneel in the middle of the yard)
		if _pose_now == "walk" or (carrying and _pose_now == carry_pose):
			_pose_now = carry_pose if carrying else "stand"
		return false
	if _pause_left > 0.0:
		_pause_left = maxf(0.0, _pause_left - delta)
		var yaw := face_at(_waypoint)
		if not is_nan(yaw):
			_face_towards(Vector3(-sin(yaw), 0, -cos(yaw)), delta)
		if _pause_left == 0.0:
			departed.emit(_waypoint)
			_waypoint = (_waypoint + 1) % patrol.size()
		return false
	var to := _home + patrol[_waypoint] - position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.06:
		_pause_left = pause_at(_waypoint)
		_pose_now = patrol_poses[_waypoint % patrol_poses.size()]
		reached.emit(_waypoint)
		if _pause_left <= 0.0:
			departed.emit(_waypoint)
			_waypoint = (_waypoint + 1) % patrol.size()
		return false
	var step := minf(patrol_speed * delta, dist)
	position += to / dist * step
	if follow_ground:
		global_position.y = Topo.surface(global_position.x, global_position.z)
	var before := _stride
	# a boy's stride is shorter than a man's
	_stride = fposmod(_stride + step / (STRIDE * figure_scale), 1.0)
	# two steps per stride: at the half, and at the wrap
	if _step != null and ((before < 0.5 and _stride >= 0.5) or before > _stride):
		_step.pitch_scale = randf_range(0.9, 1.1)
		_step.play()
	_face_towards(to / dist, delta)
	_pose_now = "walk"
	return true


func pause_at(i: int) -> float:
	return patrol_pauses[i] if i < patrol_pauses.size() else patrol_pause


func face_at(i: int) -> float:
	return deg_to_rad(patrol_faces[i]) if i < patrol_faces.size() and not is_nan(patrol_faces[i]) else NAN


func pose_now() -> String:
	return _pose_now


## True in a pose that rests the hips on something (Figure.SEAT well under standing).
func seated() -> bool:
	return float(Figure.SEAT.get(_pose_now, 0.92)) < 0.7


func _face_towards(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	_face = lerp_angle(_face, atan2(-dir.x, -dir.z), 1.0 - exp(-7.0 * delta))
	rotation.y = _face


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


## The bubble bobs on the 15 fps clock the rest of the city moves on, hides while
## any panel is open, and goes quiet once the player has heard this person out.
func _update_marker() -> void:
	if marker == null:
		return
	# Hang it off the head joint: a baker leaning over the oven and an actor
	# declaiming upright do not have their heads at the same height.
	var head: Node3D = joints.get("head")
	if head != null:
		_marker_y = head.global_position.y - global_position.y + 0.55 * figure_scale
	marker.visible = not Game.ui_blocking
	var step := floorf(_t * 15.0) / 15.0
	marker.position.y = _marker_y + sin(step * 2.2) * 0.03
	var heard: bool = Game.talked.get(npc_id, false)
	marker.modulate = Color(0.62, 0.57, 0.47, 0.85) if heard else Color.WHITE
