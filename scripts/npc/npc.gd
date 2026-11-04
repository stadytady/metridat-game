class_name Npc
extends StaticBody3D
## A person in the city. Talk with E: the DialoguePanel walks `dialogue`, so a
## conversation can branch. A talkable Npc carries a speech bubble over the
## head, and the head turns to the player when they come close.

@export var npc_id := ""
@export var name_key := ""
## A Dialogue Manager resource; every talkable NPC needs one.
@export var dialogue: DialogueResource
@export var dialogue_start := "start"
@export var pose := "stand"
@export var body_mat := "chiton"
@export var figure_scale := 1.0
@export var talkable := true

var joints := {}
var marker: TalkMarker
var _t := 0.0
var _head_yaw := 0.0
var _marker_y := 0.0


func _ready() -> void:
	collision_layer = 3
	add_to_group(&"npc")
	var body := Node3D.new()
	body.name = "Body"
	body.scale = Vector3.ONE * figure_scale
	add_child(body)
	joints = Figure.build(body, body_mat)
	Figure.apply_pose(joints, pose)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 1.3 if pose != "stand" else 1.75, 0.7) * figure_scale
	cs.shape = shape
	cs.position.y = shape.size.y / 2.0
	add_child(cs)
	_t = randf() * 10.0
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
	var extra := Figure.motion(pose, _t)
	# Turn the head to a nearby player, within what a neck allows.
	var cam := get_viewport().get_camera_3d()
	var want := 0.0
	if cam and talkable:
		var to := global_transform.affine_inverse() * cam.global_position
		if to.length() < 5.0:
			want = clampf(rad_to_deg(atan2(-to.x, -to.z)), -60.0, 60.0)
	_head_yaw = lerpf(_head_yaw, want, 1.0 - exp(-4.0 * delta))
	extra["head"] = extra.get("head", Vector3.ZERO) + Vector3(0, _head_yaw, 0)
	Figure.apply_pose(joints, pose, extra)
	_update_marker()


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
